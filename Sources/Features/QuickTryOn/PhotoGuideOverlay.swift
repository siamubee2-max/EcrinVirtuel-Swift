import SwiftUI

// MARK: - PhotoGuideOverlay
// Overlay semi-transparent avant la prise de photo.
// Affiche la silhouette avec les zones surlignées en or selon le mode.

struct PhotoGuideOverlay: View {
    let mode: QuickTryOnMode
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {

                // Header
                VStack(spacing: EcrinSpacing.sm) {
                    Text(L10n.QuickTryOnUI.photoGuide)
                        .font(EcrinFont.label)
                        .kerning(3)
                        .foregroundStyle(EcrinColor.gold)
                    Text(mode.rawValue)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)

                // Silhouette + zones surlignées
                GuideBodyIllustration(highlightedSegments: mode.highlightedBodySegments)
                    .frame(height: 280)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)

                // Tips contextuels
                VStack(spacing: EcrinSpacing.sm) {
                    tipRow(icon: "arrow.up.left.and.arrow.down.right", text: positioningTip)
                    tipRow(icon: "sun.max.fill",        text: "Éclairage naturel ou lumière douce face à vous")
                    tipRow(icon: "rectangle.fill",      text: "Fond uni, clair ou neutre de préférence")
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

                Spacer()

                // CTA
                GoldButton(title: L10n.QuickTryOnUI.understood) {
                    onDismiss()
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, EcrinSpacing.lg)
            }
            .padding(.horizontal, EcrinSpacing.lg)
            .padding(.top, EcrinSpacing.xl)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    // MARK: - Tip row

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: EcrinSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(EcrinColor.gold)
                .frame(width: 20)

            Text(text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(EcrinColor.glassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // Conseil de positionnement spécifique au mode
    private var positioningTip: String {
        switch mode {
        case .shoesOnly:
            return "Assise ou debout — vos pieds doivent être entiers dans le cadre"
        case .shoesAndBottom:
            return "Debout, genoux à pieds visibles, dos droit"
        case .topOnly:
            return "Debout ou assis, cadre de la tête à la taille"
        case .jewelsOnly:
            return "Rapprochez-vous : la zone du bijou doit être nette"
        case .fullOutfit:
            return "Debout, dos droit, tête aux pieds dans le cadre"
        default:
            return "Debout, dos droit, corps entier centré dans le cadre"
        }
    }
}

// MARK: - GuideBodyIllustration
// Silhouette humaine simplifiée avec segments surlignés en or.

struct GuideBodyIllustration: View {
    let highlightedSegments: [BodySegment]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2

            ZStack {
                // Base silhouette (même tracé que HumanSilhouette dans OutfitBuilderView)
                HumanSilhouette()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        HumanSilhouette()
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
                    .frame(width: w * 0.55, height: h)
                    .position(x: cx, y: h / 2)

                // Overlays des segments surlignés
                ForEach(highlightedSegments, id: \.self) { segment in
                    segmentHighlight(segment: segment, cx: cx, w: w, h: h)
                }
            }
        }
    }

    @ViewBuilder
    private func segmentHighlight(
        segment: BodySegment,
        cx: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) -> some View {
        let bodyW  = w * 0.55
        let left   = cx - bodyW / 2
        let params = segmentParams(segment: segment, h: h)

        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(EcrinColor.gold.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(EcrinColor.gold.opacity(0.7), lineWidth: 1.2)
            )
            .frame(width: bodyW * params.widthFraction, height: h * params.heightFraction)
            .position(
                x: left + bodyW * params.cx,
                y: h * params.cy
            )
    }

    // Retourne les proportions normalisées pour chaque segment
    private struct SegmentParams {
        let widthFraction: CGFloat
        let heightFraction: CGFloat
        let cx: CGFloat  // centre X relatif à bodyW (0..1)
        let cy: CGFloat  // centre Y relatif à h (0..1)
    }

    private func segmentParams(segment: BodySegment, h: CGFloat) -> SegmentParams {
        switch segment {
        case .head:
            return SegmentParams(widthFraction: 0.42, heightFraction: 0.14, cx: 0.50, cy: 0.07)
        case .neck:
            return SegmentParams(widthFraction: 0.22, heightFraction: 0.06, cx: 0.50, cy: 0.17)
        case .shoulders:
            return SegmentParams(widthFraction: 0.90, heightFraction: 0.06, cx: 0.50, cy: 0.22)
        case .torso:
            return SegmentParams(widthFraction: 0.72, heightFraction: 0.28, cx: 0.50, cy: 0.36)
        case .waistToKnees:
            return SegmentParams(widthFraction: 0.65, heightFraction: 0.24, cx: 0.50, cy: 0.60)
        case .lowerLegs:
            return SegmentParams(widthFraction: 0.50, heightFraction: 0.18, cx: 0.50, cy: 0.80)
        case .feet:
            return SegmentParams(widthFraction: 0.55, heightFraction: 0.06, cx: 0.50, cy: 0.97)
        case .hands:
            return SegmentParams(widthFraction: 0.85, heightFraction: 0.08, cx: 0.50, cy: 0.52)
        }
    }
}
