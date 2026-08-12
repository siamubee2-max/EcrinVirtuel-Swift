import SwiftUI

// MARK: - Compose Post View
/// Composeur de publication communauté : un essayage de la session (optionnel),
/// le bijou porté, une légende → `createCommunityPost`.
struct ComposePostView: View {
    @ObservedObject var vm: CommunityViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var caption = ""
    @State private var selectedImageIndex: Int?
    @State private var selectedJewelry: JewelryItem?
    @State private var jewelryCatalog: [JewelryItem] = []
    @State private var isPublishing = false
    @State private var publishError: String?

    private var sessionImages: [UIImage] { SessionCreationsStore.images }
    private var canPublish: Bool {
        selectedJewelry != nil &&
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isPublishing
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: EcrinSpacing.lg) {
                        if !sessionImages.isEmpty {
                            sectionTitle("Votre essayage")
                            imageStrip
                        }

                        sectionTitle("Bijou porté")
                        jewelryStrip

                        sectionTitle("Légende")
                        GlassCard(cornerRadius: 14) {
                            TextField(
                                "",
                                text: $caption,
                                prompt: Text(L10n.CommunityUI.tellYourLookPlaceholder).foregroundStyle(EcrinColor.textMuted),
                                axis: .vertical
                            )
                            .foregroundStyle(EcrinColor.textPrimary)
                            .lineLimit(3...6)
                            .padding(EcrinSpacing.md)
                        }

                        if let publishError {
                            Text(publishError)
                                .font(EcrinFont.caption)
                                .foregroundStyle(.red.opacity(0.85))
                        }

                        GoldButton(title: isPublishing ? "Publication…" : "Publier") {
                            Task { await publish() }
                        }
                        .disabled(!canPublish)
                        .opacity(canPublish ? 1 : 0.5)
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.vertical, EcrinSpacing.lg)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if let raw = try? await SupabaseService.shared.fetchJewelryCatalog(), !raw.isEmpty {
                jewelryCatalog = raw.map(\.asJewelryItem)
            } else {
                jewelryCatalog = JewelryItem.samples
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Annuler") { dismiss() }
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
            Spacer()
            Text(L10n.CommunityUI.shareALook)
                .font(EcrinFont.cardTitle)
                .foregroundStyle(EcrinColor.textPrimary)
            Spacer()
            // Équilibre visuel avec le bouton Annuler
            Text("Annuler").font(EcrinFont.caption).hidden()
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(EcrinFont.label)
            .kerning(1.5)
            .textCase(.uppercase)
            .foregroundStyle(EcrinColor.textSecondary)
    }

    private var imageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(Array(sessionImages.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    selectedImageIndex == index ? EcrinColor.gold : EcrinColor.glassStroke,
                                    lineWidth: selectedImageIndex == index ? 2 : 0.5
                                )
                        }
                        .onTapGesture {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedImageIndex = selectedImageIndex == index ? nil : index
                            }
                        }
                }
            }
        }
    }

    private var jewelryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(jewelryCatalog) { jewelry in
                    let isSelected = selectedJewelry?.id == jewelry.id
                    VStack(spacing: 6) {
                        Image(systemName: jewelry.icon)
                            .font(.system(size: 20, weight: .thin))
                            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.gold)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle().fill(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
                            )
                        Text(jewelry.name)
                            .font(EcrinFont.label)
                            .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                            .lineLimit(1)
                            .frame(width: 70)
                    }
                    .onTapGesture {
                        withAnimation(EcrinAnimation.springSnap) { selectedJewelry = jewelry }
                    }
                }
            }
        }
    }

    private func publish() async {
        guard let jewelry = selectedJewelry, let author = appState.currentUser else {
            publishError = "Connectez-vous pour publier."
            return
        }
        isPublishing = true
        publishError = nil
        defer { isPublishing = false }

        let image = selectedImageIndex.flatMap { sessionImages.indices.contains($0) ? sessionImages[$0] : nil }
        let ok = await vm.createPost(
            jewelry: jewelry,
            image: image,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author
        )
        if ok {
            dismiss()
        } else {
            publishError = "Publication impossible. Vérifiez votre connexion et réessayez."
        }
    }
}
