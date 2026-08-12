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

enum SubscriptionStatus {
    case free
    case starter
    case premium
    case elite

    /// Crédits mensuels par tier — source unique, alignée sur ce que le
    /// paywall vend (15/40/100). L'Edge Function credit-generations reste
    /// l'autorité : ces valeurs ne servent qu'à l'affichage en attendant
    /// le sync serveur.
    var trialLimit: Int {
        switch self {
        case .free:    return 3
        case .starter: return 15
        case .premium: return 40
        case .elite:   return 100
        }
    }

    /// Alias for CreditsManager compatibility.
    var monthlyGenerations: Int { trialLimit }

    var isSubscribed: Bool { self != .free }
}
