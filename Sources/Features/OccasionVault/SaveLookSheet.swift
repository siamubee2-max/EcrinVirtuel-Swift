import SwiftUI

// MARK: - Save Look Sheet

struct SaveLookSheet: View {
    let previewImageData: Data?
    let preselectedJewelry: [JewelryItem]
    let onSave: (SavedLook) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedOccasion: LookOccasion = .evening
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @State private var notes: String = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var tagFocused: Bool
    @FocusState private var notesFocused: Bool

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sheet handle
                Capsule()
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 4)
                    .padding(.top, EcrinSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.lg) {
                        sheetHeader
                        previewSection
                        nameSection
                        occasionSection
                        tagsSection
                        notesSection
                        saveButton
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }
        }
        .onAppear {
            name = autoSuggestName()
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: EcrinSpacing.xs) {
            Text("SAUVEGARDER CE LOOK")
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.gold)
                .padding(.top, EcrinSpacing.md)

            Text("Dans mon Dressing")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        if let data = previewImageData, let uiImage = UIImage(data: data) {
            ZStack {
                Color.black
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if !preselectedJewelry.isEmpty {
                        HStack(spacing: -8) {
                            ForEach(preselectedJewelry.prefix(3)) { item in
                                ZStack {
                                    Circle()
                                        .fill(EcrinColor.background.opacity(0.85))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14, weight: .thin))
                                        .foregroundStyle(EcrinColor.gold)
                                }
                            }
                        }
                        .padding(.leading, EcrinSpacing.md)
                        .padding(.bottom, EcrinSpacing.md)
                    }
                }
        }
    }

    // MARK: - Name field

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("NOM DU LOOK")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            GlassCard(cornerRadius: 16) {
                TextField("Ex. Soirée Gala · Novembre", text: $name)
                    .font(EcrinFont.body)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .focused($nameFocused)
                    .padding(EcrinSpacing.md)
            }
        }
    }

    // MARK: - Occasion picker (3-column grid of chips)

    private var occasionSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("OCCASION")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            let columns = Array(repeating: GridItem(.flexible(), spacing: EcrinSpacing.sm), count: 3)
            LazyVGrid(columns: columns, spacing: EcrinSpacing.sm) {
                ForEach(LookOccasion.allCases, id: \.self) { occ in
                    OccasionChip(
                        occasion: occ,
                        isSelected: selectedOccasion == occ
                    ) {
                        withAnimation(EcrinAnimation.springSnap) {
                            selectedOccasion = occ
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tags (dynamic chips)

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("TAGS")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            GlassCard(cornerRadius: 16) {
                HStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: "tag")
                        .font(.system(size: 14, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.6))

                    TextField("Élégant, Or, Soirée…", text: $tagInput)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .focused($tagFocused)
                        .submitLabel(.done)
                        .onSubmit { addTag() }
                }
                .padding(EcrinSpacing.md)
            }

            if !tags.isEmpty {
                TagChipsRow(tags: tags) { tag in
                    withAnimation(EcrinAnimation.springSnap) {
                        tags.removeAll { $0 == tag }
                    }
                }
            }
        }
    }

    // MARK: - Notes (TextEditor glass 3 lines)

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("NOTES")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            GlassCard(cornerRadius: 16) {
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Ajoutez vos notes sur ce look…")
                            .font(EcrinFont.body)
                            .foregroundStyle(EcrinColor.textMuted)
                            .padding(EcrinSpacing.md)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $notes)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($notesFocused)
                        .frame(minHeight: 72, maxHeight: 96)
                        .padding(EcrinSpacing.sm)
                }
            }
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        GoldButton(title: "Enregistrer dans mon Dressing") {
            let finalName = name.isEmpty ? autoSuggestName() : name
            let look = SavedLook(
                name: finalName,
                occasion: selectedOccasion,
                jewelryIds: preselectedJewelry.map(\.id),
                notes: notes,
                tags: tags
            )
            onSave(look)
            dismiss()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, EcrinSpacing.sm)
    }

    // MARK: - Helpers

    private func autoSuggestName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        let dateStr = formatter.string(from: .now)
        return "\(selectedOccasion.rawValue) · \(dateStr)"
    }

    private func addTag() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else {
            tagInput = ""
            return
        }
        withAnimation(EcrinAnimation.springSnap) {
            tags.append(tag)
        }
        tagInput = ""
    }
}

// MARK: - Occasion Chip

private struct OccasionChip: View {
    let occasion: LookOccasion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(cornerRadius: 14) {
                VStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: occasion.icon)
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(isSelected ? occasion.accentColor : EcrinColor.textMuted)
                        .frame(width: 40, height: 40)

                    Text(occasion.rawValue)
                        .font(EcrinFont.caption)
                        .foregroundStyle(isSelected ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EcrinSpacing.md)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(occasion.accentColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Chips Row

private struct TagChipsRow: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textPrimary)
                        Button(action: { onRemove(tag) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, EcrinSpacing.sm)
                    .background(EcrinColor.glassFill)
                    .overlay {
                        Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    }
                    .clipShape(Capsule())
                }
            }
        }
    }
}
