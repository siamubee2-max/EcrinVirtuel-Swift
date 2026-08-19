import SwiftUI

// MARK: - CatalogBrowserView
// Parcourir le catalogue vêtements pour inspirer et lancer un essayage look

struct CatalogBrowserView: View {

    @Environment(ClothingCatalogService.self) private var catalogService
    @State private var selectedGender: ClothingGender = .femme
    @State private var selectedCategory: ClothingCategoryGroup = .all
    @State private var searchText = ""
    @State private var searchResults: [CatalogClothingItem] = []
    @State private var isSearching = false
    @State private var tryOnItem: CatalogClothingItem?

    // Debounce search
    @State private var searchTask: Task<Void, Never>?

    private var displayedItems: [CatalogClothingItem] {
        if isSearching {
            return searchResults
        }
        let base = catalogService.items(for: selectedGender)
        guard let key = selectedCategory.rawKey else { return base }
        return base.filter { $0.category == key }
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                catalogHeader
                genderSelector
                categoryChips
                searchBar
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.bottom, EcrinSpacing.sm)

                itemsGrid
            }
        }
        // Réutilise le cache s'il est déjà chargé (force: false) — avant, force: true
        // re-téléchargeait tout le catalogue à CHAQUE ouverture de l'écran.
        .task { await catalogService.fetchAll(force: false) }
        .sheet(item: $tryOnItem) { item in
            TryOnFromCatalogSheet(item: item)
        }
    }

    // MARK: - Header

    private var catalogHeader: some View {
        VStack(spacing: 4) {
            Text("CATALOGUE")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)
                .kerning(4)
            Text("Inspirations look")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.gold)
                .kerning(2)
            if catalogService.totalCount > 0 {
                Text("\(displayedItems.count) articles · \(catalogService.totalCount) au total")
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.textMuted)
            }
        }
        .padding(.top, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.md)
    }

    // MARK: - Gender Selector

    private var genderSelector: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(ClothingGender.allCases, id: \.self) { gender in
                GenderButton(
                    gender: gender,
                    isSelected: selectedGender == gender && !isSearching
                ) {
                    withAnimation(EcrinAnimation.springSnap) {
                        selectedGender = gender
                        selectedCategory = .all
                        isSearching = false
                        searchText = ""
                    }
                }
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.bottom, EcrinSpacing.md)
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(ClothingCategoryGroup.allCases, id: \.self) { cat in
                    CategoryChip(
                        group: cat,
                        isSelected: selectedCategory == cat && !isSearching
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            selectedCategory = cat
                            isSearching = false
                            searchText = ""
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
        }
        .padding(.bottom, EcrinSpacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(EcrinColor.textSecondary)
                .font(.system(size: 14, weight: .regular))

            TextField("Rechercher un article, une marque…", text: $searchText)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .tint(EcrinColor.gold)
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    if newValue.isEmpty {
                        withAnimation { isSearching = false; searchResults = [] }
                    } else {
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            guard !Task.isCancelled else { return }
                            let results = await catalogService.search(query: newValue)
                            await MainActor.run {
                                withAnimation { isSearching = true; searchResults = results }
                            }
                        }
                    }
                }

            if !searchText.isEmpty {
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        searchText = ""
                        isSearching = false
                        searchResults = []
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(EcrinColor.textSecondary)
                }
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
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        Group {
            if catalogService.isLoading && displayedItems.isEmpty {
                loadingView
            } else if displayedItems.isEmpty {
                emptyView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EcrinSpacing.sm, alignment: .top),
                            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: EcrinSpacing.sm, alignment: .top)
                        ],
                        spacing: EcrinSpacing.sm
                    ) {
                        ForEach(displayedItems) { item in
                            CatalogItemCard(item: item) {
                                tryOnItem = item
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
                .refreshable { await catalogService.fetchAll(force: true) }
                .accessibilityIdentifier("catalog.grid")
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: EcrinSpacing.md) {
            ProgressView()
                .tint(EcrinColor.gold)
            Text("Chargement du catalogue…")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Image(systemName: isSearching ? "magnifyingglass" : "tshirt")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(EcrinColor.textMuted)

            VStack(spacing: EcrinSpacing.xs) {
                Text(isSearching ? "Aucun résultat" : "Catalogue vide")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(isSearching ? "Essayez d'autres termes de recherche" : "Les articles arrivent bientôt")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)

                // Affiche le message d'erreur réel en debug — aide à diagnostiquer les
                // problèmes de décodage Supabase sans devoir brancher Xcode
                if let errMsg = catalogService.lastError?.localizedDescription {
                    Text(errMsg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, EcrinSpacing.sm)
                }
            }

            // Bouton "Réessayer"
            if !isSearching {
                Button {
                    Task { await catalogService.fetchAll(force: true) }
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
        }
        .padding(EcrinSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - GenderButton

private struct GenderButton: View {
    let gender: ClothingGender
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: gender.icon)
                    .font(.system(size: 20, weight: isSelected ? .medium : .light))
                    .foregroundStyle(isSelected ? gender.color : EcrinColor.textSecondary)
                Text(gender.label)
                    .font(EcrinFont.cta)
                    .kerning(1.5)
                    .foregroundStyle(isSelected ? gender.color : EcrinColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EcrinSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? gender.color.opacity(0.15)
                          : EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? gender.color.opacity(0.5) : EcrinColor.glassStroke,
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let group: ClothingCategoryGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: group.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(group.rawValue)
                    .font(EcrinFont.label)
                    .kerning(1)
            }
            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.xs + 2)
            .background {
                Capsule()
                    .fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : EcrinColor.glassStroke,
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - CatalogItemCard

struct CatalogItemCard: View {
    let item: CatalogClothingItem
    let onTryOn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let brand = item.brand {
                    Text(brand.uppercased())
                        .font(EcrinFont.label)
                        .kerning(1.5)
                        .foregroundStyle(EcrinColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let price = item.formattedPrice {
                    Text(price)
                        .font(EcrinFont.sans(11, weight: .semibold))
                        .foregroundStyle(EcrinColor.gold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }

                Button(action: onTryOn) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 10, weight: .medium))
                        Text("ESSAYER")
                            .font(EcrinFont.label)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(EcrinColor.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, EcrinSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(item.cardBackgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var imageArea: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        item.cardBackgroundColor
                            .brightness(0.05)

                        if let url = item.imageURL {
                            DownsampledAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                case .failure:
                                    categoryPlaceholder
                                case .empty:
                                    ProgressView().tint(EcrinColor.gold)
                                @unknown default:
                                    categoryPlaceholder
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            categoryPlaceholder
                        }

                        VStack {
                            HStack {
                                Spacer()
                                if item.isFeatured {
                                    Text("VEDETTE")
                                        .font(EcrinFont.label)
                                        .kerning(1)
                                        .foregroundStyle(EcrinColor.background)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(EcrinColor.gold)
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private var categoryPlaceholder: some View {
        Image(systemName: item.categoryIcon)
            .font(.system(size: 36, weight: .ultraLight))
            .foregroundStyle(EcrinColor.textMuted)
    }
}

// MARK: - TryOnFromCatalogSheet

struct TryOnFromCatalogSheet: View {
    let item: CatalogClothingItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                // Handle
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 5)
                    .padding(.top, EcrinSpacing.md)

                // Info article
                VStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: item.categoryIcon)
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(EcrinColor.gold)

                    Text(item.name)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .multilineTextAlignment(.center)

                    if let brand = item.brand {
                        Text(brand.uppercased())
                            .font(EcrinFont.label)
                            .kerning(2)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }

                    if let price = item.formattedPrice {
                        Text(price)
                            .font(EcrinFont.sans(16, weight: .semibold))
                            .foregroundStyle(EcrinColor.gold)
                    }
                }

                // Prompt preview
                VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                    Text("PROMPT D'ESSAYAGE")
                        .font(EcrinFont.label)
                        .kerning(2)
                        .foregroundStyle(EcrinColor.textMuted)
                    Text(item.tryOnPrompt)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .italic()
                }
                .padding(EcrinSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(EcrinColor.glassFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                }
                .padding(.horizontal, EcrinSpacing.md)

                Spacer()

                // CTA — QuickTryOn avec item catalogue pré-sélectionné
                VStack(spacing: EcrinSpacing.sm) {
                    QuickTryOnEntryButton(
                        catalogItem: item,
                        style: .gold
                    )

                    if let urlString = item.purchaseURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Text("Voir l'article en boutique")
                                .font(EcrinFont.cta)
                                .kerning(1.5)
                                .foregroundStyle(EcrinColor.gold)
                        }
                    }
                }
                .padding(.bottom, EcrinSpacing.xl)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview("Catalogue Femme") {
    CatalogBrowserView()
        .environment(ClothingCatalogService.shared)
}

#Preview("Item Card") {
    HStack {
        CatalogItemCard(item: .preview) {}
        CatalogItemCard(item: .previewMen) {}
    }
    .padding()
    .background(EcrinColor.background)
}
