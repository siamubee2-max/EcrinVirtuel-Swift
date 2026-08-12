import SwiftUI

enum AppPhase {
    case onboarding
    case unauthenticated
    case authenticated
}

private enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

/// Images générées pendant la session — alimente le paywall émotionnel.
@MainActor
enum SessionCreationsStore {
    private(set) static var images: [UIImage] = []

    static func add(_ image: UIImage) {
        images.insert(image, at: 0)
        if images.count > 10 {
            images = Array(images.prefix(10))
        }
    }

    static func reset() {
        images = []
    }
}

/// Cadeau reçu via deep link — wrapper Identifiable pour fullScreenCover(item:).
struct PendingGift: Identifiable {
    let id: UUID
}

@Observable
@MainActor
final class AppState {
    var phase: AppPhase
    var currentUser: User?
    var subscription: SubscriptionStatus = .free

    /// Cadeau en attente d'affichage (deep link ecrin://gift/<uuid>).
    var pendingGift: PendingGift?

    /// Garde-robe de l'utilisateur — source unique partagée dans toute l'app.
    var wardrobe = WardrobeViewModel()

    /// Dernier contexte corporel analysé (Try-On) — alimente le scoring bijoux par sous-ton de peau.
    var lastBodyContext: BodyContext?

    /// Genre vestimentaire pour le Look du Jour (UserDefaults + Supabase Phase 5).
    var preferredGender: ClothingGender? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: WeatherPersistence.preferredGenderKey) else {
                return nil
            }
            return ClothingGender(rawValue: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: WeatherPersistence.preferredGenderKey)
            } else {
                UserDefaults.standard.removeObject(forKey: WeatherPersistence.preferredGenderKey)
            }
        }
    }

    var isFirstRun: Bool {
        !UserDefaults.standard.bool(forKey: WizardConfig.userDefaultsKey)
    }

    var hasCompletedFirstRun: Bool {
        UserDefaults.standard.bool(forKey: WizardConfig.userDefaultsKey)
    }

    init() {
        if UserDefaults.standard.bool(forKey: AppStorageKey.hasCompletedOnboarding) {
            phase = .unauthenticated
        } else {
            phase = .onboarding
        }
    }

    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasCompletedOnboarding)
        phase = .unauthenticated
    }

    func markFirstRunComplete() {
        UserDefaults.standard.set(true, forKey: WizardConfig.userDefaultsKey)
    }

    func signIn(user: User) {
        currentUser = user
        if let gender = user.preferredGender {
            preferredGender = gender
        }
        phase = .authenticated
        // Basculer la garde-robe sur le scope de ce compte et resynchroniser
        // depuis le cloud — l'init de WardrobeViewModel tourne avant la
        // restauration de session, son sync initial ne voit jamais le cloud.
        wardrobe.switchUser(to: user.id.uuidString)
        CreditsManager.shared.syncDetached()
        // Aligner l'identité RevenueCat : indispensable pour que le webhook
        // revenuecat-webhook attribue les achats à ce compte Supabase et que
        // les entitlements suivent le compte (pas l'appareil).
        Task { await RevenueCatService.logIn(userId: user.id.uuidString) }
    }

    func signOut() {
        currentUser = nil
        subscription = .free
        phase = .unauthenticated
        // Aucune donnée du compte précédent ne doit rester visible pour le
        // prochain utilisateur de cet appareil.
        SessionCreationsStore.reset()
        CreditsManager.shared.resetForSignOut()
        wardrobe.switchUser(to: nil)
        Task { await RevenueCatService.logOut() }
    }
}
