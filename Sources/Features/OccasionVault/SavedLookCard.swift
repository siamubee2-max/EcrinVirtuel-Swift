import SwiftUI

// MARK: - Saved Look Card

struct SavedLookCard: View {
    let look: SavedLook
    let onFavorite: () -> Void
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(cornerRadius: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    coverArea
                    infoArea
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) {
                Label(L10n.Common.edit, systemImage: "pencil")
            }
            Button(action: onDuplicate) {
                Label(L10n.OccasionVaultUI.duplicate, systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(L10n.Common.delete, systemImage: "trash")
            }
        }
    }

    // MARK: - Cover area

    private var coverArea: some View {
        ZStack(alignment: .topTrailing) {
            // Background with occasion accent
            ZStack {
                Rectangle()
                    .fill(look.occasion.accentColor.opacity(0.09))
                    .frame(height: 160)

                VStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: look.occasion.icon)
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(look.occasion.accentColor.opacity(0.4))
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 18,
                    style: .continuous
                )
            )

            // Occasion icon badge (top right)
            Image(systemName: look.occasion.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(look.occasion.accentColor)
                .padding(6)
                .background(
                    Circle()
                        .fill(EcrinColor.background.opacity(0.7))
                )
                .padding(EcrinSpacing.sm)

            // Favorite button (top left)
            VStack {
                HStack {
                    Button {
                        withAnimation(EcrinAnimation.springSnap) {
                            onFavorite()
                        }
                    } label: {
                        Image(systemName: look.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: look.isFavorite ? .medium : .thin))
                            .foregroundStyle(look.isFavorite ? EcrinColor.gold : EcrinColor.textMuted)
                            .scaleEffect(look.isFavorite ? 1.15 : 1.0)
                            .animation(EcrinAnimation.springSnap, value: look.isFavorite)
                            .padding(7)
                            .background(
                                Circle()
                                    .fill(EcrinColor.background.opacity(0.65))
                            )
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(EcrinSpacing.sm)
        }
        .frame(height: 160)
    }

    // MARK: - Info area

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
            Text(look.name)
                .font(EcrinFont.cardTitle)
                .foregroundStyle(EcrinColor.textPrimary)
                .lineLimit(1)

            Text(look.createdAt.formatted(.relative(presentation: .named)))
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)

            if !look.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EcrinSpacing.xs) {
                        ForEach(look.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(look.occasion.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(look.occasion.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.md)
    }
}
