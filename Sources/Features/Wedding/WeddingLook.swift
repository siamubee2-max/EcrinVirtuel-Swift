import Foundation

// MARK: - Wedding Slot

enum WeddingSlot: String, CaseIterable, Codable, Sendable {
    case tiara      = "Diadème"
    case earrings   = "Boucles d'oreilles"
    case necklace   = "Collier"
    case bracelet   = "Bracelet"
    case ring       = "Bague"
    case anklet     = "Cheville"
    case handpiece  = "Bracelet de main"

    var icon: String {
        switch self {
        case .tiara:     return "crown.fill"
        case .earrings:  return "oval.fill"
        case .necklace:  return "link"
        case .bracelet:  return "circle"
        case .ring:      return "circle.hexagongrid.fill"
        case .anklet:    return "figure.walk"
        case .handpiece: return "hand.raised.fill"
        }
    }

    var hint: String {
        switch self {
        case .tiara:
            return "Réservez le diadème aux cérémonies formelles"
        case .earrings:
            return "Des créoles dorées subliment une robe épurée"
        case .necklace:
            return "Optez pour un solitaire discret si le décolleté est travaillé"
        case .bracelet:
            return "Un jonc fin apporte élégance sans surcharger"
        case .ring:
            return "La bague de fiançailles reste la pièce maîtresse"
        case .anklet:
            return "Privilégiez la discrétion pour un port à la cheville"
        case .handpiece:
            return "Le bracelet de main souligne le geste de la danse"
        }
    }

    var sortOrder: Int {
        switch self {
        case .tiara:     return 0
        case .earrings:  return 1
        case .necklace:  return 2
        case .bracelet:  return 3
        case .ring:      return 4
        case .anklet:    return 5
        case .handpiece: return 6
        }
    }
}

// MARK: - Identifiable conformance for sheet(item:)
extension WeddingSlot: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Wedding Piece

struct WeddingPiece: Identifiable, Codable, Sendable {
    let id: UUID
    var slotType: WeddingSlot
    var jewelry: JewelryItem
    var notes: String

    init(
        id: UUID = UUID(),
        slotType: WeddingSlot,
        jewelry: JewelryItem,
        notes: String = ""
    ) {
        self.id = id
        self.slotType = slotType
        self.jewelry = jewelry
        self.notes = notes
    }
}

// MARK: - Wedding Look

struct WeddingLook: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var weddingDate: Date?
    var pieces: [WeddingPiece]
    var bridesmaidEmails: [String]
    var isFinalized: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Mon Look de Mariée",
        weddingDate: Date? = nil,
        pieces: [WeddingPiece] = [],
        bridesmaidEmails: [String] = [],
        isFinalized: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.weddingDate = weddingDate
        self.pieces = pieces
        self.bridesmaidEmails = bridesmaidEmails
        self.isFinalized = isFinalized
        self.createdAt = createdAt
    }

    /// Returns the piece for a given slot, if any
    func piece(for slot: WeddingSlot) -> WeddingPiece? {
        pieces.first { $0.slotType == slot }
    }

    /// Completion ratio: filled slots / total slots
    var completionPercent: Double {
        Double(pieces.count) / Double(WeddingSlot.allCases.count)
    }
}
