import SwiftUI
import Foundation

@MainActor
final class WeddingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var weddingLook: WeddingLook
    @Published var showDatePicker: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var selectedSlot: WeddingSlot?
    @Published var isLoading = false
    @Published var toastMessage: String?

    // MARK: - Init

    init() {
        self.weddingLook = WeddingViewModel.loadOrCreate()
    }

    // MARK: - Computed

    var daysUntilWedding: Int? {
        guard let date = weddingLook.weddingDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: .now, to: date)
        return diff.day
    }

    var countdownLabel: String {
        guard let days = daysUntilWedding else { return "Date à définir" }
        if days < 0  { return "Le grand jour est passé" }
        if days == 0 { return "C'est aujourd'hui !" }
        return "J−\(days)"
    }

    var completionPercent: Int {
        Int(weddingLook.completionPercent * 100)
    }

    var emptySlots: [WeddingSlot] {
        WeddingSlot.allCases.filter { weddingLook.piece(for: $0) == nil }
    }

    var shareURL: String {
        "https://inferencevision.store/ecrin/wedding/\(weddingLook.id.uuidString)"
    }

    // MARK: - Actions

    func setWeddingDate(_ date: Date) {
        weddingLook.weddingDate = date
        save()
    }

    func addPiece(jewelry: JewelryItem, to slot: WeddingSlot) {
        var pieces = weddingLook.pieces.filter { $0.slotType != slot }
        pieces.append(WeddingPiece(slotType: slot, jewelry: jewelry))
        weddingLook.pieces = pieces
        save()
        showToast("Bijou ajouté au look")
    }

    func removePiece(for slot: WeddingSlot) {
        weddingLook.pieces.removeAll { $0.slotType == slot }
        save()
    }

    func addBridesmaid(email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !weddingLook.bridesmaidEmails.contains(trimmed) else { return }
        weddingLook.bridesmaidEmails.append(trimmed)
        save()
    }

    func removeBridesmaid(email: String) {
        weddingLook.bridesmaidEmails.removeAll { $0 == email }
        save()
    }

    func finalizeLook() {
        weddingLook.isFinalized = true
        save()
        showToast("Look finalisé !")
    }

    // MARK: - Persistence (UserDefaults only — wedding_looks absent from prod)
    // NOTE: `wedding_looks` table does not exist in prod (migration 009).
    // All persistence is local via UserDefaults; cloud sync deferred.

    private static let storageKey = "weddingLook_v2"

    /// Loads from UserDefaults (wedding_looks not in prod, no remote load).
    func loadFromRemote() async {
        weddingLook = WeddingViewModel.loadOrCreate()
    }

    /// Saves to UserDefaults only (no Supabase sync — table absent from prod).
    private func save() {
        if let data = try? JSONEncoder().encode(weddingLook) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func loadOrCreate() -> WeddingLook {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let look = try? JSONDecoder().decode(WeddingLook.self, from: data) else {
            return WeddingLook()
        }
        return look
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
