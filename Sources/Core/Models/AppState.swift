import SwiftUI

enum AppPhase: Equatable {
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

@Observable
@MainActor
final class AppState {
    var phase: AppPhase
    var currentUser: User?
    var subscription: SubscriptionStatus = .free

    /// Garde-robe de l'utilisateur — source unique partagée dans toute l'app.
    var wardrobe = WardrobeViewModel()

    /// Dernier contexte corporel analysé (Try-On) — alimente le scoring bijoux par sous-ton de peau.
    var lastBodyContext: BodyContext?

    /// Bijoux sélectionnés depuis un MoodBoard pour essayage AR.
    /// MoodBoardResultView y écrit puis se dismissit ; MoodBoardGalleryView l'observe et ouvre ARTryOnWrapperView.
    var pendingMoodBoardJewelry: [JewelryItem]?

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

    /// Default production initializer.
    convenience init() {
        self.init(launchArguments: ProcessInfo.processInfo.arguments)
    }

    /// Testable initializer. `launchArguments` is injected so UI-test mode is
    /// deterministic and unit-testable without spawning a process.
    init(launchArguments: [String]) {
        if AppLaunchEnvironment.isUITesting(launchArguments) {
            if AppLaunchEnvironment.mockAuthenticated(launchArguments) {
                currentUser = AppLaunchEnvironment.mockUser
                phase = .authenticated
            } else {
                phase = .onboarding
            }
            return
        }
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
    }

    func signOut() {
        currentUser = nil
        subscription = .free
        phase = .unauthenticated
    }
}
