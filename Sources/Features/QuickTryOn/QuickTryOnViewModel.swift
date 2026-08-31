import OSLog
import SwiftUI
import PhotosUI

// MARK: - QuickTryOnItem — Wrapper unifiant FashionItem et CatalogClothingItem

enum QuickTryOnItem: Identifiable, Equatable, Sendable {
    case wardrobe(FashionItem)
    case catalog(CatalogClothingItem)

    var id: String {
        switch self {
        case .wardrobe(let item): return "w-\(item.id)"
        case .catalog(let item):  return "c-\(item.id)"
        }
    }

    var name: String {
        switch self {
        case .wardrobe(let item): return item.name
        case .catalog(let item):  return item.name
        }
    }

    var brand: String? {
        switch self {
        case .wardrobe(let item): return item.brand
        case .catalog(let item):  return item.brand
        }
    }

    /// Vraie photo de l'article (catalogue/garde-robe) — envoyée au modèle comme référence.
    var referenceImageURL: URL? {
        switch self {
        case .wardrobe(let item): return item.imageURL
        case .catalog(let item):  return item.imageURL
        }
    }

    /// Identifiant de l'article de garde-robe, dont la photo vit dans un
    /// fichier. Prioritaire sur l'URL : un article ajouté par l'utilisateur n'a
    /// pas d'`imageURL`, seulement cette photo (détourée si le réglage était
    /// actif à l'ajout).
    ///
    /// On expose l'IDENTIFIANT et non les octets : les lire ici forcerait une
    /// lecture disque synchrone sur le thread de l'appelant, qui est le thread
    /// principal dans le parcours multi-poses.
    var wardrobePhotoID: UUID? {
        switch self {
        case .wardrobe(let item): return item.id
        case .catalog:            return nil
        }
    }

    var categoryLabel: String {
        switch self {
        case .wardrobe(let item): return item.category.rawValue
        case .catalog(let item):  return item.category
        }
    }

    // Résolution vers FashionCategory via asFashionItem pour les items catalogue
    var fashionCategory: FashionCategory {
        switch self {
        case .wardrobe(let item): return item.category
        case .catalog(let item):  return item.asFashionItem.category
        }
    }

    var icon: String {
        switch self {
        case .wardrobe(let item): return item.category.icon
        case .catalog(let item):  return item.categoryIcon
        }
    }

    var color: String? {
        switch self {
        case .wardrobe(let item): return item.color
        case .catalog(let item):  return item.color
        }
    }

    var tryOnPrompt: String {
        switch self {
        case .wardrobe(let item): return item.tryOnPrompt
        case .catalog(let item):  return item.tryOnPrompt
        }
    }

    var groupColor: Color {
        fashionCategory.group.color
    }

    static func == (lhs: QuickTryOnItem, rhs: QuickTryOnItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - QuickTryOnViewModel

@Observable
@MainActor
final class QuickTryOnViewModel {

    // MARK: State

    var selectedMode: QuickTryOnMode?
    var selectedItems: [QuickTryOnItem] = []
    var userPhoto: UIImage?
    var result: UIImage?
    var isGenerating: Bool = false
    var currentStep: Int = 0
    var errorMessage: String?
    var selectedPhotoItem: PhotosPickerItem?
    var lastBodyContext: BodyContext?

    /// Alias vers le gestionnaire de crédits centralisé.
    var trialsRemaining: Int { CreditsManager.shared.remaining }

    // Wardrobe source
    var wardrobeItems: [FashionItem] = FashionItem.samples

    // Catalog filters — données lues en direct depuis ClothingCatalogService.shared
    var catalogGenderFilter: ClothingGender = .femme
    var catalogCategoryGroupFilter: ClothingCategoryGroup = .all
    private(set) var isCatalogLoading = false

    private let imageService = ImageGenerationService.shared
    private var catalogService: ClothingCatalogService { ClothingCatalogService.shared }

    /// Articles bruts pour le genre sélectionné (+ unisexe sauf onglet unisexe dédié).
    var catalogItems: [CatalogClothingItem] {
        let primary = catalogService.items(for: catalogGenderFilter)
        guard catalogGenderFilter != .unisexe else { return primary }
        var seen = Set(primary.map(\.id))
        return primary + catalogService.unisexItems.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Computed

    var canProceedToNextStep: Bool {
        switch currentStep {
        case 0: return selectedMode != nil
        case 1: return !selectedItems.isEmpty
        case 2: return userPhoto != nil
        default: return false
        }
    }

    // Items garde-robe filtrés selon le mode sélectionné
    var filteredWardrobeItems: [FashionItem] {
        guard let mode = selectedMode else { return wardrobeItems }
        return wardrobeItems.filter { mode.compatibleCategories.contains($0.category) }
    }

    // Items catalogue filtrés par groupe de catégorie + mode (genre déjà appliqué via catalogItems)
    var filteredCatalogItems: [CatalogClothingItem] {
        catalogItems.filter { item in
            let groupMatch: Bool
            if catalogCategoryGroupFilter == .all {
                groupMatch = true
            } else {
                groupMatch = item.category == catalogCategoryGroupFilter.rawKey
            }

            let modeMatch: Bool
            if let mode = selectedMode {
                modeMatch = mode.compatibleCategories.contains(item.asFashionItem.category)
            } else {
                modeMatch = true
            }

            return groupMatch && modeMatch
        }
    }

    /// Vrai quand le mode sélectionné ne peut pas afficher de vêtements catalogue (ex. bijoux seuls).
    var isCatalogIncompatibleWithMode: Bool {
        guard let mode = selectedMode else { return false }
        return mode == .jewelsOnly
    }

    // Max items selon le mode
    private var maxItems: Int {
        selectedMode?.maxItemCount ?? 1
    }

    // ClothingCategoryGroup compatibles avec le mode sélectionné
    var availableCategoryGroups: [ClothingCategoryGroup] {
        guard let mode = selectedMode else { return ClothingCategoryGroup.allCases }
        let compatibleFashionCats = mode.compatibleCategories
        return ClothingCategoryGroup.allCases.filter { group in
            guard let key = group.rawKey else { return true } // .all toujours présent
            return catalogItems.contains { item in
                item.category == key
                    && compatibleFashionCats.contains(item.asFashionItem.category)
            }
        }
    }

    // MARK: - Mode selection

    func selectMode(_ mode: QuickTryOnMode) {
        selectedMode = mode
        selectedItems = []
        catalogCategoryGroupFilter = .all
    }

    /// Pré-sélection depuis le Look du Jour : articles garde-robe en priorité, complétés par le catalogue.
    func applyLookRecommendation(_ recommendation: LookRecommendation) {
        selectedMode = .fullOutfit
        catalogGenderFilter = recommendation.gender
        catalogCategoryGroupFilter = .all
        selectedItems = recommendation.allItems
        currentStep = 1
        errorMessage = nil
    }

    // MARK: - Item management

    func addItem(_ item: QuickTryOnItem) {
        guard selectedItems.count < maxItems else { return }
        guard !selectedItems.contains(item) else { return }
        if let mode = selectedMode,
           !mode.compatibleCategories.contains(item.fashionCategory) { return }
        selectedItems.append(item)
    }

    func removeItem(_ item: QuickTryOnItem) {
        selectedItems.removeAll { $0 == item }
    }

    func toggleItem(_ item: QuickTryOnItem) {
        if selectedItems.contains(item) {
            removeItem(item)
        } else {
            addItem(item)
        }
    }

    func isSelected(_ item: QuickTryOnItem) -> Bool {
        selectedItems.contains(item)
    }

    // MARK: - Catalog loading

    /// Charge le catalogue vêtements depuis Supabase (via ClothingCatalogService).
    /// Appelé à l'ouverture de QuickTryOnView et au passage sur l'onglet Catalogue.
    func loadCatalog(force: Bool = false) async {
        isCatalogLoading = true
        defer { isCatalogLoading = false }
        await catalogService.fetchAll(force: force)
        Logger(subsystem: "com.ecrin.jewelry", category: "quick-tryon").debug("QuickTryOn catalog loaded: \(self.catalogService.totalCount) articles (\(self.filteredCatalogItems.count) visibles)")
    }

    // MARK: - Photo loading

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        // Pas de rejet sur la taille brute : ImageGenerationService downscale
        // à 2048 px et compresse sous la limite Edge avant chaque envoi — une
        // photo 48 MP était refusée ici alors qu'elle passe après réduction.
        // Décodage à taille bornée (~2048 px) : une photo 48 Mpx décodée entière
        // pèse ~120 Mo de RAM ; 2048 px suffit pour la génération.
        guard let image = DownsampledImageLoader.downsample(data: data, maxPixelSize: 2048)
                ?? UIImage(data: data) else { return }
        userPhoto = image
        result = nil
    }

    // MARK: - Generation

    func generate(showPaywall: () -> Void) async {
        guard !isGenerating else { return }
        guard let photo = userPhoto, !selectedItems.isEmpty else { return }
        guard let mode = selectedMode else { return }

        let creditCost = selectedItems.count > 1 ? 2 : 1
        guard CreditsManager.shared.consume(count: creditCost, showPaywall: showPaywall) else { return }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        if let primaryItem = selectedItems.first {
            do {
                let (generated, context) = try await imageService.tryOnEnriched(
                    photo: photo,
                    item: primaryItem,
                    mode: mode
                )
                lastBodyContext = context

                // N'assigner `result` qu'une seule fois : la vue observe onChange(result)
                // pour ouvrir le cover et ajouter à SessionCreationsStore — publier le
                // résultat intermédiaire du flow multi-articles l'affichait comme final
                // et créait un doublon.
                var finalImages = generated
                if selectedItems.count > 1 {
                    let fullPrompt = buildEnrichedMultiItemPrompt(
                        mode: mode,
                        items: selectedItems,
                        bodyContext: context
                    )
                    finalImages = try await imageService.tryOnQuick(
                        photo: generated,
                        prompt: fullPrompt
                    )
                }
                result = finalImages
                CreditsManager.shared.syncDetached()
                GamingService.shared.record(.tryOnGenerated)
                // Enregistrer la session Try-On en arrière-plan (sans bloquer l'UI)
                Task {
                    try? await SupabaseService.shared.saveTryOnSession(
                        jewelryId: primaryItem.id,
                        resultImageURL: nil
                    )
                }
            } catch let error as ImageGenerationService.GenerationError {
                CreditsManager.shared.refund(count: creditCost)
                switch error {
                case .authenticationRequired:
                    errorMessage = error.localizedDescription
                case .quotaExceeded:
                    if !CreditsManager.shared.isUnlimited {
                        CreditsManager.shared.remaining = 0
                        showPaywall()
                    }
                default:
                    errorMessage = error.localizedDescription ?? "La génération a échoué. Veuillez réessayer."
                }
            } catch {
                CreditsManager.shared.refund(count: creditCost)
                errorMessage = L10n.QuickTryOnUI.generationFailedRetry
            }
        }
    }

    // MARK: - Prompt multi-items enrichi

    func buildEnrichedMultiItemPrompt(
        mode: QuickTryOnMode,
        items: [QuickTryOnItem],
        bodyContext: BodyContext
    ) -> String {
        let itemDescriptions = items.map { item -> String in
            var parts = [item.tryOnPrompt]
            if let color = item.color { parts.append("color: \(color)") }
            if let brand = item.brand { parts.append("by \(brand)") }
            return parts.joined(separator: ", ")
        }.joined(separator: " combined with ")

        let skinInfo = "Maintain exact skin tone \(bodyContext.skinHex), \(bodyContext.skinTone.description), \(bodyContext.skinUndertone.adjective)."
        let bodyInfo = "Body: \(bodyContext.bodyShape.rawValue), \(bodyContext.estimatedHeight.rawValue)."
        let lightInfo = "Lighting: \(bodyContext.lightingType.rawValue) \(bodyContext.lightingDirection.description)."

        return "EDIT the reference photo — same person, background, lighting and colours — only add the item. \(itemDescriptions). \(mode.promptSuffix). \(skinInfo) \(bodyInfo) \(lightInfo) Photorealistic, seamlessly composited. Do NOT beautify, relight, recolour or replace the background. Keep face and hair unchanged."
    }

    // MARK: - Prompt construction

    func buildPrompt(mode: QuickTryOnMode, items: [QuickTryOnItem]) -> String {
        let itemDescriptions = items.map { item -> String in
            var parts = [item.tryOnPrompt]
            if let color = item.color { parts.append("color: \(color)") }
            if let brand = item.brand { parts.append("by \(brand)") }
            return parts.joined(separator: ", ")
        }.joined(separator: " combined with ")

        let qualityTags = """
        EDIT the reference photo: keep the same background, lighting and colours — only add the item. \
        Photorealistic, seamlessly composited. Do NOT beautify, relight, recolour or replace the background. \
        Keep the person's face, skin tone, hair, and body proportions exactly the same.
        """

        return [itemDescriptions, mode.promptSuffix, qualityTags]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    // MARK: - Step navigation

    func advanceStep() {
        guard canProceedToNextStep else { return }
        withAnimation(EcrinAnimation.springSnap) {
            currentStep = min(currentStep + 1, 3)
        }
    }

    func goBack() {
        withAnimation(EcrinAnimation.springSnap) {
            currentStep = max(currentStep - 1, 0)
        }
    }

    func reset() {
        withAnimation(EcrinAnimation.springSnap) {
            selectedMode = nil
            selectedItems = []
            userPhoto = nil
            result = nil
            isGenerating = false
            errorMessage = nil
            currentStep = 0
        }
    }
}
