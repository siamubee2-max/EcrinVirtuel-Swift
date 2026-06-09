import SwiftUI

// MARK: - Frame Renderer
// Compose fond + image essayage + cadre en UIImage haute résolution

@MainActor
final class FrameRenderer {

    // MARK: - Public API

    /// Applique uniquement un cadre à une image
    func apply(frame: SnapshotFrame, to image: UIImage, customText: String? = nil) async -> UIImage {
        await compose(image: image, background: nil, frame: frame, customText: customText)
    }

    /// Applique uniquement un fond à une image
    func applyBackground(background: BackgroundItem, to image: UIImage) async -> UIImage {
        await compose(image: image, background: background, frame: nil, customText: nil)
    }

    /// Compose fond + image + cadre en une seule passe haute résolution
    func compose(
        image: UIImage,
        background: BackgroundItem?,
        frame: SnapshotFrame?,
        customText: String? = nil
    ) async -> UIImage {
        let outputSize = image.size.isEmpty ? CGSize(width: 1080, height: 1350) : image.size

        return await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: outputSize)
            return renderer.image { ctx in
                let bounds = CGRect(origin: .zero, size: outputSize)
                let cgCtx = ctx.cgContext

                // 1. Fond (background)
                if let bg = background {
                    Self.drawBackground(bg, in: bounds, context: cgCtx)
                } else {
                    UIColor.black.setFill()
                    cgCtx.fill(bounds)
                }

                // 2. Image essayage (centrée / scaled to fill)
                if let frame = frame {
                    let borderPad = frame.style.borderWidth + frame.style.innerPadding
                    let imageRect = bounds.insetBy(dx: borderPad, dy: borderPad)
                    Self.drawImage(image, in: imageRect, context: cgCtx, cornerRadius: frame.style.cornerRadius)
                } else {
                    Self.drawImage(image, in: bounds, context: cgCtx, cornerRadius: 0)
                }

                // 3. Cadre (frame)
                if let frame = frame {
                    Self.drawFrame(frame, in: bounds, context: cgCtx, image: image, customText: customText)
                }
            }
        }.value
    }

    // MARK: - Private Drawing

    nonisolated private static func drawBackground(_ bg: BackgroundItem, in rect: CGRect, context: CGContext) {
        switch bg.source {
        case .solidColor(let hex):
            UIColor(Color(hex: hex)).setFill()
            context.fill(rect)

        case .gradient(let hexColors, let angle):
            let colors = hexColors.map { UIColor(Color(hex: $0)).cgColor }
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: nil
            ) else {
                UIColor.black.setFill()
                context.fill(rect)
                return
            }
            let rad = angle * .pi / 180.0
            let cx = rect.midX
            let cy = rect.midY
            let dx = cos(rad) * rect.width * 0.5
            let dy = sin(rad) * rect.height * 0.5
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: cx - dx, y: cy - dy),
                end: CGPoint(x: cx + dx, y: cy + dy),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .generated, .userPhoto:
            UIColor(Color(hex: bg.previewColor)).setFill()
            context.fill(rect)
        }
    }

    nonisolated private static func drawImage(_ image: UIImage, in rect: CGRect, context: CGContext, cornerRadius: CGFloat) {
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.saveGState()
            path.addClip()
        }
        // Scale to fill
        let imgSize = image.size
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let drawW = imgSize.width * scale
        let drawH = imgSize.height * scale
        let drawRect = CGRect(
            x: rect.midX - drawW / 2,
            y: rect.midY - drawH / 2,
            width: drawW,
            height: drawH
        )
        image.draw(in: drawRect)
        if cornerRadius > 0 {
            context.restoreGState()
        }
    }

    nonisolated private static func drawFrame(
        _ frame: SnapshotFrame,
        in bounds: CGRect,
        context: CGContext,
        image: UIImage,
        customText: String?
    ) {
        let style = frame.style
        let borderColor = UIColor(Color(hex: style.borderColor))
        let bw = style.borderWidth
        let cr = style.cornerRadius

        // Inner padding double-border
        if style.innerPadding > 0 {
            let innerRect = bounds.insetBy(dx: bw + style.innerPadding, dy: bw + style.innerPadding)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(1)
            let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: max(cr - 2, 0))
            innerPath.stroke()
        }

        // Main border
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(bw)
        let borderInset = bw / 2
        let framePath = UIBezierPath(
            roundedRect: bounds.insetBy(dx: borderInset, dy: borderInset),
            cornerRadius: cr
        )
        framePath.stroke()

        // Overlay decorations
        if let overlay = style.overlay {
            drawOverlay(overlay, in: bounds, context: context, borderWidth: bw, borderColor: borderColor)
        }

        // Polaroid bottom tab
        if frame.category == .polaroid {
            drawPolaroidTab(
                frame: frame,
                in: bounds,
                context: context,
                customText: customText
            )
        }

        // Magazine header/footer texts
        if frame.category == .magazine {
            drawMagazineText(frame: frame, in: bounds, context: context)
        }

        // Gaming special overlay
        if frame.category == .gaming, let overlay = style.overlay,
           case .gamingCrown(let level) = overlay {
            drawGamingOverlay(level: level, frame: frame, in: bounds, context: context)
        }
    }

    nonisolated private static func drawOverlay(
        _ overlay: FrameOverlay,
        in bounds: CGRect,
        context: CGContext,
        borderWidth bw: CGFloat,
        borderColor: UIColor
    ) {
        switch overlay {
        case .goldPattern:
            drawGoldPattern(in: bounds, context: context, bw: bw)
        case .diamondSparkles:
            drawDiamondSparkles(in: bounds, context: context, bw: bw)
        case .floral(let season):
            drawFloralCorners(season: season, in: bounds, context: context, bw: bw)
        case .magazineLogo, .partnerBadge, .gamingCrown:
            break
        }
    }

    // MARK: Gold Pattern (subtle diagonal lines in border)
    nonisolated private static func drawGoldPattern(in bounds: CGRect, context: CGContext, bw: CGFloat) {
        let goldColor = UIColor(Color(hex: "#CA8A04"))
        context.setStrokeColor(goldColor.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(0.5)
        let step: CGFloat = 6
        // Diagonal stripes inside border band
        context.saveGState()
        let borderPath = UIBezierPath(rect: bounds)
        let innerPath = UIBezierPath(rect: bounds.insetBy(dx: bw, dy: bw))
        borderPath.append(innerPath.reversing())
        borderPath.addClip()
        var x: CGFloat = -bounds.height
        while x < bounds.width + bounds.height {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x + bounds.height, y: bounds.height))
            x += step
        }
        context.strokePath()
        context.restoreGState()
    }

    // MARK: Diamond Sparkles at corners
    nonisolated private static func drawDiamondSparkles(in bounds: CGRect, context: CGContext, bw: CGFloat) {
        let corners: [CGPoint] = [
            CGPoint(x: bounds.minX + bw / 2, y: bounds.minY + bw / 2),
            CGPoint(x: bounds.maxX - bw / 2, y: bounds.minY + bw / 2),
            CGPoint(x: bounds.minX + bw / 2, y: bounds.maxY - bw / 2),
            CGPoint(x: bounds.maxX - bw / 2, y: bounds.maxY - bw / 2),
        ]
        let size = bw * 1.8
        context.setFillColor(UIColor.white.cgColor)
        for center in corners {
            // 4-pointed star
            let starPath = UIBezierPath()
            let half = size / 2
            let thin = size / 6
            starPath.move(to: CGPoint(x: center.x, y: center.y - half))
            starPath.addLine(to: CGPoint(x: center.x + thin, y: center.y - thin))
            starPath.addLine(to: CGPoint(x: center.x + half, y: center.y))
            starPath.addLine(to: CGPoint(x: center.x + thin, y: center.y + thin))
            starPath.addLine(to: CGPoint(x: center.x, y: center.y + half))
            starPath.addLine(to: CGPoint(x: center.x - thin, y: center.y + thin))
            starPath.addLine(to: CGPoint(x: center.x - half, y: center.y))
            starPath.addLine(to: CGPoint(x: center.x - thin, y: center.y - thin))
            starPath.close()
            UIColor.white.withAlphaComponent(0.9).setFill()
            starPath.fill()
            UIColor(Color(hex: "#CA8A04")).setStroke()
            starPath.lineWidth = 0.5
            starPath.stroke()
        }
    }

    // MARK: Floral Corners
    nonisolated private static func drawFloralCorners(season: String, in bounds: CGRect, context: CGContext, bw: CGFloat) {
        let colors: (UIColor, UIColor)
        switch season {
        case "noel":     colors = (UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1), UIColor(Color(hex: "#CA8A04")))
        case "valentin": colors = (UIColor(red: 0.8, green: 0.2, blue: 0.3, alpha: 1), UIColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1))
        case "printemps": colors = (UIColor(red: 0.9, green: 0.5, blue: 0.65, alpha: 1), UIColor(red: 1.0, green: 0.8, blue: 0.9, alpha: 1))
        case "ete":      colors = (UIColor(red: 0.1, green: 0.5, blue: 0.7, alpha: 1), UIColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1))
        case "halloween": colors = (UIColor(red: 0.5, green: 0.1, blue: 0.6, alpha: 1), UIColor(red: 0.9, green: 0.4, blue: 0.0, alpha: 1))
        case "versailles": colors = (UIColor(Color(hex: "#D4AF37")), UIColor(red: 0.9, green: 0.8, blue: 0.4, alpha: 1))
        default:         colors = (UIColor(Color(hex: "#CA8A04")), UIColor.white)
        }

        let cornerSize = bw * 2.5
        let cornerPositions: [(CGPoint, Bool)] = [
            (CGPoint(x: bounds.minX, y: bounds.minY), false),
            (CGPoint(x: bounds.maxX - cornerSize, y: bounds.minY), true),
            (CGPoint(x: bounds.minX, y: bounds.maxY - cornerSize), false),
            (CGPoint(x: bounds.maxX - cornerSize, y: bounds.maxY - cornerSize), true),
        ]

        for (origin, flipped) in cornerPositions {
            drawFloral(
                at: origin,
                size: cornerSize,
                primary: colors.0,
                accent: colors.1,
                flipped: flipped,
                context: context
            )
        }
    }

    nonisolated private static func drawFloral(
        at origin: CGPoint,
        size: CGFloat,
        primary: UIColor,
        accent: UIColor,
        flipped: Bool,
        context: CGContext
    ) {
        context.saveGState()
        let cx = origin.x + size / 2
        let cy = origin.y + size / 2
        // Petals
        let petalCount = 5
        let petalRadius = size * 0.28
        let petalDist = size * 0.22
        for i in 0..<petalCount {
            let angle = Double(i) / Double(petalCount) * 2 * .pi + (flipped ? .pi : 0)
            let px = cx + CGFloat(cos(angle)) * petalDist
            let py = cy + CGFloat(sin(angle)) * petalDist
            let petalPath = UIBezierPath(ovalIn: CGRect(
                x: px - petalRadius / 2,
                y: py - petalRadius / 2,
                width: petalRadius,
                height: petalRadius
            ))
            primary.withAlphaComponent(0.8).setFill()
            petalPath.fill()
        }
        // Center
        let centerPath = UIBezierPath(ovalIn: CGRect(
            x: cx - size * 0.1,
            y: cy - size * 0.1,
            width: size * 0.2,
            height: size * 0.2
        ))
        accent.setFill()
        centerPath.fill()
        context.restoreGState()
    }

    // MARK: Polaroid Tab
    nonisolated private static func drawPolaroidTab(
        frame: SnapshotFrame,
        in bounds: CGRect,
        context: CGContext,
        customText: String?
    ) {
        let style = frame.style
        let tabHeight = style.borderWidth * 3.5
        let bgHex = style.backgroundColor ?? "#FAFAF9"
        let tabRect = CGRect(
            x: bounds.minX,
            y: bounds.maxY - tabHeight,
            width: bounds.width,
            height: tabHeight
        )
        UIColor(Color(hex: bgHex)).setFill()
        context.fill(tabRect)

        // Text in tab
        var lines: [String] = []
        if let custom = customText, !custom.isEmpty { lines.append(custom) }
        else if style.showJewelryName { lines.append("L'ÉCRIN VIRTUEL") }
        if style.showDate {
            let df = DateFormatter()
            df.dateFormat = "dd.MM.yyyy"
            lines.append(df.string(from: Date()))
        }

        let textColor = UIColor.black.withAlphaComponent(0.7)
        let fontSize = max(tabHeight * 0.22, 10)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Cormorant", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .light),
            .foregroundColor: textColor,
            .kern: 1.5,
        ]
        let combined = lines.joined(separator: "  ·  ")
        let nsStr = NSAttributedString(string: combined, attributes: attrs)
        let strSize = nsStr.size()
        nsStr.draw(at: CGPoint(
            x: tabRect.midX - strSize.width / 2,
            y: tabRect.midY - strSize.height / 2
        ))
    }

    // MARK: Magazine Text
    nonisolated private static func drawMagazineText(frame: SnapshotFrame, in bounds: CGRect, context: CGContext) {
        let style = frame.style
        let borderColor = UIColor(Color(hex: style.borderColor))
        let bw = style.borderWidth

        if let topText = style.topText {
            // Magazine masthead top
            let headerH = bw * 2.5
            let headerRect = CGRect(x: bounds.minX + bw, y: bounds.minY + bw / 2, width: bounds.width - bw * 2, height: headerH)
            let fontSize = max(headerH * 0.55, 14)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Cormorant", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .thin),
                .foregroundColor: borderColor,
                .kern: 4.0,
            ]
            let nsStr = NSAttributedString(string: topText.uppercased(), attributes: attrs)
            let sz = nsStr.size()
            nsStr.draw(at: CGPoint(x: headerRect.midX - sz.width / 2, y: headerRect.midY - sz.height / 2))
        }

        if let bottomText = style.bottomText {
            let footerH = bw * 2
            let footerRect = CGRect(x: bounds.minX + bw, y: bounds.maxY - bw - footerH, width: bounds.width - bw * 2, height: footerH)
            let fontSize = max(footerH * 0.4, 9)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .kern: 3.0,
            ]
            let nsStr = NSAttributedString(string: bottomText.uppercased(), attributes: attrs)
            let sz = nsStr.size()
            nsStr.draw(at: CGPoint(x: footerRect.midX - sz.width / 2, y: footerRect.midY - sz.height / 2))
        }
    }

    // MARK: Gaming Overlay
    nonisolated private static func drawGamingOverlay(level: String, frame: SnapshotFrame, in bounds: CGRect, context: CGContext) {
        let bw = frame.style.borderWidth
        let goldColor = UIColor(Color(hex: "#FFD700"))

        // Top corners: crown icons drawn as paths
        let crownSize = bw * 2.2
        for xPos in [bounds.minX + bw * 0.5, bounds.maxX - bw * 0.5 - crownSize] {
            let crownRect = CGRect(x: xPos, y: bounds.minY + bw * 0.3, width: crownSize, height: crownSize * 0.7)
            drawCrownPath(in: crownRect, color: goldColor, context: context)
        }

        // Level text at bottom
        let levelRect = CGRect(
            x: bounds.minX + bw,
            y: bounds.maxY - bw * 2.2,
            width: bounds.width - bw * 2,
            height: bw * 1.6
        )
        let fontSize = max(bw * 0.55, 10)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: goldColor,
            .kern: 3.0,
        ]
        let nsStr = NSAttributedString(string: level, attributes: attrs)
        let sz = nsStr.size()
        nsStr.draw(at: CGPoint(
            x: levelRect.midX - sz.width / 2,
            y: levelRect.midY - sz.height / 2
        ))

        // Particle sparkles along border
        drawGoldPattern(in: bounds, context: context, bw: bw)
        drawDiamondSparkles(in: bounds, context: context, bw: bw)
    }

    nonisolated private static func drawCrownPath(in rect: CGRect, color: UIColor, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath()
        // Simple crown: base + 3 points
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        path.move(to: CGPoint(x: x, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h * 0.5))
        path.addLine(to: CGPoint(x: x + w * 0.25, y: y + h * 0.15))
        path.addLine(to: CGPoint(x: x + w * 0.5, y: y))
        path.addLine(to: CGPoint(x: x + w * 0.75, y: y + h * 0.15))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.5))
        path.addLine(to: CGPoint(x: x + w, y: y + h))
        path.close()
        color.withAlphaComponent(0.85).setFill()
        path.fill()
        color.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        context.restoreGState()
    }
}

// MARK: - CGSize helper
private extension CGSize {
    var isEmpty: Bool { width == 0 || height == 0 }
}
