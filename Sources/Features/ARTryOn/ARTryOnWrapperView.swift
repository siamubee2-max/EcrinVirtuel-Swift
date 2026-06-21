import SwiftUI
import ARKit
import AVFoundation

// MARK: - AR Try-On Wrapper View

struct ARTryOnWrapperView: View {
    let jewelry: JewelryItem
    let onDismiss: () -> Void
    let onCapture: (UIImage) -> Void

    @State private var selectedJewelry: JewelryItem
    @State private var isCapturing: Bool = false
    @State private var showJewelryPicker: Bool = false
    @State private var showInstructions: Bool = true
    @State private var authState: CameraAuthState = .unknown
    @State private var capturedImage: UIImage? = nil
    @State private var showCapturePreview: Bool = false
    @State private var isARAvailable: Bool = ARFaceTrackingConfiguration.isSupported || ARBodyTrackingConfiguration.isSupported
    /// Fix C: real jewelry catalog fetched from Supabase on appear.
    /// Falls back to JewelryItem.samples when the fetch returns empty or fails,
    /// so AR remains usable offline and in UI tests.
    @State private var jewelryCatalog: [JewelryItem] = JewelryItem.samples

    init(jewelry: JewelryItem, onDismiss: @escaping () -> Void, onCapture: @escaping (UIImage) -> Void) {
        self.jewelry = jewelry
        self.onDismiss = onDismiss
        self.onCapture = onCapture
        self._selectedJewelry = State(initialValue: jewelry)
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            switch authState {
            case .unknown:
                checkingPermissionView
            case .denied, .restricted:
                ARPermissionView(onGranted: { authState = .granted })
            case .granted:
                if isARAvailable {
                    arContentView
                } else {
                    arUnavailableView
                }
            }
        }
        .onAppear {
            authState = CameraAuthState.current
            if authState == .unknown {
                requestCameraPermission()
            }
            // Hide instructions after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(EcrinAnimation.easeSlide) {
                    showInstructions = false
                }
            }
            // Fix C: load real jewelry catalog from Supabase.
            // Under UI tests keep static samples for determinism.
            guard !AppLaunchEnvironment.isUITesting else { return }
            Task {
                do {
                    let fetched = try await SupabaseService.shared.fetchJewelryCatalog()
                    let mapped = fetched.map { $0.asJewelryItem }
                    if !mapped.isEmpty {
                        jewelryCatalog = mapped
                    }
                    // If fetch returns empty, jewelryCatalog keeps its JewelryItem.samples default.
                } catch {
                    // Network/Supabase error — AR still works with samples fallback.
                }
            }
        }
    }

    // MARK: - AR Content View

    private var arContentView: some View {
        ZStack {
            // AR camera feed
            ARTryOnView(
                jewelry: selectedJewelry,
                isCapturing: $isCapturing,
                onCapture: { image in
                    capturedImage = image
                    withAnimation(EcrinAnimation.springSnap) {
                        showCapturePreview = true
                    }
                    onCapture(image)
                }
            )
            .ignoresSafeArea()

            // UI Overlay
            arOverlay

            // Capture preview flash
            if isCapturing {
                Color.white
                    .ignoresSafeArea()
                    .opacity(0.6)
                    .transition(.opacity)
            }

            // Capture preview overlay
            if showCapturePreview, let image = capturedImage {
                capturePreviewOverlay(image: image)
            }

            // Jewelry picker sheet
            if showJewelryPicker {
                jewelryPickerOverlay
            }
        }
    }

    // MARK: - AR Overlay UI

    private var arOverlay: some View {
        VStack {
            // Top bar
            topBar

            Spacer()

            // Face detection instructions
            if showInstructions {
                instructionBadge
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            // Bottom controls
            bottomControls
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.top, EcrinSpacing.md)
    }

    // MARK: - Instructions Badge

    private var instructionBadge: some View {
        HStack(spacing: EcrinSpacing.sm) {
            Image(systemName: "face.smiling")
                .font(.system(size: 16))
                .foregroundStyle(EcrinColor.gold)
            Text(selectedJewelry.category == .earring || selectedJewelry.category == .necklace
                 ? "Regardez la caméra"
                 : "Montrez vos mains à la caméra")
                .font(EcrinFont.sans(13, weight: .medium))
                .foregroundStyle(EcrinColor.textPrimary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(alignment: .center, spacing: 0) {
            // Selected jewelry button (bottom left)
            Button(action: { withAnimation(EcrinAnimation.springSnap) { showJewelryPicker.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: selectedJewelry.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(EcrinColor.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedJewelry.name)
                            .font(EcrinFont.sans(12, weight: .semibold))
                            .foregroundStyle(EcrinColor.textPrimary)
                        Text(selectedJewelry.category.rawValue)
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(EcrinColor.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Capture button (center)
            captureButton

            Spacer()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.bottom, EcrinSpacing.xl)
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button(action: {
            withAnimation(EcrinAnimation.springSnap) { isCapturing = true }
        }) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(EcrinColor.gold, lineWidth: 3)
                    .frame(width: 84, height: 84)
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(EcrinColor.background)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isCapturing ? 0.93 : 1.0)
        .animation(EcrinAnimation.springSnap, value: isCapturing)
    }

    // MARK: - Jewelry Picker Overlay

    private var jewelryPickerOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: EcrinSpacing.md) {
                // Handle
                Capsule()
                    .fill(EcrinColor.textMuted)
                    .frame(width: 36, height: 4)

                Text("Changer de bijou")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EcrinSpacing.md) {
                        // Fix C: use real Supabase catalog; falls back to samples if fetch failed.
                        ForEach(jewelryCatalog) { item in
                            JewelryPickerItem(
                                item: item,
                                isSelected: item.id == selectedJewelry.id
                            ) {
                                selectedJewelry = item
                                withAnimation(EcrinAnimation.springSnap) { showJewelryPicker = false }
                            }
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                }
            }
            .padding(.top, EcrinSpacing.md)
            .padding(.bottom, EcrinSpacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onTapGesture {
            withAnimation(EcrinAnimation.springSnap) { showJewelryPicker = false }
        }
    }

    // MARK: - Capture Preview Overlay

    private func capturePreviewOverlay(image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                Text("Look capturé")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, EcrinSpacing.xl)

                HStack(spacing: EcrinSpacing.lg) {
                    GhostButton(title: "Reprendre") {
                        withAnimation(EcrinAnimation.springSnap) { showCapturePreview = false }
                    }
                    GoldButton(title: L10n.Common.save) {
                        withAnimation(EcrinAnimation.springSnap) { showCapturePreview = false }
                        onDismiss()
                    }
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - AR Unavailable Fallback

    private var arUnavailableView: some View {
        VStack(spacing: EcrinSpacing.xl) {
            Spacer()

            Image(systemName: "arkit")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)

            VStack(spacing: EcrinSpacing.sm) {
                Text("AR non disponible")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text("L'essayage AR nécessite un iPhone compatible. Utilise l'essayage photo classique pour continuer.")
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EcrinSpacing.xl)
            }

            GoldButton(title: "Essayage Photo") { onDismiss() }

            GhostButton(title: L10n.Common.close) { onDismiss() }

            Spacer()
        }
    }

    // MARK: - Checking Permission View

    private var checkingPermissionView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(EcrinColor.gold)
            Spacer()
        }
    }

    // MARK: - Permission Request

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                authState = CameraAuthState.current
            }
        }
    }
}

// MARK: - Jewelry Picker Item

private struct JewelryPickerItem: View {
    let item: JewelryItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? EcrinColor.gold.opacity(0.2) : EcrinColor.glassFill)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        }
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                }

                Text(item.name)
                    .font(EcrinFont.label)
                    .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
