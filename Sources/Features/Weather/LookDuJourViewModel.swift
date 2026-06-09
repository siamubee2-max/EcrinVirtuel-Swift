import Foundation
import Observation

// MARK: - LookDuJourViewModel

@Observable
@MainActor
final class LookDuJourViewModel {

    enum DisplayState {
        case idle
        case loading
        case ready(LookRecommendation)
        case stale(LookRecommendation, badge: String)
        case needsGender
        case catalogEmpty
        case offline
        case error(String)
    }

    private(set) var displayState: DisplayState = .idle
    /// Clé pour animations SwiftUI sur changement d'état.
    private(set) var displayStateKey = "idle"
    private(set) var hasActivated = false

    var showLocationPreAlert = false
    var showGenderPicker = false
    var showCitySearch = false
    var showConversionMessage = false
    var showBudgetPicker = false

    /// Maximum item price in EUR for look recommendations. `nil` = no limit.
    var maxBudget: Double? {
        didSet { UserDefaults.standard.set(maxBudget, forKey: Self.budgetKey) }
    }

    static let budgetTiers: [Double?] = [nil, 50, 100, 200, 500]

    private let locationService = LocationService.shared
    private let weatherService = WeatherService.shared
    private let catalogService = ClothingCatalogService.shared
    private let recommender = WeatherLookRecommender()

    private static let activatedKey = "weather.lookDuJour.activated"
    private static let conversionShownKey = "weather.lookDuJour.conversionShown"
    private static let budgetKey = "weather.lookDuJour.maxBudget"

    // MARK: - Lifecycle

    func bootstrap(appState: AppState) async {
        hasActivated = UserDefaults.standard.bool(forKey: Self.activatedKey)
        showConversionMessage = hasActivated && !UserDefaults.standard.bool(forKey: Self.conversionShownKey)
        maxBudget = UserDefaults.standard.object(forKey: Self.budgetKey) as? Double

        if catalogService.totalCount == 0 {
            await catalogService.fetchAll(force: false)
        }
        guard catalogService.totalCount > 0 else {
            setDisplayState(.catalogEmpty)
            return
        }

        if appState.preferredGender == nil {
            setDisplayState(.needsGender)
            return
        }

        if let snapshot = weatherService.snapshot ?? weatherService.loadFromCache(),
           let gender = appState.preferredGender {
            updateRecommendation(snapshot: snapshot, gender: gender, appState: appState)
            if hasActivated { return }
        }

        if hasActivated, locationService.coordinate != nil {
            await refresh(appState: appState, force: false)
        } else {
            setDisplayState(.idle)
        }
    }

    // MARK: - Actions utilisateur

    func onCardTapped(appState: AppState) async {
        if appState.preferredGender == nil {
            showGenderPicker = true
            return
        }

        switch displayState {
        case .idle, .offline, .error:
            await activate(appState: appState)
        case .needsGender:
            showGenderPicker = true
        default:
            break
        }
    }

    func activate(appState: AppState) async {
        guard appState.preferredGender != nil else {
            showGenderPicker = true
            return
        }

        if !hasActivated {
            switch locationService.authStatus {
            case .notDetermined:
                showLocationPreAlert = true
                return
            case .denied, .restricted:
                showCitySearch = true
                return
            case .authorized:
                break
            }
        }

        await performLocateAndFetch(appState: appState, force: true)
    }

    func confirmLocationPermission(appState: AppState) async {
        showLocationPreAlert = false
        await performLocateAndFetch(appState: appState, force: true)
    }

    func refresh(appState: AppState, force: Bool = false) async {
        guard let gender = appState.preferredGender else {
            setDisplayState(.needsGender)
            return
        }

        if catalogService.totalCount == 0 {
            await catalogService.fetchAll(force: force)
            guard catalogService.totalCount > 0 else {
                setDisplayState(.catalogEmpty)
                return
            }
        }

        setDisplayState(.loading)

        if force || locationService.coordinate == nil {
            await locationService.requestPermissionAndLocate()
        }

        guard let coordinate = locationService.coordinate else {
            setDisplayState(.error("Impossible de déterminer votre position."))
            return
        }

        await weatherService.fetchCurrent(
            coordinate: coordinate,
            cityName: locationService.cityName,
            force: force
        )

        guard let snapshot = weatherService.snapshot else {
            if let cached = weatherService.loadFromCache() {
                updateRecommendation(snapshot: cached, gender: gender, appState: appState, offline: true)
            } else {
                setDisplayState(weatherService.lastError != nil ? .offline : .error(
                    weatherService.lastError?.localizedDescription ?? "Météo indisponible."
                ))
            }
            markActivated()
            return
        }

        updateRecommendation(snapshot: snapshot, gender: gender, appState: appState)
        markActivated()
    }

    func setGender(_ gender: ClothingGender, appState: AppState) async {
        appState.preferredGender = gender
        if var user = appState.currentUser {
            user.preferredGender = gender
            appState.currentUser = user
        }
        await SupabaseService.shared.updatePreferredGender(gender)
        showGenderPicker = false
        await refresh(appState: appState, force: true)
    }

    func applyManualCity(_ city: String, appState: AppState) async {
        showCitySearch = false
        setDisplayState(.loading)
        await locationService.locateManually(city: city)
        await refresh(appState: appState, force: true)
    }

    func dismissConversionMessage() {
        showConversionMessage = false
        UserDefaults.standard.set(true, forKey: Self.conversionShownKey)
    }

    /// Sets the budget filter and regenerates the current look immediately.
    func setBudget(_ budget: Double?, appState: AppState) async {
        maxBudget = budget
        if hasActivated {
            await refresh(appState: appState, force: false)
        }
    }

    // MARK: - Private

    private func performLocateAndFetch(appState: AppState, force: Bool) async {
        hasActivated = true
        UserDefaults.standard.set(true, forKey: Self.activatedKey)
        setDisplayState(.loading)
        await locationService.requestPermissionAndLocate()
        await refresh(appState: appState, force: force)
    }

    private func updateRecommendation(
        snapshot: WeatherSnapshot,
        gender: ClothingGender,
        appState: AppState,
        offline: Bool = false
    ) {
        let catalog = catalogForLook(gender: gender, season: snapshot.weatherSeason)
        // Si la garde-robe est vide, on passe un tableau vide pour que le recommender
        // se rabatte sur le catalogue (qui possède de vraies images).
        let wardrobeAll = appState.wardrobe.items
        // Sous-ton de peau depuis le dernier essayage virtuel (affine le choix des bijoux).
        let undertone = appState.lastBodyContext?.skinUndertone
        let recommendation = recommender.recommend(
            weather: snapshot,
            gender: gender,
            catalog: catalog,
            wardrobeItems: wardrobeAll,
            undertone: undertone,
            maxBudget: maxBudget,
            limit: 6
        )

        if offline {
            let age = Self.cacheAgeLabel(since: snapshot.fetchedAt)
            setDisplayState(.stale(recommendation, badge: age))
        } else if snapshot.fetchedAt.timeIntervalSinceNow < -2 * 3600 {
            setDisplayState(.stale(recommendation, badge: Self.cacheAgeLabel(since: snapshot.fetchedAt)))
        } else {
            setDisplayState(.ready(recommendation))
        }
    }

    private func setDisplayState(_ state: DisplayState) {
        // Reset bookmark when a new look is generated.
        switch state {
        case .ready, .stale: currentLookSaved = false
        default: break
        }
        displayState = state
        displayStateKey = Self.key(for: state)
    }

    private static func key(for state: DisplayState) -> String {
        switch state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .ready: return "ready"
        case .stale(_, let badge): return "stale-\(badge)"
        case .needsGender: return "needsGender"
        case .catalogEmpty: return "catalogEmpty"
        case .offline: return "offline"
        case .error(let msg): return "error-\(msg)"
        }
    }

    private func catalogForLook(gender: ClothingGender, season: WeatherSeason) -> [CatalogClothingItem] {
        catalogService.fetchBySeasonAndCategory(season: season, gender: gender)
    }

    private func markActivated() {
        hasActivated = true
        UserDefaults.standard.set(true, forKey: Self.activatedKey)
        // Propose une notification quotidienne à 8 h dès la première activation.
        // Le service demande la permission système si nécessaire.
        Task {
            await LookNotificationService.shared.requestAndSchedule()
        }
    }

    // MARK: - Notification toggle (appelé depuis LookDuJourCard)

    func toggleDailyNotification() {
        if LookNotificationService.shared.userWantsNotification {
            LookNotificationService.shared.cancel()
        } else {
            Task { await LookNotificationService.shared.requestAndSchedule() }
        }
    }

    var dailyNotificationEnabled: Bool {
        LookNotificationService.shared.userWantsNotification
    }

    // MARK: - Lookbook (save)

    private(set) var currentLookSaved = false

    func toggleSave(look: LookRecommendation) {
        currentLookSaved.toggle()
        if currentLookSaved {
            Task.detached { await SupabaseService.shared.saveLook(look) }
        }
    }

    private static func cacheAgeLabel(since date: Date) -> String {
        let hours = Int(Date().timeIntervalSince(date) / 3600)
        if hours < 1 { return "Données récentes" }
        return "⚠️ Données de \(hours) h"
    }
}
