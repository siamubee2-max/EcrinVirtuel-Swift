import SwiftUI
import RevenueCat
import UserNotifications
import os.log

@main
struct EcrinVirtuelApp: App {

    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    private let log = Logger(subsystem: "com.ecrin.jewelry", category: "universal-links")

    init() {
        if AppLaunchEnvironment.isUITesting { return }
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
        // En DEBUG, `.debug` nomme chaque identifiant que StoreKit refuse de
        // renvoyer. C'est la seule façon de distinguer une offering mal
        // configurée d'un blocage côté App Store Connect (contrat Paid
        // Applications inactif, produit en « Missing Metadata ») : dans les deux
        // cas `availablePackages` est vide, et `.warn` ne dit rien.
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
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
                        // Aligner l'identité RevenueCat sur le compte Supabase AVANT
                        // de lire les entitlements (sinon ils sont device-scoped).
                        await RevenueCatService.logIn(userId: user.id.uuidString)
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
                .task {
                    // Répercuter les changements d'entitlement en cours de session
                    // (renouvellement, expiration, refund, restore, logIn/logOut) :
                    // sans ce stream, l'état d'abonnement n'était lu qu'au launch
                    // et après un achat.
                    for await info in Purchases.shared.customerInfoStream {
                        appState.subscription = UnlimitedAccess.effectiveStatus(
                            resolved: RevenueCatService.resolveStatus(from: info),
                            email: appState.currentUser?.email
                        )
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        Task {
                            // La notif quotidienne pose badge=1 ; sans ce reset, la
                            // pastille restait affichée en permanence après la 1re notif.
                            try? await UNUserNotificationCenter.current().setBadgeCount(0)
                            await LookNotificationService.shared.rescheduleIfNeeded()
                        }
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
            // Streak + XP de connexion quotidienne (idempotent par jour).
            GamingService.shared.recordLogin()
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
    /// Résolution par productIdentifier — même convention que l'achat et le
    /// customerInfoStream. Les comptes fondateur sont forcés au tier maximal.
    @MainActor
    private func restoreSubscription(appState: AppState) async {
        let subscriptionKey = "lastKnownSubscriptionTier"
        do {
            let info = try await Purchases.shared.customerInfo()
            let resolved = RevenueCatService.resolveStatus(from: info)
            appState.subscription = UnlimitedAccess.effectiveStatus(
                resolved: resolved,
                email: appState.currentUser?.email
            )
            UserDefaults.standard.set(resolved.rawValue, forKey: subscriptionKey)
        } catch {
            let persisted = UserDefaults.standard.string(forKey: subscriptionKey)
                .flatMap(SubscriptionStatus.init(rawValue:)) ?? .free
            appState.subscription = UnlimitedAccess.effectiveStatus(
                resolved: persisted,
                email: appState.currentUser?.email
            )
        }
    }

    // MARK: - Deep link / Universal Link handler

    /// Handles both the custom-scheme `ecrin://` URL and the Universal Link
    /// `https://ecrin.app/ecrin/…`. Routes auth callbacks, gift and referral links.
    @MainActor
    private func handleIncomingURL(_ url: URL) {
        // Ne jamais logger l'URL complète : les callbacks d'auth Supabase portent
        // le token dans le fragment (#access_token=…). On loggue seulement schéma+chemin.
        log.info("Incoming URL: \(url.scheme ?? "?", privacy: .public)://\(url.host ?? "?", privacy: .public)\(url.path, privacy: .public)")

        // Cadeau : ecrin://gift/<uuid> ou https://…/ecrin/gift/<uuid>
        if let giftID = Self.giftID(from: url) {
            appState.pendingGift = PendingGift(id: giftID)
            return
        }

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

    /// Extrait l'UUID d'un lien cadeau — `ecrin://gift/<uuid>` ou
    /// `https://…/ecrin/gift/<uuid>` (Universal Link).
    private static func giftID(from url: URL) -> UUID? {
        let isGiftLink = (url.scheme == "ecrin" && url.host == "gift")
            || url.pathComponents.contains("gift")
        guard isGiftLink else { return nil }
        return UUID(uuidString: url.lastPathComponent)
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
