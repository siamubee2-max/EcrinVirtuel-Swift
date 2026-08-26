import SwiftUI
import PhotosUI

// MARK: - WardrobeView

struct WardrobeView: View {
    @Environment(AppState.self) private var appState
    private var viewModel: WardrobeViewModel { appState.wardrobe }

    @State private var showAddSheet = false
    @State private var showAnalytics = false
    @State private var contextItem: FashionItem?
    @State private var showContextMenu = false
    @State private var itemToEdit: FashionItem?
    @State private var itemToTryOn: FashionItem?
    @State private var itemToCompleteLook: FashionItem?

    private let columns = [
        GridItem(.flexible(), spacing: EcrinSpacing.sm),
        GridItem(.flexible(), spacing: EcrinSpacing.sm),
        GridItem(.flexible(), spacing: EcrinSpacing.sm)
    ]

    var body: some View {
        @Bindable var vm = viewModel
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    wardrobeHeader
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.top, EcrinSpacing.md)

                    // Group tabs
                    groupTabBar
                        .padding(.top, EcrinSpacing.lg)

                    // Sub-category chips
                    if !viewModel.selectedGroup.categories.isEmpty {
                        subCategoryChips
                            .padding(.top, EcrinSpacing.md)
                    }

                    // Grid
                    if viewModel.filteredItems.isEmpty {
                        emptyState
                    } else {
                        itemsGrid
                            .padding(.top, EcrinSpacing.md)
                            .padding(.horizontal, EcrinSpacing.md)
                    }

                    Spacer(minLength: 100)
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fabButton
                        .padding(.trailing, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddWardrobeItemSheet { item in
                viewModel.add(item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAnalytics) {
            WardrobeAnalyticsView(items: viewModel.items)
        }
        .confirmationDialog(
            contextItem?.name ?? "",
            isPresented: $showContextMenu,
            titleVisibility: .visible
        ) {
            if let item = contextItem {
                Button(L10n.TryOn.title) {
                    itemToTryOn = item
                }
                // Visible uniquement pour les vêtements (pas les bijoux/accessoires seuls)
                if item.category.group == .clothing || item.category.group == .shoes {
                    Button(L10n.WardrobeUI.completesThisLook) {
                        itemToCompleteLook = item
                    }
                }
                Button(item.isFavorite ? L10n.Boutique.removeFromFavorites : L10n.Boutique.addToFavorites) {
                    viewModel.toggleFavorite(item)
                }
                Button(L10n.Common.edit) {
                    itemToEdit = item
                }
                Button(L10n.Common.delete, role: .destructive) {
                    withAnimation {
                        viewModel.delete(item)
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            }
        }
        .sheet(item: $itemToEdit) { item in
            EditWardrobeItemSheet(item: item) { updated in
                viewModel.update(updated)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $itemToTryOn) { item in
            ItemTryOnSheet(item: item)
                .presentationDetents([.large])
        }
        .sheet(item: $itemToCompleteLook) { item in
            QuickTryOnView(
                preselectedItem: .wardrobe(item),
                preselectedMode: .fullOutfit
            )
            .environment(appState)
            .environment(ClothingCatalogService.shared)
            .presentationDetents([.large])
        }
        // Fix B: surface Supabase sync errors to the user.
        .alert("Erreur de synchronisation",
               isPresented: Binding(
                   get: { vm.errorMessage != nil },
                   set: { if !$0 { vm.errorMessage = nil } }
               )) {
            Button(L10n.Common.ok, role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var wardrobeHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.WardrobeUI.myWardrobeCaps)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.WardrobeUI.virtual)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text("\(viewModel.totalCount) pièces")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                // Analytics button
                Button {
                    showAnalytics = true
                } label: {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(EcrinColor.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassCircleButton()
                }
                .buttonStyle(.plain)

                // Favorites filter
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        viewModel.showOnlyFavorites.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.showOnlyFavorites ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(viewModel.showOnlyFavorites ? EcrinColor.gold : EcrinColor.textSecondary)
                        .frame(width: 36, height: 36)
                        .glassCircleButton(active: viewModel.showOnlyFavorites)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Group Tab Bar

    private var groupTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(FashionGroup.allCases, id: \.self) { group in
                    GroupTabItem(
                        group: group,
                        count: viewModel.groupCount[group] ?? 0,
                        isSelected: viewModel.selectedGroup == group
                    ) {
                        viewModel.selectGroup(group)
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Sub-category Chips

    private var subCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                // "Tous" chip
                SubCatChip(
                    label: L10n.Common.all,
                    icon: "square.grid.2x2",
                    isSelected: viewModel.selectedCategory == nil,
                    color: viewModel.selectedGroup.color
                ) {
                    viewModel.selectCategory(nil)
                }

                ForEach(viewModel.selectedGroup.categories, id: \.self) { cat in
                    let count = viewModel.items.filter { $0.category == cat }.count
                    if count > 0 {
                        SubCatChip(
                            label: cat.rawValue,
                            icon: cat.icon,
                            isSelected: viewModel.selectedCategory == cat,
                            color: viewModel.selectedGroup.color
                        ) {
                            viewModel.selectCategory(cat)
                        }
                    }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        LazyVGrid(columns: columns, spacing: EcrinSpacing.sm) {
            ForEach(viewModel.filteredItems) { item in
                WardrobeItemCard(item: item)
                    .contextMenu {
                        WardrobeItemContextMenu(
                            item: item,
                            onTryOn: { itemToTryOn = item },
                            onCompleteLook: { itemToCompleteLook = item },
                            onEdit: { itemToEdit = item },
                            onToggleFavorite: { viewModel.toggleFavorite(item) },
                            onDelete: { viewModel.delete(item) }
                        )
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        contextItem = item
                        showContextMenu = true
                    }
                    .onTapGesture {
                        itemToTryOn = item
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(EcrinAnimation.springSnap, value: viewModel.filteredItems.map { $0.id })
        .accessibilityIdentifier("wardrobe.list")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Spacer(minLength: 60)
            Image(systemName: viewModel.selectedGroup.icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(viewModel.selectedGroup.color.opacity(0.4))

            VStack(spacing: EcrinSpacing.sm) {
                Text(L10n.WardrobeUI.noPieces)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text("Ajoutez vos \(viewModel.selectedGroup.rawValue.lowercased()) avec le bouton +")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(EcrinSpacing.xl)
        .accessibilityIdentifier("wardrobe.empty")
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            showAddSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold)
                    .frame(width: 56, height: 56)
                    .shadow(color: EcrinColor.gold.opacity(0.4), radius: 12, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(EcrinColor.background)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wardrobe.add")
    }
}

// MARK: - Group Tab Item

private struct GroupTabItem: View {
    let group: FashionGroup
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? group.color.opacity(0.2) : EcrinColor.glassFill)
                        .frame(width: 52, height: 52)
                        .overlay {
                            if #available(iOS 26, *), !isSelected {
                                Circle().glassEffect(.regular, in: .circle)
                            }
                        }
                        .overlay {
                            Circle().strokeBorder(
                                isSelected ? group.color.opacity(0.5) : EcrinColor.glassStroke,
                                lineWidth: isSelected ? 1 : 0.5
                            )
                        }

                    Image(systemName: group.icon)
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(isSelected ? group.color : EcrinColor.textSecondary)
                }

                Text(group.rawValue)
                    .font(EcrinFont.caption)
                    .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? group.color : EcrinColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? group.color.opacity(0.15) : EcrinColor.glassFill)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Sub-category Chip

private struct SubCatChip: View {
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
            .background(isSelected ? color.opacity(0.15) : EcrinColor.glassFill)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? color.opacity(0.4) : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
            }
            .glassChip(enabled: !isSelected)
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Edit Wardrobe Item Sheet (stub rapide)

struct EditWardrobeItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: FashionItem
    var onSave: (FashionItem) -> Void

    @State private var name: String
    @State private var brand: String
    @State private var color: String
    @State private var material: String

    init(item: FashionItem, onSave: @escaping (FashionItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _brand = State(initialValue: item.brand ?? "")
        _color = State(initialValue: item.color ?? "")
        _material = State(initialValue: item.material ?? "")
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack(spacing: EcrinSpacing.lg) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(EcrinColor.textMuted)
                    .frame(width: 36, height: 4)
                    .padding(.top, EcrinSpacing.md)

                HStack {
                    Text(L10n.Common.edit.uppercased())
                        .font(EcrinFont.label).kerning(3)
                        .foregroundStyle(EcrinColor.gold)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)

                Group {
                    editField("Nom", text: $name)
                    editField("Marque", text: $brand)
                    editField("Couleur", text: $color)
                    editField("Matière", text: $material)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                GoldButton(title: L10n.Common.save) {
                    var updated = item
                    updated.name = name
                    updated.brand = brand.isEmpty ? nil : brand
                    updated.color = color.isEmpty ? nil : color
                    updated.material = material.isEmpty ? nil : material
                    onSave(updated)
                    dismiss()
                }
                .padding(.horizontal, EcrinSpacing.lg)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func editField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(EcrinFont.label).kerning(1.5)
                .foregroundStyle(EcrinColor.textMuted)
            TextField(label, text: text)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .padding(EcrinSpacing.md)
                .background(EcrinColor.glassFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Item Try On Sheet (routing vers TryOn avec item présélectionné)

struct ItemTryOnSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: FashionItem

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            VStack(spacing: EcrinSpacing.lg) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(EcrinColor.textMuted)
                    .frame(width: 36, height: 4)
                    .padding(.top, EcrinSpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.TryOn.title.uppercased())
                            .font(EcrinFont.label).kerning(3)
                            .foregroundStyle(EcrinColor.gold)
                        Text(item.name)
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(EcrinColor.textSecondary)
                            .padding(10)
                            .background(EcrinColor.glassFill)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Route selon groupe :
                // Chaussures → vue spécialisée pieds
                // Vêtements/Accessoires → QuickTryOn avec mode auto-détecté
                // Bijoux → TryOnView classique
                Group {
                    if item.category.group == .shoes {
                        ShoesTryOnView(preselectedItem: item)
                    } else if item.category.group == .clothing || item.category.group == .accessories {
                        QuickTryOnView(preselectedItem: .wardrobe(item))
                            .environment(ClothingCatalogService.shared)
                    } else {
                        GenericItemTryOnView(item: item)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Generic Try On pour non-chaussures

struct GenericItemTryOnView: View {
    let item: FashionItem
    @State private var vm = TryOnViewModel()
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                // Prompt zone hint
                GlassCard(cornerRadius: 16) {
                    HStack(spacing: EcrinSpacing.md) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 24, weight: .thin))
                            .foregroundStyle(item.category.group.color)
                            .frame(width: 44, height: 44)
                            .background(item.category.group.color.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(EcrinFont.body)
                                .foregroundStyle(EcrinColor.textPrimary)
                            if let brand = item.brand {
                                Text(brand)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }
                            Text(item.category.rawValue + " · " + item.category.group.rawValue)
                                .font(EcrinFont.caption)
                                .foregroundStyle(item.category.group.color)
                        }
                        Spacer()
                    }
                    .padding(EcrinSpacing.md)
                }

                // Photo
                PhotoDropZone(
                    image: vm.userPhoto,
                    isLoading: vm.isGenerating,
                    onTap: { showPhotoPicker = true }
                )

                // Conseil zone
                zoneTip

                // Result
                if let result = vm.result {
                    ResultCarousel(images: result)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                GoldButton(title: vm.isGenerating ? L10n.CommonUI.generating : L10n.WardrobeUI.tryNow) {
                    Task {
                        await vm.generateFashion(
                            item: item,
                            showPaywall: {}
                        )
                    }
                }
                .disabled(vm.userPhoto == nil || vm.isGenerating)
                .opacity(vm.userPhoto == nil ? 0.4 : 1)
                .padding(.bottom, EcrinSpacing.xxl)
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task { await vm.loadPhoto(from: item) }
        }
    }

    @ViewBuilder
    private var zoneTip: some View {
        let tip: String = switch item.category.bodyZone {
        case .fullBody:   "Photo en pied de préférence pour les vêtements"
        case .feet:       "Photographiez vos jambes depuis le devant"
        case .face, .head: "Portrait face caméra avec bon éclairage"
        case .neck:       "Décolleté visible, fond neutre"
        case .wrist:      "Main et poignet visibles"
        default:          "Fond neutre, bonne luminosité"
        }

        GlassCard(cornerRadius: 12) {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(EcrinColor.gold)
                Text(tip)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }
}
