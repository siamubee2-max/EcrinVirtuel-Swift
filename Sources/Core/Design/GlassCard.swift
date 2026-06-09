import SwiftUI

// MARK: - Liquid Glass Card (iOS 26 native + iOS 18 fallback)
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Glass Container (wraps siblings for morphing on iOS 26)
struct GlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - View Helpers for Glass UI

extension View {
    /// Applies a circular glass button background (iOS 26 native / iOS 18 fallback).
    @ViewBuilder
    func glassCircleButton(active: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(active ? .regular.tint(EcrinColor.gold.opacity(0.2)) : .regular, in: .circle)
        } else {
            self
                .background(EcrinColor.glassFill)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5) }
        }
    }

    /// Applies a capsule glass chip background (iOS 26 native / iOS 18 fallback).
    @ViewBuilder
    func glassChip(enabled: Bool = true) -> some View {
        if #available(iOS 26, *), enabled {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
        }
    }
}

// MARK: - Gold Accent Button
struct GoldButton: View {
    let title: String
    var flexible: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EcrinFont.cta)
                .kerning(flexible ? 1.0 : 2.5)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(EcrinColor.background)
                .padding(.horizontal, flexible ? EcrinSpacing.sm : EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
                .frame(maxWidth: flexible ? .infinity : nil)
                .background(EcrinColor.gold)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost Button
struct GhostButton: View {
    let title: String
    var flexible: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(EcrinFont.cta)
                .kerning(flexible ? 1.0 : 2.5)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(EcrinColor.gold)
                .padding(.horizontal, flexible ? EcrinSpacing.sm : EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)
                .frame(maxWidth: flexible ? .infinity : nil)
                .overlay {
                    Capsule()
                        .strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
