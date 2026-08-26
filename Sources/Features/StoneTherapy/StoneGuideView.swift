import SwiftUI

// MARK: - Stone Guide View

struct StoneGuideView: View {
    @State private var selectedChakra: Chakra?
    @State private var selectedIntention: StoneIntentionCategory?
    @State private var selectedStone: Stone?
    @State private var showDetail = false
    @State private var searchText = ""

    private var filteredStones: [Stone] {
        var stones = StoneDatabase.all

        if let chakra = selectedChakra {
            stones = stones.filter { $0.chakra == chakra }
        }
        if let intention = selectedIntention {
            stones = stones.filter { $0.intentionCategories.contains(intention) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased().folding(options: .diacriticInsensitive, locale: .current)
            stones = stones.filter {
                $0.name.lowercased().folding(options: .diacriticInsensitive, locale: .current).contains(query) ||
                $0.englishName.lowercased().contains(query) ||
                $0.virtues.joined().lowercased().contains(query)
            }
        }
        return stones
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                filtersView
                stonesGrid
            }
        }
        .sheet(isPresented: $showDetail) {
            if let stone = selectedStone {
                StoneDetailView(stone: stone)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: EcrinSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.StoneTherapyUI.lithotherapy)
                        .font(EcrinFont.label)
                        .kerning(3)
                        .foregroundStyle(EcrinColor.gold)
                    Text(L10n.StoneTherapyUI.stoneGuide)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                }
                Spacer()

                Text("\(filteredStones.count)")
                    .font(EcrinFont.heroTitle)
                    .foregroundStyle(EcrinColor.gold.opacity(0.3))
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.lg)

            // Search
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(EcrinColor.textMuted)

                TextField(L10n.StoneTherapyUI.searchStonePlaceholder, text: $searchText)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .tint(EcrinColor.gold)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Filters

    private var filtersView: some View {
        VStack(spacing: EcrinSpacing.sm) {
            // Chakra filter
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text(L10n.StoneTherapyUI.byChakra)
                    .font(EcrinFont.label)
                    .kerning(2.5)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.horizontal, EcrinSpacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EcrinSpacing.sm) {
                        // All button
                        ChakraFilterChip(
                            label: "Tous",
                            color: EcrinColor.textMuted,
                            isSelected: selectedChakra == nil
                        ) {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedChakra = nil
                            }
                        }

                        ForEach(Chakra.allCases) { chakra in
                            ChakraFilterChip(
                                label: chakra.rawValue,
                                color: chakra.color,
                                isSelected: selectedChakra == chakra
                            ) {
                                withAnimation(EcrinAnimation.springSnap) {
                                    selectedChakra = selectedChakra == chakra ? nil : chakra
                                }
                            }
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, 2)
                }
            }

            // Intention filter
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text(L10n.StoneTherapyUI.byIntention)
                    .font(EcrinFont.label)
                    .kerning(2.5)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.horizontal, EcrinSpacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EcrinSpacing.sm) {
                        // All button
                        IntentionFilterChip(
                            category: nil,
                            isSelected: selectedIntention == nil
                        ) {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedIntention = nil
                            }
                        }

                        ForEach(StoneIntentionCategory.allCases) { intention in
                            IntentionFilterChip(
                                category: intention,
                                isSelected: selectedIntention == intention
                            ) {
                                withAnimation(EcrinAnimation.springSnap) {
                                    selectedIntention = selectedIntention == intention ? nil : intention
                                }
                            }
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, EcrinSpacing.md)
    }

    // MARK: - Grid

    private var stonesGrid: some View {
        ScrollView(showsIndicators: false) {
            if filteredStones.isEmpty {
                emptyState
            } else {
                let columns = [GridItem(.flexible(), spacing: EcrinSpacing.md), GridItem(.flexible(), spacing: EcrinSpacing.md)]
                LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
                    ForEach(filteredStones) { stone in
                        StoneGridCard(stone: stone) {
                            selectedStone = stone
                            showDetail = true
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, EcrinSpacing.xxl)
                .animation(EcrinAnimation.springSnap, value: filteredStones.map(\.id))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text(L10n.StoneTherapyUI.noStoneFound)
                .font(EcrinFont.cardTitle)
                .foregroundStyle(EcrinColor.textSecondary)
            Text(L10n.StoneTherapyUI.tryOtherFilters)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Stone Grid Card

private struct StoneGridCard: View {
    let stone: Stone
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: EcrinSpacing.md) {
                // Gem orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [stone.stoneColor.opacity(0.7), stone.stoneColor.opacity(0.15)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: stone.stoneColor.opacity(0.4), radius: 12)

                    Circle()
                        .strokeBorder(stone.stoneColor.opacity(0.5), lineWidth: 0.8)
                        .frame(width: 60, height: 60)

                    Image(systemName: "diamond.fill")
                        .font(.system(size: 18, weight: .ultraLight))
                        .foregroundStyle(Color.white.opacity(0.9))
                }

                VStack(spacing: 4) {
                    Text(stone.name)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(1)

                    // Chakra indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stone.chakra.color)
                            .frame(width: 5, height: 5)
                        Text(stone.chakra.rawValue)
                            .font(EcrinFont.label)
                            .kerning(0.5)
                            .foregroundStyle(stone.chakra.color.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                // Intentions
                HStack(spacing: 4) {
                    ForEach(stone.intentionCategories.prefix(2), id: \.rawValue) { cat in
                        Image(systemName: cat.sfSymbol)
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(cat.color.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(EcrinSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(stone.stoneColor.opacity(0.05))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [stone.stoneColor.opacity(0.2), EcrinColor.glassStroke],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 0,
            pressing: { pressed in
                withAnimation(EcrinAnimation.springSnap) {
                    isPressed = pressed
                }
            },
            perform: {}
        )
    }
}

// MARK: - Chakra Filter Chip

private struct ChakraFilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(EcrinFont.label)
                    .kerning(0.8)
                    .foregroundStyle(isSelected ? color : EcrinColor.textMuted)
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? color.opacity(0.12) : EcrinColor.glassFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? color.opacity(0.5) : EcrinColor.glassStroke, lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Intention Filter Chip

private struct IntentionFilterChip: View {
    let category: StoneIntentionCategory?
    let isSelected: Bool
    let action: () -> Void

    private var label: String { category?.rawValue ?? "Toutes" }
    private var icon: String { category?.sfSymbol ?? "sparkles" }
    private var color: Color { category?.color ?? EcrinColor.textMuted }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(isSelected ? color : EcrinColor.textMuted)
                Text(label)
                    .font(EcrinFont.label)
                    .kerning(0.8)
                    .foregroundStyle(isSelected ? color : EcrinColor.textMuted)
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? color.opacity(0.12) : EcrinColor.glassFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? color.opacity(0.5) : EcrinColor.glassStroke, lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    StoneGuideView()
        .preferredColorScheme(.dark)
}
