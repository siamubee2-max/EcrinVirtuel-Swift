import Foundation

// MARK: - Gift Occasion
enum GiftOccasion: String, CaseIterable, Codable {
    case birthday    = "Anniversaire"
    case wedding     = "Mariage"
    case valentines  = "Saint-Valentin"
    case christmas   = "Noël"
    case anniversary = "Anniversaire couple"
    case justBecause = "Juste parce que"

    var emoji: String {
        switch self {
        case .birthday:    return "🎂"
        case .wedding:     return "💍"
        case .valentines:  return "❤️"
        case .christmas:   return "🎄"
        case .anniversary: return "🥂"
        case .justBecause: return "✨"
        }
    }

    var displayLabel: String { "\(emoji) \(rawValue)" }
}

// MARK: - Gift Card Model
struct GiftCard: Identifiable, Codable {
    let id: UUID
    let fromUser: User
    let jewelryItem: JewelryItem
    var tryOnImageData: Data?
    var message: String
    var occasionType: GiftOccasion
    var shareURL: URL?
    var isRevealed: Bool
    let createdAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        fromUser: User,
        jewelryItem: JewelryItem,
        tryOnImageData: Data? = nil,
        message: String = "",
        occasionType: GiftOccasion = .justBecause,
        shareURL: URL? = nil,
        isRevealed: Bool = false,
        createdAt: Date = .now,
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    ) {
        self.id = id
        self.fromUser = fromUser
        self.jewelryItem = jewelryItem
        self.tryOnImageData = tryOnImageData
        self.message = message
        self.occasionType = occasionType
        self.shareURL = shareURL
        self.isRevealed = isRevealed
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    /// Generates a deeplink URL for this gift
    var generatedShareURL: URL {
        URL(string: "ecrin://gift/\(id.uuidString)")!
    }

    /// Whether the gift has expired
    var isExpired: Bool { expiresAt < .now }
}

// MARK: - Sample
extension GiftCard {
    static let sample = GiftCard(
        fromUser: User(
            email: "marie@example.com",
            displayName: "Marie",
            createdAt: .now
        ),
        jewelryItem: JewelryItem.samples[0],
        message: "Pour toi, avec tout mon amour.",
        occasionType: .valentines
    )
}
