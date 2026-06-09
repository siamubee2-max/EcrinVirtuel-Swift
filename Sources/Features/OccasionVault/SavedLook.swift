import SwiftUI
import Foundation

// MARK: - Look Occasion

enum LookOccasion: String, CaseIterable, Codable, Sendable {
    case daily   = "Quotidien"
    case work    = "Travail"
    case evening = "Soirée"
    case wedding = "Mariage"
    case beach   = "Plage"
    case sport   = "Sport"
    case gala    = "Gala"
    case date    = "Rendez-vous"
    case travel  = "Voyage"

    var icon: String {
        switch self {
        case .daily:   return "sun.max"
        case .work:    return "briefcase"
        case .evening: return "moon.stars"
        case .wedding: return "heart"
        case .beach:   return "beach.umbrella"
        case .sport:   return "figure.run"
        case .gala:    return "crown"
        case .date:    return "flame"
        case .travel:  return "airplane"
        }
    }

    var accentColor: Color {
        switch self {
        case .daily:   return Color(hex: "#A8A29E")
        case .work:    return Color(hex: "#64748B")
        case .evening: return Color(hex: "#8B5CF6")
        case .wedding: return Color(hex: "#FB7185")
        case .beach:   return Color(hex: "#0EA5E9")
        case .sport:   return Color(hex: "#22C55E")
        case .gala:    return Color(hex: "#CA8A04")
        case .date:    return Color(hex: "#F97316")
        case .travel:  return Color(hex: "#06B6D4")
        }
    }
}

// MARK: - Saved Look

struct SavedLook: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var occasion: LookOccasion
    var jewelryIds: [UUID]
    var notes: String
    var isFavorite: Bool
    var tags: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        occasion: LookOccasion,
        jewelryIds: [UUID] = [],
        notes: String = "",
        isFavorite: Bool = false,
        tags: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.occasion = occasion
        self.jewelryIds = jewelryIds
        self.notes = notes
        self.isFavorite = isFavorite
        self.tags = tags
        self.createdAt = createdAt
    }

    // MARK: - Sample data (10 looks)

    static let samples: [SavedLook] = {
        let ids = JewelryItem.samples.map(\.id)
        return [
            SavedLook(
                name: "Soirée Gala · Avril",
                occasion: .gala,
                jewelryIds: ids,
                isFavorite: true,
                tags: ["Élégant", "Noir & Or"]
            ),
            SavedLook(
                name: "Dîner romantique",
                occasion: .date,
                jewelryIds: Array(ids.prefix(2)),
                tags: ["Minimaliste"]
            ),
            SavedLook(
                name: "Réunion importante",
                occasion: .work,
                jewelryIds: ids.count > 3 ? [ids[3]] : [],
                tags: ["Professionnel", "Sobre"]
            ),
            SavedLook(
                name: "Weekend Côte d'Azur",
                occasion: .beach,
                jewelryIds: ids.count >= 2 ? Array(ids.suffix(2)) : [],
                tags: ["Décontracté"]
            ),
            SavedLook(
                name: "Cocktail de printemps",
                occasion: .evening,
                jewelryIds: ids.count >= 3 ? Array(ids.prefix(3)) : ids,
                isFavorite: true,
                tags: ["Fleuri", "Pastel"]
            ),
            SavedLook(
                name: "Look mariage ami",
                occasion: .wedding,
                jewelryIds: Array(ids.prefix(2)),
                tags: ["Invitée", "Sobre"]
            ),
            SavedLook(
                name: "Voyage business",
                occasion: .travel,
                jewelryIds: ids.count > 0 ? [ids[0]] : [],
                tags: ["Minimaliste", "Discret"]
            ),
            SavedLook(
                name: "Journée yoga",
                occasion: .sport,
                jewelryIds: [],
                tags: ["Sans bijou lourds"]
            ),
            SavedLook(
                name: "Quotidien élégant",
                occasion: .daily,
                jewelryIds: ids.count >= 2 ? [ids[0], ids[2]] : ids,
                tags: ["Polyvalent"]
            ),
            SavedLook(
                name: "Gala de charité",
                occasion: .gala,
                jewelryIds: ids,
                isFavorite: true,
                tags: ["Grand soir", "Complet"]
            ),
        ]
    }()
}
