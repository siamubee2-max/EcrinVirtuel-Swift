import SwiftUI

// MARK: - Wedding Slot Card

struct WeddingSlotCard: View {
    let slot: WeddingSlot
    let piece: WeddingPiece?
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isPulse = false

    var isFilled: Bool { piece != nil }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glass base
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(EcrinColor.glassFill)

                // Border: gold if filled, glass if empty
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isFilled
                            ? EcrinColor.gold.opacity(0.55)
                            : EcrinColor.glassStroke,
                        lineWidth: isFilled ? 1.0 : 0.5
                    )

                if let piece {
                    filledContent(piece: piece)
                } else {
                    emptyContent
                }
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if piece != nil {
                Button(role: .destructive, action: onRemove) {
                    Label(L10n.WeddingUI.removeThisJewel, systemImage: "trash")
                }
                Button(action: onTap) {
                    Label(L10n.WeddingUI.changeButton, systemImage: "arrow.2.circlepath")
                }
            }
        }
    }

    // MARK: - Filled content

    @ViewBuilder
    private func filledContent(piece: WeddingPiece) -> some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            // Slot label
            Text(slot.rawValue.uppercased())
                .font(EcrinFont.label)
                .kerning(1.5)
                .foregroundStyle(EcrinColor.gold)
                .padding(.top, EcrinSpacing.md)
                .padding(.horizontal, EcrinSpacing.md)

            HStack(spacing: EcrinSpacing.sm) {
                // Jewelry icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(EcrinColor.gold.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: piece.jewelry.icon)
                        .font(.system(size: 22, weight: .thin))
                        .foregroundStyle(EcrinColor.gold)
                }
                .padding(.leading, EcrinSpacing.md)

                VStack(alignment: .leading, spacing: 3) {
                    Text(piece.jewelry.name)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(1)
                    Text(piece.jewelry.material)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            // "Changer" button
            HStack {
                Spacer()
                Text(L10n.WeddingUI.changeButton)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.gold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(EcrinColor.gold)
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.bottom, EcrinSpacing.sm)
        }
    }

    // MARK: - Empty content

    private var emptyContent: some View {
        VStack(spacing: EcrinSpacing.sm) {
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(isPulse ? 0.15 : 0.06))
                    .frame(width: 52, height: 52)
                    .scaleEffect(isPulse ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.7).repeatForever(autoreverses: true),
                        value: isPulse
                    )

                Image(systemName: slot.icon)
                    .font(.system(size: 22, weight: .thin))
                    .foregroundStyle(EcrinColor.gold.opacity(0.65))
            }

            Text(slot.rawValue)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, EcrinSpacing.sm)

            Text(L10n.JewelryDetectionUI.add)
                .font(EcrinFont.label)
                .kerning(1)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.vertical, EcrinSpacing.md)
        .onAppear { isPulse = true }
    }
}
