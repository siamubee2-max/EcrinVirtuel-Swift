import SwiftUI
import PhotosUI

// MARK: - OutfitViewModel

@MainActor
final class OutfitViewModel: ObservableObject {

    // MARK: Published state

    @Published var currentOutfit: Outfit = Outfit()
    @Published var availableItems: [FashionItem] = FashionItem.samples
    @Published var isGenerating: Bool = false
    @Published var result: UIImage?
    @Published var errorMessage: String?
    @Published var conflicts: [String] = []
    @Published var showConflictWarning: Bool = false

    // Photo utilisateur pour le try-on
    @Published var userPhoto: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?

    // Groupe sélectionné dans le picker bas
    @Published var selectedGroup: FashionGroup = .clothing

    // Tenues sauvegardées
    @Published var savedOutfits: [Outfit] = []

    // ImageGenerationService gère le JWT utilisateur (+ fallback anonyme) et le format JSON
    // attendu par l'Edge Function tryon-generate.
    private let imageService = ImageGenerationService.shared

    // MARK: - Item assignment

    func assignItem(_ item: FashionItem, to slot: OutfitSlot) {
        guard slot.compatibleCategories.contains(item.category) else { return }
        currentOutfit.slots[slot] = FashionItemRef(from: item)
        refreshConflicts()
    }

    func autoAssignItem(_ item: FashionItem) {
        guard let slot = OutfitSlot.allCases.first(where: {
            $0.compatibleCategories.contains(item.category)
        }) else { return }
        assignItem(item, to: slot)
    }

    func removeItem(from slot: OutfitSlot) {
        currentOutfit.slots.removeValue(forKey: slot)
        refreshConflicts()
    }

    func clearOutfit() {
        currentOutfit = Outfit(occasion: currentOutfit.occasion)
        result = nil
        conflicts = []
    }

    // MARK: - Occasion

    func setOccasion(_ occasion: OutfitOccasion) {
        currentOutfit.occasion = occasion
    }

    // MARK: - Suggestions

    func suggestCompletions() -> [OutfitSlot: FashionItem] {
        let missingSlots = OutfitPromptBuilder.suggestMissingSlots(for: currentOutfit)
        var suggestions: [OutfitSlot: FashionItem] = [:]
        for slot in missingSlots {
            if let item = availableItems.first(where: { slot.compatibleCategories.contains($0.category) }) {
                suggestions[slot] = item
            }
        }
        return suggestions
    }

    func applySuggestions() {
        for (slot, item) in suggestCompletions() {
            assignItem(item, to: slot)
        }
    }

    // MARK: - Photo loading

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        userPhoto = image
        result = nil
    }

    // MARK: - Generation

    func generate(showPaywall: (() -> Void)? = nil) async {
        guard currentOutfit.isReadyToGenerate else {
            errorMessage = "Ajoutez au moins un vêtement principal pour générer le look."
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let photo = userPhoto ?? makePlaceholderPhoto()
        let prompt = OutfitPromptBuilder.build(
            outfit: currentOutfit,
            userContext: "a stylish woman, full body, standing naturally"
        )

        do {
            let generated = try await imageService.tryOnQuick(photo: photo, prompt: prompt)
            result = generated
            if let data = generated.jpegData(compressionQuality: 0.9) {
                currentOutfit.generatedImageData = data
            }
            saveCurrentOutfit()
        } catch {
            errorMessage = "Génération échouée : \(error.localizedDescription)"
        }
    }

    // MARK: - Save / favorite

    func saveCurrentOutfit() {
        if let idx = savedOutfits.firstIndex(where: { $0.id == currentOutfit.id }) {
            savedOutfits[idx] = currentOutfit
        } else {
            savedOutfits.append(currentOutfit)
        }
    }

    func toggleFavorite(outfitId: UUID) {
        if let idx = savedOutfits.firstIndex(where: { $0.id == outfitId }) {
            savedOutfits[idx].isFavorite.toggle()
        }
        if currentOutfit.id == outfitId {
            currentOutfit.isFavorite.toggle()
        }
    }

    func deleteOutfit(outfitId: UUID) {
        savedOutfits.removeAll { $0.id == outfitId }
        if currentOutfit.id == outfitId {
            currentOutfit = Outfit()
            result = nil
        }
    }

    // MARK: - Private helpers

    private func refreshConflicts() {
        conflicts = OutfitPromptBuilder.detectConflicts(in: currentOutfit)
        showConflictWarning = !conflicts.isEmpty
    }

    private func makePlaceholderPhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { ctx in
            UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        }
    }
}

// OutfitGenerationService supprimé — remplacé par ImageGenerationService.shared
// qui gère correctement le JWT utilisateur et le format JSON de l'Edge Function.
