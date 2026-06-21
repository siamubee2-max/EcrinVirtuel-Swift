import SwiftUI
import Photos

// MARK: - BrandedShareSheet
// Bottom sheet qui prévisualise l'image brandée avant de partager.

struct BrandedShareSheet: View {
    let image: UIImage
    let jewelryName: String

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var savedToPhotos = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Radial glow gold subtil en fond
            RadialGradient(
                colors: [EcrinColor.gold.opacity(0.08), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                // ── Drag indicator ─────────────────────────────────────
                Capsule()
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 36, height: 4)
                    .padding(.top, EcrinSpacing.sm)

                // ── Preview card (ratio 9:16, hauteur max 300pt) ────────
                previewCard

                // ── Share targets row ──────────────────────────────────
                shareTargetsRow

                // ── CTA principal ──────────────────────────────────────
                GoldButton(title: "PARTAGER MAINTENANT") {
                    showSystemShare = true
                }
                .padding(.horizontal, EcrinSpacing.xl)
                .padding(.bottom, EcrinSpacing.xl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .onAppear {
            withAnimation(EcrinAnimation.glassReveal) { appeared = true }
        }
        .sheet(isPresented: $showSystemShare) {
            ShareSheet(items: [makeBrandedImage()])
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var previewCard: some View {
        ZStack(alignment: .bottomTrailing) {
            // Image résultat
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Overlay gradient bas pour lisibilité du branding
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Watermark bas-droite
            VStack(alignment: .trailing, spacing: 2) {
                Text("L'ÉCRIN VIRTUEL")
                    .font(EcrinFont.serif(11))
                    .kerning(2)
                    .foregroundStyle(EcrinColor.gold)
                Text(jewelryName)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            .padding(.trailing, 12)
            .padding(.bottom, 12)

            // Bordure gold
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 1)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
        }
        .padding(.horizontal, EcrinSpacing.xl)
    }

    @ViewBuilder
    private var shareTargetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.md) {
                // Instagram Stories — gradient pink/orange
                ShareTargetButton(
                    icon: "camera.fill",
                    label: "Stories",
                    style: .instagram
                ) {
                    shareToInstagramStories()
                }

                // WhatsApp — vert
                ShareTargetButton(
                    icon: "message.fill",
                    label: "WhatsApp",
                    style: .whatsapp
                ) {
                    showSystemShare = true
                }

                // Télécharger — glass
                ShareTargetButton(
                    icon: savedToPhotos ? "checkmark" : "arrow.down.to.line",
                    label: savedToPhotos ? "Sauvegardé ✓" : "Sauver",
                    style: .glass
                ) {
                    downloadToPhotos()
                }

                // Plus — glass
                ShareTargetButton(
                    icon: "square.and.arrow.up",
                    label: "Plus",
                    style: .glass
                ) {
                    showSystemShare = true
                }
            }
            .padding(.horizontal, EcrinSpacing.xl)
        }
    }

    // MARK: - Actions

    private func shareToInstagramStories() {
        let branded = makeBrandedImage()
        if let url = URL(string: "instagram-stories://share"),
           UIApplication.shared.canOpenURL(url) {
            guard let data = branded.pngData() else {
                showSystemShare = true
                return
            }
            let pasteboard = UIPasteboard.general
            pasteboard.setData(data, forPasteboardType: "com.instagram.sharedSticker.backgroundImage")
            UIApplication.shared.open(url)
        } else {
            showSystemShare = true
        }
    }

    private func downloadToPhotos() {
        guard !savedToPhotos else { return }
        let branded = makeBrandedImage()
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: branded)
            } completionHandler: { success, _ in
                guard success else { return }
                DispatchQueue.main.async {
                    withAnimation(EcrinAnimation.springSnap) {
                        savedToPhotos = true
                    }
                }
            }
        }
    }

    // MARK: - Branded image rendering

    static func renderBranded(image: UIImage, jewelryName: String) -> UIImage {
        BrandedShareSheet(image: image, jewelryName: jewelryName).makeBrandedImage()
    }

    func makeBrandedImage() -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            // 1. Image originale
            image.draw(in: CGRect(origin: .zero, size: size))

            // 2. Gradient bas (noir transparent → 70%)
            let gradientHeight = size.height * 0.45
            let gradientRect = CGRect(
                x: 0,
                y: size.height - gradientHeight,
                width: size.width,
                height: gradientHeight
            )
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.7).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: gradientRect.minY),
                end: CGPoint(x: 0, y: gradientRect.maxY),
                options: []
            )

            // 3. Watermark "L'ÉCRIN VIRTUEL" — bas-droite
            let goldColor = UIColor(red: 202/255, green: 138/255, blue: 4/255, alpha: 1)
            let brandFontSize = max(size.width * 0.030, 12)
            let brandFont = UIFont(name: "Cormorant", size: brandFontSize)
                ?? UIFont.systemFont(ofSize: brandFontSize, weight: .light)

            let brandParagraph = NSMutableParagraphStyle()
            brandParagraph.alignment = .right

            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: goldColor,
                .kern: 2.0,
                .paragraphStyle: brandParagraph
            ]
            let brandString = "L'ÉCRIN VIRTUEL" as NSString
            let brandSize = brandString.size(withAttributes: brandAttrs)
            let margin = size.width * 0.04
            let brandOrigin = CGPoint(
                x: size.width - brandSize.width - margin,
                y: size.height - brandSize.height - margin
            )
            brandString.draw(at: brandOrigin, withAttributes: brandAttrs)

            // 4. Nom du bijou — au-dessus du watermark
            let subFontSize = max(size.width * 0.020, 9)
            let subFont = UIFont(name: "Cormorant", size: subFontSize)
                ?? UIFont.systemFont(ofSize: subFontSize, weight: .light)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            let subString = jewelryName as NSString
            let subSize = subString.size(withAttributes: subAttrs)
            let subOrigin = CGPoint(
                x: size.width - subSize.width - margin,
                y: brandOrigin.y - subSize.height - 4
            )
            subString.draw(at: subOrigin, withAttributes: subAttrs)
        }
    }
}

// MARK: - ShareTargetButton

private enum ShareTargetStyle {
    case instagram
    case whatsapp
    case glass
}

private struct ShareTargetButton: View {
    let icon: String
    let label: String
    let style: ShareTargetStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: EcrinSpacing.xs) {
                ZStack {
                    iconBackground
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)

                Text(label)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 68)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconBackground: some View {
        switch style {
        case .instagram:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E1306C"),
                            Color(hex: "#F56040"),
                            Color(hex: "#FFDC80")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

        case .whatsapp:
            Circle()
                .fill(Color(hex: "#25D366"))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

        case .glass:
            Circle()
                .fill(EcrinColor.glassFill)
                .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
        }
    }
}
