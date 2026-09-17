import SwiftUI

// MARK: - Stone Detail View

struct StoneDetailView: View {
    let stone: Stone
    @Environment(\.dismiss) private var dismiss

    @State private var appearPhase: CGFloat = 0
    @State private var chakraRotation: Double = 0

    var body: some View {
        ZStack {
            // Immersive background
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 60)

                    VStack(spacing: EcrinSpacing.xl) {
                        chakraWheelSection
                        virtuesGridSection
                        zodiacSection
                        usageSection
                        pairsSection
                        WellnessDisclaimer()
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }

            // Nav bar
            navigationBar
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appearPhase = 1
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                chakraRotation = 360
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            EcrinColor.background

            // Stone color radial glow at top
            RadialGradient(
                colors: [stone.stoneColor.opacity(0.22), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: 320
            )

            // Subtle noise-like texture using canvas
            Canvas { context, size in
                for _ in 0..<60 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height * 0.4)
                    let r = CGFloat.random(in: 0.5...2.5)
                    context.opacity = Double.random(in: 0.02...0.08)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(stone.stoneColor)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        VStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(EcrinColor.glassFill)
                            .overlay {
                                Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                            }
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(EcrinColor.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(L10n.StoneTherapyUI.lithotherapy)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(stone.stoneColor)
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, 56)

            Spacer()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            // Gem orb
            ZStack {
                // Outer ring (animated)
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [stone.stoneColor.opacity(0.6), stone.stoneColor.opacity(0.1), stone.stoneColor.opacity(0.6)],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(chakraRotation))

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [stone.stoneColor.opacity(0.7), stone.stoneColor.opacity(0.1)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 48
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: stone.stoneColor.opacity(0.6), radius: 24)

                // Gem icon
                Image(systemName: "diamond.fill")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .scaleEffect(appearPhase)
            .opacity(appearPhase)

            // Name
            VStack(spacing: EcrinSpacing.xs) {
                Text(stone.name)
                    .font(EcrinFont.heroTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(stone.englishName)
                    .font(.custom("Cormorant", size: 18).weight(.light))
                    .italic()
                    .foregroundStyle(stone.stoneColor.opacity(0.8))
            }
            .opacity(appearPhase)

            // Intention quote
            Text(stone.intention)
                .font(.custom("Cormorant", size: 18).weight(.light))
                .italic()
                .foregroundStyle(EcrinColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, EcrinSpacing.xl)
                .opacity(appearPhase * 0.85)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.xl)
    }

    // MARK: - Chakra Wheel

    private var chakraWheelSection: some View {
        SectionCard(title: "CHAKRA ASSOCIÉ", icon: "circle.hexagongrid.fill", stone: stone) {
            VStack(spacing: EcrinSpacing.lg) {
                // Wheel
                ChakraWheelView(highlightedChakra: stone.chakra)
                    .frame(height: 220)

                // Info
                HStack(spacing: EcrinSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(stone.chakra.color.opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: stone.chakra.sfSymbol)
                            .font(.system(size: 20, weight: .thin))
                            .foregroundStyle(stone.chakra.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stone.chakra.rawValue)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(stone.chakra.color)
                        Text("Chakra \(stone.chakra.number) sur 7")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }

                    Spacer()

                    // Element badge
                    VStack(spacing: 4) {
                        Image(systemName: stone.element.sfSymbol)
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(stone.element.color)
                        Text(stone.element.rawValue)
                            .font(EcrinFont.label)
                            .kerning(1)
                            .foregroundStyle(stone.element.color)
                    }
                }
            }
        }
    }

    // MARK: - Virtues Grid

    private var virtuesGridSection: some View {
        SectionCard(title: "VERTUS", icon: "sparkles", stone: stone) {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                ForEach(Array(stone.virtues.enumerated()), id: \.offset) { i, virtue in
                    VirtueCard(virtue: virtue, stone: stone, index: i)
                }
            }
        }
    }

    // MARK: - Zodiac

    private var zodiacSection: some View {
        SectionCard(title: "SIGNES COMPATIBLES", icon: "star.fill", stone: stone) {
            HStack(spacing: EcrinSpacing.md) {
                ForEach(stone.zodiac, id: \.self) { sign in
                    ZodiacBadge(sign: sign, stone: stone)
                }
                Spacer()
            }
        }
    }

    // MARK: - Usage Guide

    private var usageSection: some View {
        SectionCard(title: "COMMENT UTILISER CE BIJOU", icon: "person.fill.questionmark", stone: stone) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                Text(stone.usageGuide)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary.opacity(0.8))
                    .lineSpacing(6)

                Divider()
                    .background(EcrinColor.glassStroke)

                // Usage tips
                VStack(spacing: EcrinSpacing.sm) {
                    UsageTip(icon: "moon.stars.fill", text: "Méditation du soir", stone: stone)
                    UsageTip(icon: "sunrise.fill", text: "Intention du matin", stone: stone)
                    UsageTip(icon: "sparkle", text: "Port quotidien conscient", stone: stone)
                }
            }
        }
    }

    // MARK: - Pairs Section

    private var pairsSection: some View {
        SectionCard(title: "PIERRES COMPLÉMENTAIRES", icon: "link.circle.fill", stone: stone) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.md) {
                    ForEach(stone.pairsWith, id: \.self) { pairName in
                        PairStoneThumbnail(name: pairName, sourceStone: stone)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Chakra Wheel View

struct ChakraWheelView: View {
    let highlightedChakra: Chakra

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let chakras = Chakra.allCases

            ZStack {
                // Connecting line (spine)
                Path { path in
                    path.move(to: CGPoint(x: center.x, y: 20))
                    path.addLine(to: CGPoint(x: center.x, y: geo.size.height - 20))
                }
                .stroke(Color.white.opacity(0.06), lineWidth: 1)

                // Chakra circles
                ForEach(Array(chakras.enumerated()), id: \.element.id) { i, chakra in
                    let isHighlighted = chakra == highlightedChakra
                    let yPos = 20 + (CGFloat(i) / CGFloat(chakras.count - 1)) * (geo.size.height - 40)
                    let size: CGFloat = isHighlighted ? 40 : 22

                    ZStack {
                        // Glow for highlighted
                        if isHighlighted {
                            Circle()
                                .fill(chakra.color.opacity(0.3))
                                .frame(width: size + 16, height: size + 16)
                                .blur(radius: 8)
                        }

                        Circle()
                            .fill(isHighlighted ? chakra.color : chakra.color.opacity(0.25))
                            .frame(width: size, height: size)

                        Circle()
                            .strokeBorder(chakra.color.opacity(isHighlighted ? 0.8 : 0.3), lineWidth: 1)
                            .frame(width: size, height: size)

                        if isHighlighted {
                            Image(systemName: chakra.sfSymbol)
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                    }
                    .position(x: center.x, y: yPos)

                    // Label
                    if isHighlighted {
                        Text(chakra.rawValue)
                            .font(EcrinFont.caption)
                            .foregroundStyle(chakra.color)
                            .position(x: center.x + 44, y: yPos)
                    }
                }
            }
        }
    }
}

// MARK: - Section Card

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let stone: Stone
    let content: Content

    init(title: String, icon: String, stone: Stone, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.stone = stone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(stone.stoneColor)
                Text(title)
                    .font(EcrinFont.label)
                    .kerning(2.5)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            content
        }
        .padding(EcrinSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [stone.stoneColor.opacity(0.15), EcrinColor.glassStroke],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
    }
}

// MARK: - Virtue Card

private struct VirtueCard: View {
    let virtue: String
    let stone: Stone
    let index: Int

    private let icons = ["sparkle", "moon.fill", "wind", "flame.fill", "leaf.fill", "drop.fill"]

    var body: some View {
        VStack(spacing: EcrinSpacing.sm) {
            Image(systemName: icons[index % icons.count])
                .font(.system(size: 20, weight: .thin))
                .foregroundStyle(stone.stoneColor.opacity(0.9))
                .frame(height: 28)

            Text(virtue)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(EcrinSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(stone.stoneColor.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(stone.stoneColor.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Zodiac Badge

private struct ZodiacBadge: View {
    let sign: String
    let stone: Stone

    var body: some View {
        VStack(spacing: 4) {
            Text(zodiacEmoji(for: sign))
                .font(.system(size: 22))
            Text(sign)
                .font(EcrinFont.label)
                .kerning(0.5)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.vertical, EcrinSpacing.md)
        .padding(.horizontal, EcrinSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(stone.stoneColor.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(stone.stoneColor.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    private func zodiacEmoji(for sign: String) -> String {
        switch sign {
        case "Bélier":    "♈️"
        case "Taureau":   "♉️"
        case "Gémeaux":   "♊️"
        case "Cancer":    "♋️"
        case "Lion":      "♌️"
        case "Vierge":    "♍️"
        case "Balance":   "♎️"
        case "Scorpion":  "♏️"
        case "Sagittaire":"♐️"
        case "Capricorne":"♑️"
        case "Verseau":   "♒️"
        case "Poissons":  "♓️"
        default:          "✨"
        }
    }
}

// MARK: - Usage Tip

private struct UsageTip: View {
    let icon: String
    let text: String
    let stone: Stone

    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(stone.stoneColor.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Pair Stone Thumbnail

private struct PairStoneThumbnail: View {
    let name: String
    let sourceStone: Stone

    private var pairedStone: Stone? {
        StoneDatabase.stone(named: name)
    }

    private var color: Color {
        pairedStone?.stoneColor ?? sourceStone.stoneColor.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: EcrinSpacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.7), color.opacity(0.15)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 24
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: color.opacity(0.4), radius: 8)

                Circle()
                    .strokeBorder(color.opacity(0.5), lineWidth: 0.8)
                    .frame(width: 52, height: 52)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.8))
            }

            Text(name)
                .font(EcrinFont.label)
                .kerning(0.5)
                .foregroundStyle(EcrinColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(width: 68)
                .lineLimit(2)
        }
        .frame(width: 72)
    }
}

// MARK: - Preview

#Preview {
    StoneDetailView(stone: StoneDatabase.all[3])
}
