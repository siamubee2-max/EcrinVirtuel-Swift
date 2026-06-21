import SwiftUI
import RevenueCat

@main
struct EcrinVirtuelApp: App {

    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

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

                    // 2. Restaurer le statut d'abonnement depuis RevenueCat.
                    //    On persiste le tier résolu dans UserDefaults pour le restaurer
                    //    en cas de panne réseau au démarrage (Bug C7).
                    let subscriptionKey = "lastKnownSubscriptionTier"
                    do {
                        let info = try await Purchases.shared.customerInfo()
                        let entitlements = info.entitlements.all
                        let activeIds = entitlements.filter { $0.value.isActive }.keys
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
                        // Network/RevenueCat failure — restore last known tier so paying
                        // subscribers aren't downgraded to .free for the session.
                        if let raw = UserDefaults.standard.string(forKey: subscriptionKey),
                           let persisted = SubscriptionStatus(rawValue: raw) {
                            appState.subscription = persisted
                        }
                        // If nothing persisted, appState.subscription stays .free (safe default).
                    }

                    // 3. Synchroniser les crédits et le profil gaming depuis Supabase.
                    await CreditsManager.shared.sync()
                    if appState.currentUser != nil {
                        await GamingService.shared.syncFromSupabase()
                    }

                    // 4. Précharger le catalogue vêtements (95 articles Supabase).
                    await ClothingCatalogService.shared.fetchAll(force: true)

                    // 5. Localisation + météo (cache puis fetch si coordonnées connues).
                    LocationService.shared.loadPersisted()
                    WeatherService.shared.loadFromCache()
                    if let coordinate = LocationService.shared.coordinate {
                        await WeatherService.shared.fetchCurrent(
                            coordinate: coordinate,
                            cityName: LocationService.shared.cityName
                        )
                    }

                    // 6. Précharger le catalogue bijoux.
                    _ = try? await SupabaseService.shared.fetchJewelryCatalog()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await LookNotificationService.shared.rescheduleIfNeeded() }
                }
                .onOpenURL { url in
                    // Lien magique Supabase: ecrin://login-callback#access_token=...
                    Task { @MainActor in
                        if let user = await SupabaseService.shared.handleDeepLink(url) {
                            appState.signIn(user: user)
                        }
                    }
                }
        }
    }
}
