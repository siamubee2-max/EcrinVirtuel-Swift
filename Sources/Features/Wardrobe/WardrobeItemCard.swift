import SwiftUI

// MARK: - WardrobeItemCard

struct WardrobeItemCard: View {
    let item: FashionItem
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    @State private var pressed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background / Photo
            photoBackground

            // Bottom gradient overlay
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Text info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)
                Text(item.category.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .kerning(0.5)
            }
            .padding(EcrinSpacing.sm)

            // Favorite badge
            if item.isFavorite {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(EcrinColor.gold)
                            .padding(6)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(6)
                    }
                    Spacer()
                }
            }

            // Source badge
            if item.source == .catalog {
                VStack {
                    HStack {
                        Text(L10n.WardrobeUI.shopCaps)
                            .font(.system(size: 7, weight: .semibold))
                            .kerning(0.5)
                            .foregroundStyle(EcrinColor.background)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(EcrinColor.gold)
                            .clipShape(Capsule())
                            .padding(6)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        }
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(EcrinAnimation.springSnap, value: pressed)
        .animation(EcrinAnimation.springSnap, value: isSelected)
        .accessibilityIdentifier("wardrobe.item")
        .onTapGesture { onTap?() }
        .onLongPressGesture(minimumDuration: 0.4,
                            pressing: { pressing in
                                withAnimation(EcrinAnimation.springSnap) { self.pressed = pressing }
                            },
                            perform: { onLongPress?() })
    }

    @ViewBuilder
    private var photoBackground: some View {
        // scaledToFit + fond noir pour préserver l'image entière (essayages IA en portrait)
        // même dans la vignette carrée. Les barres noires haut/bas permettent de reconnaître
        // l'item d'un coup d'œil sans crop sauvage de la tête ou des pieds.
        ZStack {
            Color.black
            if let data = item.userPhotoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if let url = item.imageURL {
                DownsampledAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        ZStack {
            // Fond visible : couleur du groupe à faible opacité + surface sombre
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            item.category.group.color.opacity(0.18),
                            EcrinColor.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: EcrinSpacing.sm) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 32, weight: .thin))
                    .foregroundStyle(item.category.group.color.opacity(0.9))
                if let brand = item.brand {
                    Text(brand)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - WardrobeItemContextMenu

struct WardrobeItemContextMenu: View {
    let item: FashionItem
    var onTryOn: () -> Void
    var onCompleteLook: (() -> Void)? = nil
    var onEdit: () -> Void
    var onToggleFavorite: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Group {
            Button {
                onTryOn()
            } label: {
                Label(L10n.LookOfDay.tryButton, systemImage: "sparkles")
            }

            // Complète ce look — visible pour vêtements et chaussures
            if let completeLook = onCompleteLook,
               item.category.group == .clothing || item.category.group == .shoes {
                Button {
                    completeLook()
                } label: {
                    Label(L10n.WardrobeUI.completesThisLook, systemImage: "person.crop.rectangle.stack.fill")
                }
            }

            Button {
                onEdit()
            } label: {
                Label(L10n.Common.edit, systemImage: "pencil")
            }

            Button {
                onToggleFavorite()
            } label: {
                Label(
                    item.isFavorite ? L10n.Boutique.removeFromFavorites : L10n.Boutique.addToFavorites,
                    systemImage: item.isFavorite ? "heart.slash" : "heart.fill"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.Common.delete, systemImage: "trash")
            }
        }
    }
}
