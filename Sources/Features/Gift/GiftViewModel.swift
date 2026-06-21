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

    // MARK: - Gift Creation (local-only)
    // gift_cards table not provisioned in prod — gift is local-only (see docs/audits 2026-06-21 C3).

    func createGiftLink(fromUser: User) async {
        guard let jewelry = selectedJewelry else { return }
        isCreatingLink = true
        errorMessage = nil
        defer { isCreatingLink = false }

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

    // MARK: - Gift Reception (local-only — deep-link cannot be resolved)
    // gift_cards table not provisioned in prod — gift is local-only (see docs/audits 2026-06-21 C3).
    // A received deep-link cannot be looked up; inform the user honestly.

    func receive(giftID: UUID) async {
        isLoadingGift = true
        errorMessage = nil
        defer { isLoadingGift = false }

        errorMessage = "Ce cadeau n'est plus disponible."
        revealedGift = nil
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
