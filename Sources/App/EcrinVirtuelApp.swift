import SwiftUI
import RevenueCat
import os.log

@main
struct EcrinVirtuelApp: App {

    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    private let log = Logger(subsystem: "com.ecrin.jewelry", category: "universal-links")

    init() {
        if AppLaunchEnvironment.isUITesting { return }
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
        Purchases.logLevel = .warn
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(ClothingCatalogService.shared)
                .environment(LocationService.shared)
                .environment(WeatherService.shared)
                .preferredColorScheme(.dark)
                .task {
                    // UI-test mode: no live backend. Seed deterministic state and stop.
                    if AppLaunchEnvironment.isUITesting {
                        CreditsManager.shared.remaining = AppLaunchEnvironment.mockCredits
                        return
                    }
                    // 1. Restaurer une session Supabase persistée (auto-login).
                    if let user = await SupabaseService.shared.currentUser() {
                        appState.signIn(user: user)
                    }

                    // 2-6. TOUS les chargements réseau indépendants lancés EN PARALLÈLE.
                    //      Avant, ils étaient séquentiels : le catalogue bijoux (écran
                    //      d'accueil) attendait RevenueCat + crédits + gaming + vêtements
                    //      + météo. En parallèle, chaque écran est prêt dès que SA donnée
                    //      arrive — démarrage nettement plus réactif.
                    LocationService.shared.loadPersisted()
                    WeatherService.shared.loadFromCache()

                    async let subscription: Void = restoreSubscription(appState: appState)
                    async let jewelry: Void    = prefetchJewelryCatalog()
                    async let clothing: Void   = ClothingCatalogService.shared.fetchAll(force: true)
                    async let credits: Void    = CreditsManager.shared.sync()
                    async let gaming: Void     = syncGamingIfSignedIn(appState: appState)
                    async let weather: Void    = fetchWeatherIfLocated()

                    // On attend l'ensemble (chaque service publie déjà son état au fil de l'eau).
                    _ = await (subscription, jewelry, clothing, credits, gaming, weather)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task { await LookNotificationService.shared.rescheduleIfNeeded() }
                    case .background:
                        // Purge les essayages en mémoire (photos utilisateur + résultats IA)
                        // dès la mise en arrière-plan : hygiène mémoire et confidentialité.
                        SessionCreationsStore.reset()
                    default:
                        break
                    }
                }
                .onOpenURL { url in
                    // Custom scheme fallback: ecrin://login-callback#access_token=...
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Universal Links: https://ecrin.app/ecrin/login-callback#...
                    //                  https://ecrin.app/ecrin/gift/<id>
                    guard let url = activity.webpageURL else { return }
                    handleIncomingURL(url)
                }
        }
    }

    // MARK: - Chargements de démarrage (helpers concurrents)

    @MainActor private func prefetchJewelryCatalog() async {
        _ = try? await SupabaseService.shared.fetchJewelryCatalog()
    }

    @MainActor private func syncGamingIfSignedIn(appState: AppState) async {
        if appState.currentUser != nil {
            await GamingService.shared.syncFromSupabase()
        }
    }

    @MainActor private func fetchWeatherIfLocated() async {
        guard let coordinate = LocationService.shared.coordinate else { return }
        await WeatherService.shared.fetchCurrent(
            coordinate: coordinate,
            cityName: LocationService.shared.cityName
        )
    }

    // MARK: - Subscription restore (concurrent au démarrage)

    /// Restaure le tier d'abonnement depuis RevenueCat, avec repli sur le dernier
    /// tier persisté en cas de panne réseau (un abonné payant n'est jamais rétrogradé
    /// à .free le temps d'une session). Exécuté en parallèle des autres chargements.
    @MainActor
    private func restoreSubscription(appState: AppState) async {
        let subscriptionKey = "lastKnownSubscriptionTier"
        do {
            let info = try await Purchases.shared.customerInfo()
            let activeIds = info.entitlements.all.filter { $0.value.isActive }.keys
            let resolved: SubscriptionStatus
            if activeIds.contains(where: { $0.contains("elite") }) {
                resolved = .elite
            } else if activeIds.contains(where: { $0.contains("premium") }) {
                resolved = .premium
            } else if activeIds.contains(where: { $0.contains("starter") || $0 == "premium" }) {
                resolved = .starter
            } else {
                resolved = .free
            }
            appState.subscription = resolved
            UserDefaults.standard.set(resolved.rawValue, forKey: subscriptionKey)
        } catch {
            if let raw = UserDefaults.standard.string(forKey: subscriptionKey),
               let persisted = SubscriptionStatus(rawValue: raw) {
                appState.subscription = persisted
            }
        }
    }

    // MARK: - Deep link / Universal Link handler

    /// Handles both the custom-scheme `ecrin://` URL and the Universal Link
    /// `https://ecrin.app/ecrin/…`. Routes auth callbacks and gift links.
    @MainActor
    private func handleIncomingURL(_ url: URL) {
        // Ne jamais logger l'URL complète : les callbacks d'auth Supabase portent
        // le token dans le fragment (#access_token=…). On loggue seulement schéma+chemin.
        log.info("Incoming URL: \(url.scheme ?? "?", privacy: .public)://\(url.host ?? "?", privacy: .public)\(url.path, privacy: .public)")

        // Lien de parrainage : ecrin://ref/<uuid> ou https://ecrin.app/ecrin/ref/<uuid>
        if let referrer = Self.referralID(from: url) {
            Task { @MainActor in await redeemReferral(referrer) }
            return
        }

        Task { @MainActor in
            if let user = await SupabaseService.shared.handleDeepLink(url) {
                appState.signIn(user: user)
            }
        }
    }

    /// Extrait l'UUID de la marraine d'un lien `…/ref/<uuid>` (scheme custom ou Universal Link).
    static func referralID(from url: URL) -> UUID? {
        var components = url.pathComponents.filter { $0 != "/" }
        if let host = url.host { components.insert(host, at: 0) }   // ecrin://ref/<uuid> → host = "ref"
        guard let refIndex = components.firstIndex(of: "ref"),
              components.indices.contains(refIndex + 1) else { return nil }
        return UUID(uuidString: components[refIndex + 1])
    }

    /// Consomme le parrainage (session anonyme créée au besoin) et affiche le résultat.
    @MainActor
    private func redeemReferral(_ referrer: UUID) async {
        guard await GenerationAuthGate.ensureSession() else { return }
        do {
            _ = try await SupabaseService.shared.redeemReferral(referrerID: referrer)
            await CreditsManager.shared.sync()
            appState.referralMessage = "🎁 Parrainage validé — 3 essais offerts ajoutés à votre solde !"
        } catch {
            let msg = String(describing: error)
            if msg.contains("ALREADY_REDEEMED") {
                appState.referralMessage = "Ce compte a déjà profité d'un parrainage."
            } else if msg.contains("SELF_REFERRAL") {
                appState.referralMessage = "Impossible d'utiliser votre propre lien de parrainage."
            } else if msg.contains("INVALID_CODE") {
                appState.referralMessage = "Ce lien de parrainage n'est plus valide."
            } else {
                appState.referralMessage = "Le parrainage n'a pas pu être appliqué. Réessayez plus tard."
            }
        }
    }
}
