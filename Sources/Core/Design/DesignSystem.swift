import SwiftUI
import ImageIO
import UIKit

// MARK: - Palette A+B : Noir profond + Gold + Liquid Glass
enum EcrinColor {
    static let background    = Color(hex: "#080808")
    static let surface       = Color(hex: "#1A1A1A")
    static let gold          = Color(hex: "#C8A85A")  // champagne désaturé (canal bleu remonté) — moins chaud que l'ocre #CA8A04
    static let goldLight     = Color(hex: "#EADFB8")  // champagne pâle
    static let ivory         = Color(hex: "#FAFAF9")
    static let textPrimary   = Color.white
    static let textSecondary  = Color.white.opacity(0.5)
    static let textMuted      = Color.white.opacity(0.45)  // WCAG AA ~5:1 sur #080808
    static let textDecorative = Color.white.opacity(0.25)  // éléments purement visuels
    static let glassStroke   = Color.white.opacity(0.08)
    static let glassFill     = Color.white.opacity(0.04)
}

// MARK: - Typographie Cormorant + Montserrat
enum EcrinFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom("Cormorant", size: size).weight(weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // Tokens — relativeTo: permet au Dynamic Type d'iOS de scaler la fonte custom
    static let heroTitle   = Font.custom("Cormorant", size: 42, relativeTo: .largeTitle).weight(.thin)
    static let sectionHead = Font.custom("Cormorant", size: 28, relativeTo: .title).weight(.light)
    static let cardTitle   = Font.custom("Cormorant", size: 22, relativeTo: .title2).weight(.regular)
    static let label       = Font.system(.caption2, design: .default).weight(.medium)
    static let caption     = Font.system(.caption, design: .default).weight(.light)
    static let body        = Font.system(.body, design: .default).weight(.regular)
    static let cta         = Font.system(.footnote, design: .default).weight(.semibold)
}

// MARK: - Spacing (8pt grid)
enum EcrinSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 40
    static let xxl: CGFloat = 64
}

// MARK: - Animation
enum EcrinAnimation {
    static let springSnap   = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let springBounce = Animation.spring(response: 0.5, dampingFraction: 0.65)
    static let easeSlide    = Animation.easeInOut(duration: 0.4)
    static let glassReveal  = Animation.easeOut(duration: 0.6)
}

// MARK: - Accessible Motion Helper
struct AccessibleTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let standard: AnyTransition
    let reduced: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? reduced : standard)
    }
}

extension View {
    func accessibleTransition(standard: AnyTransition, reduced: AnyTransition = .opacity) -> some View {
        modifier(AccessibleTransition(standard: standard, reduced: reduced))
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Downsampled remote images
//
// AsyncImage décode l'image distante en PLEINE résolution : une photo produit
// 4000×3000 = ~45 Mo de backing store CoreAnimation, même affichée en vignette
// de 100 pt. Sur les grilles (catalogue, garde-robe, communauté, mannequins),
// l'empreinte mémoire dépassait 2,6 Go de CoreAnimation en session longue.
// `DownsampledAsyncImage` télécharge puis décode via ImageIO directement à la
// taille d'affichage (CGImageSourceCreateThumbnailAtIndex) et borne le cache.

actor DownsampledImageLoader {

    static let shared = DownsampledImageLoader()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 128 * 1024 * 1024   // 128 Mo de pixels décodés max
        c.countLimit = 400
        return c
    }()

    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString

        if let hit = cache.object(forKey: key) { return hit }

        if let running = inFlight[key as String] {
            return await running.value
        }

        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse).map({ $0.statusCode < 400 }) ?? true,
                  let image = Self.downsample(data: data, maxPixelSize: maxPixelSize)
            else { return nil }
            return image
        }
        inFlight[key as String] = task
        let image = await task.value
        inFlight[key as String] = nil

        if let image {
            let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
            cache.setObject(image, forKey: key, cost: cost)
        }
        return image
    }

    /// Décode à `maxPixelSize` max (grand côté) sans jamais matérialiser la
    /// pleine résolution en mémoire.
    nonisolated static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Remplacement direct d'`AsyncImage(url:content:)` (API par phases) qui décode
/// à la taille d'affichage. `maxPixelSize` en pixels physiques : ~600 pour une
/// vignette de grille, ~1200 pour une carte pleine largeur, ~2000 pour du plein écran.
struct DownsampledAsyncImage<Content: View>: View {
    let url: URL?
    var maxPixelSize: CGFloat = 600
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else { return }
                if let image = await DownsampledImageLoader.shared.image(for: url, maxPixelSize: maxPixelSize) {
                    phase = .success(Image(uiImage: image))
                } else if !Task.isCancelled {
                    phase = .failure(URLError(.cannotDecodeContentData))
                }
            }
    }
}
