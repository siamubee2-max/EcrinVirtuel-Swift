import SwiftUI
import RevenueCat
import UserNotifications

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
                        // Aligner l'identité RevenueCat sur le compte Supabase AVANT
                        // de lire les entitlements (sinon ils sont device-scoped).
                        await RevenueCatService.logIn(userId: user.id.uuidString)
                    }

                    // 2. Restaurer le statut d'abonnement depuis RevenueCat.
                    // Résolution par productIdentifier — même convention que l'achat.
                    if let info = try? await Purchases.shared.customerInfo() {
                        appState.subscription = RevenueCatService.resolveStatus(from: info)
                    }

                    // 3. Synchroniser les crédits et le profil gaming depuis Supabase.
                    await CreditsManager.shared.sync()
                    if appState.currentUser != nil {
                        await GamingService.shared.syncFromSupabase()
                        // Streak + XP de connexion quotidienne (idempotent par jour).
                        GamingService.shared.recordLogin()
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
                .task {
                    // Répercuter les changements d'entitlement en cours de session
                    // (renouvellement, expiration, refund, restore, logIn/logOut) :
                    // sans ce stream, l'état d'abonnement n'était lu qu'au launch
                    // et après un achat.
                    for await info in Purchases.shared.customerInfoStream {
                        appState.subscription = RevenueCatService.resolveStatus(from: info)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        // La notif quotidienne pose badge=1 ; sans ce reset, la
                        // pastille restait affichée en permanence après la 1re notif.
                        try? await UNUserNotificationCenter.current().setBadgeCount(0)
                        await LookNotificationService.shared.rescheduleIfNeeded()
                    }
                }
                .onOpenURL { url in
                    // Cadeau : ecrin://gift/<uuid> (et variante https du lien partagé)
                    if let giftID = Self.giftID(from: url) {
                        appState.pendingGift = PendingGift(id: giftID)
                        return
                    }
                    // Lien magique Supabase: ecrin://login-callback#access_token=...
                    Task { @MainActor in
                        if let user = await SupabaseService.shared.handleDeepLink(url) {
                            appState.signIn(user: user)
                        }
                    }
                }
        }
    }

    /// Extrait l'UUID d'un lien cadeau — `ecrin://gift/<uuid>` ou
    /// `https://…/ecrin/gift/<uuid>` (universal link, si l'entitlement
    /// Associated Domains est ajouté un jour).
    private static func giftID(from url: URL) -> UUID? {
        let isGiftLink = (url.scheme == "ecrin" && url.host == "gift")
            || url.pathComponents.contains("gift")
        guard isGiftLink else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
