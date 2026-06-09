import SwiftUI
import PhotosUI

// MARK: - EarringsPoseView
// Vue dédiée aux boucles d'oreilles — 3 poses pré-sélectionnées, triptyque automatique.

struct EarringsPoseView: View {
    let item: QuickTryOnItem
    /// Photo pré-chargée (mannequin ou photo déjà choisie dans TryOnView).
    /// Si fournie, la step photo est pré-remplie — l'utilisateur n'a plus à sélectionner.
    var preloadedPhoto: UIImage? = nil

    @State private var vm = MultiPoseViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var userPhoto: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showResult: Bool = false
    @State private var currentStep: EarStep = .photo
    @State private var fullScreenImage: UIImage? = nil

    enum EarStep {
        case photo
        case generating
        case results
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.md)

                Divider()
                    .background(EcrinColor.glassStroke)
                    .padding(.vertical, EcrinSpacing.md)

                switch currentStep {
                case .photo:
                    photoStep
                case .generating:
                    generatingStep
                case .results:
                    resultsStep
                }
            }

            if let img = fullScreenImage {
                fullScreenOverlay(image: img)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Pré-sélectionner les 3 poses BO par défaut
            vm.selectedPoses = PoseVariant.earringsPoses
            // Utiliser la photo pré-chargée (mannequin ou photo perso) si fournie
            if let p = preloadedPhoto {
                userPhoto = p
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await loadPhoto(from: item) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text("ESSAYAGE · BOUCLES D'OREILLES")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.gold)
                Text(item.name)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: - Step : Photo

    private var photoStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                // Poses sélectionnées (modifiables)
                posesPanel
                    .padding(.horizontal, EcrinSpacing.lg)

                // Zone photo
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(EcrinColor.glassFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(
                                        userPhoto != nil
                                            ? EcrinColor.gold.opacity(0.4)
                                            : EcrinColor.glassStroke,
                                        style: StrokeStyle(lineWidth: 1, dash: userPhoto != nil ? [] : [6])
                                    )
                            }

                        if let photo = userPhoto {
                            ZStack {
                                Color.black
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFit()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        } else {
                            VStack(spacing: EcrinSpacing.md) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 44, weight: .thin))
                                    .foregroundStyle(EcrinColor.textMuted)
                                Text("Ajouter votre photo")
                                    .font(EcrinFont.body)
                                    .foregroundStyle(EcrinColor.textMuted)
                                Text("Portrait face / 3/4 — oreilles visibles")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textMuted.opacity(0.6))
                            }
                        }
                    }
                    .frame(height: 300)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                // CTA
                if userPhoto != nil {
                    GoldButton(title: "Générer \(vm.selectedPoses.count) vues") {
                        withAnimation(EcrinAnimation.springSnap) {
                            currentStep = .generating
                        }
                        Task { await startGeneration() }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }

                Spacer(minLength: EcrinSpacing.xxl)
            }
            .padding(.top, EcrinSpacing.md)
        }
    }

    // MARK: - Poses panel (3 poses BO, on peut décocher)

    private var posesPanel: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                HStack {
                    Text("VUES GÉNÉRÉES")
                        .font(EcrinFont.label)
                        .kerning(2)
                        .foregroundStyle(EcrinColor.textMuted)
                    Spacer()
                    Text("\(vm.selectedPoses.count) vue\(vm.selectedPoses.count > 1 ? "s" : "")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(EcrinColor.gold)
                }

                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(PoseVariant.earringsPoses) { pose in
                        let isSelected = vm.isSelected(pose)
                        Button {
                            withAnimation(EcrinAnimation.springSnap) {
                                vm.togglePose(pose)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textMuted)
                                Text(pose.name)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textMuted)
                            }
                            .padding(.horizontal, EcrinSpacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? EcrinColor.gold.opacity(0.1) : Color.clear,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        isSelected ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke,
                                        lineWidth: 0.5
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(EcrinAnimation.springSnap, value: isSelected)
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Step : Generating

    private var generatingStep: some View {
        VStack(spacing: EcrinSpacing.xl) {
            Spacer()

            // Animation de génération
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(EcrinColor.gold.opacity(0.15 + Double(i) * 0.1), lineWidth: 1)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                }
                Image(systemName: "sparkle")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(EcrinColor.gold)
            }

            VStack(spacing: EcrinSpacing.sm) {
                Text("Génération en cours…")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                if let poseId = vm.generatingPoseId,
                   let pose = vm.results.first(where: { $0.id == poseId })?.pose {
                    Text("Vue \(pose.name)")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold)
                        .animation(EcrinAnimation.springSnap, value: poseId)
                }
            }

            // Progress
            progressBar
                .padding(.horizontal, EcrinSpacing.xl)

            resultsPreviewStrip

            Spacer()
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EcrinColor.glassFill)
                    .overlay(Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                    .frame(height: 4)

                Capsule()
                    .fill(EcrinColor.gold)
                    .frame(width: max(8, geo.size.width * vm.progress), height: 4)
                    .animation(EcrinAnimation.springSnap, value: vm.progress)
            }
        }
        .frame(height: 4)
    }

    // Miniatures des résultats qui apparaissent progressivement
    private var resultsPreviewStrip: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(vm.results) { result in
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .frame(width: 72, height: 88)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }

                    switch result.state {
                    case .waiting:
                        Image(systemName: result.pose.icon)
                            .font(.system(size: 20, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                    case .generating:
                        ProgressView()
                            .tint(EcrinColor.gold)
                    case .done:
                        if let img = result.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(EcrinColor.gold)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(4)
                    case .failed:
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18, weight: .thin))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .frame(width: 72, height: 88)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Step : Results (triptyque)

    private var resultsStep: some View {
        VStack(spacing: 0) {
            // Triptyque 3 colonnes — ratio 9:16 vertical story
            // (format mobile natif, immersif pour visualiser les boucles).
            ScrollView {
                HStack(spacing: 2) {
                    let doneResults = vm.results.filter { $0.state == .done && $0.image != nil }
                    ForEach(doneResults) { result in
                        triptychCellFlexible(result: result)
                            .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    }
                }
                .padding(.horizontal, EcrinSpacing.xs)
                .padding(.top, EcrinSpacing.md)
            }

            // Error message
            if let error = vm.errorMessage {
                Text(error)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.sm)
            }

            // Actions
            HStack(spacing: EcrinSpacing.md) {
                GhostButton(title: L10n.Common.share) {
                    let images = vm.results.compactMap(\.image)
                    guard !images.isEmpty else { return }
                    // share
                }

                GoldButton(title: "Sauvegarder") {
                    for result in vm.results {
                        if let img = result.image {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        }
                    }
                }
            }
            .padding(EcrinSpacing.lg)
        }
    }

    /// Cellule flexible — la taille est dictée par le parent (aspectRatio sur le grid).
    /// Plus de bandes noires énormes : l'image fit dans la cellule à ratio image.
    private func triptychCellFlexible(result: MultiPoseViewModel.PoseResult) -> some View {
        ZStack(alignment: .bottom) {
            Color.black

            if let img = result.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            }

            Text(result.pose.name.uppercased())
                .font(EcrinFont.label)
                .kerning(1.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5))
                .padding(.bottom, EcrinSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            withAnimation(EcrinAnimation.glassReveal) {
                fullScreenImage = result.image
            }
        }
    }

    // MARK: - Fullscreen overlay (tap-to-zoom)

    private func fullScreenOverlay(image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(EcrinAnimation.glassReveal) {
                        fullScreenImage = nil
                    }
                }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(EcrinSpacing.md)

            VStack {
                HStack {
                    Button {
                        withAnimation(EcrinAnimation.glassReveal) {
                            fullScreenImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(EcrinSpacing.lg)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Spacer()

                HStack(spacing: EcrinSpacing.lg) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    } label: {
                        fullScreenActionButton(icon: "square.and.arrow.down", label: "Sauvegarder")
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Share this single image
                        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(av, animated: true)
                        }
                    } label: {
                        fullScreenActionButton(icon: "square.and.arrow.up", label: L10n.Common.share)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, EcrinSpacing.xl)
            }
        }
    }

    private func fullScreenActionButton(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.15), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            Text(label)
                .font(EcrinFont.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Helpers

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        userPhoto = image
    }

    private func startGeneration() async {
        guard let photo = userPhoto else { return }
        let defaultMode = QuickTryOnMode.allCases.first(where: {
            $0.compatibleCategories.contains(item.fashionCategory)
        }) ?? QuickTryOnMode.allCases[0]

        // Analyse réelle de la photo (teint, lumière, morphologie) — indispensable
        // pour que le prompt bijou respecte la zone et le rendu.
        let context = await BodyContextAnalyzer.shared.analyze(image: photo)

        await vm.generateAll(
            photo: photo,
            items: [item],
            mode: defaultMode,
            bodyContext: context
        )

        withAnimation(EcrinAnimation.springSnap) {
            currentStep = .results
        }
    }
}
