import AppIntents
import SwiftUI

// MARK: - OpenLookDuJourIntent

struct OpenLookDuJourIntent: AppIntent {
    static var title: LocalizedStringResource { "Voir mon Look du Jour" }
    static var description: IntentDescription { IntentDescription("Ouvre le look personnalisé du jour basé sur la météo.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - OpenWardrobeIntent

struct OpenWardrobeIntent: AppIntent {
    static var title: LocalizedStringResource { "Ouvrir ma Garde-robe" }
    static var description: IntentDescription { IntentDescription("Accède directement à la garde-robe virtuelle.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - SuggestLookIntent

struct SuggestLookIntent: AppIntent {
    static var title: LocalizedStringResource { "Suggérer un look" }
    static var description: IntentDescription { IntentDescription("Demande à l'IA Styliste de suggérer un look pour une occasion.") }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Occasion", description: "L'occasion pour laquelle vous voulez un look.")
    var occasion: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - OpenJewelryDetectionIntent

struct OpenJewelryDetectionIntent: AppIntent {
    static var title: LocalizedStringResource { "Détecter un bijou" }
    static var description: IntentDescription { IntentDescription("Lance la détection automatique de bijoux par photo.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
