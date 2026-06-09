import SwiftUI
import Foundation

@MainActor
final class OccasionVaultViewModel: ObservableObject {

    // MARK: - Published State

    @Published var savedLooks: [SavedLook] = []
    @Published var selectedOccasion: LookOccasion = .gala
    @Published var showSaveLookSheet = false
    @Published var selectedLook: SavedLook?
    @Published var toastMessage: String?

    // MARK: - Computed

    var filteredLooks: [SavedLook] {
        savedLooks.filter { $0.occasion == selectedOccasion }
    }

    var favoriteLooks: [SavedLook] {
        savedLooks.filter(\.isFavorite)
    }

    func count(for occasion: LookOccasion) -> Int {
        savedLooks.filter { $0.occasion == occasion }.count
    }

    // MARK: - Init

    init() {
        load()
        if savedLooks.isEmpty {
            savedLooks = SavedLook.samples
            save()
        }
    }

    // MARK: - Actions

    func saveLook(_ look: SavedLook) {
        savedLooks.insert(look, at: 0)
        save()
        showToast("Look sauvegardé dans votre dressing")
    }

    func updateLook(_ look: SavedLook) {
        guard let idx = savedLooks.firstIndex(where: { $0.id == look.id }) else { return }
        savedLooks[idx] = look
        save()
    }

    func toggleFavorite(_ look: SavedLook) {
        guard let idx = savedLooks.firstIndex(where: { $0.id == look.id }) else { return }
        savedLooks[idx].isFavorite.toggle()
        save()
    }

    func deleteLook(_ look: SavedLook) {
        withAnimation(EcrinAnimation.springSnap) {
            savedLooks.removeAll { $0.id == look.id }
        }
        save()
        showToast("Look supprimé")
    }

    func duplicateLook(_ look: SavedLook) {
        var copy = look
        copy = SavedLook(
            id: UUID(),
            name: "\(look.name) (copie)",
            occasion: look.occasion,
            jewelryIds: look.jewelryIds,
            notes: look.notes,
            isFavorite: false,
            tags: look.tags,
            createdAt: .now
        )
        savedLooks.insert(copy, at: 0)
        save()
        showToast("Look dupliqué")
    }

    func updateNotes(_ notes: String, for look: SavedLook) {
        guard let idx = savedLooks.firstIndex(where: { $0.id == look.id }) else { return }
        savedLooks[idx].notes = notes
        save()
    }

    func updateTags(_ tags: [String], for look: SavedLook) {
        guard let idx = savedLooks.firstIndex(where: { $0.id == look.id }) else { return }
        savedLooks[idx].tags = tags
        save()
    }

    // MARK: - Persistence

    private static let storageKey = "occasionVault_v2"

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SavedLook].self, from: data) else { return }
        savedLooks = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(savedLooks) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            toastMessage = nil
        }
    }
}
