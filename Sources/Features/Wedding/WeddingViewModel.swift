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

    // MARK: - Persistence (Supabase + UserDefaults fallback)

    private static let storageKey = "weddingLook_v2"

    /// Charge le look depuis Supabase si l'utilisateur est connecté,
    /// sinon depuis UserDefaults (mode offline / anonyme).
    func loadFromRemote() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let userId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString else {
                weddingLook = WeddingViewModel.loadOrCreate()
                return
            }

            struct WeddingRow: Decodable {
                let id: String
                let name: String
                let wedding_date: String?
                let pieces: String   // JSONB → String en Supabase Swift SDK
                let bridesmaid_emails: [String]
                let is_finalized: Bool
                let created_at: String
            }

            let rows: [WeddingRow] = try await SupabaseService.shared.latestWeddingRows(userId: userId)

            if let row = rows.first,
               let piecesData = row.pieces.data(using: .utf8),
               let pieces = try? JSONDecoder().decode([WeddingPiece].self, from: piecesData) {

                var look = WeddingLook(
                    id: UUID(uuidString: row.id) ?? UUID(),
                    name: row.name,
                    pieces: pieces,
                    bridesmaidEmails: row.bridesmaid_emails,
                    isFinalized: row.is_finalized
                )
                if let dateStr = row.wedding_date {
                    let formatter = ISO8601DateFormatter()
                    look.weddingDate = formatter.date(from: dateStr)
                }
                weddingLook = look
            } else {
                weddingLook = WeddingViewModel.loadOrCreate()
            }
        } catch {
            weddingLook = WeddingViewModel.loadOrCreate()
        }
    }

    /// Sauvegarde dans UserDefaults (cache local) + Supabase (si connecté).
    private func save() {
        // Cache local immédiat
        if let data = try? JSONEncoder().encode(weddingLook) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        // Sync Supabase en arrière-plan
        Task.detached { [look = weddingLook] in
            guard let userId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString else { return }
            let piecesJSON = (try? String(data: JSONEncoder().encode(look.pieces), encoding: .utf8)) ?? "[]"
            struct Row: Encodable {
                let id: String
                let user_id: String
                let name: String
                let wedding_date: String?
                let pieces: String
                let bridesmaid_emails: [String]
                let is_finalized: Bool
                let updated_at: String
            }
            let iso = ISO8601DateFormatter()
            let row = Row(
                id: look.id.uuidString,
                user_id: userId,
                name: look.name,
                wedding_date: look.weddingDate.map { iso.string(from: $0) },
                pieces: piecesJSON,
                bridesmaid_emails: look.bridesmaidEmails,
                is_finalized: look.isFinalized,
                updated_at: iso.string(from: .now)
            )
            try? await SupabaseService.shared.upsertRow(row, into: SupabaseService.weddingLooks)
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
