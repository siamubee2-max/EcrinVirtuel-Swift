import SwiftUI

// MARK: - SwiftUI live frame overlay (100% SwiftUI, no external assets)
// Renders the frame visually over any content — used for live preview.

struct FrameSwiftUIView: View {
    let frame: SnapshotFrame
    let size: CGSize

    var body: some View {
        ZStack {
            // Border
            RoundedRectangle(cornerRadius: frame.style.cornerRadius, style: .continuous)
                .strokeBorder(Color(hex: frame.style.borderColor), lineWidth: frame.style.borderWidth)

            // Inner double border if needed
            if frame.style.innerPadding > 0 {
                RoundedRectangle(
                    cornerRadius: max(frame.style.cornerRadius - frame.style.innerPadding, 0),
                    style: .continuous
                )
                .strokeBorder(Color(hex: frame.style.borderColor).opacity(0.5), lineWidth: 1)
                .padding(frame.style.borderWidth + frame.style.innerPadding)
            }

            // Overlay decoration
            if let overlay = frame.style.overlay {
                overlayView(overlay)
            }

            // Category-specific decorations
            categoryDecor
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Overlay

    @ViewBuilder
    private func overlayView(_ overlay: FrameOverlay) -> some View {
        switch overlay {
        case .goldPattern:
            GoldPatternOverlay(borderWidth: frame.style.borderWidth, cornerRadius: frame.style.cornerRadius)

        case .diamondSparkles:
            DiamondSparklesOverlay(borderWidth: frame.style.borderWidth)

        case .floral(let season):
            FloralCornersOverlay(season: season, borderWidth: frame.style.borderWidth)

        case .gamingCrown(let level):
            GamingCrownOverlay(level: level, borderWidth: frame.style.borderWidth, borderColor: Color(hex: frame.style.borderColor))

        case .magazineLogo(let name):
            VStack {
                Text(name)
                    .font(.custom("Cormorant", size: 11))
                    .fontWeight(.thin)
                    .kerning(3)
                    .foregroundStyle(Color(hex: frame.style.borderColor).opacity(0.6))
                    .padding(.top, frame.style.borderWidth + 2)
                Spacer()
            }

        case .partnerBadge(let brand):
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(brand.uppercased())
                        .font(.system(size: 8, weight: .medium))
                        .kerning(1.5)
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(frame.style.borderWidth + 4)
                }
            }
        }
    }

    // MARK: Category Decorations

    @ViewBuilder
    private var categoryDecor: some View {
        switch frame.category {
        case .polaroid:
            PolaroidTabOverlay(frame: frame)

        case .magazine:
            MagazineTextOverlay(frame: frame)

        default:
            EmptyView()
        }
    }
}

// MARK: - Gold Pattern Overlay

struct GoldPatternOverlay: View {
    let borderWidth: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                // Draw diagonal stripes only in border band (simulated — no CGContext clipping in SwiftUI Canvas)
                // Use two overlaid rounded rectangles to approximate
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: x, y: 0))
                    linePath.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    ctx.stroke(linePath, with: .color(EcrinColor.gold.opacity(0.2)), lineWidth: 0.6)
                    x += 5
                }
            }
            .clipShape(
                // Clip to border ring via mask
                BorderRingShape(borderWidth: borderWidth, cornerRadius: cornerRadius)
            )
        }
        .allowsHitTesting(false)
    }
}

struct BorderRingShape: Shape {
    let borderWidth: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        let inner = rect.insetBy(dx: borderWidth, dy: borderWidth)
        let innerRadius = max(cornerRadius - borderWidth, 0)
        path.addRoundedRect(in: inner, cornerSize: CGSize(width: innerRadius, height: innerRadius))
        return path
    }
}

// MARK: - Diamond Sparkles Overlay

struct DiamondSparklesOverlay: View {
    let borderWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let offset = borderWidth * 0.5
            let positions: [CGPoint] = [
                CGPoint(x: offset, y: offset),
                CGPoint(x: w - offset, y: offset),
                CGPoint(x: offset, y: h - offset),
                CGPoint(x: w - offset, y: h - offset),
            ]
            ZStack {
                ForEach(positions.indices, id: \.self) { i in
                    SparkleView(size: max(borderWidth * 1.6, 10))
                        .position(positions[i])
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SparkleView: View {
    let size: CGFloat
    @State private var glow = false

    var body: some View {
        ZStack {
            SparkleShape()
                .fill(Color.white)
                .frame(width: size, height: size)
            SparkleShape()
                .fill(Color(hex: "#CA8A04").opacity(0.5))
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .shadow(color: Color.white.opacity(glow ? 0.9 : 0.4), radius: glow ? 4 : 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Floral Corners Overlay

struct FloralCornersOverlay: View {
    let season: String
    let borderWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let flowerSize = max(borderWidth * 2.2, 18)
            let offset = borderWidth * 0.6
            let positions: [CGPoint] = [
                CGPoint(x: offset + flowerSize / 2, y: offset + flowerSize / 2),
                CGPoint(x: w - offset - flowerSize / 2, y: offset + flowerSize / 2),
                CGPoint(x: offset + flowerSize / 2, y: h - offset - flowerSize / 2),
                CGPoint(x: w - offset - flowerSize / 2, y: h - offset - flowerSize / 2),
            ]
            ZStack {
                ForEach(positions.indices, id: \.self) { i in
                    SeasonalFlower(season: season, size: flowerSize)
                        .position(positions[i])
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeasonalFlower: View {
    let season: String
    let size: CGFloat
    @State private var rotate = false

    var primaryColor: Color {
        switch season {
        case "noel":      return Color(red: 0.1, green: 0.55, blue: 0.15)
        case "valentin":  return Color(red: 0.85, green: 0.2, blue: 0.35)
        case "printemps": return Color(red: 0.92, green: 0.5, blue: 0.68)
        case "ete":       return Color(red: 0.1, green: 0.55, blue: 0.75)
        case "halloween": return Color(red: 0.55, green: 0.1, blue: 0.65)
        case "versailles": return Color(hex: "#D4AF37")
        default:          return EcrinColor.gold
        }
    }

    var accentColor: Color {
        switch season {
        case "noel":      return EcrinColor.gold
        case "valentin":  return Color(red: 1.0, green: 0.75, blue: 0.82)
        case "printemps": return Color(red: 1.0, green: 0.88, blue: 0.94)
        case "ete":       return Color(red: 0.9, green: 0.85, blue: 0.5)
        case "halloween": return Color(red: 0.92, green: 0.5, blue: 0.05)
        case "versailles": return Color(red: 0.98, green: 0.94, blue: 0.6)
        default:          return Color.white
        }
    }

    var seasonEmoji: String {
        switch season {
        case "noel":      return "✦"
        case "valentin":  return "♥"
        case "ete":       return "✿"
        default:          return ""
        }
    }

    var body: some View {
        ZStack {
            // 5 petals
            ForEach(0..<5) { i in
                Ellipse()
                    .fill(primaryColor.opacity(0.85))
                    .frame(width: size * 0.35, height: size * 0.5)
                    .offset(y: -size * 0.22)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            // Center dot
            Circle()
                .fill(accentColor)
                .frame(width: size * 0.25, height: size * 0.25)
                .shadow(color: accentColor.opacity(0.5), radius: 2)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotate ? 360 : 0))
        .onAppear {
            withAnimation(
                .linear(duration: Double.random(in: 12...20))
                .repeatForever(autoreverses: false)
            ) {
                rotate = true
            }
        }
    }
}

// MARK: - Gaming Crown Overlay

struct GamingCrownOverlay: View {
    let level: String
    let borderWidth: CGFloat
    let borderColor: Color
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            let crownW = max(borderWidth * 2.5, 22)
            let crownH = crownW * 0.65

            ZStack {
                // Top-left crown
                CrownShape()
                    .fill(Color(hex: "#FFD700").opacity(shimmer ? 1.0 : 0.7))
                    .frame(width: crownW, height: crownH)
                    .shadow(color: Color(hex: "#FFD700").opacity(0.6), radius: shimmer ? 6 : 2)
                    .position(CGPoint(x: borderWidth * 0.8, y: borderWidth * 0.6))

                // Top-right crown
                CrownShape()
                    .fill(Color(hex: "#FFD700").opacity(shimmer ? 1.0 : 0.7))
                    .frame(width: crownW, height: crownH)
                    .shadow(color: Color(hex: "#FFD700").opacity(0.6), radius: shimmer ? 6 : 2)
                    .position(CGPoint(x: geo.size.width - borderWidth * 0.8, y: borderWidth * 0.6))

                // Level label bottom
                VStack {
                    Spacer()
                    Text(level)
                        .font(.system(size: max(borderWidth * 0.55, 8), weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color(hex: "#FFD700"))
                        .shadow(color: Color(hex: "#FFD700").opacity(0.7), radius: 4)
                        .padding(.bottom, borderWidth * 0.4)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Polaroid Tab Overlay

struct PolaroidTabOverlay: View {
    let frame: SnapshotFrame

    private var tabBgColor: Color {
        Color(hex: frame.style.backgroundColor ?? "#FAFAF9")
    }

    private var tabText: String {
        if let bottom = frame.style.bottomText, !bottom.isEmpty { return bottom }
        var parts: [String] = []
        if frame.style.showJewelryName { parts.append("L'ÉCRIN VIRTUEL") }
        if frame.style.showDate {
            let df = DateFormatter()
            df.dateFormat = "dd · MM · yyyy"
            parts.append(df.string(from: Date()))
        }
        return parts.joined(separator: "  ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                tabBgColor
                    .frame(height: frame.style.borderWidth * 3.5)
                if !tabText.isEmpty {
                    Text(tabText)
                        .font(.custom("Cormorant", size: 11))
                        .fontWeight(.light)
                        .kerning(1.5)
                        .foregroundStyle(Color.black.opacity(0.65))
                }
            }
            .frame(height: frame.style.borderWidth * 3.5)
        }
    }
}

// MARK: - Magazine Text Overlay

struct MagazineTextOverlay: View {
    let frame: SnapshotFrame

    var body: some View {
        VStack {
            if let top = frame.style.topText {
                Text(top)
                    .font(.custom("Cormorant", size: 16))
                    .fontWeight(.thin)
                    .kerning(5)
                    .foregroundStyle(Color(hex: frame.style.borderColor))
                    .shadow(color: Color(hex: frame.style.borderColor).opacity(0.3), radius: 4)
                    .padding(.top, frame.style.borderWidth + 4)
            }
            Spacer()
            if let bottom = frame.style.bottomText {
                Text(bottom)
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(3)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.bottom, frame.style.borderWidth + 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
