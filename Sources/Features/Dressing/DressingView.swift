import SwiftUI
import UIKit

// MARK: - DressingView — galerie persistante de tous les essayages générés
// Les créations sont stockées sur disque (SessionCreationsStore) : on les retrouve
// toujours ici, même après avoir fermé l'écran de résultat ou redémarré l'app.

struct DressingView: View {
    @State private var creations: [SavedCreation] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var fullScreen: SavedCreation?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                if creations.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(creations) { creation in
                                cell(creation)
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.xs)
                        .padding(.bottom, 100)
                    }
                }
            }

            if let creation = fullScreen {
                fullScreenOverlay(creation)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .task { reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MON")
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.gold)
            HStack(alignment: .firstTextBaseline) {
                Text("Dressing")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                if !creations.isEmpty {
                    Text("\(creations.count)")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, 8)
        .padding(.bottom, EcrinSpacing.md)
    }

    private func cell(_ creation: SavedCreation) -> some View {
        ZStack {
            Color.black
            if let img = thumbnails[creation.id] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(EcrinColor.gold)
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { withAnimation(EcrinAnimation.glassReveal) { fullScreen = creation } }
        .contextMenu {
            Button {
                if let img = SessionCreationsStore.loadImage(creation, maxPixelSize: 2400) {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                }
            } label: { Label("Enregistrer dans Photos", systemImage: "square.and.arrow.down") }
            Button(role: .destructive) { remove(creation) } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .task(id: creation.id) {
            if thumbnails[creation.id] == nil {
                let img = await Task.detached(priority: .userInitiated) {
                    await SessionCreationsStore.loadImage(creation, maxPixelSize: 600)
                }.value
                if let img { thumbnails[creation.id] = img }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: EcrinSpacing.md) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text("Vos essayages apparaîtront ici")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
            Text("Chaque photo générée est sauvegardée automatiquement.")
                .font(.system(size: 11))
                .foregroundStyle(EcrinColor.textMuted.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, EcrinSpacing.xl)
    }

    private func fullScreenOverlay(_ creation: SavedCreation) -> some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
                .onTapGesture { withAnimation(EcrinAnimation.glassReveal) { fullScreen = nil } }

            if let img = thumbnails[creation.id] {
                Image(uiImage: img).resizable().scaledToFit().padding(EcrinSpacing.md)
            }

            VStack {
                HStack {
                    Button { withAnimation(EcrinAnimation.glassReveal) { fullScreen = nil } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(EcrinSpacing.lg)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Spacer()
                HStack(spacing: EcrinSpacing.xl) {
                    Button {
                        if let img = SessionCreationsStore.loadImage(creation, maxPixelSize: 2400) {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        }
                    } label: { overlayAction(icon: "square.and.arrow.down", label: "Enregistrer") }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        remove(creation); fullScreen = nil
                    } label: { overlayAction(icon: "trash", label: "Supprimer") }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, EcrinSpacing.xl)
            }
        }
    }

    private func overlayAction(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.15), in: Circle())
            Text(label).font(EcrinFont.caption).foregroundStyle(.white.opacity(0.75))
        }
    }

    private func reload() {
        creations = SessionCreationsStore.persistedCreations()
    }

    private func remove(_ creation: SavedCreation) {
        SessionCreationsStore.delete(creation)
        thumbnails[creation.id] = nil
        withAnimation { creations.removeAll { $0.id == creation.id } }
    }
}
