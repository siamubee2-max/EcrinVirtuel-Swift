import SwiftUI

// MARK: - Visual preview tile for a background item (pure SwiftUI, no external assets)

struct BackgroundPreviewTile: View {
    let item: BackgroundItem
    let isSelected: Bool
    let lockLabel: String?

    private let size: CGFloat = 80

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background visual
            backgroundFill
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(EcrinColor.gold, lineWidth: 2.5)
                    .frame(width: size, height: size)
            }

            // Lock overlay
            if let label = lockLabel {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                    VStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(EcrinColor.gold)
                        Text(label)
                            .font(.system(size: 8, weight: .semibold))
                            .kerning(0.5)
                            .foregroundStyle(EcrinColor.ivory)
                    }
                }
                .frame(width: size, height: size)
            }

            // Checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(EcrinColor.gold)
                    .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 20, height: 20))
                    .offset(x: 4, y: 4)
            }
        }
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch item.source {
        case .solidColor(let hex):
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: hex))

        case .gradient(let hexColors, let angle):
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(angularGradient(colors: hexColors, angle: angle))

        case .generated:
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: item.previewColor))
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(EcrinColor.gold.opacity(0.7))
            }

        case .userPhoto:
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#333333"))
                Image(systemName: "person.crop.square.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private func angularGradient(colors: [String], angle: Double) -> LinearGradient {
        let swiftColors = colors.map { Color(hex: $0) }
        let rad = angle * .pi / 180.0
        let dx = cos(rad)
        let dy = sin(rad)
        return LinearGradient(
            colors: swiftColors,
            startPoint: UnitPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5),
            endPoint:   UnitPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
        )
    }
}

// MARK: - Larger background view for live preview compositing

struct BackgroundSwatchView: View {
    let item: BackgroundItem
    var cornerRadius: CGFloat = 20

    var body: some View {
        switch item.source {
        case .solidColor(let hex):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: hex))

        case .gradient(let hexColors, let angle):
            let swiftColors = hexColors.map { Color(hex: $0) }
            let rad = angle * .pi / 180.0
            let dx = cos(rad)
            let dy = sin(rad)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: swiftColors,
                        startPoint: UnitPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5),
                        endPoint:   UnitPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
                    )
                )

        case .generated, .userPhoto:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: item.previewColor))
        }
    }
}
