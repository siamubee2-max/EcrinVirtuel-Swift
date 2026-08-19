import SwiftUI

// MARK: - Mood Board Gallery View

struct MoodBoardGalleryView: View {
    @Environment(AppState.self) private var appState
    @State private var store                = MoodBoardStore.shared
    @State private var showGenerator        = false
    @State private var selectedBoard: MoodBoard?
    @State private var showDetail           = false
    @State private var showARTryOn          = false
    @State private var arTryOnJewelry: JewelryItem?
    @State private var headerVisible        = false

    private var boards: [MoodBoard] { store.boards }

    // Masonry: 2 columns with varying heights via alternating shorter/taller cards
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            if boards.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(boards.enumerated()), id: \.element.id) { index, board in
                                boardCell(board: board, index: index)
                            }
                        }
                        .padding(.top, EcrinSpacing.md)
                        .padding(.bottom, EcrinSpacing.xxl)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }
            }

            // FAB
            fabButton
        }
        .onAppear { headerVisible = true }
        // React to "Essayer ces bijoux": MoodBoardResultView writes pendingMoodBoardJewelry
        // into AppState then dismisses. The gallery picks it up here and opens AR try-on.
        .onChange(of: appState.pendingMoodBoardJewelry) { _, pending in
            guard let jewelry = pending?.first else { return }
            arTryOnJewelry = jewelry
            showARTryOn = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGenerator) {
            NavigationStack {
                MoodBoardGeneratorView()
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .fullScreenCover(isPresented: $showDetail) {
            if let board = selectedBoard {
                MoodBoardResultView(board: board)
            }
        }
        .fullScreenCover(isPresented: $showARTryOn, onDismiss: {
            appState.pendingMoodBoardJewelry = nil
            arTryOnJewelry = nil
        }) {
            if let jewelry = arTryOnJewelry {
                ARTryOnWrapperView(
                    jewelry: jewelry,
                    onDismiss: { showARTryOn = false },
                    onCapture: { _ in showARTryOn = false }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.MoodBoardUI.galleryTitle)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(x: headerVisible ? 0 : -10)
                    .animation(EcrinAnimation.easeSlide, value: headerVisible)

                Text(L10n.MoodBoardUI.mySavedLooks)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(x: headerVisible ? 0 : -10)
                    .animation(EcrinAnimation.easeSlide.delay(0.07), value: headerVisible)
            }

            Spacer()

            Text("\(boards.count) look\(boards.count > 1 ? "s" : "")")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .padding(.bottom, EcrinSpacing.sm)
    }

    // MARK: - FAB

    private var fabButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { showGenerator = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.MoodBoardUI.newLook)
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.background)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(EcrinColor.gold)
                    .clipShape(Capsule())
                    .shadow(color: EcrinColor.gold.opacity(0.4), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.trailing, EcrinSpacing.lg)
                .padding(.bottom, EcrinSpacing.xxl)
            }
        }
    }

    // MARK: - Board Cell (extracted to help the type-checker with @Observable store access)

    @ViewBuilder
    private func boardCell(board: MoodBoard, index: Int) -> some View {
        MoodBoardCard(board: board, isTall: index % 3 == 0)
            .onTapGesture {
                selectedBoard = board
                showDetail    = true
            }
            .contextMenu {
                Button(role: .destructive) {
                    let id = board.id
                    withAnimation(EcrinAnimation.springSnap) { store.delete(id: id) }
                } label: {
                    Label(L10n.Common.delete, systemImage: "trash")
                }
            }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.xl) {
            headerSection
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: EcrinSpacing.lg) {
                ZStack {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(EcrinColor.gold.opacity(0.06 - Double(i) * 0.015))
                            .frame(width: 120 - CGFloat(i * 20), height: 120 - CGFloat(i * 20))
                            .rotationEffect(.degrees(Double(i * 8)))
                    }
                    Image(systemName: "photo.stack")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.5))
                }
                .frame(height: 140)

                VStack(spacing: EcrinSpacing.sm) {
                    Text(L10n.MoodBoardUI.emptyGallery)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(L10n.MoodBoardUI.firstMoodBoardHint)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                GoldButton(title: L10n.MoodBoardUI.createFirstLook) {
                    showGenerator = true
                }
            }

            Spacer()
        }
    }
}

// MARK: - Masonry Card

struct MoodBoardCard: View {
    let board: MoodBoard
    let isTall: Bool

    private var cardHeight: CGFloat { isTall ? 240 : 180 }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            ZStack(alignment: .bottomLeading) {
                // Palette as background strips
                VStack(spacing: 0) {
                    ForEach(Array(board.colorPalette.enumerated()), id: \.offset) { _, hex in
                        Color(hex: hex)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .opacity(0.3)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Full palette strip on top
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(Array(board.colorPalette.enumerated()), id: \.offset) { _, hex in
                            Color(hex: hex)
                                .frame(height: 5)
                        }
                    }
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, EcrinColor.background.opacity(0.92)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    if !board.occasion.isEmpty || !board.style.isEmpty {
                        HStack(spacing: 4) {
                            if !board.occasion.isEmpty {
                                Text(board.occasion.uppercased())
                                    .font(EcrinFont.label)
                                    .kerning(1)
                                    .foregroundStyle(EcrinColor.gold.opacity(0.8))
                            }
                            if !board.occasion.isEmpty && !board.style.isEmpty {
                                Text("·")
                                    .foregroundStyle(EcrinColor.textMuted)
                                    .font(EcrinFont.caption)
                            }
                            if !board.style.isEmpty {
                                Text(board.style.uppercased())
                                    .font(EcrinFont.label)
                                    .kerning(1)
                                    .foregroundStyle(EcrinColor.textMuted)
                            }
                        }
                    }

                    Text(board.title)
                        .font(EcrinFont.serif(isTall ? 20 : 17, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(2)

                    Text(board.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(EcrinSpacing.md)
            }
            .frame(height: cardHeight)
        }
    }
}

// MARK: - Preview Data

extension MoodBoard {
    static let previews: [MoodBoard] = [
        MoodBoard(
            title: "Classique · Gala",
            prompt: "Un gala parisien en décembre",
            occasion: "Gala",
            style: "Classique",
            jewelryItems: JewelryItem.samples,
            generatedDescription: "Dans la magnificence du gala…",
            colorPalette: ["#080808", "#CA8A04", "#F5D37A", "#1A1A2E", "#4A4080"],
            keywords: ["Gala", "Somptueux", "Classique"]
        ),
        MoodBoard(
            title: "Minimaliste · Business",
            prompt: "Réunion stratégique à Londres",
            occasion: "Business",
            style: "Minimaliste",
            jewelryItems: Array(JewelryItem.samples.prefix(3)),
            generatedDescription: "Dans l'arène de l'ambition…",
            colorPalette: ["#FAFAF9", "#E5E7EB", "#9CA3AF", "#374151"],
            keywords: ["Business", "Confiant", "Structuré"]
        ),
        MoodBoard(
            title: "Romantique · Soirée",
            prompt: "Dîner pour deux à Venise",
            occasion: "Soirée",
            style: "Romantique",
            jewelryItems: Array(JewelryItem.samples.prefix(4)),
            generatedDescription: "Pour cette soirée d'exception…",
            colorPalette: ["#1A0A0A", "#7F1D1D", "#DC2626", "#CA8A04"],
            keywords: ["Soirée", "Séduisant", "Romantique"]
        ),
    ]
}

#Preview {
    NavigationStack {
        MoodBoardGalleryView()
    }
}
