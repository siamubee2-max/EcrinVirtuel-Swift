import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import RevenueCat

// MARK: - Background View Model

@MainActor
final class BackgroundViewModel: ObservableObject {

    // MARK: Published State
    @Published var backgrounds: [BackgroundItem] = BackgroundItem.catalog
    @Published var selectedBackground: BackgroundItem?
    @Published var unlockedByUser: Set<String> = []
    @Published var isApplying: Bool = false
    @Published var selectedCategory: BackgroundCategory = .studio
    @Published var userPhotoBackground: BackgroundItem?

    /// Tier d'abonnement — résolu par le VM lui-même (il est créé hors de la
    /// hiérarchie SwiftUI, sans accès à AppState). customerInfo() est servi
    /// depuis le cache RevenueCat, donc quasi instantané.
    @Published var subscription: SubscriptionStatus = .free

    init() {
        Task { [weak self] in
            let email = try? await SupabaseService.shared.client.auth.session.user.email
            if let info = try? await Purchases.shared.customerInfo() {
                self?.subscription = UnlimitedAccess.effectiveStatus(
                    resolved: RevenueCatService.resolveStatus(from: info),
                    email: email
                )
            } else if UnlimitedAccess.isUnlimited(email: email) {
                self?.subscription = .elite
            }
        }
    }

    // MARK: - Computed

    var filteredBackgrounds: [BackgroundItem] {
        let base = backgrounds.filter { $0.category == selectedCategory }
        if let userBg = userPhotoBackground, selectedCategory == .custom {
            return [userBg] + base
        }
        return selectedCategory == .custom ? [] : base
    }

    func isUnlocked(_ item: BackgroundItem) -> Bool {
        if !item.isPremium && !item.isUnlockableByXP { return true }
        // Fonds XP : débloqués dès que l'XP gagné atteint le seuil affiché.
        // (unlockedByUser n'était écrit nulle part → tuiles verrouillées à vie.)
        if item.isUnlockableByXP {
            return unlockedByUser.contains(item.id)
                || GamingService.shared.profile.totalXP >= item.xpRequired
        }
        // Fonds premium : inclus dans tout abonnement payant.
        return subscription.isSubscribed
    }

    func lockLabel(_ item: BackgroundItem) -> String? {
        guard !isUnlocked(item) else { return nil }
        if item.isUnlockableByXP { return "\(item.xpRequired) XP" }
        return "Premium"
    }

    // MARK: - Actions

    func select(_ item: BackgroundItem) {
        guard isUnlocked(item) else { return }
        withAnimation(EcrinAnimation.springSnap) {
            selectedBackground = item
        }
    }

    func setUserPhoto(_ data: Data) {
        let filename = "user_bg_\(UUID().uuidString)"
        let item = BackgroundItem(
            id: filename,
            name: "Ma Photo",
            category: .custom,
            previewColor: "#333333",
            prompt: "",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .userPhoto(filename: filename)
        )
        userPhotoBackground = item
        selectedBackground = item
    }

    func clearBackground() {
        withAnimation(EcrinAnimation.springSnap) {
            selectedBackground = nil
        }
    }

    // MARK: - Rendering

    /// Compose un fond SwiftUI en UIImage (fond seul, sans la photo essayage)
    func renderBackground(size: CGSize, background: BackgroundItem) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                switch background.source {
                case .solidColor(let hex):
                    UIColor(Color(hex: hex)).setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))

                case .gradient(let hexColors, let angle):
                    let colors = hexColors.map { UIColor(Color(hex: $0)).cgColor }
                    guard let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: colors as CFArray,
                        locations: nil
                    ) else { return }
                    let rad = angle * .pi / 180.0
                    let dx = cos(rad) * size.width
                    let dy = sin(rad) * size.height
                    let cx = size.width / 2
                    let cy = size.height / 2
                    ctx.cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: cx - dx / 2, y: cy - dy / 2),
                        end: CGPoint(x: cx + dx / 2, y: cy + dy / 2),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )

                case .generated, .userPhoto:
                    UIColor(Color(hex: background.previewColor)).setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                }
            }
        }.value
    }

    /// Compose fond + image essayage via CoreImage (centré, scaled to fill)
    func applyBackground(to image: UIImage, background: BackgroundItem) async -> UIImage {
        isApplying = true
        defer { Task { @MainActor in isApplying = false } }

        let size = image.size
        let bgImage = await renderBackground(size: size, background: background)

        return await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                bgImage.draw(in: CGRect(origin: .zero, size: size))
                let aspect = image.size.width / image.size.height
                let targetAspect = size.width / size.height
                var drawRect = CGRect.zero
                if aspect > targetAspect {
                    let h = size.height
                    let w = h * aspect
                    drawRect = CGRect(x: (size.width - w) / 2, y: 0, width: w, height: h)
                } else {
                    let w = size.width
                    let h = w / aspect
                    drawRect = CGRect(x: 0, y: (size.height - h) / 2, width: w, height: h)
                }
                image.draw(in: drawRect)
            }
        }.value
    }
}
