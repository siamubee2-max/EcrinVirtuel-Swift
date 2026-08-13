import SwiftUI

// MARK: - Mood Board Result View

struct MoodBoardResultView: View {
    let board: MoodBoard
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSheet   = false
    @State private var savedSuccessfully = false
    @State private var descriptionVisible = false
    @State private var paletteVisible     = false
    @State private var jewelryVisible     = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            EcrinColor.background.ignoresSafeArea()

            // Dynamic background tinted by palette
            if let firstHex = board.colorPalette.first {
                Color(hex: firstHex).opacity(0.08)
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    heroSection
                        .padding(.top, 60)

                    // Color palette
                    paletteSection
                        .padding(.top, EcrinSpacing.xl)
                        .opacity(paletteVisible ? 1 : 0)
                        .offset(y: paletteVisible ? 0 : 20)
                        .animation(EcrinAnimation.glassReveal.delay(0.15), value: paletteVisible)

                    // Poetic description
                    descriptionSection
                        .padding(.top, EcrinSpacing.xl)
                        .opacity(descriptionVisible ? 1 : 0)
                        .offset(y: descriptionVisible ? 0 : 20)
                        .animation(EcrinAnimation.glassReveal.delay(0.3), value: descriptionVisible)

                    // Jewelry grid
                    jewelrySection
                        .padding(.top, EcrinSpacing.xl)
                        .opacity(jewelryVisible ? 1 : 0)
                        .offset(y: jewelryVisible ? 0 : 20)
                        .animation(EcrinAnimation.glassReveal.delay(0.45), value: jewelryVisible)

                    // Keywords
                    keywordsSection
                        .padding(.top, EcrinSpacing.xl)

                    // Actions
                    actionsSection
                        .padding(.top, EcrinSpacing.xxl)

                    Spacer(minLength: EcrinSpacing.xxl)
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }

            // Top bar
            topBar
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { paletteVisible  = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { descriptionVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)  { jewelryVisible = true }
        }
        .sheet(isPresented: $showSaveSheet) {
            MoodSaveLookSheet(board: board, onSave: {
                savedSuccessfully = true
                showSaveSheet = false
            })
        }
        .overlay {
            if savedSuccessfully {
                SavedToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedSuccessfully = false }
                        }
                    }
            }
        }
        .animation(EcrinAnimation.springSnap, value: savedSuccessfully)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            Spacer()
            Text(L10n.MoodBoardUI.yourLookLabel)
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.textSecondary)
            Spacer()
            Button {
                showSaveSheet = true
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.gold)
                    .padding(10)
                    .background(EcrinColor.gold.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.gold.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, 56)
        .background {
            LinearGradient(
                colors: [EcrinColor.background, EcrinColor.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            // Occasion / Style badges
            HStack(spacing: EcrinSpacing.sm) {
                if !board.occasion.isEmpty {
                    TagBadge(text: board.occasion)
                }
                if !board.style.isEmpty {
                    TagBadge(text: board.style)
                }
            }

            Text(board.title)
                .font(EcrinFont.serif(36, weight: .thin))
                .foregroundStyle(EcrinColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Palette Section

    private var paletteSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            HStack {
                Text(L10n.MoodBoardUI.paletteLabel)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(Array(board.colorPalette.enumerated()), id: \.offset) { index, hex in
                    Color(hex: hex)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: index == 0 ? 12 : 0,
                                bottomLeadingRadius: index == 0 ? 12 : 0,
                                bottomTrailingRadius: index == board.colorPalette.count - 1 ? 12 : 0,
                                topTrailingRadius: index == board.colorPalette.count - 1 ? 12 : 0
                            )
                        )
                        .overlay(alignment: .bottom) {
                            Text(hex.uppercased())
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.bottom, 6)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 18, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.5))
                    Spacer()
                }

                Text(board.generatedDescription)
                    .font(EcrinFont.serif(18, weight: .light))
                    .italic()
                    .foregroundStyle(EcrinColor.ivory.opacity(0.9))
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Image(systemName: "quote.closing")
                        .font(.system(size: 18, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.5))
                }
            }
            .padding(EcrinSpacing.xl)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.15), lineWidth: 0.5)
        }
    }

    // MARK: - Jewelry Section

    private var jewelrySection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            HStack {
                Text(L10n.MoodBoardUI.selectedPiecesLabel)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                Spacer()
                Text("\(board.jewelryItems.count) pièces")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.md) {
                    ForEach(board.jewelryItems) { item in
                        MoodJewelCard(item: item) {
                            // Open TryOnView with this item
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Keywords

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text(L10n.MoodBoardUI.keywordsLabel)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            FlowLayout(spacing: EcrinSpacing.sm) {
                ForEach(board.keywords, id: \.self) { kw in
                    Text("# \(kw)")
                        .font(EcrinFont.caption)
                        .kerning(0.5)
                        .foregroundStyle(EcrinColor.gold.opacity(0.8))
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.vertical, 7)
                        .background(EcrinColor.gold.opacity(0.05))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.15), lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            GoldButton(title: L10n.MoodBoardUI.tryTheseJewels) {
                dismiss()
            }

            GhostButton(title: L10n.MoodBoardUI.saveLook) {
                showSaveSheet = true
            }
        }
    }
}

// MARK: - Saved Toast (inside MoodBoardResultView module — already defined above)


// MARK: - Jewelry Card for Result

struct MoodJewelCard: View {
    let item: JewelryItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(EcrinColor.gold.opacity(0.06))
                        Image(systemName: item.icon)
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(EcrinColor.gold.opacity(0.7))
                    }
                    .frame(width: 120, height: 110)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .lineLimit(1)

                        Text(item.material)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 8))
                            Text(L10n.LookOfDay.tryButton)
                                .font(EcrinFont.label)
                                .kerning(1)
                        }
                        .foregroundStyle(EcrinColor.gold)
                        .padding(.top, 2)
                    }
                    .padding([.horizontal, .bottom], EcrinSpacing.md)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 152)
    }
}

// MARK: - Tag Badge

private struct TagBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(EcrinFont.label)
            .kerning(1.5)
            .foregroundStyle(EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, 5)
            .background(EcrinColor.glassFill)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
    }
}

// MARK: - Saved Toast

private struct SavedToastView: View {
    var body: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EcrinColor.gold)
            Text(L10n.MoodBoardUI.lookSavedToGallery)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .background(EcrinColor.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
        .padding(.top, 60)
    }
}

// MARK: - Save Look Sheet

struct MoodSaveLookSheet: View {
    let board: MoodBoard
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customTitle: String = ""

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(EcrinColor.textMuted)
                    .frame(width: 36, height: 3)
                    .padding(.top, EcrinSpacing.md)

                VStack(spacing: EcrinSpacing.sm) {
                    Text(L10n.AiStylist.saveLook)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.MoodBoardUI.findItInGallery)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }

                // Title field
                GlassCard(cornerRadius: 14) {
                    TextField(L10n.MoodBoardUI.lookTitlePlaceholder, text: $customTitle)
                        .font(EcrinFont.serif(18, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                        .tint(EcrinColor.gold)
                        .padding(EcrinSpacing.md)
                        .onAppear { customTitle = board.title }
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Preview strip
                HStack(spacing: 0) {
                    ForEach(Array(board.colorPalette.enumerated()), id: \.offset) { index, hex in
                        Color(hex: hex)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, EcrinSpacing.lg)

                Spacer()

                VStack(spacing: EcrinSpacing.md) {
                    GoldButton(title: L10n.OutfitBuilderUI.save) {
                        onSave()
                    }
                    Button(L10n.Common.cancel) { dismiss() }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(.bottom, EcrinSpacing.xxl)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}

#Preview {
    MoodBoardResultView(board: MoodBoard(
        title: "Classique · Gala",
        prompt: "Un gala parisien en décembre",
        occasion: "Gala",
        style: "Classique",
        jewelryItems: JewelryItem.samples,
        generatedDescription: "Dans la magnificence du gala, l'or blanc s'élève au rang de trophée. La rivière parachève une silhouette royale, affirmant avec éclat votre souveraineté.",
        colorPalette: ["#080808", "#CA8A04", "#F5D37A", "#1A1A2E", "#4A4080"],
        keywords: ["Gala", "Classique", "Hiver", "Grandiose", "Somptueux"]
    ))
}
