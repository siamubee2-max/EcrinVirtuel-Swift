import Foundation
import SwiftUI

// MARK: - BodyModel
// Mannequin de référence pour essayage (table body_parts).
// user_id NULL = mannequin global proposé à tous les utilisateurs.
// user_id renseigné = photo personnelle uploadée par l'utilisateur.

struct BodyModel: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let type: String          // earrings | necklace | neck | wrist | ring | foot | body | corps_entier | torse | full_body
    let imageURL: URL?
    let userId: UUID?         // NULL = mannequin global
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case imageURL  = "image_url"
        case userId    = "user_id"
        case createdAt = "created_at"
    }

    /// Indique si c'est un mannequin global ou une photo perso.
    var isGlobal: Bool { userId == nil }

    /// Catégorie de bijou compatible avec ce mannequin.
    var compatibleJewelryCategory: JewelryItem.JewelryCategory {
        switch type.lowercased() {
        case "earrings":            return .earring
        case "necklace", "neck":    return .necklace
        case "bracelet", "wrist":   return .bracelet
        case "ring":                return .ring
        case "foot", "anklet":      return .bracelet  // pas d'anklet dans l'enum → fallback bracelet
        default:                    return .necklace
        }
    }

    /// True si ce mannequin convient pour essayage de vêtements (corps visible).
    var isBodyModel: Bool {
        let t = type.lowercased()
        return t.contains("body") || t.contains("corps") || t.contains("torse")
            || t.contains("full") || t.contains("complet") || t == "necklace"
            || t == "neck" || t == "tenue"
    }

    /// Icône SF Symbol représentative.
    var icon: String {
        switch type.lowercased() {
        case "earrings":                            return "ear"
        case "bracelet", "wrist":                   return "hand.raised"
        case "ring":                                return "circle.hexagongrid"
        case "foot", "anklet", "cheville":          return "figure.walk"
        case "body", "corps_entier", "full_body",
             "torse", "complet", "tenue":           return "person.crop.rectangle.fill"
        default:                                    return "person.fill"
        }
    }

    /// Libellé localisé du type pour l'UI.
    var typeLabel: String {
        switch type.lowercased() {
        case "earrings":                            return "Boucles d'oreilles"
        case "necklace", "neck":                    return "Collier"
        case "bracelet", "wrist":                   return "Bracelet"
        case "ring":                                return "Bague"
        case "foot", "anklet", "cheville":          return "Cheville"
        case "body", "corps_entier", "full_body":   return "Corps entier"
        case "torse":                               return "Torse"
        case "complet", "tenue":                    return "Tenue complète"
        default:                                    return type.capitalized
        }
    }
}
