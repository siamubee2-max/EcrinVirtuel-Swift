import SwiftUI
import AVFoundation

// MARK: - AR Permission View

struct ARPermissionView: View {
    let onGranted: () -> Void

    @State private var isRequesting: Bool = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [EcrinColor.goldLight, EcrinColor.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                // Title
                VStack(spacing: EcrinSpacing.sm) {
                    Text("Accès à la caméra")
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)

                    Text("L'Écrin Virtuel a besoin d'accéder à votre caméra pour l'essayage AR de bijoux en temps réel.")
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.xl)
                }

                // Feature list
                VStack(spacing: EcrinSpacing.md) {
                    PermissionFeatureRow(
                        icon: "sparkles",
                        title: "Essayage en temps réel",
                        description: "Visualisez les bijoux sur vous instantanément"
                    )
                    PermissionFeatureRow(
                        icon: "camera.viewfinder",
                        title: "Détection du visage & corps",
                        description: "Positionnement précis des bijoux"
                    )
                    PermissionFeatureRow(
                        icon: "photo.fill",
                        title: "Capture de looks",
                        description: "Sauvegardez vos essayages préférés"
                    )
                }
                .padding(.horizontal, EcrinSpacing.lg)

                Spacer()

                // CTA
                VStack(spacing: EcrinSpacing.md) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(EcrinColor.gold)
                    } else {
                        GoldButton(title: "Autoriser la caméra") {
                            requestCameraAccess()
                        }
                    }

                    Button(action: {
                        openSettings()
                    }) {
                        Text("Ouvrir les réglages")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, EcrinSpacing.xxl)
            }
        }
    }

    // MARK: - Actions

    private func requestCameraAccess() {
        isRequesting = true
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                isRequesting = false
                if granted { onGranted() }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Permission Feature Row

private struct PermissionFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(EcrinColor.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(EcrinColor.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EcrinFont.sans(14, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(description)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Camera Authorization State

enum CameraAuthState {
    case unknown
    case granted
    case denied
    case restricted

    static var current: CameraAuthState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:           return .granted
        case .denied:               return .denied
        case .restricted:           return .restricted
        case .notDetermined:        return .unknown
        @unknown default:           return .unknown
        }
    }
}
