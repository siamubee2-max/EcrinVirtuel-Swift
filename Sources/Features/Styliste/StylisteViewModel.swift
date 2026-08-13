import Foundation
import Observation

// MARK: - StylisteViewModel

@Observable
@MainActor
final class StylisteViewModel {

    // MARK: - State

    private(set) var messages: [StylisteMessage] = []
    var inputText: String = ""
    private(set) var isThinking = false
    private(set) var errorMessage: String?

    // MARK: - Init

    init() {
        // Greet the user with a context-aware opening.
        messages = [
            StylisteMessage(
                role: .assistant,
                text: "Bonjour ! Je suis votre styliste personnelle ✨\nPosez-moi n'importe quelle question : tenues pour une occasion, conseils matières, associations de couleurs ou suggestions selon la météo du jour."
            )
        ]
    }

    // MARK: - Send

    func sendMessage(appState: AppState) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = StylisteMessage(role: .user, text: trimmed)
        messages.append(userMessage)

        isThinking = true
        defer { isThinking = false }

        let context = buildContext(appState: appState)
        let history = messages
            .dropLast()              // exclude the message we just added
            .map(\.asAPIMessage)

        let newMsg = userMessage.asAPIMessage

        do {
            let reply = try await SupabaseService.shared.chatWithStyliste(
                history: history + [newMsg],
                context: context
            )
            messages.append(StylisteMessage(role: .assistant, text: reply))
        } catch {
            errorMessage = L10n.StylisteUI.contactFailed
        }
    }

    // MARK: - Context builder

    private func buildContext(appState: AppState) -> String {
        var lines: [String] = []

        // Weather
        if let weather = WeatherService.shared.snapshot ?? WeatherService.shared.loadFromCache() {
            lines.append("Météo actuelle : \(weather.weatherEmojiLine)")
            lines.append("Température ressentie : \(Int(weather.feelsLikeC.rounded()))°C")
            if weather.isRainy { lines.append("Il pleut : prévoir imperméable / chaussures imperméables.") }
            if weather.isWindy { lines.append("Vent fort : éviter les vêtements amples.") }
            if weather.isSunny { lines.append("Fort ensoleillement (UV \(Int(weather.uvIndex))) : protection solaire recommandée.") }
        }

        // Budget
        if let lookVM = findLookVM(), let budget = lookVM.maxBudget {
            lines.append("Budget maximum par article : \(Int(budget))€")
        }

        // Gender preference
        if let gender = appState.preferredGender {
            lines.append("Style recherché : \(gender.rawValue)")
        }

        // Wardrobe summary
        let wardrobe = appState.wardrobe.items
        if !wardrobe.isEmpty {
            lines.append("Garde-robe (\(wardrobe.count) pièces) :")
            // Group by category, list at most 4 per category to keep context short
            let byCategory = Dictionary(grouping: wardrobe, by: \.category)
            for (category, items) in byCategory.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let names = items.prefix(4).map { item in
                    var desc = item.name
                    if let color = item.color { desc += " (\(color))" }
                    if let brand = item.brand { desc += " — \(brand)" }
                    return desc
                }
                lines.append("  \(category.rawValue): \(names.joined(separator: ", "))")
            }
        } else {
            lines.append("Garde-robe : non renseignée.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Utilities

    /// Finds the active LookDuJourViewModel if available (to read maxBudget).
    private func findLookVM() -> LookDuJourViewModel? { nil } // injected via init if needed
}
