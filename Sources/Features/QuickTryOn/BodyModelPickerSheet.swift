import SwiftUI

// MARK: - BodyModelPickerSheet
// Sheet de sélection d'un mannequin de référence (ex : Visage 1, Main 2…)
// pour servir de "photo source" à l'essayage IA, à la place d'une photo perso.

struct BodyModelPickerSheet: View {

    /// Callback reçoit l'UIImage déjà téléchargée — pas besoin de re-télécharger.
    let onPick: (UIImage) -> Void
    /// Mode d'essayage en cours — permet d'adapter le filtre par défaut.
    var mode: QuickTryOnMode? = nil

    @ObservedObject private var service = BodyModelService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: String? = nil
    @State private var isDownloading = false

    /// Types "corps" prioritaires pour les modes vêtements.
    private var isClothingMode: Bool {
        guard let m = mode else { return false }
        switch m {
        case .topOnly, .bottomOnly, .topAndBottom, .fullOutfit, .shoesOnly, .shoesAndBottom:
            return true
        case .accessoryOnly, .jewelsOnly:
            return false
        }
    }

    /// Type de mannequin suggéré selon le mode — pre-filtre automatiquement
    private var suggestedType: String? {
        switch mode {
        case .topOnly, .topAndBottom, .fullOutfit: return "corps_entier"
        case .bottomOnly:                          return "corps_entier"
        case .shoesOnly, .shoesAndBottom:          return "foot"
        case .jewelsOnly:                          return "earrings"
        case .accessoryOnly:                       return "necklace"
        default:                                   return nil  // nil = Tous
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: EcrinSpacing.md),
        GridItem(.flexible(), spacing: EcrinSpacing.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                EcrinColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: EcrinSpacing.lg) {
                        header
                        typeFilter
                        if service.isLoading && service.globalModels.isEmpty {
                            ProgressView()
                                .tint(EcrinColor.gold)
                                .padding(.top, EcrinSpacing.xxl)
                        } else if filtered.isEmpty {
                            empty
                        } else {
                            grid
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.lg)
                    .padding(.bottom, EcrinSpacing.xxl)
                }
            }
            .navigationTitle("Choisir un mannequin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }
            .task {
                await service.fetchAll()
                // Applique le filtre par défaut selon le mode
                if selectedType == nil {
                    selectedType = suggestedType
                }
            }
            .overlay { if isDownloading { downloadOverlay } }
            .alert("Téléchargement échoué", isPresented: Binding(
                get: { downloadError != nil },
                set: { if !$0 { downloadError = nil } }
            )) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(downloadError ?? "")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MANNEQUINS DE RÉFÉRENCE")
                .font(EcrinFont.label)
                .kerning(3)
                .foregroundStyle(EcrinColor.gold)

            if isClothingMode {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.rectangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(EcrinColor.gold)
                    Text("Mode \(mode?.rawValue ?? "") — choisissez un mannequin corps entier")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold.opacity(0.85))
                }
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
                .background(EcrinColor.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text("Pas de photo ? Choisissez un mannequin pour votre essayage.")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, EcrinSpacing.md)
    }

    private var typeFilter: some View {
        let types = Array(Set(service.globalModels.map { $0.type })).sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.sm) {
                filterChip("Tous", selected: selectedType == nil) { selectedType = nil }
                ForEach(types, id: \.self) { type in
                    filterChip(
                        BodyModel(id: UUID(), name: "", type: type, imageURL: nil, userId: nil, createdAt: nil).typeLabel,
                        selected: selectedType == type
                    ) { selectedType = type }
                }
            }
        }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? EcrinColor.background : EcrinColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? EcrinColor.gold : EcrinColor.glassFill)
                )
                .overlay(
                    Capsule().strokeBorder(EcrinColor.glassStroke, lineWidth: selected ? 0 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: EcrinSpacing.md) {
            ForEach(filtered) { model in
                Button { pick(model) } label: {
                    BodyModelCard(model: model)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: EcrinSpacing.md) {
            Image(systemName: "person.crop.rectangle.badge.xmark")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text("Aucun mannequin disponible")
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textMuted)
            if let err = service.error {
                Text(err)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, EcrinSpacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private var downloadOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: EcrinSpacing.md) {
                ProgressView().tint(EcrinColor.gold)
                Text("Téléchargement…")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            .padding(EcrinSpacing.lg)
            .background(RoundedRectangle(cornerRadius: 16).fill(EcrinColor.glassFill))
        }
    }

    // MARK: - Helpers

    private var filtered: [BodyModel] {
        guard let type = selectedType else { return service.globalModels }
        return service.globalModels.filter { $0.type == type }
    }

    @State private var downloadError: String? = nil

    private func pick(_ model: BodyModel) {
        isDownloading = true
        downloadError = nil
        Task {
            defer { isDownloading = false }
            if let img = await service.downloadImage(for: model) {
                onPick(img)   // ← UIImage directe, pas de second téléchargement
                dismiss()
            } else {
                downloadError = "Impossible de télécharger ce mannequin. Vérifiez votre connexion."
            }
        }
    }
}

// MARK: - BodyModelCard

private struct BodyModelCard: View {
    let model: BodyModel

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            // Zone image — frame fixe + clip strict pour empêcher tout débordement
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(EcrinColor.glassFill)

                if let url = model.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().tint(EcrinColor.gold)
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: model.icon)
                                .font(.system(size: 30, weight: .thin))
                                .foregroundStyle(EcrinColor.textMuted)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: model.icon)
                        .font(.system(size: 30, weight: .thin))
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )

            // Zone texte — fixe sous l'image, jamais en overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .lineLimit(1)
                Text(model.typeLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(EcrinColor.gold.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Garantit que la cellule reste compacte et ne déborde pas sur la suivante
        .padding(.bottom, EcrinSpacing.xs)
    }
}
