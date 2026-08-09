import SwiftUI
import Foundation
import OSLog

// MARK: - Gift Creation State
enum GiftCreatorStep: Int, CaseIterable {
    case chooseJewelry = 0
    case customize     = 1
    case send          = 2

    var title: String {
        switch self {
        case .chooseJewelry: return "Choisir"
        case .customize:     return "Personnaliser"
        case .send:          return "Envoyer"
        }
    }
}

// MARK: - Gift View Model
@MainActor
final class GiftViewModel: ObservableObject {

    // MARK: Creator state
    @Published var currentStep: GiftCreatorStep = .chooseJewelry
    @Published var selectedJewelry: JewelryItem?
    @Published var selectedTryOnImage: UIImage?
    @Published var message: String = ""
    @Published var occasion: GiftOccasion = .justBecause
    @Published var createdGift: GiftCard?
    @Published var shareURL: URL?
    @Published var isCreatingLink = false
    @Published var showShareSheet = false
    @Published var errorMessage: String?

    // MARK: Receive state
    @Published var revealedGift: GiftCard?
    @Published var isBoxOpen = false
    @Published var isLoadingGift = false

    // MARK: Try-on images (populated from dressing/history)
    @Published var availableTryOns: [TryOnEntry] = TryOnEntry.samples

    // MARK: Validation
    var canProceedToCustomize: Bool { selectedJewelry != nil }
    var canProceedToSend: Bool { !message.trimmingCharacters(in: .whitespaces).isEmpty }

    var stepProgress: Double {
        Double(currentStep.rawValue + 1) / Double(GiftCreatorStep.allCases.count)
    }

    // MARK: - Navigation

    func next() {
        guard let next = GiftCreatorStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(EcrinAnimation.springSnap) { currentStep = next }
    }

    func previous() {
        guard let prev = GiftCreatorStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(EcrinAnimation.springSnap) { currentStep = prev }
    }

    func goTo(_ step: GiftCreatorStep) {
        withAnimation(EcrinAnimation.springSnap) { currentStep = step }
    }

    // MARK: - Gift Creation (Supabase backend)

    func createGiftLink(fromUser: User) async {
        guard let jewelry = selectedJewelry else { return }
        isCreatingLink = true
        errorMessage = nil
        defer { isCreatingLink = false }

        do {
            // gift_cards.from_user_id references users(id), not auth.uid() —
            // resolve the profile row id so the insert satisfies the RLS
            // ownership check (migration 007).
            var userId: String?
            if let authId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString {
                userId = try? await SupabaseService.shared.resolveUsersRowID(authId: authId)
            }

            let giftID = UUID()
            let expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
            let iso = ISO8601DateFormatter()

            // Encode full JewelryItem as JSON for faithful reconstruction on receive
            let jewelryJSON = (try? String(data: JSONEncoder().encode(jewelry), encoding: .utf8)) ?? "{}"

            struct GiftRow: Encodable {
                let id: String
                let from_user_id: String?
                let from_display_name: String?
                let from_email: String
                let jewelry_id: String
                let jewelry_name: String
                let jewelry_image_url: String?
                let jewelry_json: String
                let message: String
                let occasion: String
                let is_revealed: Bool
                let expires_at: String
            }

            let row = GiftRow(
                id: giftID.uuidString,
                from_user_id: userId,
                from_display_name: fromUser.displayName,
                from_email: fromUser.email,
                jewelry_id: jewelry.id.uuidString,
                jewelry_name: jewelry.name,
                jewelry_image_url: jewelry.imageURL?.absoluteString,
                jewelry_json: jewelryJSON,
                message: message,
                occasion: occasion.rawValue,
                is_revealed: false,
                expires_at: iso.string(from: expiresAt)
            )

            try await SupabaseService.shared.client
                .from(SupabaseService.giftCards)
                .insert(row)
                .execute()

            let gift = GiftCard(
                id: giftID,
                fromUser: fromUser,
                jewelryItem: jewelry,
                tryOnImageData: selectedTryOnImage?.jpegData(compressionQuality: 0.85),
                message: message,
                occasionType: occasion,
                shareURL: URL(string: "https://inferencevision.store/ecrin/gift/\(giftID.uuidString)"),
                expiresAt: expiresAt
            )
            createdGift = gift
            shareURL = gift.generatedShareURL
            showShareSheet = true

        } catch {
            Logger(subsystem: "com.ecrin.jewelry", category: "gift").error("createGiftLink error: \(error.localizedDescription, privacy: .public)")
            // Degrade gracefully: local-only gift (no persistence)
            let gift = GiftCard(
                fromUser: fromUser,
                jewelryItem: jewelry,
                tryOnImageData: selectedTryOnImage?.jpegData(compressionQuality: 0.85),
                message: message,
                occasionType: occasion
            )
            createdGift = gift
            shareURL = gift.generatedShareURL
            showShareSheet = true
        }
    }

    // MARK: - Gift Reception (Supabase backend)

    func receive(giftID: UUID) async {
        isLoadingGift = true
        errorMessage = nil
        defer { isLoadingGift = false }

        do {
            struct GiftRow: Decodable {
                let id: String
                let from_display_name: String?
                let from_email: String?
                let jewelry_json: String?
                let jewelry_name: String
                let jewelry_image_url: String?
                let message: String
                let occasion: String
                let is_revealed: Bool
                let expires_at: String
                let created_at: String?
            }

            struct GiftLookupParams: Encodable { let gift_id: String }

            // Single-row RPC (get_gift_card, migration 007) instead of a direct
            // table select — gift_cards has no public SELECT policy, so an
            // anonymous recipient can only ever fetch the one gift they hold
            // the id for, never the whole table.
            let rows: [GiftRow] = try await SupabaseService.shared.client
                .rpc("get_gift_card", params: GiftLookupParams(gift_id: giftID.uuidString))
                .execute()
                .value

            guard let row = rows.first else {
                errorMessage = "Ce cadeau est introuvable ou a expiré."
                return
            }

            // Reconstruct JewelryItem — prefer full JSON, fallback to stub
            let jewelry: JewelryItem
            if let jsonStr = row.jewelry_json,
               let data = jsonStr.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(JewelryItem.self, from: data) {
                jewelry = decoded
            } else {
                jewelry = JewelryItem(
                    id: UUID(),
                    name: row.jewelry_name,
                    category: .ring,
                    imageURL: URL(string: row.jewelry_image_url ?? ""),
                    icon: "diamond.fill",
                    material: "",
                    prompt: row.jewelry_name
                )
            }

            let sender = User(
                email: row.from_email ?? "",
                displayName: row.from_display_name
            )

            let iso = ISO8601DateFormatter()
            let expiresAt = iso.date(from: row.expires_at) ?? .now
            let createdAt = iso.date(from: row.created_at ?? "") ?? .now

            let gift = GiftCard(
                id: giftID,
                fromUser: sender,
                jewelryItem: jewelry,
                message: row.message,
                occasionType: GiftOccasion(rawValue: row.occasion) ?? .justBecause,
                isRevealed: row.is_revealed,
                createdAt: createdAt,
                expiresAt: expiresAt
            )

            // get_gift_card() already marks the gift as revealed server-side.
            withAnimation(EcrinAnimation.glassReveal) {
                revealedGift = gift
            }

        } catch {
            Logger(subsystem: "com.ecrin.jewelry", category: "gift").error("receive error: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Impossible de charger ce cadeau. Vérifiez votre connexion."
            // Fallback: show sample for demo purposes
            withAnimation(EcrinAnimation.glassReveal) {
                revealedGift = GiftCard.sample
            }
        }
    }

    // MARK: - Box

    func openBox() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
            isBoxOpen = true
        }
    }

    // MARK: - Reset

    func reset() {
        currentStep = .chooseJewelry
        selectedJewelry = nil
        selectedTryOnImage = nil
        message = ""
        occasion = .justBecause
        createdGift = nil
        shareURL = nil
        errorMessage = nil
    }
}

// MARK: - Try-On Entry Helper
struct TryOnEntry: Identifiable {
    let id: UUID
    let jewelry: JewelryItem
    let image: UIImage?

    static let samples: [TryOnEntry] = JewelryItem.samples.map {
        TryOnEntry(id: UUID(), jewelry: $0, image: nil)
    }
}
