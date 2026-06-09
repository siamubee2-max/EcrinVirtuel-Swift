import SwiftUI
import PhotosUI

// MARK: - AddWardrobeItemSheet

struct AddWardrobeItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form = AddItemForm()

    var onAdd: (FashionItem) -> Void

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(EcrinColor.textMuted)
                        .frame(width: 36, height: 4)
                        .padding(.top, EcrinSpacing.md)

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOUVELLE PIÈCE")
                                .font(EcrinFont.label)
                                .kerning(3)
                                .foregroundStyle(EcrinColor.gold)
                            Text("Garde-robe")
                                .font(EcrinFont.sectionHead)
                                .foregroundStyle(EcrinColor.textPrimary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(EcrinColor.textSecondary)
                                .padding(10)
                                .background(EcrinColor.glassFill)
                                .clipShape(Circle())
                        }
                    }

                    // Photo picker
                    PhotoPickerSection(
                        selectedItem: $form.photoItem,
                        previewImage: form.previewImage
                    )
                    .onChange(of: form.photoItem) { _, item in
                        Task { await form.loadPhoto(from: item) }
                    }

                    // Category selector
                    CategorySelectorSection(
                        selectedGroup: $form.selectedGroup,
                        selectedCategory: $form.selectedCategory
                    )

                    // Details fields
                    DetailsSection(form: form)

                    // Boutique toggle
                    BoutiqueToggleRow(isEnabled: $form.isFromBoutique)

                    // CTA
                    GoldButton(title: "Ajouter à ma garde-robe") {
                        let item = form.buildItem()
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(!form.isValid)
                    .opacity(form.isValid ? 1 : 0.4)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
                .padding(.horizontal, EcrinSpacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Photo Picker Section

private struct PhotoPickerSection: View {
    @Binding var selectedItem: PhotosPickerItem?
    let previewImage: UIImage?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                previewImage != nil ? EcrinColor.gold.opacity(0.4) : EcrinColor.glassStroke,
                                style: StrokeStyle(lineWidth: 1, dash: previewImage != nil ? [] : [6])
                            )
                    }
                    .frame(height: 220)

                if let img = previewImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(EcrinColor.gold)
                                .padding(12)
                        }
                } else {
                    VStack(spacing: EcrinSpacing.md) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(EcrinColor.textMuted)
                        Text("Ajouter une photo")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                            .kerning(1)
                        Text("Depuis votre bibliothèque")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted.opacity(0.6))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Selector Section

private struct CategorySelectorSection: View {
    @Binding var selectedGroup: FashionGroup
    @Binding var selectedCategory: FashionCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.md) {
            Text("CATÉGORIE")
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.textMuted)

            // Group tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(FashionGroup.allCases, id: \.self) { group in
                        GroupChip(group: group, isSelected: selectedGroup == group) {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedGroup = group
                                selectedCategory = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Sub-categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EcrinSpacing.sm) {
                    ForEach(selectedGroup.categories, id: \.self) { cat in
                        CategoryChip(
                            category: cat,
                            isSelected: selectedCategory == cat
                        ) {
                            withAnimation(EcrinAnimation.springSnap) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct GroupChip: View {
    let group: FashionGroup
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: group.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(group.rawValue)
                    .font(EcrinFont.cta)
                    .kerning(0.5)
            }
            .foregroundStyle(isSelected ? EcrinColor.background : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm)
            .background(isSelected ? EcrinColor.gold : EcrinColor.glassFill)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryChip: View {
    let category: FashionCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 10))
                Text(category.rawValue)
                    .font(EcrinFont.caption)
            }
            .foregroundStyle(isSelected ? category.group.color : EcrinColor.textSecondary)
            .padding(.horizontal, EcrinSpacing.sm)
            .padding(.vertical, 6)
            .background(isSelected ? category.group.color.opacity(0.15) : EcrinColor.glassFill)
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? category.group.color.opacity(0.4) : EcrinColor.glassStroke,
                    lineWidth: 0.5
                )
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}

// MARK: - Details Section

private struct DetailsSection: View {
    @ObservedObject var form: AddItemForm

    var body: some View {
        VStack(spacing: EcrinSpacing.md) {
            FormField(label: "Nom", placeholder: "Ex: Robe midi noire", text: $form.name)
            FormField(label: "Marque", placeholder: "Optionnel", text: $form.brand)

            HStack(spacing: EcrinSpacing.md) {
                FormField(label: "Couleur", placeholder: "Noir", text: $form.color)
                FormField(label: "Matière", placeholder: "Soie", text: $form.material)
            }

            HStack(spacing: EcrinSpacing.md) {
                FormField(label: "Prix (€)", placeholder: "0", text: $form.priceText)
                    .keyboardType(.decimalPad)
                FormField(label: "Lien d'achat", placeholder: "https://...", text: $form.purchaseURL)
                    .keyboardType(.URL)
            }
        }
    }
}

private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(EcrinFont.label)
                .kerning(1.5)
                .foregroundStyle(EcrinColor.textMuted)

            TextField(placeholder, text: $text)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textPrimary)
                .padding(EcrinSpacing.md)
                .background(EcrinColor.glassFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Boutique Toggle

private struct BoutiqueToggleRow: View {
    @Binding var isEnabled: Bool

    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: EcrinSpacing.md) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18, weight: .thin))
                    .foregroundStyle(EcrinColor.gold)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Disponible en boutique partenaire")
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text("Permet l'achat direct depuis L'Écrin")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .tint(EcrinColor.gold)
                    .labelsHidden()
            }
            .padding(EcrinSpacing.md)
        }
    }
}

// MARK: - Form Model

@MainActor
final class AddItemForm: ObservableObject {
    @Published var photoItem: PhotosPickerItem?
    @Published var previewImage: UIImage?
    @Published var photoData: Data?

    @Published var selectedGroup: FashionGroup = .clothing
    @Published var selectedCategory: FashionCategory?

    @Published var name: String = ""
    @Published var brand: String = ""
    @Published var color: String = ""
    @Published var material: String = ""
    @Published var priceText: String = ""
    @Published var purchaseURL: String = ""
    @Published var isFromBoutique: Bool = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategory != nil
    }

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        previewImage = image
        photoData = data
    }

    func buildItem() -> FashionItem {
        let cat = selectedCategory ?? selectedGroup.categories.first ?? .top
        return FashionItem(
            name: name.trimmingCharacters(in: .whitespaces),
            category: cat,
            brand: brand.isEmpty ? nil : brand,
            color: color.isEmpty ? nil : color,
            material: material.isEmpty ? nil : material,
            userPhotoData: photoData,
            source: isFromBoutique ? .catalog : .userPhoto,
            price: Double(priceText),
            purchaseURL: purchaseURL.isEmpty ? nil : purchaseURL
        )
    }
}
