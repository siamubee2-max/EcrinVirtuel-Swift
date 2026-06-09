import SwiftUI
import PhotosUI

// MARK: - JewelryDetectionView

/// Allows the user to pick or shoot a jewelry photo, runs Vision detection,
/// and proposes adding the detected piece to their wardrobe.
struct JewelryDetectionView: View {

    @Environment(AppState.self) private var appState
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var detectionResults: [JewelryDetectionResult] = []
    @State private var isAnalysing = false
    @State private var pickerSource: PhotoSource = .photoLibrary
    @State private var showAddSheet = false
    @State private var addedSuccessfully = false
    @State private var chosenResult: JewelryDetectionResult?

    enum PhotoSource { case photoLibrary, camera }

    var body: some View {
        ScrollView {
            VStack(spacing: EcrinSpacing.lg) {
                headerSection
                imagePicker
                if let image = selectedImage {
                    selectedImagePreview(image)
                    analyseButton
                }
                if isAnalysing {
                    analysingIndicator
                }
                if !detectionResults.isEmpty {
                    resultsSection
                }
                if addedSuccessfully {
                    successBanner
                }
            }
            .padding(EcrinSpacing.lg)
        }
        .background(EcrinColor.background)
        .navigationTitle("Détecter un bijou")
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadImage(from: newItem) }
        }
        .sheet(isPresented: $showAddSheet) {
            if let result = chosenResult {
                AddDetectedJewelrySheet(result: result, appState: appState) {
                    showAddSheet = false
                    addedSuccessfully = true
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(EcrinColor.gold)
                Text("Détection automatique")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
            }
            Text("Photographiez un bijou — l'IA identifie le type et le prérempli dans votre garde-robe.")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imagePicker: some View {
        HStack(spacing: EcrinSpacing.md) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Galerie", systemImage: "photo.on.rectangle")
                    .font(EcrinFont.sans(14, weight: .medium))
                    .foregroundStyle(EcrinColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func selectedImagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            )
    }

    private var analyseButton: some View {
        Button {
            Task { await runDetection() }
        } label: {
            Label("Analyser le bijou", systemImage: "sparkles")
                .font(EcrinFont.sans(15, weight: .semibold))
                .foregroundStyle(EcrinColor.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(EcrinColor.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isAnalysing)
    }

    private var analysingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(EcrinColor.gold)
            Text("Analyse en cours…")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            Text("Résultats de l'analyse")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)

            if detectionResults.isEmpty {
                Text("Aucun bijou détecté. Essayez avec une photo plus nette ou mieux cadrée.")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            } else {
                ForEach(detectionResults, id: \.category) { result in
                    DetectionResultRow(result: result) {
                        chosenResult = result
                        showAddSheet = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Bijou ajouté à votre garde-robe !")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
        )
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                addedSuccessfully = false
            }
        }
    }

    // MARK: - Actions

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        selectedImage = uiImage
        detectionResults = []
        addedSuccessfully = false
    }

    private func runDetection() async {
        guard let image = selectedImage else { return }
        isAnalysing = true
        detectionResults = await JewelryDetectionService.shared.detect(image: image)
        isAnalysing = false
    }
}

// MARK: - DetectionResultRow

private struct DetectionResultRow: View {
    let result: JewelryDetectionResult
    let onAdd: () -> Void

    var confidence: String {
        "\(Int((result.confidence * 100).rounded()))%"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: result.category.detectionIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(EcrinColor.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.category.rawValue)
                    .font(EcrinFont.sans(15, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
                Text("Confiance : \(confidence)")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            Spacer()

            // Confidence bar
            VStack(alignment: .trailing, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(EcrinColor.surface)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(EcrinColor.gold)
                            .frame(width: geo.size.width * CGFloat(result.confidence))
                    }
                }
                .frame(width: 64, height: 4)

                Button {
                    onAdd()
                } label: {
                    Text("Ajouter")
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(EcrinColor.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EcrinSpacing.md)
        .background(EcrinColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
        )
    }
}

// MARK: - FashionCategory icon helper

private extension FashionCategory {
    var detectionIcon: String {
        switch self {
        case .ring:           return "circle.hexagonpath"
        case .necklace:       return "link"
        case .earring:        return "oval"
        case .bracelet:       return "circle"
        case .watch:          return "clock"
        case .brooch:         return "star.circle"
        case .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing:
            return "diamond"
        default:              return "sparkles"
        }
    }
}

// MARK: - AddDetectedJewelrySheet

private struct AddDetectedJewelrySheet: View {

    let result: JewelryDetectionResult
    let appState: AppState
    let onDone: () -> Void

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var color: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Type détecté")
                            .foregroundStyle(EcrinColor.textMuted)
                        Spacer()
                        Text(result.category.rawValue)
                            .foregroundStyle(EcrinColor.gold)
                            .fontWeight(.semibold)
                    }
                }
                Section("Informations") {
                    TextField("Nom (ex : Bague solitaire)", text: $name)
                    TextField("Marque (optionnel)", text: $brand)
                    TextField("Couleur (optionnel)", text: $color)
                }
            }
            .navigationTitle("Ajouter à la garde-robe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        saveItem()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
            }
            .onAppear {
                name = result.category.rawValue
            }
        }
    }

    private func saveItem() {
        let item = FashionItem(
            name: name.trimmingCharacters(in: .whitespaces),
            category: result.category,
            brand: brand.isEmpty ? nil : brand,
            color: color.isEmpty ? nil : color,
            tags: [],
            tryOnPrompt: result.category.rawValue.lowercased(),
            source: .userPhoto,
            isFavorite: false
        )
        appState.wardrobe.add(item)
        onDone()
        dismiss()
    }
}
