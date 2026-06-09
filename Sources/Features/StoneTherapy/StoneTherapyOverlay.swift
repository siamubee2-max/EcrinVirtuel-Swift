import SwiftUI

// MARK: - Stone Therapy Overlay

/// Floating overlay that appears after jewelry try-on generation
/// when a gemstone is detected in the jewelry item.
struct StoneTherapyOverlay: View {
    let stone: Stone
    let onDismiss: () -> Void
    let onLearnMore: () -> Void

    @State private var isVisible = false
    @State private var particlePhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            card
                .offset(y: isVisible ? 0 : 300)
                .opacity(isVisible ? 1 : 0)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            withAnimation(EcrinAnimation.glassReveal.delay(0.2)) {
                isVisible = true
            }
            withAnimation(
                .linear(duration: 3).repeatForever(autoreverses: false)
            ) {
                particlePhase = .pi * 2
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, EcrinSpacing.md)
                .padding(.bottom, EcrinSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    headerSection
                    virtuesSection
                    chakraSection
                    intentionSection
                    pairsSection
                    actionButtons
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, EcrinSpacing.xxl)
            }
        }
        .background {
            ZStack {
                // Dark glass background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "#0D0D0D").opacity(0.97))

                // Subtle stone color top glow
                VStack {
                    LinearGradient(
                        colors: [stone.stoneColor.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Particle canvas
                Canvas { context, size in
                    drawParticles(context: context, size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .opacity(0.4)

                // Border
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [stone.stoneColor.opacity(0.4), EcrinColor.glassStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.62)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                Text("LITHOTHÉRAPIE")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(stone.stoneColor)

                Text(stone.name)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                Text(stone.englishName)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .italic()
            }

            Spacer()

            // Stone color gem indicator
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [stone.stoneColor.opacity(0.8), stone.stoneColor.opacity(0.2)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: stone.stoneColor.opacity(0.5), radius: 12)

                Circle()
                    .strokeBorder(stone.stoneColor.opacity(0.6), lineWidth: 1)
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
        }
    }

    // MARK: - Virtues

    private var virtuesSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("VERTUS")
                .font(EcrinFont.label)
                .kerning(2.5)
                .foregroundStyle(EcrinColor.textMuted)

            VStack(spacing: EcrinSpacing.xs) {
                ForEach(Array(stone.virtues.prefix(3).enumerated()), id: \.offset) { i, virtue in
                    VirtueRow(virtue: virtue, stone: stone, index: i)
                }
            }
        }
    }

    // MARK: - Chakra

    private var chakraSection: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Chakra circle
            ZStack {
                Circle()
                    .fill(stone.chakra.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Circle()
                    .strokeBorder(stone.chakra.color.opacity(0.5), lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: stone.chakra.sfSymbol)
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(stone.chakra.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("CHAKRA")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                Text(stone.chakra.rawValue)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(stone.chakra.color)
            }

            Spacer()

            // Element
            VStack(alignment: .trailing, spacing: 2) {
                Text("ÉLÉMENT")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                HStack(spacing: 4) {
                    Text(stone.element.rawValue)
                        .font(EcrinFont.body)
                        .foregroundStyle(stone.element.color)
                    Image(systemName: stone.element.sfSymbol)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(stone.element.color)
                }
            }
        }
        .padding(EcrinSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
    }

    // MARK: - Intention

    private var intentionSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            Text("\u{201C}")
                .font(.custom("Cormorant", size: 48).weight(.thin))
                .foregroundStyle(stone.stoneColor.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: 8)

            Text(stone.intention)
                .font(.custom("Cormorant", size: 20).weight(.light))
                .italic()
                .foregroundStyle(EcrinColor.textPrimary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, EcrinSpacing.xl)

            Text("\u{201D}")
                .font(.custom("Cormorant", size: 48).weight(.thin))
                .foregroundStyle(stone.stoneColor.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -8)
        }
    }

    // MARK: - Pairs

    private var pairsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("PIERRES COMPLÉMENTAIRES")
                .font(EcrinFont.label)
                .kerning(2.5)
                .foregroundStyle(EcrinColor.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(stone.pairsWith, id: \.self) { pairName in
                        StoneChip(name: pairName, sourceStone: stone)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: EcrinSpacing.md) {
            GoldButton(title: "En savoir plus") {
                withAnimation(EcrinAnimation.springSnap) {
                    onLearnMore()
                }
            }

            Button {
                withAnimation(EcrinAnimation.springSnap) {
                    onDismiss()
                }
            } label: {
                Text(L10n.Common.close)
                    .font(EcrinFont.caption)
                    .kerning(1.5)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Particles

    private func drawParticles(context: GraphicsContext, size: CGSize) {
        let particleCount = 12
        for i in 0..<particleCount {
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2 + particlePhase
            let radius = CGFloat.random(in: 20...80)
            let x = size.width * 0.5 + cos(angle) * radius * 1.5
            let y = size.height * 0.15 + sin(angle) * radius * 0.5
            let particleSize = CGFloat.random(in: 1...3)

            var point = context
            point.opacity = Double.random(in: 0.1...0.4)
            point.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: particleSize, height: particleSize)),
                with: .color(stone.stoneColor)
            )
        }
    }
}

// MARK: - Virtue Row

private struct VirtueRow: View {
    let virtue: String
    let stone: Stone
    let index: Int

    private let icons = ["sparkle", "moon.stars.fill", "wind"]

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            Image(systemName: icons[index % icons.count])
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(stone.stoneColor.opacity(0.8))
                .frame(width: 24)

            Text(virtue)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary.opacity(0.85))

            Spacer()
        }
        .padding(.vertical, EcrinSpacing.xs)
        .padding(.horizontal, EcrinSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(stone.stoneColor.opacity(0.06))
        }
    }
}

// MARK: - Stone Chip

private struct StoneChip: View {
    let name: String
    let sourceStone: Stone

    private var pairedStone: Stone? {
        StoneDatabase.stone(named: name)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pairedStone?.stoneColor ?? sourceStone.stoneColor.opacity(0.5))
                .frame(width: 8, height: 8)

            Text(name)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background {
            Capsule()
                .fill(EcrinColor.glassFill)
                .overlay {
                    Capsule()
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        EcrinColor.background.ignoresSafeArea()

        // Simulated try-on result
        VStack {
            Spacer()
            Text("Try-on result here")
                .foregroundStyle(.white)
            Spacer()
        }

        StoneTherapyOverlay(
            stone: StoneDatabase.all[0],
            onDismiss: {},
            onLearnMore: {}
        )
    }
}
