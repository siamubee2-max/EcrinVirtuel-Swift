import SwiftUI

// MARK: - Palette A+B : Noir profond + Gold + Liquid Glass
enum EcrinColor {
    static let background    = Color(hex: "#080808")
    static let surface       = Color(hex: "#1A1A1A")
    static let gold          = Color(hex: "#CA8A04")
    static let goldLight     = Color(hex: "#F5D37A")
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
