import SwiftUI

// MARK: - Mood Board Generator View

struct MoodBoardGeneratorView: View {
    @State private var prompt      = ""
    @State private var occasion: MoodOccasion?
    @State private var style: MoodStyle?
    @State private var season: MoodSeason?
    @State private var isGenerating = false
    @State private var generatedBoard: MoodBoard?
    @State private var showResult   = false
    @State private var dotPhase: CGFloat = 0
    @State private var headerVisible = false
    @FocusState private var promptFocused: Bool

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Ambient gradient
            RadialGradient(
                colors: [EcrinColor.gold.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 8)

                    VStack(spacing: EcrinSpacing.xl) {
                        promptSection
                        occasionSection
                        styleSection
                        seasonSection
                        generateButton
                    }
                    .padding(.bottom, EcrinSpacing.xxl)
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }

            // Generating overlay
            if isGenerating {
                generatingOverlay
                    .transition(.opacity)
            }
        }
        .onAppear { headerVisible = true }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showResult) {
            if let board = generatedBoard {
                MoodBoardResultView(board: board)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MOOD BOARD")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 8)
                    .animation(EcrinAnimation.easeSlide, value: headerVisible)

                Text("Créez votre univers")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 8)
                    .animation(EcrinAnimation.easeSlide.delay(0.07), value: headerVisible)
            }
            Spacer()
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 20, weight: .thin))
                .foregroundStyle(EcrinColor.gold.opacity(0.5))
        }
        .padding(.bottom, EcrinSpacing.lg)
    }

    // MARK: - Prompt Field

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Label {
                Text("Décrivez votre moment")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
            } icon: {
                Image(systemName: "text.quote")
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.textMuted)
            }

            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("", text: $prompt, axis: .vertical)
                        .font(EcrinFont.serif(17, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                        .tint(EcrinColor.gold)
                        .lineSpacing(4)
                        .focused($promptFocused)
                        .submitLabel(.done)
                        .lineLimit(3...5)
                        .padding(EcrinSpacing.md)
                        .overlay(alignment: .topLeading) {
                            if prompt.isEmpty {
                                Text("Une soirée élégante à Paris en hiver…")
                                    .font(EcrinFont.serif(17, weight: .light))
                                    .foregroundStyle(EcrinColor.textMuted)
                                    .allowsHitTesting(false)
                                    .padding(EcrinSpacing.md)
                            }
                        }

                    Divider().background(EcrinColor.glassStroke)
                        .padding(.horizontal, EcrinSpacing.md)

                    HStack {
                        Text("Optionnel — affinez avec les filtres ci-dessous")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                        Spacer()
                        Text("\(prompt.count)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(prompt.count > 80 ? EcrinColor.gold : EcrinColor.textMuted)
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, EcrinSpacing.sm)
                }
            }
        }
    }

    // MARK: - Occasion Chips

    private var occasionSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            SelectorLabel(text: "OCCASION", icon: "calendar")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())],
                      spacing: EcrinSpacing.sm) {
                ForEach(MoodOccasion.allCases, id: \.self) { item in
                    OccasionChip(
                        label: item.rawValue,
                        icon: item.icon,
                        isSelected: occasion == item
                    )
                    .onTapGesture {
                        withAnimation(EcrinAnimation.springSnap) {
                            occasion = occasion == item ? nil : item
                        }
                    }
                }
            }
        }
    }

    // MARK: - Style Chips

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            SelectorLabel(text: "STYLE", icon: "paintpalette.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())],
                      spacing: EcrinSpacing.sm) {
                ForEach(MoodStyle.allCases, id: \.self) { item in
                    OccasionChip(
                        label: item.rawValue,
                        icon: item.icon,
                        isSelected: style == item
                    )
                    .onTapGesture {
                        withAnimation(EcrinAnimation.springSnap) {
                            style = style == item ? nil : item
                        }
                    }
                }
            }
        }
    }

    // MARK: - Season Chips

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            SelectorLabel(text: "SAISON", icon: "leaf.circle")

            HStack(spacing: EcrinSpacing.sm) {
                ForEach(MoodSeason.allCases, id: \.self) { item in
                    OccasionChip(
                        label: item.rawValue,
                        icon: item.icon,
                        isSelected: season == item
                    )
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(EcrinAnimation.springSnap) {
                            season = season == item ? nil : item
                        }
                    }
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        let canGenerate = !prompt.isEmpty || occasion != nil || style != nil || season != nil

        return VStack(spacing: EcrinSpacing.sm) {
            Button {
                Task { await generateBoard() }
            } label: {
                HStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(EcrinColor.background)
                    Text("Générer mon look")
                        .font(EcrinFont.cta)
                        .kerning(2.5)
                        .foregroundStyle(EcrinColor.background)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EcrinSpacing.md)
                .background(canGenerate ? EcrinColor.gold : EcrinColor.gold.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canGenerate)
            .buttonStyle(.plain)
            .scaleEffect(canGenerate ? 1 : 0.97)
            .animation(EcrinAnimation.springSnap, value: canGenerate)

            if canGenerate {
                Text("Propulsé par l'IA stylistique de L'Écrin")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(EcrinAnimation.easeSlide, value: canGenerate)
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { } // block pass-through

            VStack(spacing: EcrinSpacing.xl) {
                // Animated gold dots
                HStack(spacing: 10) {
                    ForEach(0..<5) { i in
                        let delay = Double(i) * 0.15
                        Circle()
                            .fill(EcrinColor.gold)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1 + 0.5 * sin(dotPhase + CGFloat(i) * .pi * 0.6))
                            .opacity(0.5 + 0.5 * sin(dotPhase + CGFloat(i) * .pi * 0.6))
                            .animation(
                                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: false).delay(delay),
                                value: dotPhase
                            )
                    }
                }
                .onAppear {
                    withAnimation {
                        dotPhase = .pi * 2
                    }
                }

                VStack(spacing: EcrinSpacing.sm) {
                    Text("Notre styliste IA compose votre look…")
                        .font(EcrinFont.serif(20, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Sélection des pièces · Rédaction poétique · Création de palette")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(EcrinSpacing.xl)
        }
    }

    // MARK: - Generation Logic

    private func generateBoard() async {
        promptFocused = false
        withAnimation(EcrinAnimation.easeSlide) { isGenerating = true }

        do {
            let board = try await MoodBoardService.generate(
                prompt: prompt,
                occasion: occasion,
                style: style,
                season: season
            )
            generatedBoard = board
            withAnimation(EcrinAnimation.easeSlide) { isGenerating = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            showResult = true
        } catch {
            withAnimation(EcrinAnimation.easeSlide) { isGenerating = false }
        }
    }
}

// MARK: - Selector Components

private struct SelectorLabel: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(EcrinColor.textMuted)
            Text(text)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)
        }
    }
}

private struct OccasionChip: View {
    let label: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .thin))
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            Text(label)
                .font(EcrinFont.caption)
                .kerning(0.3)
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EcrinSpacing.md)
        .background(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.clear : EcrinColor.glassStroke, lineWidth: 0.5)
        }
        .scaleEffect(isSelected ? 1.02 : 1)
        .shadow(color: isSelected ? EcrinColor.gold.opacity(0.3) : .clear, radius: 8, y: 4)
    }
}

#Preview {
    NavigationStack {
        MoodBoardGeneratorView()
    }
}
