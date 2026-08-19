import SwiftUI
import UIKit

enum AppPhase: Equatable {
    case onboarding
    case unauthenticated
    case authenticated
}

private enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

/// Images générées pendant la session — alimente le paywall émotionnel.
// MARK: - SessionCreationsStore
// Persiste TOUTES les images générées sur disque (Application Support/Creations) afin
// qu'elles ne soient JAMAIS perdues : on les retrouve dans le Dressing même après avoir
// glissé/fermé l'écran, mis l'app en arrière-plan ou redémarré. `images` garde en mémoire
// les créations récentes (borné) pour le paywall ; le disque est la source de vérité.

struct SavedCreation: Identifiable, Hashable {
    let id: String        // nom de fichier
    let url: URL
    let date: Date
}

@MainActor
enum SessionCreationsStore {
    private(set) static var images: [UIImage] = []

    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Creations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func add(_ image: UIImage) {
        images.insert(image, at: 0)
        if images.count > 10 { images = Array(images.prefix(10)) }
        persist(image)
    }

    /// Écrit l'image sur disque (JPEG) hors du thread principal.
    private static func persist(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let url = directory.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Toutes les créations persistées, les plus récentes d'abord (métadonnées seulement).
    static func persistedCreations() -> [SavedCreation] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys)) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return SavedCreation(id: url.lastPathComponent, url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    /// Charge une création à la taille d'affichage (downsampling ImageIO, mémoire bornée).
    static func loadImage(_ creation: SavedCreation, maxPixelSize: CGFloat = 1200) -> UIImage? {
        guard let data = try? Data(contentsOf: creation.url) else { return nil }
        return DownsampledImageLoader.downsample(data: data, maxPixelSize: maxPixelSize) ?? UIImage(data: data)
    }

    static func delete(_ creation: SavedCreation) {
        try? FileManager.default.removeItem(at: creation.url)
    }

    /// Vide uniquement le cache mémoire (le disque — donc le Dressing — est conservé).
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

    /// Message de résultat de parrainage (affiché en alerte par RootView).
    var referralMessage: String?

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

    /// Entrée invitée depuis l'onboarding : marque l'onboarding terminé et
    /// ouvre directement l'app avec la session (anonyme) déjà établie.
    func signInAsGuest(user: User) {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasCompletedOnboarding)
        signIn(user: user)
    }

    func markFirstRunComplete() {
        UserDefaults.standard.set(true, forKey: WizardConfig.userDefaultsKey)
    }

    func signIn(user: User) {
        currentUser = user
        if let gender = user.preferredGender {
            preferredGender = gender
        }
        // Comptes fondateur : tier maximal immédiat, sans attendre le
        // round-trip RevenueCat (le stream confirmera avec le même résultat).
        if UnlimitedAccess.isUnlimited(email: user.email) {
            subscription = .elite
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
