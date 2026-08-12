import SwiftUI

// MARK: - Look Detail View

struct LookDetailView: View {
    @ObservedObject var viewModel: OccasionVaultViewModel
    let look: SavedLook

    @State private var currentLook: SavedLook
    @State private var editingNotes = false
    @State private var notesText = ""
    @State private var tagInput = ""
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: OccasionVaultViewModel, look: SavedLook) {
        self.viewModel = viewModel
        self.look = look
        _currentLook = State(initialValue: look)
        _notesText = State(initialValue: look.notes)
    }

    // Resolve jewelry from IDs against sample catalogue
    private var resolvedJewelry: [JewelryItem] {
        let catalogue = JewelryItem.samples
        return currentLook.jewelryIds.compactMap { id in
            catalogue.first { $0.id == id }
        }
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    occasionCover
                    infoHeader
                    jewelrySection
                    notesSection
                    tagsSection
                    actionButtons
                }
                .padding(.bottom, EcrinSpacing.xxl)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .thin))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                    .padding(.top, EcrinSpacing.lg)
                    .padding(.trailing, EcrinSpacing.lg)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivitySheet(items: [buildShareText()])
        }
        .confirmationDialog(
            L10n.OccasionVaultUI.deleteLookConfirm,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                viewModel.deleteLook(currentLook)
                dismiss()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        }
    }

    // MARK: - Occasion Cover

    private var occasionCover: some View {
        ZStack {
            Rectangle()
                .fill(currentLook.occasion.accentColor.opacity(0.09))
                .frame(height: 220)

            VStack(spacing: EcrinSpacing.md) {
                Image(systemName: currentLook.occasion.icon)
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(currentLook.occasion.accentColor.opacity(0.55))
                Text(currentLook.occasion.rawValue)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(currentLook.occasion.accentColor)
            }
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                Text(currentLook.name)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .padding(.leading, EcrinSpacing.lg)

                Text(currentLook.createdAt.formatted(date: .long, time: .omitted))
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.leading, EcrinSpacing.lg)
            }

            Spacer()

            Button {
                withAnimation(EcrinAnimation.springSnap) {
                    viewModel.toggleFavorite(currentLook)
                    currentLook = SavedLook(
                        id: currentLook.id,
                        name: currentLook.name,
                        occasion: currentLook.occasion,
                        jewelryIds: currentLook.jewelryIds,
                        notes: currentLook.notes,
                        isFavorite: !currentLook.isFavorite,
                        tags: currentLook.tags,
                        createdAt: currentLook.createdAt
                    )
                }
            } label: {
                Image(systemName: currentLook.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .thin))
                    .foregroundStyle(currentLook.isFavorite ? EcrinColor.gold : EcrinColor.textMuted)
                    .scaleEffect(currentLook.isFavorite ? 1.1 : 1.0)
                    .animation(EcrinAnimation.springSnap, value: currentLook.isFavorite)
            }
            .padding(.trailing, EcrinSpacing.lg)
        }
    }

    // MARK: - Jewelry Section

    @ViewBuilder
    private var jewelrySection: some View {
        if !resolvedJewelry.isEmpty {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                Text(L10n.OccasionVaultUI.lookJewelsLabel)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(.horizontal, EcrinSpacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EcrinSpacing.md) {
                        ForEach(resolvedJewelry) { item in
                            JewelryMiniCard(item: item)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            HStack {
                Text(L10n.OccasionVaultUI.notesLabel)
                    .font(EcrinFont.label)
                    .kerning(2)
                    .foregroundStyle(EcrinColor.textMuted)
                Spacer()
                Button {
                    editingNotes.toggle()
                    if !editingNotes {
                        viewModel.updateNotes(notesText, for: currentLook)
                        currentLook = SavedLook(
                            id: currentLook.id,
                            name: currentLook.name,
                            occasion: currentLook.occasion,
                            jewelryIds: currentLook.jewelryIds,
                            notes: notesText,
                            isFavorite: currentLook.isFavorite,
                            tags: currentLook.tags,
                            createdAt: currentLook.createdAt
                        )
                    }
                } label: {
                    Text(editingNotes ? L10n.Common.save : L10n.Common.edit)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold)
                }
            }
            .padding(.horizontal, EcrinSpacing.lg)

            GlassCard(cornerRadius: 16) {
                Group {
                    if editingNotes {
                        TextEditor(text: $notesText)
                            .font(EcrinFont.body)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                    } else {
                        Text(currentLook.notes.isEmpty ? "Ajouter des notes…" : currentLook.notes)
                            .font(EcrinFont.body)
                            .foregroundStyle(
                                currentLook.notes.isEmpty ? EcrinColor.textMuted : EcrinColor.textPrimary
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 40)
                    }
                }
                .padding(EcrinSpacing.md)
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text(L10n.OccasionVaultUI.tagsLabel)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)
                .padding(.horizontal, EcrinSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(currentLook.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textPrimary)
                            Button(action: {
                                var updatedTags = currentLook.tags
                                updatedTags.removeAll { $0 == tag }
                                viewModel.updateTags(updatedTags, for: currentLook)
                                currentLook = SavedLook(
                                    id: currentLook.id,
                                    name: currentLook.name,
                                    occasion: currentLook.occasion,
                                    jewelryIds: currentLook.jewelryIds,
                                    notes: currentLook.notes,
                                    isFavorite: currentLook.isFavorite,
                                    tags: updatedTags,
                                    createdAt: currentLook.createdAt
                                )
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(EcrinColor.textMuted)
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.vertical, EcrinSpacing.sm)
                        .background(EcrinColor.glassFill)
                        .overlay { Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5) }
                        .clipShape(Capsule())
                    }

                    // Inline add tag
                    GlassCard(cornerRadius: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(EcrinColor.gold.opacity(0.6))
                            TextField(L10n.OccasionVaultUI.tagPlaceholder, text: $tagInput)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textPrimary)
                                .frame(width: 60)
                                .submitLabel(.done)
                                .onSubmit { addTag() }
                        }
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.vertical, EcrinSpacing.sm)
                    }
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: EcrinSpacing.md) {
            IconActionButton(icon: "square.and.arrow.up", label: L10n.Common.share) {
                showShareSheet = true
            }
            IconActionButton(icon: "doc.on.doc", label: "Dupliquer") {
                viewModel.duplicateLook(currentLook)
                dismiss()
            }
            IconActionButton(icon: "arrow.counterclockwise", label: "Ré-essayer") {
                // Naviguer vers TryOnView avec les bijoux pré-chargés
            }
            IconActionButton(icon: "trash", label: L10n.Common.delete, isDestructive: true) {
                showDeleteConfirm = true
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    // MARK: - Helpers

    private func buildShareText() -> String {
        let summary = resolvedJewelry.prefix(3).map(\.name).joined(separator: ", ")
        return "Mon look \"\(currentLook.name)\" sur L'Écrin Virtuel · \(summary)"
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !currentLook.tags.contains(tag) else {
            tagInput = ""
            return
        }
        var updatedTags = currentLook.tags
        updatedTags.append(tag)
        viewModel.updateTags(updatedTags, for: currentLook)
        currentLook = SavedLook(
            id: currentLook.id,
            name: currentLook.name,
            occasion: currentLook.occasion,
            jewelryIds: currentLook.jewelryIds,
            notes: currentLook.notes,
            isFavorite: currentLook.isFavorite,
            tags: updatedTags,
            createdAt: currentLook.createdAt
        )
        tagInput = ""
    }
}

// MARK: - Jewelry Mini Card

private struct JewelryMiniCard: View {
    let item: JewelryItem

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(spacing: EcrinSpacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 24, weight: .thin))
                    .foregroundStyle(EcrinColor.gold)
                    .frame(width: 52, height: 52)

                Text(item.name)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)

                Text(item.category.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .kerning(1)
                    .foregroundStyle(EcrinColor.textMuted)
                    .textCase(.uppercase)
            }
            .frame(width: 80)
            .padding(.vertical, EcrinSpacing.md)
        }
    }
}

// MARK: - Icon Action Button

private struct IconActionButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(cornerRadius: 14) {
                VStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(isDestructive ? Color.red.opacity(0.7) : EcrinColor.gold.opacity(0.8))
                        .frame(height: 28)
                    Text(label)
                        .font(EcrinFont.caption)
                        .foregroundStyle(isDestructive ? Color.red.opacity(0.6) : EcrinColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EcrinSpacing.md)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UIActivity wrapper

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
