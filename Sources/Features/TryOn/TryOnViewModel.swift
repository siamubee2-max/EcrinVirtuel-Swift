import OSLog
import SwiftUI
import PhotosUI

@Observable
@MainActor
final class TryOnViewModel {
    var userPhoto: UIImage?
    var selectedJewelry: JewelryItem?
    var result: [UIImage]?
    var isGenerating = false
    var errorMessage: String?

    /// Alias vers le gestionnaire de crédits centralisé.
    var trialsRemaining: Int { CreditsManager.shared.remaining }
    /// Catalogue chargé depuis Supabase — fallback sur samples si fetch échoue
    var jewelryCatalog: [JewelryItem] = JewelryItem.samples

    private let imageService = ImageGenerationService.shared

    func loadCatalog() async {
        do {
            let raw = try await SupabaseService.shared.fetchJewelryCatalog()
            let mapped = raw.map { $0.asJewelryItem }
            if !mapped.isEmpty {
                jewelryCatalog = mapped
                return
            }
            Logger(subsystem: "com.ecrin.jewelry", category: "tryon").warning("TryOnViewModel: fetchJewelryCatalog returned 0 items")
        } catch {
            Logger(subsystem: "com.ecrin.jewelry", category: "tryon").error("TryOnViewModel: fetchJewelryCatalog failed – \(error.localizedDescription, privacy: .public)")
        }

        // Fallback REST si le SDK échoue
        if let mapped = try? await SupabaseService.shared.fetchJewelryCatalogViaREST(), !mapped.isEmpty {
            jewelryCatalog = mapped.map { $0.asJewelryItem }
        }
    }

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        userPhoto = image
        result = nil
    }

    func generate(showPaywall: () -> Void) async {
        guard CreditsManager.shared.consume(showPaywall: showPaywall) else { return }
        guard let photo = userPhoto, let jewelry = selectedJewelry else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await imageService.tryOn(photo: photo, jewelry: jewelry)
            result = [generated]
            CreditsManager.shared.syncDetached()
        } catch let error as ImageGenerationService.GenerationError {
            CreditsManager.shared.refund()
            errorMessage = error.localizedDescription
        } catch {
            CreditsManager.shared.refund()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - FashionItem generate (garde-robe étendue)

    func generateFashion(item: FashionItem, showPaywall: () -> Void) async {
        guard CreditsManager.shared.consume(showPaywall: showPaywall) else { return }
        guard let photo = userPhoto else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let generated = try await imageService.tryOnFashion(photo: photo, item: item)
            result = [generated]
            CreditsManager.shared.syncDetached()
        } catch let error as ImageGenerationService.GenerationError {
            CreditsManager.shared.refund()
            errorMessage = error.localizedDescription
        } catch {
            CreditsManager.shared.refund()
            errorMessage = error.localizedDescription
        }
    }
}
