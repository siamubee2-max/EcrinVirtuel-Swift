import SwiftUI
import UIKit
import Photos

// MARK: - Snapshot Renderer
/// Renders a LookSnapshot to a UIImage at the target social format resolution.
@MainActor
final class SnapshotRenderer {

    // MARK: - Render
    /// Returns the composed UIImage for the given snapshot configuration.
    func render(_ snapshot: LookSnapshot) async -> UIImage? {
        let targetSize = snapshot.format.renderSize
        let scale: CGFloat = 1 // Use 1x since we specify pixel dimensions directly

        let composedView = SnapshotCompositeView(snapshot: snapshot)
            .frame(width: targetSize.width, height: targetSize.height)

        let renderer = ImageRenderer(content: composedView)
        renderer.proposedSize = ProposedViewSize(
            width: targetSize.width,
            height: targetSize.height
        )
        renderer.scale = scale

        return renderer.uiImage
    }

    // MARK: - Save to Photos
    func saveToPhotos(_ snapshot: LookSnapshot) async throws {
        guard let image = await render(snapshot) else {
            throw RenderError.renderFailed
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    // MARK: - Error
    enum RenderError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed: return "Impossible de générer l'image."
            }
        }
    }
}

// MARK: - Composite View (used by ImageRenderer)
struct SnapshotCompositeView: View {
    let snapshot: LookSnapshot

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background: try-on image fills frame
            Image(uiImage: snapshot.tryOnImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: snapshot.format.renderSize.width,
                    height: snapshot.format.renderSize.height
                )
                .clipped()

            // Bottom gradient vignette
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
            .frame(
                width: snapshot.format.renderSize.width,
                height: snapshot.format.renderSize.height
            )

            // Watermark layer
            if snapshot.watermark != .none {
                WatermarkOverlay(snapshot: snapshot)
                    .padding(40)
            }

            // Partner badge (top-left)
            if let brand = snapshot.brandName {
                PartnerBadge(brandName: brand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(40)
            }
        }
        .frame(
            width: snapshot.format.renderSize.width,
            height: snapshot.format.renderSize.height
        )
    }
}

// MARK: - Watermark Overlay
struct WatermarkOverlay: View {
    let snapshot: LookSnapshot

    /// Scale factor relative to 1080px wide canvas
    private let scale: CGFloat = 1080 / 375

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if snapshot.watermark == .branded {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 10 * scale))
                    .foregroundStyle(Color(hex: "#CA8A04").opacity(0.7))
            }

            Text(L10n.OnboardingUI.brandName)
                .font(.custom("Cormorant", size: 13 * scale))
                .fontWeight(.light)
                .kerning(3 * scale)
                .foregroundStyle(Color(hex: "#CA8A04").opacity(
                    snapshot.watermark == .branded ? 0.9 : 0.6
                ))

            if snapshot.watermark == .branded {
                Text(snapshot.jewelryItem.name.uppercased())
                    .font(.system(size: 9 * scale, weight: .medium))
                    .kerning(2 * scale)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .multilineTextAlignment(.trailing)
    }
}

// MARK: - Partner Badge
struct PartnerBadge: View {
    let brandName: String
    private let scale: CGFloat = 1080 / 375

    var body: some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 10 * scale))
                .foregroundStyle(Color(hex: "#CA8A04"))

            Text("Disponible chez \(brandName)")
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 7 * scale)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color(hex: "#CA8A04").opacity(0.4), lineWidth: 1)
        }
    }
}
