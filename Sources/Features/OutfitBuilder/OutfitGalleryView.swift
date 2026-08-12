import SwiftUI

// MARK: - OutfitGalleryView

struct OutfitGalleryView: View {
    @ObservedObject var vm: OutfitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var filterOccasion: OutfitOccasion?
    @State private var showFavoritesOnly = false
    @State private var selectedOutfit: Outfit?

    private let columns = [
        GridItem(.flexible(), spacing: EcrinSpacing.sm),
        GridItem(.flexible(), spacing: EcrinSpacing.sm)
    ]

    private var displayedOutfits: [Outfit] {
        vm.savedOutfits
            .filter { outfit in
                if showFavoritesOnly && !outfit.isFavorite { return false }
                if let occasion = filterOccasion, outfit.occasion != occasion { return false }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterBar
                    Divider().background(EcrinColor.glassStroke)

                    if displayedOutfits.isEmpty {
                        emptyState
                    } else {
                        gallery
                    }
                }
            }
            .navigationTitle(L10n.OutfitBuilderUI.myOutfits)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EcrinColor.surface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold)
                }
            }
        }
        .sheet(item: $selectedOutfit) { outfit in
            if let imgData = outfit.generatedImageData,
               let uiImage = UIImage(data: imgData) {
                OutfitResultView(image: uiImage, outfit: outfit, vm: vm)
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                // Favoris toggle
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        showFavoritesOnly.toggle()
                    }
                } label: {
                    Label("Favoris", systemImage: showFavoritesOnly ? "heart.fill" : "heart")
                        .font(EcrinFont.caption)
                        .foregroundStyle(showFavoritesOnly ? EcrinColor.gold : EcrinColor.textSecondary)
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            showFavoritesOnly ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill,
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(
                            showFavoritesOnly ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke
                        ))
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
                    .background(EcrinColor.glassStroke)

                // Filtres occasions
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        filterOccasion = nil
                    }
                } label: {
                    Text("Toutes")
                        .font(EcrinFont.caption)
                        .foregroundStyle(filterOccasion == nil ? EcrinColor.gold : EcrinColor.textSecondary)
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            filterOccasion == nil ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill,
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(
                            filterOccasion == nil ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke
                        ))
                }
                .buttonStyle(.plain)

                ForEach(OutfitOccasion.allCases, id: \.self) { occasion in
                    Button {
                        withAnimation(EcrinAnimation.springSnap) {
                            filterOccasion = filterOccasion == occasion ? nil : occasion
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: occasion.icon)
                                .font(.system(size: 10))
                            Text(occasion.rawValue)
                                .font(EcrinFont.caption)
                        }
                        .foregroundStyle(filterOccasion == occasion ? EcrinColor.gold : EcrinColor.textSecondary)
                        .padding(.horizontal, EcrinSpacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            filterOccasion == occasion ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill,
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(
                            filterOccasion == occasion ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
        }
        .background(EcrinColor.surface)
    }

    // MARK: - Gallery grid

    private var gallery: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: EcrinSpacing.sm) {
                ForEach(displayedOutfits) { outfit in
                    OutfitGalleryCard(outfit: outfit) {
                        selectedOutfit = outfit
                    } onFavorite: {
                        vm.toggleFavorite(outfitId: outfit.id)
                    } onDelete: {
                        vm.deleteOutfit(outfitId: outfit.id)
                    }
                }
            }
            .padding(EcrinSpacing.sm)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Spacer()
            Image(systemName: "tshirt.fill")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)

            VStack(spacing: EcrinSpacing.sm) {
                Text(L10n.OutfitBuilderUI.noSavedOutfits)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.ivory)
                Text(L10n.OutfitBuilderUI.createFirstLook)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GoldButton(title: L10n.OutfitBuilderUI.createALook) { dismiss() }
            Spacer()
        }
        .padding(EcrinSpacing.xl)
    }
}

// MARK: - OutfitGalleryCard

struct OutfitGalleryCard: View {
    let outfit: Outfit
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Thumbnail ou placeholder
                imageArea
                    .frame(height: 180)
                    .clipped()

                // Metadata
                infoArea
            }
        }
        .buttonStyle(.plain)
        .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button {
                onFavorite()
            } label: {
                Label(
                    outfit.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: outfit.isFavorite ? "heart.slash" : "heart"
                )
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(L10n.Common.delete, systemImage: "trash")
            }
        }
        .confirmationDialog(L10n.OutfitBuilderUI.deleteOutfitConfirm, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.Common.delete, role: .destructive) { onDelete() }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }

    // MARK: - Image area

    private var imageArea: some View {
        ZStack(alignment: .topTrailing) {
            if let imgData = outfit.generatedImageData,
               let uiImage = UIImage(data: imgData) {
                // Fond noir + scaledToFit pour voir le look généré ENTIER
                // (essayages IA en portrait — éviter le crop tête/pieds).
                ZStack {
                    Color.black
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                // Placeholder silhouette mini
                ZStack {
                    EcrinColor.glassFill
                    HumanSilhouette()
                        .fill(EcrinColor.ivory.opacity(0.08))
                        .overlay(HumanSilhouette().stroke(EcrinColor.ivory.opacity(0.15), lineWidth: 0.6))
                        .padding(EcrinSpacing.lg)
                }
            }

            // Favoris
            Button(action: onFavorite) {
                Image(systemName: outfit.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(outfit.isFavorite ? .red : EcrinColor.ivory)
                    .padding(8)
                    .background(Circle().fill(EcrinColor.glassFill))
            }
            .padding(8)

            // Completion badge
            VStack {
                Spacer()
                HStack {
                    completionBar
                        .padding(8)
                    Spacer()
                }
            }
        }
    }

    private var completionBar: some View {
        Text("\(outfit.completionScore)%")
            .font(EcrinFont.label)
            .kerning(0.5)
            .foregroundStyle(outfit.completionScore >= 70 ? EcrinColor.gold : EcrinColor.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(EcrinColor.glassFill, in: Capsule())
            .overlay(Capsule().strokeBorder(EcrinColor.glassStroke))
    }

    // MARK: - Info area

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(outfit.name)
                .font(EcrinFont.cardTitle)
                .foregroundStyle(EcrinColor.ivory)
                .lineLimit(1)

            HStack(spacing: 5) {
                Image(systemName: outfit.occasion.icon)
                    .font(.system(size: 10))
                Text(outfit.occasion.rawValue)
                    .font(EcrinFont.caption)

                Spacer()

                Text(outfit.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(EcrinColor.textSecondary)

            // Slots pills
            if !outfit.slots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(outfit.slots.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { slot in
                            Image(systemName: slot.icon)
                                .font(.system(size: 9))
                                .foregroundStyle(EcrinColor.gold.opacity(0.7))
                                .padding(4)
                                .background(EcrinColor.gold.opacity(0.1), in: Circle())
                        }
                    }
                }
            }
        }
        .padding(EcrinSpacing.sm)
    }
}
