import SwiftUI
import PhotosUI

// MARK: - MultiPoseFlowView
// Vue d'essayage multi-poses complète (sélection poses → photo → génération → résultats).
// Présentée en sheet depuis QuickTryOnView quand le toggle "Multi-vues" est activé.

struct MultiPoseFlowView: View {
    let item: QuickTryOnItem        // Article principal (rétrocompatibilité)
    let allItems: [QuickTryOnItem]  // Tous les articles du look (haut + bas + chaussures)
    let mode: QuickTryOnMode
    let preloadedPhoto: UIImage?

    @State private var vm = MultiPoseViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var savedToDressingToast: String? = nil

    @State private var flowStep: FlowStep = .selectPoses
    @State private var userPhoto: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var bodyContext: BodyContext = .default
    @State private var showPaywall = false

    enum FlowStep: Int, CaseIterable {
        case selectPoses  = 0
        case photo        = 1
        case generating   = 2
        case results      = 3
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.top, EcrinSpacing.md)

                stepIndicator
                    .padding(.vertical, EcrinSpacing.md)

                stepContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(EcrinAnimation.easeSlide, value: flowStep)

                if flowStep != .generating && flowStep != .results {
                    bottomBar
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.vertical, EcrinSpacing.md)
                        .background {
                            Rectangle()
                                .fill(EcrinColor.surface)
                                .ignoresSafeArea(edges: .bottom)
                        }
                }
            }

            // Toast de confirmation après sauvegarde dans le dressing
            if let toast = savedToDressingToast {
                VStack {
                    Spacer()
                    HStack(spacing: EcrinSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(EcrinColor.gold)
                        Text(toast)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .background(EcrinColor.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 0.5))
                    .padding(.bottom, EcrinSpacing.xxl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .animation(EcrinAnimation.springSnap, value: savedToDressingToast)
        .preferredColorScheme(.dark)
        .onAppear {
            if let photo = preloadedPhoto {
                userPhoto = photo
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await loadPhoto(from: item) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
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

            VStack(spacing: 2) {
                Text(L10n.MultiPoseUI.multiViewsCaps)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(allItems.count > 1 ? "Tenue complète · \(allItems.count) pièces" : item.name)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Reset (hors étapes generating/results)
            if flowStep.rawValue < 2 {
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        vm.resetSelection()
                        flowStep = .selectPoses
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(EcrinColor.textSecondary)
                        .padding(10)
                        .background(EcrinColor.glassFill, in: Circle())
                        .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .opacity(vm.selectedPoses.isEmpty ? 0 : 1)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: EcrinSpacing.sm) {
            let steps = ["Poses", "Photo", "Génération", "Résultats"]
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                HStack(spacing: EcrinSpacing.sm) {
                    stepDot(index: index, label: label)
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < flowStep.rawValue ? EcrinColor.gold : EcrinColor.glassStroke)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .animation(EcrinAnimation.springSnap, value: flowStep)
                    }
                }
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    private func stepDot(index: Int, label: String) -> some View {
        let isPast    = index < flowStep.rawValue
        let isCurrent = index == flowStep.rawValue
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isPast || isCurrent ? EcrinColor.gold : EcrinColor.glassFill)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if !isPast && !isCurrent {
                            Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                    }
                if isPast {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(EcrinColor.background)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isCurrent ? EcrinColor.background : EcrinColor.textMuted)
                }
            }
        }
        .animation(EcrinAnimation.springSnap, value: flowStep)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch flowStep {
            case .selectPoses:
                PoseSelectorView(fashionCategory: item.fashionCategory, vm: vm)
            case .photo:
                photoStepContent
            case .generating:
                generatingStepContent
            case .results:
                MultiPoseResultView(
                    results: vm.results,
                    item: item,
                    onSaveToDressing: { saveResultsToDressing() },
                    onClose: { dismiss() }
                )
                .onAppear {
                    // Persiste automatiquement chaque vue générée dans « Mes créations »
                    // pour qu'elles ne soient jamais perdues au glissement/fermeture.
                    vm.results.compactMap(\.image).forEach { SessionCreationsStore.add($0) }
                }
            }
        }
        .id(flowStep)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Photo step

    private var photoStepContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: EcrinSpacing.lg) {
                // Summary des poses sélectionnées
                if !vm.selectedPoses.isEmpty {
                    posesSummaryCard
                        .padding(.horizontal, EcrinSpacing.lg)
                }

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
                                Image(systemName: "person.crop.rectangle.badge.plus")
                                    .font(.system(size: 40, weight: .thin))
                                    .foregroundStyle(EcrinColor.textMuted)
                                Text(L10n.MultiPoseUI.addYourPhoto)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.textMuted)
                                Text(mode.photoTip)
                                    .font(.system(size: 10))
                                    .foregroundStyle(EcrinColor.textMuted.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, EcrinSpacing.lg)
                            }
                        }
                    }
                    .frame(height: 300)
                }
                .padding(.horizontal, EcrinSpacing.lg)

                Spacer(minLength: EcrinSpacing.xxl)
            }
            .padding(.top, EcrinSpacing.md)
        }
    }

    private var posesSummaryCard: some View {
        GlassCard(cornerRadius: 14) {
            HStack(spacing: EcrinSpacing.md) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14))
                    .foregroundStyle(EcrinColor.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.selectedPoses.count) vue\(vm.selectedPoses.count > 1 ? "s" : "") sélectionnée\(vm.selectedPoses.count > 1 ? "s" : "")")
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(vm.selectedPoses.map(\.name).joined(separator: " · "))
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(String(format: "%.2f", vm.costEstimate(itemsCount: allItems.count)))$")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                    if allItems.count >= 2 {
                        Text(L10n.MultiPoseUI.nbPro)
                            .font(.system(size: 9, weight: .medium))
                            .kerning(1.2)
                            .foregroundStyle(EcrinColor.gold.opacity(0.8))
                    }
                }
            }
            .padding(EcrinSpacing.md)
        }
    }

    // MARK: - Generating step

    private var generatingStepContent: some View {
        VStack(spacing: EcrinSpacing.xl) {
            Spacer()

            generatingPulse

            VStack(spacing: EcrinSpacing.sm) {
                Text(L10n.MultiPoseUI.multiViewGenerating)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                if let poseId = vm.generatingPoseId,
                   let pose = vm.results.first(where: { $0.id == poseId })?.pose {
                    HStack(spacing: 6) {
                        Image(systemName: pose.icon)
                            .font(.system(size: 12))
                        Text("Vue \(pose.name) en cours…")
                            .font(EcrinFont.caption)
                    }
                    .foregroundStyle(EcrinColor.gold)
                    .animation(EcrinAnimation.springSnap, value: poseId)
                }
            }

            // Progress bar
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
            .padding(.horizontal, EcrinSpacing.xl)

            // Preview des résultats
            resultsMiniGrid

            Spacer()
        }
    }

    private var generatingPulse: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(EcrinColor.gold.opacity(0.12 + Double(i) * 0.08), lineWidth: 1)
                    .frame(width: CGFloat(56 + i * 28), height: CGFloat(56 + i * 28))
            }
            Image(systemName: "sparkle")
                .font(.system(size: 26, weight: .thin))
                .foregroundStyle(EcrinColor.gold)
        }
    }

    private var resultsMiniGrid: some View {
        HStack(spacing: EcrinSpacing.sm) {
            ForEach(vm.results) { result in
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .frame(width: 64, height: 78)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    result.state == .done ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke,
                                    lineWidth: 0.5
                                )
                        }

                    switch result.state {
                    case .waiting:
                        Image(systemName: result.pose.icon)
                            .font(.system(size: 18, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                    case .generating:
                        ProgressView().tint(EcrinColor.gold)
                    case .done:
                        if let img = result.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    case .failed:
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 16, weight: .thin))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: EcrinSpacing.md) {
            if flowStep.rawValue > 0 {
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        flowStep = FlowStep(rawValue: flowStep.rawValue - 1) ?? .selectPoses
                    }
                } label: {
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

            let canNext = canProceedFromCurrentStep
            Button {
                advanceStep()
            } label: {
                HStack(spacing: 6) {
                    Text(nextLabel)
                        .font(EcrinFont.cta)
                        .kerning(2)
                        .textCase(.uppercase)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(canNext ? EcrinColor.background : EcrinColor.textMuted)
                .padding(.horizontal, EcrinSpacing.xl)
                .padding(.vertical, EcrinSpacing.md)
                .background(canNext ? EcrinColor.gold : EcrinColor.gold.opacity(0.25), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canNext)
        }
    }

    private var canProceedFromCurrentStep: Bool {
        switch flowStep {
        case .selectPoses: return !vm.selectedPoses.isEmpty
        case .photo:       return userPhoto != nil
        case .generating, .results: return false
        }
    }

    private var nextLabel: String {
        switch flowStep {
        case .selectPoses: return "Photo"
        case .photo:       return "Générer \(vm.selectedPoses.count)"
        default:           return L10n.Common.next
        }
    }

    private func advanceStep() {
        guard canProceedFromCurrentStep else { return }
        withAnimation(EcrinAnimation.springSnap) {
            switch flowStep {
            case .selectPoses:
                flowStep = .photo
            case .photo:
                flowStep = .generating
                Task { await runGeneration() }
            default:
                break
            }
        }
    }

    private func runGeneration() async {
        guard let photo = userPhoto else { return }
        bodyContext = await BodyContextAnalyzer.shared.analyze(image: photo)

        await vm.generateAll(
            photo: photo,
            items: allItems,
            mode: mode,
            bodyContext: bodyContext
        )

        withAnimation(EcrinAnimation.springSnap) {
            flowStep = .results
        }
    }

    private func loadPhoto(from photoItem: PhotosPickerItem?) async {
        guard let photoItem else { return }
        guard let data = try? await photoItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        userPhoto = image
    }

    /// Sauvegarde chaque image générée comme un nouvel élément de la garde-robe
    /// (le JPEG de l'essayage part dans `WardrobePhotoStore`). Le retour visuel passe par
    /// `savedToDressingToast` et le dismiss après affichage.
    private func saveResultsToDressing() {
        let images = vm.results.compactMap { $0.image }
        guard !images.isEmpty else { return }

        let category = item.fashionCategory
        let baseName = item.name

        for (index, img) in images.enumerated() {
            // Compresser en JPEG raisonnable (0.85) — équivalent à ce qui est fait
            // dans le reste du dressing.
            guard let data = img.jpegData(compressionQuality: 0.85) else { continue }
            let suffix = images.count > 1 ? " (vue \(index + 1))" : ""
            let saved = FashionItem(
                name: baseName + suffix,
                category: category,
                tags: ["essayage virtuel"],
                source: .userPhoto,
                isFavorite: false
            )
            WardrobePhotoStore.shared.save(data, for: saved.id)
            appState.wardrobe.add(saved)
        }

        savedToDressingToast = images.count > 1
            ? L10n.MultiPoseUI.viewsAddedToWardrobe(images.count)
            : L10n.MultiPoseUI.addedToWardrobe

        // Dismiss après un court délai pour laisser voir la confirmation.
        // Using structured Task so the work is tied to view lifecycle and can be cancelled;
        // avoids calling dismiss() on an already-dismissed sheet (DispatchQueue.main.asyncAfter
        // is not cancellable and can double-dismiss a SwiftUI sheet).
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}

// MARK: - MultiViewToggle
// Petit composant toggle à intégrer dans QuickTryOnView step 0 ou step 1.

struct MultiViewToggle: View {
    @Binding var isEnabled: Bool
    let poseCount: Int

    var body: some View {
        Button {
            withAnimation(EcrinAnimation.springSnap) {
                isEnabled.toggle()
            }
        } label: {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: isEnabled ? "square.grid.2x2.fill" : "square.grid.2x2")
                    .font(.system(size: 14))
                    .foregroundStyle(isEnabled ? EcrinColor.gold : EcrinColor.textSecondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.MultiPoseUI.multiViews)
                        .font(EcrinFont.body)
                        .foregroundStyle(isEnabled ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                    Text(isEnabled ? "\(poseCount) pose\(poseCount > 1 ? "s" : "") sélectionnée\(poseCount > 1 ? "s" : "")" : "1 vue par défaut")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }

                Spacer()

                ZStack {
                    Capsule()
                        .fill(isEnabled ? EcrinColor.gold.opacity(0.3) : EcrinColor.glassFill)
                        .frame(width: 42, height: 24)
                        .overlay {
                            Capsule().strokeBorder(
                                isEnabled ? EcrinColor.gold.opacity(0.6) : EcrinColor.glassStroke,
                                lineWidth: 0.5
                            )
                        }
                    Circle()
                        .fill(isEnabled ? EcrinColor.gold : EcrinColor.textMuted)
                        .frame(width: 18, height: 18)
                        .offset(x: isEnabled ? 9 : -9)
                }
            }
            .padding(EcrinSpacing.md)
            .background(
                isEnabled ? EcrinColor.gold.opacity(0.06) : EcrinColor.glassFill,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isEnabled ? EcrinColor.gold.opacity(0.3) : EcrinColor.glassStroke,
                        lineWidth: 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
