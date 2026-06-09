import SwiftUI

// MARK: - Level Up Celebration View

struct LevelUpCelebrationView: View {
    let newLevel: StyleLevel
    let onDismiss: () -> Void

    @State private var titleScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.1
    @State private var iconGlow: Bool = false
    @State private var perksVisible: Bool = false
    @State private var buttonVisible: Bool = false
    @State private var particlesActive: Bool = false
    @State private var backgroundOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()

            // Particle canvas
            if particlesActive {
                GoldParticlesCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: EcrinSpacing.xl) {
                Spacer()

                // Level icon with glow
                ZStack {
                    Circle()
                        .fill(newLevel.color.opacity(0.12))
                        .frame(width: 140, height: 140)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [newLevel.color, newLevel.color.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .shadow(color: newLevel.color.opacity(iconGlow ? 0.8 : 0.3), radius: iconGlow ? 30 : 10)

                    Image(systemName: newLevel.icon)
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [newLevel.color, EcrinColor.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: newLevel.color.opacity(0.6), radius: 12)
                }
                .scaleEffect(iconScale)
                .animation(EcrinAnimation.springBounce.delay(0.1), value: iconScale)

                // Congratulation & new level
                VStack(spacing: EcrinSpacing.sm) {
                    Text("Félicitations !")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .kerning(3)
                        .textCase(.uppercase)
                        .opacity(titleOpacity)

                    Text(newLevel.title)
                        .font(EcrinFont.heroTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [EcrinColor.ivory, newLevel.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)
                        .shadow(color: newLevel.color.opacity(0.4), radius: 20)

                    Text("Niveau \(newLevel.rawValue) · Nouveau rang atteint")
                        .font(EcrinFont.caption)
                        .foregroundStyle(newLevel.color.opacity(0.7))
                        .opacity(titleOpacity)
                }
                .animation(EcrinAnimation.springBounce.delay(0.25), value: titleScale)

                // Divider
                HStack(spacing: EcrinSpacing.md) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, newLevel.color.opacity(0.4)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(newLevel.color)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [newLevel.color.opacity(0.4), Color.clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
                .padding(.horizontal, EcrinSpacing.xxl)
                .opacity(titleOpacity)

                // Perks unlocked
                if perksVisible {
                    VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                        Text("Avantages débloqués")
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .kerning(2)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, EcrinSpacing.xs)

                        ForEach(Array(newLevel.perks.enumerated()), id: \.offset) { index, perk in
                            PerkRow(text: perk, color: newLevel.color, delay: Double(index) * 0.08)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // CTA
                if buttonVisible {
                    Button(action: onDismiss) {
                        HStack(spacing: EcrinSpacing.sm) {
                            Text("Célébrer !")
                                .font(EcrinFont.cta)
                                .kerning(2.5)
                                .textCase(.uppercase)
                                .foregroundStyle(EcrinColor.background)
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EcrinColor.background)
                        }
                        .padding(.horizontal, EcrinSpacing.xl)
                        .padding(.vertical, EcrinSpacing.md)
                        .background(newLevel.color)
                        .clipShape(Capsule())
                        .shadow(color: newLevel.color.opacity(0.4), radius: 15, y: 5)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }
        }
        .onAppear { startCelebration() }
    }

    private func startCelebration() {
        withAnimation(.easeIn(duration: 0.3)) {
            backgroundOpacity = 0.92
        }

        withAnimation(EcrinAnimation.springBounce.delay(0.1)) {
            iconScale = 1.0
        }

        withAnimation(EcrinAnimation.springBounce.delay(0.25)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            iconGlow = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            particlesActive = true
        }

        withAnimation(EcrinAnimation.glassReveal.delay(0.5)) {
            perksVisible = true
        }

        withAnimation(EcrinAnimation.springBounce.delay(1.0)) {
            buttonVisible = true
        }
    }
}

// MARK: - Perk Row

private struct PerkRow: View {
    let text: String
    let color: Color
    let delay: Double

    @State private var visible = false

    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(text)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : 20)
        .onAppear {
            withAnimation(EcrinAnimation.easeSlide.delay(delay)) {
                visible = true
            }
        }
    }
}


// MARK: - Preview

#if DEBUG
#Preview {
    LevelUpCelebrationView(newLevel: .hauteCouture, onDismiss: {})
}
#endif
