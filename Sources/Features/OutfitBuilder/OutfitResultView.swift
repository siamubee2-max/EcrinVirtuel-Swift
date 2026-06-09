import SwiftUI

// MARK: - OutfitResultView

struct OutfitResultView: View {
    let image: UIImage
    let outfit: Outfit
    @ObservedObject var vm: OutfitViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: OutfitSlot?
    @State private var showShareSheet  = false
    @State private var showSavedToast  = false
    @State private var dragOffset: CGFloat = 0
    @State private var coherenceScore  = 0

    private let slotItems: [(OutfitSlot, FashionItemRef)] = {
        OutfitSlot.allCases.compactMap { slot in
            // placeholder — filled dynamically in body
            nil
        }
    }()

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // --- Image plein écran ---
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    bottomOverlay
                }
                .overlay(alignment: .top) {
                    topBar
                }

            // Toast sauvegarde
            if showSavedToast {
                savedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(99)
            }
        }
        .onAppear {
            animateCoherenceScore()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(EcrinColor.ivory)
                    .padding(10)
                    .background(Circle().fill(EcrinColor.glassFill))
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke))
            }

            Spacer()

            // Score de cohérence
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(EcrinColor.gold)
                Text("Cohérence \(coherenceScore)%")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.ivory)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(EcrinColor.glassFill, in: Capsule())
            .overlay(Capsule().strokeBorder(EcrinColor.glassStroke))
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.top, EcrinSpacing.sm)
    }

    // MARK: - Bottom overlay

    private var bottomOverlay: some View {
        VStack(spacing: 0) {
            // Pièces en carrousel
            piecesCarousel
                .padding(.bottom, EcrinSpacing.sm)

            // Actions
            actionBar
                .padding(.bottom, EcrinSpacing.lg)
        }
        .background(
            LinearGradient(
                colors: [EcrinColor.background.opacity(0), EcrinColor.background.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Pieces carousel

    private var piecesCarousel: some View {
        let items = outfit.slots.sorted { $0.key.rawValue < $1.key.rawValue }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(items, id: \.key) { slot, ref in
                    PieceCard(
                        slot: slot,
                        ref: ref,
                        isSelected: selectedSlot == slot
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            selectedSlot = selectedSlot == slot ? nil : slot
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Sauvegarder
            Button {
                vm.saveCurrentOutfit()
                withAnimation(EcrinAnimation.springSnap) { showSavedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSavedToast = false }
                }
            } label: {
                Label("Sauvegarder", systemImage: "heart.fill")
                    .font(EcrinFont.cta)
                    .kerning(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(EcrinColor.glassFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.5)))
            }
            .buttonStyle(.plain)

            // Partager
            GoldButton(title: L10n.Common.share) {
                showShareSheet = true
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
    }

    // MARK: - Toast

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Tenue sauvegardée")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.ivory)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(EcrinColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(EcrinColor.glassStroke))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    // MARK: - Score animation

    private func animateCoherenceScore() {
        let target = computeCoherenceScore()
        let duration = 1.2
        let steps = 60
        let stepDelay = duration / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDelay) {
                coherenceScore = Int(Double(target) * Double(i) / Double(steps))
            }
        }
    }

    private func computeCoherenceScore() -> Int {
        // Mock : score basé sur complétude + présence bijoux + chaussures
        let base = outfit.completionScore
        let hasJewelry  = outfit.slots.keys.contains(where: { [.necklace, .earrings, .ring, .bracelet].contains($0) })
        let hasShoes    = outfit.slots[.shoes] != nil
        let bonus = (hasJewelry ? 10 : 0) + (hasShoes ? 10 : 0)
        return min(100, base + bonus)
    }
}

// MARK: - PieceCard

struct PieceCard: View {
    let slot: OutfitSlot
    let ref: FashionItemRef
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? EcrinColor.gold.opacity(0.25) : EcrinColor.glassFill)
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        )

                    Image(systemName: ref.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                }

                Text(ref.name)
                    .font(EcrinFont.label)
                    .kerning(0.5)
                    .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textMuted)
                    .lineLimit(1)
                    .frame(maxWidth: 60)

                Text(slot.rawValue)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}
