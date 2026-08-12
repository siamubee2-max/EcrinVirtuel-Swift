import SwiftUI
import PhotosUI

// MARK: - QuickTryOnView — Vue principale 4 étapes

struct QuickTryOnView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = QuickTryOnViewModel()
    @Environment(ClothingCatalogService.self) private var catalogService
    @Environment(\.dismiss) private var dismiss

    @State private var showPhotoGuide = false
    @State private var showProportionGuide = ProportionGuideView.shouldShow
    @State private var showResult = false
    @State private var showPaywall = false
    @State private var showGenerationAuth = false
    private enum PickerTab { case wardrobe, catalog }
    @State private var pickerTab: PickerTab = .wardrobe
    @State private var multiPoseEnabled = false  // toggle multi-vues
    @State private var showMultiPoseFlow = false
    @State private var showBodyModelPicker = false
    @State private var showCamera = false
    @State private var cameraDenied = false

    var preselectedItem: QuickTryOnItem?
    var preselectedLook: LookRecommendation?
    /// Mode forcé — utiliser pour "Complète ce look" (fullOutfit) depuis la garde-robe.
    var preselectedMode: QuickTryOnMode?

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.md)

                stepIndicator
                    .padding(.vertical, EcrinSpacing.md)

                // Contenu selon étape courante
                stepContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

                // Bottom nav
                bottomNav
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background {
                        Rectangle()
                            .fill(EcrinColor.surface)
                            .ignoresSafeArea(edges: .bottom)
                    }
            }

            // Photo Guide Overlay
            if showPhotoGuide, let mode = vm.selectedMode {
                PhotoGuideOverlay(mode: mode) {
                    withAnimation(EcrinAnimation.glassReveal) {
                        showPhotoGuide = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let look = preselectedLook {
                vm.applyLookRecommendation(look)
            } else if let item = preselectedItem {
                // Utilise le mode forcé (ex. fullOutfit depuis "Complète ce look")
                // ou détecte automatiquement le mode compatible avec l'article.
                let resolvedMode: QuickTryOnMode? = preselectedMode
                    ?? QuickTryOnMode.allCases.first(where: {
                        $0.compatibleCategories.contains(item.fashionCategory)
                    })
                if let mode = resolvedMode {
                    vm.selectedMode = mode
                    vm.currentStep = 1
                }
                vm.addItem(item)
            }
        }
        .task {
            // Injecter la vraie garde-robe depuis AppState (se met à jour si la garde-robe change).
            vm.wardrobeItems = appState.wardrobe.items
            await vm.loadCatalog(force: true)
        }
        .onChange(of: appState.wardrobe.items) { _, items in
            vm.wardrobeItems = items
        }
        .onChange(of: pickerTab) { _, tab in
            guard tab == .catalog else { return }
            Task { await vm.loadCatalog(force: catalogService.totalCount == 0) }
        }
        .sheet(isPresented: $showPaywall) {
            EmotionalPaywallView(generatedImages: SessionCreationsStore.images)
        }
        .sheet(isPresented: $showGenerationAuth) {
            GenerationSignInSheet {
                Task { await vm.generate(showPaywall: { showPaywall = true }) }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showProportionGuide) {
            ProportionGuideView(onDismiss: { showProportionGuide = false })
        }
        // Multi-vues — sélecteur de poses (passe tous les articles du look)
        .sheet(isPresented: $showMultiPoseFlow) {
            if let photo = vm.userPhoto,
               let item = vm.selectedItems.first,
               let mode = vm.selectedMode {
                MultiPoseFlowView(
                    item: item,
                    allItems: vm.selectedItems,
                    mode: mode,
                    preloadedPhoto: photo
                )
                .environment(appState)
            }
        }
        .fullScreenCover(isPresented: $showResult) {
            if let image = vm.result {
                QuickTryOnResultView(
                    image: image,
                    modeName: vm.selectedMode?.rawValue ?? "Essayage",
                    onRetry: {
                        showResult = false
                        vm.result = nil
                    },
                    onClose: {
                        showResult = false
                        dismiss()
                    },
                    onNextJewelry: CreditsManager.shared.remaining > 0 ? {
                        showResult = false
                        vm.result = nil
                        vm.currentStep = 1
                    } : nil,
                    creditsRemaining: CreditsManager.shared.remaining,
                    nudgePicks: WizardConfig.nudgePicks,
                    onSelectNudgeJewelry: { _ in
                        showResult = false
                        vm.result = nil
                        vm.currentStep = 1
                    }
                )
            }
        }
        .onChange(of: vm.result) { _, newResult in
            if let image = newResult {
                SessionCreationsStore.add(image)
                showResult = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: EcrinSpacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.close)

            Spacer()

            VStack(spacing: 2) {
                Text(L10n.QuickTryOnUI.quickTryOnTitle)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(vm.selectedMode?.rawValue ?? "Choisir le mode")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .animation(.none, value: vm.selectedMode?.rawValue)
            }

            Spacer()

            // Reset si pas à l'étape 0
            if vm.currentStep > 0 {
                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(EcrinColor.textSecondary)
                        .padding(10)
                        .background(EcrinColor.glassFill, in: Circle())
                        .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.reset)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: EcrinSpacing.sm) {
                    stepDot(index: index)
                    if index < 3 {
                        Rectangle()
                            .fill(index < vm.currentStep ? EcrinColor.gold : EcrinColor.glassStroke)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .animation(EcrinAnimation.springSnap, value: vm.currentStep)
                    }
                }
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    private func stepDot(index: Int) -> some View {
        let isPast    = index < vm.currentStep
        let isCurrent = index == vm.currentStep

        return ZStack {
            Circle()
                .fill(
                    isPast || isCurrent
                        ? EcrinColor.gold
                        : EcrinColor.glassFill
                )
                .frame(width: 24, height: 24)
                .overlay {
                    if !isPast && !isCurrent {
                        Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    }
                }

            if isPast {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(EcrinColor.background)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isCurrent ? EcrinColor.background : EcrinColor.textMuted)
            }
        }
        .animation(EcrinAnimation.springSnap, value: vm.currentStep)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch vm.currentStep {
            case 0: step0ModeGrid
            case 1: step1ItemPicker
            case 2: step2PhotoZone
            case 3: step3Generate
            default: EmptyView()
            }
        }
        .id(vm.currentStep) // force transition on step change
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Étape 0 : Grille des modes

    private var step0ModeGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: EcrinSpacing.md
                ) {
                    ForEach(QuickTryOnMode.allCases) { mode in
                        ModeCard(
                            mode: mode,
                            isSelected: vm.selectedMode == mode
                        ) {
                            withAnimation(EcrinAnimation.springSnap) {
                                vm.selectMode(mode)
                            }
                        }
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Conseil contextuel
                if let mode = vm.selectedMode {
                    GlassCard(cornerRadius: 14) {
                        HStack(spacing: EcrinSpacing.md) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(EcrinColor.gold)
                            Text(mode.photoTip)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(EcrinSpacing.md)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.vertical, EcrinSpacing.md)
        }
    }

    // MARK: - Étape 1 : Sélection articles

    private var step1ItemPicker: some View {
        VStack(spacing: 0) {
            // Tab switcher Ma garde-robe | Catalogue
            tabSwitcher
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.bottom, EcrinSpacing.sm)

            // Chips des articles sélectionnés
            if !vm.selectedItems.isEmpty {
                selectedItemsChips
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.sm)
            }

            // Contenu du tab actif
            if pickerTab == .wardrobe {
                wardrobePickerContent
            } else {
                CatalogBrowserMiniView(vm: vm)
                    .environment(catalogService)
            }

            // Indication de sélection max
            if let mode = vm.selectedMode, mode.maxItemCount > 1 {
                Text("\(vm.selectedItems.count) / \(mode.maxItemCount) articles sélectionnés")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.vertical, EcrinSpacing.sm)
            }
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Ma garde-robe",
                icon: "hanger",
                isSelected: pickerTab == .wardrobe
            ) {
                withAnimation(EcrinAnimation.springSnap) { pickerTab = .wardrobe }
            }
            TabButton(
                title: "Catalogue",
                icon: "storefront.fill",
                isSelected: pickerTab == .catalog
            ) {
                withAnimation(EcrinAnimation.springSnap) { pickerTab = .catalog }
            }
        }
        .background(EcrinColor.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        }
    }

    private var wardrobePickerContent: some View {
        Group {
            if vm.filteredWardrobeItems.isEmpty {
                VStack(spacing: EcrinSpacing.md) {
                    Image(systemName: "hanger")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(EcrinColor.textMuted)
                    Text(L10n.QuickTryOnUI.noCompatiblePiece)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(EcrinSpacing.xl)
            } else {
                ScrollView(showsIndicators: false) {
                    let cols = [GridItem(.flexible(), spacing: EcrinSpacing.sm),
                                GridItem(.flexible(), spacing: EcrinSpacing.sm),
                                GridItem(.flexible(), spacing: EcrinSpacing.sm)]
                    LazyVGrid(columns: cols, spacing: EcrinSpacing.sm) {
                        ForEach(vm.filteredWardrobeItems) { item in
                            WardrobeMiniCard(
                                item: item,
                                isSelected: vm.isSelected(.wardrobe(item))
                            ) {
                                withAnimation(EcrinAnimation.springSnap) {
                                    vm.toggleItem(.wardrobe(item))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.lg)
                }
            }
        }
    }

    private var selectedItemsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(vm.selectedItems) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(EcrinColor.gold)
                        Text(item.name)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .lineLimit(1)
                        Button {
                            withAnimation(EcrinAnimation.springSnap) {
                                vm.removeItem(item)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(EcrinColor.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.QuickTryOnUI.removeThisItem)
                    }
                    .padding(.horizontal, EcrinSpacing.sm)
                    .padding(.vertical, 6)
                    .background(EcrinColor.gold.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 0.5))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Étape 2 : Photo

    private var step2PhotoZone: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                // Bouton Conseils photo
                HStack {
                    Spacer()
                    Button {
                        showProportionGuide = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 13))
                            Text(L10n.QuickTryOnUI.photoTips)
                                .font(EcrinFont.caption)
                        }
                        .foregroundStyle(EcrinColor.gold.opacity(0.8))
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, 6)
                        .background(EcrinColor.gold.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // Summary des items choisis
                if !vm.selectedItems.isEmpty {
                    itemsSummaryCard
                        .padding(.horizontal, EcrinSpacing.lg)
                }

                // Zone photo + guide
                VStack(spacing: EcrinSpacing.md) {
                    PhotosPicker(
                        selection: $vm.selectedPhotoItem,
                        matching: .images
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(EcrinColor.glassFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(
                                            vm.userPhoto != nil
                                                ? EcrinColor.gold.opacity(0.4)
                                                : EcrinColor.glassStroke,
                                            style: StrokeStyle(lineWidth: 1, dash: vm.userPhoto != nil ? [] : [6])
                                        )
                                }

                            if let photo = vm.userPhoto {
                                // Fond noir + scaledToFit pour garder le mannequin entier (pas de crop bas)
                                ZStack {
                                    Color.black
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFit()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else {
                                VStack(spacing: EcrinSpacing.md) {
                                    Image(systemName: "person.crop.rectangle.badge.plus")
                                        .font(.system(size: 40, weight: .thin))
                                        .foregroundStyle(EcrinColor.textMuted)
                                    Text(L10n.MultiPoseUI.addYourPhoto)
                                        .font(EcrinFont.caption)
                                        .foregroundStyle(EcrinColor.textMuted)
                                    Text(vm.selectedMode?.photoTip ?? "")
                                        .font(.system(size: 10))
                                        .foregroundStyle(EcrinColor.textMuted.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, EcrinSpacing.lg)
                                }
                            }
                        }
                        .frame(height: 320)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)

                    // Triple-choix : caméra / photothèque / mannequin
                    HStack(spacing: EcrinSpacing.sm) {
                        photoSourceButton(
                            icon: "camera.fill",
                            label: "Prendre",
                            action: openCamera
                        )
                        photoSourceButton(
                            icon: "person.crop.rectangle.stack",
                            label: "Mannequin",
                            action: { showBodyModelPicker = true }
                        )
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.xs)

                    // Bouton guide photo
                    if let mode = vm.selectedMode {
                        Button {
                            withAnimation(EcrinAnimation.glassReveal) {
                                showPhotoGuide = true
                            }
                        } label: {
                            HStack(spacing: EcrinSpacing.sm) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 14))
                                Text("Voir le guide de pose pour « \(mode.rawValue) »")
                                    .font(EcrinFont.caption)
                            }
                            .foregroundStyle(EcrinColor.gold.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: EcrinSpacing.xxl)
            }
            .padding(.top, EcrinSpacing.md)
        }
        .onChange(of: vm.selectedPhotoItem) { _, item in
            Task { await vm.loadPhoto(from: item) }
        }
        .sheet(isPresented: $showBodyModelPicker) {
            BodyModelPickerSheet(onPick: { img in vm.userPhoto = img }, mode: vm.selectedMode)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(
                onCapture: { image in
                    vm.userPhoto = image
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .alert("Accès caméra refusé", isPresented: $cameraDenied) {
            Button(L10n.TryOnUI.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.TryOnUI.cameraAccessSettingsHint)
        }
    }

    // MARK: - Photo source helpers

    private func photoSourceButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                Text(label)
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(EcrinColor.gold.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(EcrinColor.gold.opacity(0.08))
                    .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private func openCamera() {
        Task {
            let granted = await CameraAvailability.requestPermission()
            await MainActor.run {
                if granted {
                    showCamera = true
                } else {
                    cameraDenied = true
                }
            }
        }
    }

    private var itemsSummaryCard: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text(L10n.QuickTryOnUI.selectedItems)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)

                ForEach(vm.selectedItems) { item in
                    HStack(spacing: EcrinSpacing.sm) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(item.groupColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(EcrinFont.body)
                                .foregroundStyle(EcrinColor.textPrimary)
                            if let brand = item.brand {
                                Text(brand)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }
                        }
                        Spacer()
                        Text(item.categoryLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Étape 3 : Génération

    private var step3Generate: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                // Récap photo + articles
                if let photo = vm.userPhoto {
                    ZStack(alignment: .bottomLeading) {
                        ZStack {
                            Color.black
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        GlassCard(cornerRadius: 12) {
                            HStack(spacing: EcrinSpacing.sm) {
                                Image(systemName: vm.selectedMode?.icon ?? "sparkle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(EcrinColor.gold)
                                Text(vm.selectedMode?.rawValue ?? "")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                                Text("·")
                                    .foregroundStyle(EcrinColor.textMuted)
                                Text("\(vm.selectedItems.count) article\(vm.selectedItems.count > 1 ? "s" : "")")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textSecondary)
                            }
                            .padding(.horizontal, EcrinSpacing.md)
                            .padding(.vertical, EcrinSpacing.sm)
                        }
                        .padding(EcrinSpacing.md)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }

                // Erreur
                if let error = vm.errorMessage {
                    GlassCard(cornerRadius: 12) {
                        HStack(spacing: EcrinSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                        }
                        .padding(EcrinSpacing.md)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }

                // CTA principal
                if vm.isGenerating {
                    VStack(spacing: EcrinSpacing.md) {
                        ProgressView()
                            .tint(EcrinColor.gold)
                            .scaleEffect(1.4)
                        Text(L10n.MultiPoseUI.generationInProgress)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EcrinSpacing.lg)
                } else {
                    VStack(spacing: EcrinSpacing.sm) {
                        // Toggle multi-vues
                        MultiViewToggle(isEnabled: $multiPoseEnabled, poseCount: vm.selectedItems.count)
                            .padding(.bottom, EcrinSpacing.xs)

                        GoldButton(
                            title: multiPoseEnabled ? "Choisir mes angles →" : "Essayer maintenant"
                        ) {
                            if multiPoseEnabled {
                                showMultiPoseFlow = true
                            } else {
                                Task { await generateWithAuth() }
                            }
                        }
                    }
                }

                Spacer(minLength: EcrinSpacing.xxl)
            }
            .padding(.top, EcrinSpacing.md)
        }
    }

    // MARK: - Bottom Nav

    private func generateWithAuth() async {
        if await GenerationAuthGate.hasSession() {
            await vm.generate(showPaywall: { showPaywall = true })
            // Synchronise le contexte corporel vers AppState pour le scoring bijoux
            if let ctx = vm.lastBodyContext {
                appState.lastBodyContext = ctx
            }
        } else {
            showGenerationAuth = true
        }
    }

    private var bottomNav: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Retour
            if vm.currentStep > 0 {
                Button { vm.goBack() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n.Common.previous)
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(EcrinColor.glassFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Suivant / Générer selon étape
            if vm.currentStep < 3 {
                Button {
                    if vm.currentStep == 2 && vm.userPhoto == nil {
                        // Afficher guide si pas de photo
                        withAnimation { showPhotoGuide = true }
                    } else {
                        vm.advanceStep()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(nextButtonLabel)
                            .font(EcrinFont.cta)
                            .kerning(2)
                            .textCase(.uppercase)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(vm.canProceedToNextStep ? EcrinColor.background : EcrinColor.textMuted)
                    .padding(.horizontal, EcrinSpacing.xl)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(
                        vm.canProceedToNextStep ? EcrinColor.gold : EcrinColor.gold.opacity(0.25),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(!vm.canProceedToNextStep)
            }
        }
    }

    private var nextButtonLabel: String {
        switch vm.currentStep {
        case 0: return "Choisir article"
        case 1: return "Photo"
        case 2: return "Générer"
        default: return L10n.Common.next
        }
    }
}

// MARK: - ModeCard

private struct ModeCard: View {
    let mode: QuickTryOnMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: EcrinSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? EcrinColor.gold.opacity(0.2) : EcrinColor.glassFill)
                        .frame(width: 52, height: 52)
                        .overlay {
                            Circle().strokeBorder(
                                isSelected ? EcrinColor.gold.opacity(0.6) : EcrinColor.glassStroke,
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                        }

                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                }

                Text(mode.rawValue)
                    .font(EcrinFont.caption)
                    .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EcrinSpacing.md)
            .background(
                isSelected ? EcrinColor.gold.opacity(0.06) : EcrinColor.glassFill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                        lineWidth: isSelected ? 1.2 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - WardrobeMiniCard

private struct WardrobeMiniCard: View {
    let item: FashionItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: EcrinSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.category.group.color.opacity(0.12))
                            .frame(height: 64)

                        Image(systemName: item.category.icon)
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(
                                isSelected ? EcrinColor.gold : item.category.group.color
                            )
                    }

                    VStack(spacing: 2) {
                        Text(item.name)
                            .font(EcrinFont.caption)
                            .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if let brand = item.brand {
                            Text(brand)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(EcrinColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(EcrinSpacing.sm)
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
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - TabButton

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? EcrinColor.gold.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}
