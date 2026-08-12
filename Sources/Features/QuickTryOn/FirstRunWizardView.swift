// FirstRunWizardView.swift
// Path: Sources/Features/QuickTryOn/FirstRunWizardView.swift

import SwiftUI
import PhotosUI
import Vision
import UIKit

struct FirstRunWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Lance la génération IA depuis l'étape loading. Retourne `true` si succès.
    let onGenerate: (UIImage, JewelryItem) async -> Bool

    // MARK: - Step state

    @State private var step: Int = 0
    @State private var selectedPhoto: UIImage? = nil
    @State private var selectedJewelry: JewelryItem = WizardConfig.starJewelry
    @State private var photoQuality: PhotoQualityAnalyzer.Quality? = nil
    @State private var isAnalyzing: Bool = false

    // MARK: - Photo picker state

    @State private var photoPickerItem: PhotosPickerItem? = nil

    // MARK: - Loading step subtexts

    private let loadingSubtexts = [
        "Analyse de votre photo…",
        "Application du bijou…",
        "Rendu final en cours…",
    ]
    @State private var loadingSubtextIndex: Int = 0
    @State private var loadingSubtextTask: Task<Void, Never>? = nil

    // MARK: - Rings animation

    @State private var ringPulse: Bool = false
    @State private var generationError: String? = nil
    @State private var jewelryCardsAppeared: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                stepProgressHeader

                // Page content
                Group {
                    switch step {
                    case 0: photoStep
                    case 1: jewelryStep
                    default: loadingStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPhoto(from: newItem) }
        }
        .onDisappear {
            loadingSubtextTask?.cancel()
        }
    }

    // MARK: - Step progress header

    private var stepProgressHeader: some View {
        HStack(spacing: EcrinSpacing.sm) {
            // Back button (steps 1 and 2)
            if step > 0 && step < 2 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(EcrinAnimation.springSnap) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.gold)
                        .frame(width: 36, height: 36)
                }
            } else {
                Spacer().frame(width: 36)
            }

            Spacer()

            // Step dots
            HStack(spacing: EcrinSpacing.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? EcrinColor.gold : EcrinColor.glassStroke)
                        .frame(width: i == step ? 24 : 8, height: 4)
                        .animation(EcrinAnimation.springSnap, value: step)
                }
            }

            Spacer()

            // Close button (only on step 0)
            if step == 0 {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .frame(width: 36, height: 36)
                }
            } else {
                Spacer().frame(width: 36)
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.top, EcrinSpacing.md)
        .padding(.bottom, EcrinSpacing.sm)
    }

    // MARK: - Step 0: Photo guide

    private var photoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EcrinSpacing.lg) {

                // Header label
                Text(L10n.QuickTryOnUI.step1YourPhoto)
                    .font(EcrinFont.label)
                    .kerning(1.5)
                    .foregroundStyle(EcrinColor.gold)

                // Title
                Text(L10n.QuickTryOnUI.rightPhotoMatters)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Tips
                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    photoTip("Fond neutre ou clair")
                    photoTip("Lumière naturelle de face")
                    photoTip("Buste visible, pas de chapeau")
                }

                // Photo picker zone
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    photoPickerZone
                }
                .buttonStyle(.plain)

                // Quality badge
                if let quality = photoQuality {
                    qualityBadge(quality)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // CTA buttons
                VStack(spacing: EcrinSpacing.sm) {
                    if let quality = photoQuality {
                        if quality == .poor {
                            // Warn but allow continue
                            VStack(spacing: EcrinSpacing.sm) {
                                Text(L10n.QuickTryOnUI.photoHardToProcess)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(Color.red.opacity(0.8))
                                    .multilineTextAlignment(.center)

                                GoldButton(title: L10n.QuickTryOnUI.nextCta) {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(EcrinAnimation.springSnap) { step = 1 }
                                }

                                Button(L10n.OutfitBuilderUI.continueAnyway) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(EcrinAnimation.springSnap) { step = 1 }
                                }
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                            }
                        } else {
                            GoldButton(title: L10n.QuickTryOnUI.nextCta) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(EcrinAnimation.springSnap) { step = 1 }
                            }
                        }
                    } else if selectedPhoto != nil {
                        // Photo selected but analysis still running
                        HStack(spacing: EcrinSpacing.sm) {
                            ProgressView()
                                .tint(EcrinColor.gold)
                            Text(L10n.JewelryDetectionUI.analyzing)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(EcrinAnimation.glassReveal, value: photoQuality != nil)
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xl)
        }
    }

    @ViewBuilder
    private var photoPickerZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            EcrinColor.glassStroke,
                            style: StrokeStyle(lineWidth: 1, dash: selectedPhoto == nil ? [6, 4] : [])
                        )
                }

            if let photo = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isAnalyzing {
                            ProgressView()
                                .tint(EcrinColor.gold)
                                .padding(EcrinSpacing.sm)
                                .background(EcrinColor.surface.opacity(0.8))
                                .clipShape(Circle())
                                .padding(EcrinSpacing.sm)
                        }
                    }
            } else {
                VStack(spacing: EcrinSpacing.sm) {
                    Text("📷")
                        .font(.system(size: 32))
                    Text(L10n.QuickTryOnUI.tapToChoosePhoto)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(height: 180)
    }

    @ViewBuilder
    private func photoTip(_ text: String) -> some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .font(.system(size: 14))
            Text(text)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textSecondary)
        }
    }

    @ViewBuilder
    private func qualityBadge(_ quality: PhotoQualityAnalyzer.Quality) -> some View {
        HStack(spacing: EcrinSpacing.sm) {
            Text(quality.emoji)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(quality.label)
                    .font(EcrinFont.label)
                    .kerning(1.5)
                    .foregroundStyle(quality.color)

                Text(quality.description)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            Spacer()
        }
        .padding(EcrinSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(quality.color.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(quality.color.opacity(0.25), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Step 1: Jewelry picker

    private var jewelryStep: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.lg) {

            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                Text(L10n.QuickTryOnUI.step2YourJewel)
                    .font(EcrinFont.label)
                    .kerning(1.5)
                    .foregroundStyle(EcrinColor.gold)

                Text(L10n.QuickTryOnUI.currentFavorites)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, EcrinSpacing.lg)

            // 2×2 grid
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: EcrinSpacing.sm),
                          GridItem(.flexible(), spacing: EcrinSpacing.sm)],
                spacing: EcrinSpacing.sm
            ) {
                ForEach(Array(WizardConfig.curatedPicks.enumerated()), id: \.element.id) { index, jewelry in
                    jewelryCard(jewelry)
                        .opacity(jewelryCardsAppeared ? 1 : 0)
                        .offset(y: jewelryCardsAppeared ? 0 : 20)
                        .animation(
                            EcrinAnimation.springSnap.delay(Double(index) * 0.08),
                            value: jewelryCardsAppeared
                        )
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .onAppear {
                // Pre-select star on appear
                selectedJewelry = WizardConfig.starJewelry
                // Staggered entrance
                withAnimation {
                    jewelryCardsAppeared = true
                }
            }
            .onDisappear {
                jewelryCardsAppeared = false
            }

            // Star note
            HStack(spacing: EcrinSpacing.xs) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.QuickTryOnUI.preselectedFirstTryOn)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            .padding(.horizontal, EcrinSpacing.lg)

            Spacer()

            GoldButton(title: L10n.QuickTryOnUI.generateCta) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(EcrinAnimation.springSnap) { step = 2 }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.xl)
        }
    }

    @ViewBuilder
    private func jewelryCard(_ jewelry: JewelryItem) -> some View {
        let isSelected = selectedJewelry.id == jewelry.id
        let isStar = jewelry.id == WizardConfig.starJewelry.id

        Button {
            withAnimation(EcrinAnimation.springSnap) {
                selectedJewelry = jewelry
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: EcrinSpacing.sm) {
                    // Icon
                    Image(systemName: jewelry.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                        .frame(height: 40)

                    // Name
                    Text(jewelry.name)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    // Material
                    Text(jewelry.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(EcrinSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 130)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(EcrinColor.glassFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                    lineWidth: isSelected ? 1.5 : 0.5
                                )
                        }
                }

                // STAR badge
                if isStar {
                    Text(L10n.QuickTryOnUI.starBadge)
                        .font(EcrinFont.label)
                        .kerning(1)
                        .foregroundStyle(EcrinColor.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(EcrinColor.gold)
                        .clipShape(Capsule())
                        .padding(EcrinSpacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }

    // MARK: - Step 2: Loading

    private var loadingStep: some View {
        VStack(spacing: EcrinSpacing.xl) {
            Spacer()

            // Gold concentric rings animation
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let delay = Double(i) * 0.2
                    let baseSize: CGFloat = 80 + CGFloat(i) * 44
                    Circle()
                        .strokeBorder(
                            EcrinColor.gold.opacity(0.6 - Double(i) * 0.15),
                            lineWidth: 1.5 - CGFloat(i) * 0.4
                        )
                        .frame(width: baseSize, height: baseSize)
                        .scaleEffect(ringPulse ? 1.12 : 0.92)
                        .opacity(ringPulse ? 0.4 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(delay),
                            value: ringPulse
                        )
                }
            }
            .frame(width: 220, height: 220)
            .onAppear {
                ringPulse = true
            }

            VStack(spacing: EcrinSpacing.md) {
                // Main label
                Text(L10n.QuickTryOnUI.creationInProgress)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.gold)

                // Rotating subtext
                Text(loadingSubtexts[loadingSubtextIndex])
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(loadingSubtextIndex)
                    .animation(EcrinAnimation.easeSlide, value: loadingSubtextIndex)
            }

            if let generationError {
                Text(generationError)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EcrinSpacing.lg)
            }

            Spacer()

            // Quote block
            VStack(spacing: EcrinSpacing.sm) {
                Rectangle()
                    .fill(EcrinColor.gold.opacity(0.3))
                    .frame(width: 24, height: 1)

                Text(L10n.QuickTryOnUI.preciseJewelPlacement)
                    .font(EcrinFont.caption)
                    .italic()
                    .foregroundStyle(EcrinColor.textMuted)
                    .multilineTextAlignment(.center)

                Rectangle()
                    .fill(EcrinColor.gold.opacity(0.3))
                    .frame(width: 24, height: 1)
            }
            .padding(.horizontal, EcrinSpacing.xl)
            .padding(.bottom, EcrinSpacing.xl)
        }
        .onAppear {
            startLoadingSubtextRotation()
            generationError = nil
            Task {
                guard let photo = selectedPhoto else { return }
                let success = await onGenerate(photo, selectedJewelry)
                if !success {
                    generationError = "La génération a échoué. Réessayez avec une autre photo ou un autre bijou."
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(EcrinAnimation.springSnap) { step = 1 }
                }
            }
        }
        .onDisappear {
            loadingSubtextTask?.cancel()
            loadingSubtextTask = nil
        }
    }

    // MARK: - Helpers

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let rawImage = UIImage(data: data) else { return }

        // Downscale to max 2048px to prevent OOM on high-res photos
        let maxDimension: CGFloat = 2048
        let image: UIImage
        let size = rawImage.size
        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            image = renderer.image { _ in
                rawImage.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            image = rawImage
        }

        selectedPhoto = image
        photoQuality = nil
        isAnalyzing = true
        let quality = await PhotoQualityAnalyzer().analyze(image)
        withAnimation(EcrinAnimation.glassReveal) {
            photoQuality = quality
            isAnalyzing = false
        }
    }

    private func startLoadingSubtextRotation() {
        loadingSubtextTask?.cancel()
        loadingSubtextTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(EcrinAnimation.easeSlide) {
                        loadingSubtextIndex = (loadingSubtextIndex + 1) % loadingSubtexts.count
                    }
                }
            }
        }
    }
}
