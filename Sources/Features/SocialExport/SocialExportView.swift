import SwiftUI
import Photos

// MARK: - Social Export View
struct SocialExportView: View {
    let snapshot: LookSnapshot
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SocialExportViewModel

    init(snapshot: LookSnapshot) {
        self.snapshot = snapshot
        _viewModel = StateObject(wrappedValue: SocialExportViewModel(snapshot: snapshot))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                ExportTopBar(onDismiss: { dismiss() })

                // Live preview
                ExportPreview(viewModel: viewModel)

                // Controls panel
                ExportControlsPanel(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let image = viewModel.renderedImage {
                SystemShareSheet(items: [image])
            }
        }
        .alert("Enregistré", isPresented: $viewModel.savedSuccess) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(L10n.SocialExportUI.lookSavedToPhotos)
        }
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue.")
        }
    }
}

// MARK: - View Model
@MainActor
final class SocialExportViewModel: ObservableObject {
    @Published var snapshot: LookSnapshot
    @Published var renderedImage: UIImage?
    @Published var isRendering = false
    @Published var showShareSheet = false
    @Published var savedSuccess = false
    @Published var showError = false
    @Published var errorMessage: String?

    private let renderer = SnapshotRenderer()

    init(snapshot: LookSnapshot) {
        self.snapshot = snapshot
    }

    var currentFormat: SocialFormat {
        get { snapshot.format }
        set {
            snapshot = LookSnapshot(
                id: snapshot.id,
                tryOnImage: snapshot.tryOnImage,
                jewelryItem: snapshot.jewelryItem,
                brandName: snapshot.brandName,
                watermark: snapshot.watermark,
                format: newValue
            )
            scheduleRender()
        }
    }

    var currentWatermark: WatermarkStyle {
        get { snapshot.watermark }
        set {
            snapshot = LookSnapshot(
                id: snapshot.id,
                tryOnImage: snapshot.tryOnImage,
                jewelryItem: snapshot.jewelryItem,
                brandName: snapshot.brandName,
                watermark: newValue,
                format: snapshot.format
            )
            scheduleRender()
        }
    }

    private var renderTask: Task<Void, Never>?

    func scheduleRender() {
        renderTask?.cancel()
        renderTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await doRender()
        }
    }

    private func doRender() async {
        isRendering = true
        renderedImage = await renderer.render(snapshot)
        isRendering = false
    }

    func share() async {
        if renderedImage == nil { await doRender() }
        guard renderedImage != nil else { return }
        showShareSheet = true
    }

    func saveToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            errorMessage = L10n.SocialExportUI.allowPhotoLibraryAccess
            showError = true
            return
        }
        do {
            try await renderer.saveToPhotos(snapshot)
            savedSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Top Bar
private struct ExportTopBar: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(L10n.SocialExportUI.exportButton)
                    .font(EcrinFont.label)
                    .kerning(3)
                    .foregroundStyle(EcrinColor.gold)
                Text(L10n.SocialExportUI.yourLookTitle)
                    .font(EcrinFont.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.md)
        .padding(.bottom, EcrinSpacing.sm)
    }
}

// MARK: - Live Preview
private struct ExportPreview: View {
    @ObservedObject var viewModel: SocialExportViewModel

    var body: some View {
        GeometryReader { proxy in
            let maxH = proxy.size.height
            let ratio = viewModel.snapshot.format.aspectRatio
            let previewW = min(proxy.size.width - EcrinSpacing.lg * 2, maxH * ratio)
            let previewH = previewW / ratio

            ZStack {
                // Rendered preview or live overlay
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: viewModel.snapshot.tryOnImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: previewW, height: previewH)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Gradient vignette
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.5)],
                        startPoint: UnitPoint(x: 0.5, y: 0.5),
                        endPoint: .bottom
                    )
                    .frame(width: previewW, height: previewH)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Watermark preview (screen-scale version)
                    if viewModel.snapshot.watermark != .none {
                        PreviewWatermark(snapshot: viewModel.snapshot)
                            .padding(12)
                    }

                    // Partner badge preview
                    if let brand = viewModel.snapshot.brandName {
                        PreviewPartnerBadge(brandName: brand)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .frame(width: previewW, height: previewH)
                            .padding(10)
                    }
                }
                .frame(width: previewW, height: previewH)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 1)
                }
                .shadow(color: EcrinColor.gold.opacity(0.1), radius: 20, x: 0, y: 10)

                // Rendering spinner
                if viewModel.isRendering {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: previewW, height: previewH)
                    ProgressView()
                        .tint(EcrinColor.gold)
                        .scaleEffect(1.2)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(EcrinAnimation.springSnap, value: viewModel.snapshot.format)
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }
}

// MARK: - Screen-scale Watermark (preview only)
private struct PreviewWatermark: View {
    let snapshot: LookSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if snapshot.watermark == .branded {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(EcrinColor.gold.opacity(0.7))
            }
            Text(L10n.OnboardingUI.brandName)
                .font(.custom("Cormorant", size: 10))
                .fontWeight(.light)
                .kerning(2)
                .foregroundStyle(EcrinColor.gold.opacity(
                    snapshot.watermark == .branded ? 0.9 : 0.6
                ))
            if snapshot.watermark == .branded {
                Text(snapshot.jewelryItem.name.uppercased())
                    .font(.system(size: 7, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

private struct PreviewPartnerBadge: View {
    let brandName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 8))
                .foregroundStyle(EcrinColor.gold)
            Text("Disponible chez \(brandName)")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(EcrinColor.gold.opacity(0.35), lineWidth: 0.5)
        }
    }
}

// MARK: - Controls Panel
private struct ExportControlsPanel: View {
    @ObservedObject var viewModel: SocialExportViewModel

    var body: some View {
        VStack(spacing: EcrinSpacing.lg) {
            // Format selector
            FormatSelector(
                current: viewModel.currentFormat,
                onSelect: { viewModel.currentFormat = $0 }
            )

            // Watermark selector
            WatermarkSelector(
                current: viewModel.currentWatermark,
                onSelect: { viewModel.currentWatermark = $0 }
            )

            // Action buttons
            HStack(spacing: EcrinSpacing.md) {
                // Save button
                Button {
                    Task { await viewModel.saveToPhotos() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 13))
                        Text(L10n.Common.save)
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .foregroundStyle(EcrinColor.gold)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.md)
                    .overlay {
                        Capsule()
                            .strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                // Share button
                GoldButton(title: L10n.Common.share) {
                    Task { await viewModel.share() }
                }
            }
        }
        .padding(EcrinSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(EcrinColor.surface.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Format Selector
private struct FormatSelector: View {
    let current: SocialFormat
    let onSelect: (SocialFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text(L10n.SocialExportUI.formatLabel)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            HStack(spacing: EcrinSpacing.sm) {
                ForEach(SocialFormat.allCases, id: \.self) { fmt in
                    FormatChip(format: fmt, isSelected: fmt == current)
                        .onTapGesture { onSelect(fmt) }
                }
            }
        }
    }
}

private struct FormatChip: View {
    let format: SocialFormat
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: format.iconName)
                .font(.system(size: 18, weight: .thin))
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)

            Text(format.displayLabel)
                .font(EcrinFont.caption)
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)

            Text(format.dimensionLabel)
                .font(.system(size: 9, weight: .light))
                .foregroundStyle(isSelected ? EcrinColor.background.opacity(0.7) : EcrinColor.textMuted)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Watermark Selector
private struct WatermarkSelector: View {
    let current: WatermarkStyle
    let onSelect: (WatermarkStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text(L10n.SocialExportUI.watermarkLabel)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            HStack(spacing: EcrinSpacing.sm) {
                ForEach(WatermarkStyle.allCases, id: \.self) { style in
                    WatermarkChip(style: style, isSelected: style == current)
                        .onTapGesture { onSelect(style) }
                }
            }
        }
    }
}

private struct WatermarkChip: View {
    let style: WatermarkStyle
    let isSelected: Bool

    var icon: String {
        switch style {
        case .minimal:  return "textformat.size.smaller"
        case .branded:  return "seal.fill"
        case .none:     return "minus.circle"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            Text(style.displayLabel)
                .font(EcrinFont.caption)
                .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(
            Capsule()
                .fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - System Share Sheet
private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
