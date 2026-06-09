import SwiftUI

// MARK: - Frame Preview Tile (100% SwiftUI, no external assets)

struct FramePreviewTile: View {
    let frame: SnapshotFrame
    let isSelected: Bool
    let lockLabel: String?
    private let size: CGFloat = 80

    var body: some View {
        ZStack {
            // Frame visual representation
            frameVisual
                .frame(width: size, height: size)

            // Lock overlay
            if let label = lockLabel {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.6))
                    VStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(EcrinColor.gold)
                        Text(label)
                            .font(.system(size: 8, weight: .semibold))
                            .kerning(0.5)
                            .foregroundStyle(EcrinColor.ivory)
                    }
                }
                .frame(width: size, height: size)
            }

            // Selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(EcrinColor.gold, lineWidth: 2.5)
                    .frame(width: size, height: size)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(EcrinColor.gold)
                    .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 20, height: 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 4, y: 4)
            }
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }

    @ViewBuilder
    private var frameVisual: some View {
        ZStack {
            // Inner fill (simulated image area)
            RoundedRectangle(cornerRadius: max(frame.style.cornerRadius - 2, 0), style: .continuous)
                .fill(innerFillColor)
                .padding(frame.style.borderWidth / scaleDown)

            // Overlay decoration preview
            overlayPreview

            // Border
            RoundedRectangle(cornerRadius: frame.style.cornerRadius, style: .continuous)
                .strokeBorder(Color(hex: frame.style.borderColor), lineWidth: max(frame.style.borderWidth / scaleDown, 1.5))

            // Category-specific decorations
            categoryDecoration
        }
    }

    private var scaleDown: CGFloat { frame.style.borderWidth > 0 ? max(frame.style.borderWidth / 3, 1) : 1 }

    private var innerFillColor: Color {
        switch frame.category {
        case .polaroid:
            return Color(hex: frame.style.backgroundColor ?? "#FAFAF9").opacity(0.3)
        case .magazine:
            return Color.black.opacity(0.6)
        default:
            return Color.black.opacity(0.5)
        }
    }

    @ViewBuilder
    private var overlayPreview: some View {
        if let overlay = frame.style.overlay {
            switch overlay {
            case .goldPattern:
                goldPatternPreview
            case .diamondSparkles:
                diamondSparklesPreview
            case .floral(let season):
                floralPreview(season: season)
            case .gamingCrown:
                gamingPreview
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var categoryDecoration: some View {
        switch frame.category {
        case .polaroid:
            // White bottom strip
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(hex: frame.style.backgroundColor ?? "#FAFAF9").opacity(0.85))
                    .frame(height: 18)
                    .overlay(
                        Text(polaroidLabel)
                            .font(.system(size: 6, weight: .light))
                            .foregroundStyle(Color.black.opacity(0.5))
                            .kerning(0.8)
                    )
            }

        case .magazine:
            VStack {
                if let top = frame.style.topText {
                    Text(top)
                        .font(.custom("Cormorant", size: 9))
                        .fontWeight(.thin)
                        .kerning(2)
                        .foregroundStyle(Color(hex: frame.style.borderColor))
                        .padding(.top, 4)
                }
                Spacer()
                if let bottom = frame.style.bottomText {
                    Text(bottom)
                        .font(.system(size: 6, weight: .medium))
                        .kerning(1.5)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 4)

        default:
            EmptyView()
        }
    }

    private var polaroidLabel: String {
        frame.style.showDate ? todayShort : (frame.style.showJewelryName ? "L'ÉCRIN" : "")
    }

    private var todayShort: String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM"
        return df.string(from: Date())
    }

    // MARK: Overlay Previews

    private var goldPatternPreview: some View {
        Canvas { context, size in
            let bw = frame.style.borderWidth / 3
            context.stroke(
                Path { path in
                    var x: CGFloat = 0
                    while x < size.width + size.height {
                        path.move(to: CGPoint(x: x - size.height, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: 0))
                        x += 5
                    }
                },
                with: .color(Color(hex: "#CA8A04").opacity(0.25)),
                lineWidth: 0.5
            )
            _ = bw
        }
        .clipShape(
            RoundedRectangle(cornerRadius: frame.style.cornerRadius, style: .continuous)
        )
        .allowsHitTesting(false)
    }

    private var diamondSparklesPreview: some View {
        GeometryReader { geo in
            let positions: [CGPoint] = [
                CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.1),
                CGPoint(x: geo.size.width * 0.9, y: geo.size.height * 0.1),
                CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.9),
                CGPoint(x: geo.size.width * 0.9, y: geo.size.height * 0.9),
            ]
            ZStack {
                ForEach(positions.indices, id: \.self) { i in
                    SparkleShape()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 8, height: 8)
                        .position(positions[i])
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func floralPreview(season: String) -> some View {
        let color = floralColor(season: season)
        return GeometryReader { geo in
            ZStack {
                ForEach(0..<4) { i in
                    let x: CGFloat = i < 2 ? geo.size.width * 0.12 : geo.size.width * 0.88
                    let y: CGFloat = (i % 2 == 0) ? geo.size.height * 0.12 : geo.size.height * 0.88
                    PetalFlower()
                        .fill(color.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .position(CGPoint(x: x, y: y))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var gamingPreview: some View {
        GeometryReader { geo in
            ZStack {
                CrownShape()
                    .fill(Color(hex: "#FFD700").opacity(0.9))
                    .frame(width: 16, height: 12)
                    .position(CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.1))
                CrownShape()
                    .fill(Color(hex: "#FFD700").opacity(0.9))
                    .frame(width: 16, height: 12)
                    .position(CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.1))
            }
        }
        .allowsHitTesting(false)
    }

    private func floralColor(season: String) -> Color {
        switch season {
        case "noel":     return Color(red: 0.1, green: 0.5, blue: 0.1)
        case "valentin": return Color(red: 0.8, green: 0.2, blue: 0.3)
        case "printemps": return Color(red: 0.9, green: 0.5, blue: 0.65)
        case "ete":      return Color(red: 0.1, green: 0.5, blue: 0.7)
        case "halloween": return Color(red: 0.5, green: 0.1, blue: 0.6)
        case "versailles": return Color(hex: "#D4AF37")
        default:         return EcrinColor.gold
        }
    }
}

// MARK: - Custom Shapes

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let h = rect.height / 2, t = rect.height / 6
        path.move(to: CGPoint(x: cx, y: cy - h))
        path.addLine(to: CGPoint(x: cx + t, y: cy - t))
        path.addLine(to: CGPoint(x: cx + h, y: cy))
        path.addLine(to: CGPoint(x: cx + t, y: cy + t))
        path.addLine(to: CGPoint(x: cx, y: cy + h))
        path.addLine(to: CGPoint(x: cx - t, y: cy + t))
        path.addLine(to: CGPoint(x: cx - h, y: cy))
        path.addLine(to: CGPoint(x: cx - t, y: cy - t))
        path.closeSubpath()
        return path
    }
}

struct PetalFlower: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) * 0.35
        let cr = min(rect.width, rect.height) * 0.12
        for i in 0..<5 {
            let angle = Double(i) / 5.0 * 2 * .pi - .pi / 2
            let px = cx + CGFloat(cos(angle)) * r
            let py = cy + CGFloat(sin(angle)) * r
            path.addEllipse(in: CGRect(x: px - cr, y: py - cr, width: cr * 2, height: cr * 2))
        }
        path.addEllipse(in: CGRect(x: cx - cr * 0.7, y: cy - cr * 0.7, width: cr * 1.4, height: cr * 1.4))
        return path
    }
}

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.minX, y = rect.minY
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: x, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h * 0.45))
        path.addLine(to: CGPoint(x: x + w * 0.22, y: y + h * 0.12))
        path.addLine(to: CGPoint(x: x + w * 0.5, y: y))
        path.addLine(to: CGPoint(x: x + w * 0.78, y: y + h * 0.12))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.45))
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        path.closeSubpath()
        return path
    }
}
