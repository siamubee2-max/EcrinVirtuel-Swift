import SwiftUI

/// Feuille de commentaires d'un post — l'image d'essayage présentée est affichée
/// en tête pour que chaque commentaire soit clairement relié à CE bijou / cet essayage.
struct CommentsSheet: View {
    let post: CommunityPost
    @ObservedObject var vm: CommunityViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var samples: [PostComment] = []
    @FocusState private var inputFocused: Bool

    private var allComments: [PostComment] {
        (samples + (vm.addedComments[post.id] ?? []))
            .filter { !vm.hiddenCommentIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                        presentedImageHeader
                        Divider().overlay(EcrinColor.glassStroke)
                        if allComments.isEmpty {
                            Text("Soyez la première à commenter cet essayage.")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                                .padding(.top, EcrinSpacing.md)
                        } else {
                            ForEach(allComments) { comment in
                                commentRow(comment)
                            }
                        }
                    }
                    .padding(EcrinSpacing.md)
                }
                inputBar
            }
            .background(EcrinColor.background)
            .navigationTitle("Commentaires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(EcrinColor.gold)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if samples.isEmpty { samples = PostComment.samples(for: post) }
        }
    }

    // MARK: - Image présentée (l'essayage commenté)

    private var presentedImageHeader: some View {
        HStack(spacing: EcrinSpacing.md) {
            presentedImage
                .frame(width: 64, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 0.6)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.jewelry.name)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)
                Text(post.caption)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var presentedImage: some View {
        if let url = post.jewelry.imageURL {
            DownsampledAsyncImage(url: url, maxPixelSize: 300) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    ZStack { Color.black; ProgressView().tint(EcrinColor.gold) }
                }
            }
        } else if let ui = UIImage(data: post.tryOnImage) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                Color.black
                Image(systemName: "diamond.fill").foregroundStyle(EcrinColor.gold.opacity(0.6))
            }
        }
    }

    // MARK: - Ligne de commentaire

    private func commentRow(_ comment: PostComment) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(comment.authorName)
                    .font(EcrinFont.sans(13, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                Text(comment.createdAt.formatted(.relative(presentation: .named)))
                    .font(EcrinFont.label)
                    .foregroundStyle(EcrinColor.textMuted)
            }
            Text(comment.text)
                .font(EcrinFont.sans(14, weight: .regular))
                .foregroundStyle(EcrinColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Signalement de commentaire (App Store 1.2)
        .contextMenu {
            Button(role: .destructive) {
                vm.reportComment(comment)
            } label: {
                Label("Signaler ce commentaire", systemImage: "exclamationmark.triangle")
            }
        }
    }

    // MARK: - Barre de saisie

    private var inputBar: some View {
        HStack(spacing: EcrinSpacing.sm) {
            TextField("Ajouter un commentaire…", text: $draft, axis: .vertical)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
                .background(EcrinColor.surface, in: Capsule())

            Button {
                vm.addComment(to: post, text: draft)
                draft = ""
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? EcrinColor.textMuted : EcrinColor.gold)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(EcrinSpacing.md)
        .background(.ultraThinMaterial)
    }
}
