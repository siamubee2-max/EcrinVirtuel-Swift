import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var email: String
    var displayName: String?
    var avatarURL: URL?
    var preferredGender: ClothingGender?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, displayName, avatarURL, createdAt
        case preferredGender = "preferred_gender"
    }

    init(
        id: UUID = UUID(),
        email: String,
        displayName: String? = nil,
        avatarURL: URL? = nil,
        preferredGender: ClothingGender? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.preferredGender = preferredGender
        self.createdAt = createdAt
    }
}

enum SubscriptionStatus: String {
    case free    = "free"
    case starter = "starter"
    case premium = "premium"
    case elite   = "elite"

    var trialLimit: Int {
        switch self {
        case .free:    return 3
        case .starter: return 20
        case .premium: return 60
        case .elite:   return .max
        }
    }

    /// Alias for CreditsManager compatibility.
    var monthlyGenerations: Int { trialLimit }

    var isSubscribed: Bool { self != .free }
}
