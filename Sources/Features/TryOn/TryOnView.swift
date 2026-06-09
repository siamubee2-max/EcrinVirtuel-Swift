import SwiftUI
import PhotosUI

struct TryOnView: View {
    @Environment(AppState.self) private var appState
    @Environment(ClothingCatalogService.self) private var catalogService
    @State private var viewModel = TryOnViewModel()
    @State private var lookDuJourVM = LookDuJourViewModel()
    @State private var showPhotoPicker = false
    @State private var selectedLookRecommendation: LookRecommendation?
    @State private var showCatalogFromLook = false
    @State private var showPaywall = false
    @State private var showGenerationAuth = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showEarringsPose = false  // multi-vues BO
    @State private var showMultiPose = false     // multi-vues général
    @State private var showCamera = false
    @State private var showBodyModelPicker = false
    @State private var cameraDenied = false

    // Boucles d'oreilles → EarringsPoseView automatiquement
    private var isEarrings: Bool {
        viewModel.selectedJewelry?.category == .earring
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESSAYAGE")
                                .font(EcrinFont.label)
                                .kerning(3)
                                .foregroundStyle(EcrinColor.gold)
                            Text("Virtuel")
                                .font(EcrinFont.sectionHead)
                                .foregroundStyle(EcrinColor.textPrimary)
                        }
                        Spacer()
                        TrialBadge(remaining: viewModel.trialsRemaining)
                    }
                    .padding(.top, 8)

                    LookDuJourCard(
                        viewModel: lookDuJourVM,
                        onTryLook: { look in
                            // .sheet(item:) s'active dès que selectedLookRecommendation ≠ nil
                            selectedLookRecommendation = look
                        },
                        onOpenCatalog: { showCatalogFromLook = true }
                    )

                    // Photo zone
                    PhotoDropZone(
                        image: viewModel.userPhoto,
                        isLoading: viewModel.isGenerating,
                        onTap: { showPhotoPicker = true }
                    )

                    // 3 sources photo : photothèque (tap drop zone) / caméra / mannequin
                    HStack(spacing: EcrinSpacing.sm) {
                        photoSourceButton(icon: "camera.fill", label: "Prendre", action: openCamera)
                        photoSourceButton(icon: "person.crop.rectangle.stack", label: "Mannequin") {
                            showBodyModelPicker = true
                        }
                    }

                    // Result
                    if let result = viewModel.result {
                        ResultCarousel(images: result)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Jewelry picker — catalogue Supabase avec vraies images
                    JewelryPickerRow(
                        selected: viewModel.selectedJewelry,
                        items: viewModel.jewelryCatalog,
                        onSelect: { viewModel.selectedJewelry = $0 }
                    )

                    // CTA — adaptatif selon le type de bijou
                    VStack(spacing: EcrinSpacing.sm) {
                        GoldButton(
                            title: viewModel.isGenerating ? "Génération…"
                                 : isEarrings ? "Essayer · 3 vues (Face / 3/4 / Profil)"
                                 : "Essayer maintenant"
                        ) {
                            if isEarrings {
                                showEarringsPose = true
                            } else {
                                Task { await generateWithAuth() }
                            }
                        }
                        .disabled(viewModel.userPhoto == nil || viewModel.selectedJewelry == nil || viewModel.isGenerating)
                        .opacity(viewModel.userPhoto == nil || viewModel.selectedJewelry == nil ? 0.4 : 1)

                        // Option multi-vues pour tous les bijoux
                        if viewModel.selectedJewelry != nil && viewModel.userPhoto != nil && !isEarrings {
                            GhostButton(title: "Multi-vues (choisir les angles)") {
                                showMultiPose = true
                            }
                        }
                    }
                    .padding(.bottom, EcrinSpacing.xxl)
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task { await viewModel.loadPhoto(from: item) }
        }
        .task {
            await viewModel.loadCatalog()
            await lookDuJourVM.bootstrap(appState: appState)
        }
        // `.sheet(item:)` garantit que la valeur est non-nil au rendu
        // — évite l'écran noir causé par une évaluation `if let` trop tôt.
        .sheet(item: $selectedLookRecommendation) { look in
            QuickTryOnView(preselectedLook: look)
                .environment(appState)
                .environment(catalogService)
                .environment(LocationService.shared)
                .environment(WeatherService.shared)
        }
        .sheet(isPresented: $showCatalogFromLook) {
            NavigationStack {
                CatalogBrowserView()
            }
        }
        .onChange(of: viewModel.result) { _, newResult in
            newResult?.forEach { SessionCreationsStore.add($0) }
        }
        .sheet(isPresented: $showPaywall) {
            EmotionalPaywallView(generatedImages: SessionCreationsStore.images)
        }
        .sheet(isPresented: $showGenerationAuth) {
            GenerationSignInSheet {
                Task { await viewModel.generate(showPaywall: { showPaywall = true }) }
            }
            .environment(appState)
        }
        // BO → 3 vues automatiques (Face / 3/4 / Profil)
        // preloadedPhoto transmet le mannequin (ou photo perso) déjà choisi
        .sheet(isPresented: $showEarringsPose) {
            if let jewelry = viewModel.selectedJewelry {
                EarringsPoseView(
                    item: .wardrobe(jewelry.asFashionItem),
                    preloadedPhoto: viewModel.userPhoto
                )
            }
        }
        // Autres bijoux → sélecteur multi-vues libre
        .sheet(isPresented: $showMultiPose) {
            if let photo = viewModel.userPhoto,
               let jewelry = viewModel.selectedJewelry {
                let jewelryItem = QuickTryOnItem.wardrobe(jewelry.asFashionItem)
                MultiPoseFlowView(
                    item: jewelryItem,
                    allItems: [jewelryItem],
                    mode: .accessoryOnly,
                    preloadedPhoto: photo
                )
                .environment(appState)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(
                onCapture: { image in
                    viewModel.userPhoto = image
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showBodyModelPicker) {
            BodyModelPickerSheet { img in
                viewModel.userPhoto = img
            }
        }
        .alert("Accès caméra refusé", isPresented: $cameraDenied) {
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text("Autorisez l'accès à la caméra dans Réglages pour prendre une photo dans l'app.")
        }
    }

    // MARK: - Photo source helpers

    private func generateWithAuth() async {
        if await GenerationAuthGate.hasSession() {
            await viewModel.generate(showPaywall: { showPaywall = true })
        } else {
            showGenerationAuth = true
        }
    }

    private func photoSourceButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(EcrinFont.caption)
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
                if granted { showCamera = true } else { cameraDenied = true }
            }
        }
    }
}

struct TrialBadge: View {
    let remaining: Int

    private var label: String {
        if CreditsManager.shared.isUnlimited { return "illimité" }
        return "\(remaining) restants"
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                    .foregroundStyle(EcrinColor.gold)
                Text(label)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
    }
}

struct PhotoDropZone: View {
    let image: UIImage?
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(EcrinColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                image != nil ? EcrinColor.gold.opacity(0.4) : Color.white.opacity(0.15),
                                style: StrokeStyle(lineWidth: 1, dash: image != nil ? [] : [6])
                            )
                    }

                if let image {
                    ZStack {
                        Color.black
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if isLoading {
                        ZStack {
                            Color.black.opacity(0.5)
                            ProgressView()
                                .tint(EcrinColor.gold)
                                .scaleEffect(1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                } else {
                    VStack(spacing: EcrinSpacing.md) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                        Text("Ajouter votre photo")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                            .kerning(1)
                    }
                }
            }
            .frame(height: 320)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter votre photo")
        .accessibilityHint("Ouvre la photothèque")
    }
}

struct JewelryPickerRow: View {
    let selected: JewelryItem?
    let items: [JewelryItem]
    let onSelect: (JewelryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text("CHOISIR UN BIJOU")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.md) {
                    ForEach(items) { item in
                        let isSelected = selected?.id == item.id
                        JewelryThumb(item: item, isSelected: isSelected)
                            .onTapGesture { onSelect(item) }
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct JewelryThumb: View {
    let item: JewelryItem
    let isSelected: Bool

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(spacing: EcrinSpacing.sm) {
                // Photo réelle si disponible, icône SF Symbol en fallback
                if let url = item.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        case .failure:
                            iconFallback
                        default:
                            ProgressView().tint(EcrinColor.gold).frame(width: 70, height: 70)
                        }
                    }
                } else {
                    iconFallback
                }

                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textMuted)
                    .lineLimit(1)
            }
            .padding(EcrinSpacing.sm)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(EcrinColor.gold, lineWidth: 1.5)
            }
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }

    private var iconFallback: some View {
        // Placeholder élégant : dégradé doré + icône bijou + initiale du nom
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            EcrinColor.gold.opacity(0.18),
                            EcrinColor.gold.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(EcrinColor.gold.opacity(0.25), lineWidth: 0.5)
                }
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.gold.opacity(0.6))
                if let first = item.name.first {
                    Text(String(first).uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(EcrinColor.gold.opacity(0.7))
                }
            }
        }
        .frame(width: 70, height: 70)
    }
}

struct ResultCarousel: View {
    let images: [UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text("RÉSULTAT")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.md) {
                    ForEach(images.indices, id: \.self) { i in
                        ZStack {
                            Color.black
                            Image(uiImage: images[i])
                                .resizable()
                                .scaledToFit()
                        }
                        .frame(width: 200, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
    }
}
