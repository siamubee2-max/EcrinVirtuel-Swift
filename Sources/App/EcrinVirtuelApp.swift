import SwiftUI
import RevenueCat

@main
struct EcrinVirtuelApp: App {

    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
                    // 1. Restaurer une session Supabase persistée (auto-login).
                    if let user = await SupabaseService.shared.currentUser() {
                        appState.signIn(user: user)
                    }

                    // 2. Restaurer le statut d'abonnement depuis RevenueCat.
                    if let info = try? await Purchases.shared.customerInfo() {
                        let entitlements = info.entitlements.all
                        let activeIds = entitlements.filter { $0.value.isActive }.keys
                        if activeIds.contains(where: { $0.contains("elite") }) {
                            appState.subscription = .elite
                        } else if activeIds.contains(where: { $0.contains("premium") }) {
                            appState.subscription = .premium
                        } else if activeIds.contains(where: { $0.contains("starter") || $0 == "premium" }) {
                            appState.subscription = .starter
                        }
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
