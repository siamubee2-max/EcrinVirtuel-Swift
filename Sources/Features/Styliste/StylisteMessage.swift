import Foundation

// MARK: - StylisteMessage

/// A single message in the AI Styliste conversation.
struct StylisteMessage: Identifiable, Equatable {

    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date

    init(role: Role, text: String, timestamp: Date = .now) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

    // MARK: Serialisation for Edge Function

    struct APIMessage: Codable {
        let role: String
        let content: String
    }

    var asAPIMessage: APIMessage {
        APIMessage(role: role.rawValue, content: text)
    }
}
