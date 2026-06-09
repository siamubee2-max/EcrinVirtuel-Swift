import SwiftUI
import Photos

// MARK: - Full Export View
// Combine fond + image essayage + cadre → export haute résolution

struct FullExportView: View {
    let tryOnImage: UIImage
    let jewelryName: String

    @StateObject private var vm: FullExportViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showBackgroundPicker = false
    @State private var showFramePicker = false

    init(tryOnImage: UIImage, jewelryName: String = "L'ÉCRIN VIRTUEL") {
        self.tryOnImage = tryOnImage
        self.jewelryName = jewelryName
        _vm = StateObject(wrappedValue: FullExportViewModel(tryOnImage: tryOnImage))
    }

    var body: some View {
        ZStack {
            Color(hex: "#080808").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                // Main preview
                fullPreview

                // Section title
                HStack {
                    Text("CRÉER MON SNAPSHOT")
                        .font(.custom("Cormorant", size: 20))
                        .fontWeight(.light)
                        .kerning(4)
                        .foregroundStyle(EcrinColor.ivory)
                    Spacer()
                    if vm.isRendering {
                        ProgressView()
                            .tint(EcrinColor.gold)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.vertical, EcrinSpacing.md)

                // Controls panel
                controlsPanel

                // Format + Export row
                exportRow
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerView(viewModel: vm.backgroundVM, tryOnImage: tryOnImage)
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFramePicker) {
            FramePickerView(viewModel: vm.frameVM, tryOnImage: tryOnImage)
                .presentationDetents([.fraction(0.9), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showShareSheet) {
            if let img = vm.composedImage {
                SystemShareSheet(items: [img])
            }
        }
        .alert("Enregistré", isPresented: $vm.savedSuccess) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text("Votre snapshot a été enregistré dans la Photothèque.")
        }
        .alert("Erreur", isPresented: $vm.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "Une erreur est survenue.")
        }
        .onChange(of: vm.backgroundVM.selectedBackground) { _, _ in
            vm.scheduleCompose()
        }
        .onChange(of: vm.frameVM.selectedFrame) { _, _ in
            vm.scheduleCompose()
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(EcrinColor.glassFill)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("SNAPSHOT")
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(jewelryName)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.md)
        .padding(.bottom, EcrinSpacing.sm)
    }

    // MARK: Full Preview

    private var fullPreview: some View {
        GeometryReader { geo in
            let format: SocialFormat = vm.selectedFormat
            let ratio = format.aspectRatio
            let maxW = geo.size.width - EcrinSpacing.lg * 2
            let maxH = geo.size.height
            let previewW = min(maxW, maxH * ratio)
            let previewH = previewW / ratio

            ZStack {
                // Background layer
                if let bg = vm.backgroundVM.selectedBackground {
                    BackgroundSwatchView(item: bg, cornerRadius: 16)
                        .frame(width: previewW, height: previewH)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .frame(width: previewW, height: previewH)
                }

                // Try-on image
                Image(uiImage: tryOnImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewW, height: previewH)
                    .clipped()

                // Frame overlay
                if let frame = vm.frameVM.selectedFrame {
                    FrameSwiftUIView(frame: frame, size: CGSize(width: previewW, height: previewH))
                }

                // Rendering overlay
                if vm.isRendering {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                    ProgressView()
                        .tint(EcrinColor.gold)
                        .scaleEffect(1.3)
                }
            }
            .frame(width: previewW, height: previewH)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )
            .shadow(color: EcrinColor.gold.opacity(0.12), radius: 20, x: 0, y: 10)
            .frame(maxWidth: .infinity)
            .animation(EcrinAnimation.springSnap, value: vm.selectedFormat)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .frame(height: 340)
    }

    // MARK: Controls Panel

    private var controlsPanel: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Background button
            controlButton(
                icon: "photo.fill.on.rectangle.fill",
                label: "Fond",
                subtitle: vm.backgroundVM.selectedBackground?.name ?? "Aucun",
                hasItem: vm.backgroundVM.selectedBackground != nil,
                action: { showBackgroundPicker = true }
            )

            // Frame button
            controlButton(
                icon: "rectangle.portrait.fill",
                label: "Cadre",
                subtitle: vm.frameVM.selectedFrame?.name ?? "Aucun",
                hasItem: vm.frameVM.selectedFrame != nil,
                action: { showFramePicker = true }
            )
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.md)
    }

    private func controlButton(
        icon: String,
        label: String,
        subtitle: String,
        hasItem: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: EcrinSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(hasItem ? EcrinColor.gold : EcrinColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(hasItem ? EcrinColor.gold.opacity(0.12) : EcrinColor.glassFill)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(EcrinFont.cta)
                        .kerning(1)
                        .foregroundStyle(hasItem ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                    Text(subtitle)
                        .font(EcrinFont.caption)
                        .foregroundStyle(hasItem ? EcrinColor.gold : EcrinColor.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(EcrinColor.textMuted)
            }
            .padding(EcrinSpacing.md)
            .background(EcrinColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        hasItem ? EcrinColor.gold.opacity(0.3) : EcrinColor.glassStroke,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: Export Row

    private var exportRow: some View {
        VStack(spacing: EcrinSpacing.md) {
            // Format selector
            HStack(spacing: EcrinSpacing.sm) {
                Text("FORMAT")
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)

                Spacer()

                ForEach(SocialFormat.allCases, id: \.self) { fmt in
                    Button {
                        withAnimation(EcrinAnimation.springSnap) {
                            vm.selectedFormat = fmt
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: fmt.exportIcon)
                                .font(.system(size: 14, weight: .thin))
                            Text(fmt.exportLabel)
                                .font(.system(size: 9, weight: .medium))
                                .kerning(0.5)
                        }
                        .foregroundStyle(vm.selectedFormat == fmt ? EcrinColor.background : EcrinColor.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(vm.selectedFormat == fmt ? EcrinColor.gold : EcrinColor.glassFill)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)

            // Action buttons
            HStack(spacing: EcrinSpacing.md) {
                // Save to Photos
                GhostButton(title: L10n.Common.save) {
                    Task { await vm.saveToPhotos() }
                }

                // Share
                GoldButton(title: L10n.Common.share) {
                    Task { await vm.share() }
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.bottom, EcrinSpacing.lg + (UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets.bottom ?? 0))
        }
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(EcrinColor.surface.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                )
                .ignoresSafeArea(edges: .bottom)
        }
        .padding(.top, EcrinSpacing.sm)
    }
}

// MARK: - Export Format (alias over SocialFormat for display)
// Uses SocialFormat from LookSnapshot.swift — only adds display helpers here.

private extension SocialFormat {
    var exportIcon: String {
        switch self {
        case .stories:  return "iphone"
        case .post:     return "square"
        case .portrait: return "rectangle.portrait"
        }
    }

    var exportLabel: String {
        switch self {
        case .stories:  return "9:16"
        case .post:     return "1:1"
        case .portrait: return "4:5"
        }
    }
}

// MARK: - Full Export View Model

@MainActor
final class FullExportViewModel: ObservableObject {

    @Published var selectedFormat: SocialFormat = .portrait
    @Published var composedImage: UIImage?
    @Published var isRendering = false
    @Published var showShareSheet = false
    @Published var savedSuccess = false
    @Published var showError = false
    @Published var errorMessage: String?

    let backgroundVM = BackgroundViewModel()
    let frameVM = FrameViewModel()

    private let tryOnImage: UIImage
    private let renderer = FrameRenderer()
    private var composeTask: Task<Void, Never>?

    // SocialFormat convenience
    var outputSize: CGSize { selectedFormat.renderSize }

    init(tryOnImage: UIImage) {
        self.tryOnImage = tryOnImage
    }

    func scheduleCompose() {
        composeTask?.cancel()
        composeTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await doCompose()
        }
    }

    private func doCompose() async {
        isRendering = true
        composedImage = await renderer.compose(
            image: tryOnImage,
            background: backgroundVM.selectedBackground,
            frame: frameVM.selectedFrame,
            customText: nil
        )
        isRendering = false
    }

    func share() async {
        if composedImage == nil { await doCompose() }
        guard composedImage != nil else { return }
        showShareSheet = true
    }

    func saveToPhotos() async {
        if composedImage == nil { await doCompose() }
        guard let image = composedImage else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            errorMessage = "Veuillez autoriser l'accès à la Photothèque dans les Réglages."
            showError = true
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            savedSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - System Share Sheet (reusable)

private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
