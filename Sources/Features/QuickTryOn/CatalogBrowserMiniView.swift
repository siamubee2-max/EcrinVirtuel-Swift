import SwiftUI

// MARK: - CatalogBrowserMiniView
// Version compacte du catalogue, embarquable dans QuickTryOnView.
// Sélection par tap, articles sélectionnés = border or + checkmark.

struct CatalogBrowserMiniView: View {
    @Bindable var vm: QuickTryOnViewModel
    @Environment(ClothingCatalogService.self) private var catalogService

    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EcrinSpacing.sm, alignment: .top),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EcrinSpacing.sm, alignment: .top),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EcrinSpacing.sm, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 0) {
            genderChips
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.bottom, EcrinSpacing.sm)

            categoryGroupChips
                .padding(.bottom, EcrinSpacing.sm)

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if vm.isCatalogLoading && catalogService.totalCount == 0 {
            loadingState
        } else if vm.isCatalogIncompatibleWithMode {
            incompatibleModeState
        } else if vm.filteredCatalogItems.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: EcrinSpacing.sm) {
                    ForEach(vm.filteredCatalogItems) { item in
                        CatalogMiniCard(
                            item: item,
                            isSelected: vm.isSelected(.catalog(item))
                        ) {
                            withAnimation(EcrinAnimation.springSnap) {
                                vm.toggleItem(.catalog(item))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.bottom, EcrinSpacing.lg)
            }
            .refreshable { await vm.loadCatalog(force: true) }
        }
    }

    // MARK: - Gender Chips

    private var genderChips: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(ClothingGender.allCases, id: \.self) { gender in
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        vm.catalogGenderFilter = gender
                        vm.catalogCategoryGroupFilter = .all
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: gender.icon)
                            .font(.system(size: 11))
                        Text(gender.label)
                            .font(EcrinFont.caption)
                    }
                    .foregroundStyle(
                        vm.catalogGenderFilter == gender
                            ? EcrinColor.background
                            : EcrinColor.textSecondary
                    )
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, 7)
                    .background(
                        vm.catalogGenderFilter == gender
                            ? EcrinColor.gold
                            : EcrinColor.glassFill,
                        in: Capsule()
                    )
                    .overlay {
                        if vm.catalogGenderFilter != gender {
                            Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(EcrinAnimation.springSnap, value: vm.catalogGenderFilter)
            }
        }
    }

    // MARK: - Category Group Chips

    private var categoryGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(vm.availableCategoryGroups, id: \.self) { group in
                    FilterChip(
                        label: group.rawValue,
                        icon: group.icon,
                        isSelected: vm.catalogCategoryGroupFilter == group,
                        color: EcrinColor.gold
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            vm.catalogCategoryGroupFilter = group
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: EcrinSpacing.md) {
            ProgressView()
                .tint(EcrinColor.gold)
            Text("Chargement du catalogue…")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, EcrinSpacing.xl)
    }

    private var incompatibleModeState: some View {
        VStack(spacing: EcrinSpacing.md) {
            Image(systemName: "diamond")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text("Mode « Bijoux seuls »")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
            Text("Le catalogue vêtements ne s'applique pas à ce mode.\nUtilisez Ma garde-robe ou la Boutique.")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.md) {
            Image(systemName: "tshirt")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)

            Text(emptyTitle)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .multilineTextAlignment(.center)

            if catalogService.totalCount > 0 {
                Text("\(catalogService.totalCount) articles au catalogue · \(vm.filteredCatalogItems.count) pour ce filtre")
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.textMuted.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if let errMsg = catalogService.lastError?.localizedDescription {
                Text(errMsg)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await vm.loadCatalog(force: true) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(L10n.Common.retry)
                }
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.gold)
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
                .background(Capsule().stroke(EcrinColor.gold.opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.xl)
    }

    private var emptyTitle: String {
        if catalogService.totalCount == 0 {
            return "Catalogue vide — vérifiez votre connexion"
        }
        if vm.selectedMode != nil {
            return "Aucun article compatible\navec ce mode et ces filtres"
        }
        return "Aucun article disponible"
    }
}

// MARK: - CatalogMiniCard

struct CatalogMiniCard: View {
    let item: CatalogClothingItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: EcrinSpacing.sm) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(item.cardBackgroundColor)

                                if let url = item.imageURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure, .empty:
                                            Image(systemName: item.categoryIcon)
                                                .font(.system(size: 24, weight: .light))
                                                .foregroundStyle(
                                                    isSelected ? EcrinColor.gold : EcrinColor.textSecondary
                                                )
                                        @unknown default:
                                            Image(systemName: item.categoryIcon)
                                                .font(.system(size: 24, weight: .light))
                                                .foregroundStyle(EcrinColor.textSecondary)
                                        }
                                    }
                                } else {
                                    Image(systemName: item.categoryIcon)
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundStyle(
                                            isSelected ? EcrinColor.gold : EcrinColor.textSecondary
                                        )
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()

                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(EcrinFont.caption)
                            .foregroundStyle(
                                isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary
                            )
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        if let brand = item.brand {
                            Text(brand)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(EcrinColor.textMuted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    if let price = item.formattedPrice {
                        Text(price)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(EcrinSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected ? EcrinColor.gold.opacity(0.08) : EcrinColor.glassFill,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                            lineWidth: isSelected ? 1.2 : 0.5
                        )
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(EcrinColor.gold)
                        .background(Circle().fill(EcrinColor.background))
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - FilterChip (partagé avec d'autres vues QuickTryOn)

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(isSelected ? color : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, 7)
            .background(
                isSelected ? color.opacity(0.15) : EcrinColor.glassFill,
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? color.opacity(0.4) : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}
