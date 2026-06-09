import Foundation

// MARK: - Outfit — Tenue complète

struct Outfit: Identifiable, Codable {
    let id: UUID
    var name: String
    var occasion: OutfitOccasion
    var slots: [OutfitSlot: FashionItemRef]
    var generatedImageData: Data?
    var backgroundId: String?
    var frameId: String?
    var notes: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Ma tenue",
        occasion: OutfitOccasion = .casual,
        slots: [OutfitSlot: FashionItemRef] = [:],
        generatedImageData: Data? = nil,
        backgroundId: String? = nil,
        frameId: String? = nil,
        notes: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.occasion = occasion
        self.slots = slots
        self.generatedImageData = generatedImageData
        self.backgroundId = backgroundId
        self.frameId = frameId
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    // Score de complétude 0-100
    var completionScore: Int {
        let filled = slots.count
        let total = OutfitSlot.allCases.count
        return Int(Double(filled) / Double(total) * 100)
    }

    // Nombre minimum pour pouvoir générer (au moins 1 vêtement principal)
    var isReadyToGenerate: Bool {
        let hasClothing = slots.keys.contains(where: { $0.group == .clothing })
        return slots.count >= 2 && hasClothing
    }
}

// MARK: - OutfitSlot

enum OutfitSlot: String, CaseIterable, Codable, Hashable {
    // Bijoux
    case necklace   = "Collier"
    case earrings   = "Boucles"
    case ring       = "Bague"
    case bracelet   = "Bracelet"
    // Vêtements
    case top        = "Haut"
    case bottom     = "Bas"
    case dress      = "Robe"
    case jacket     = "Veste"
    // Chaussures
    case shoes      = "Chaussures"
    // Accessoires
    case bag        = "Sac"
    case sunglasses = "Lunettes"
    case belt       = "Ceinture"

    var isOptional: Bool {
        switch self {
        case .necklace, .earrings, .ring, .bracelet, .jacket, .shoes, .bag, .sunglasses, .belt:
            return true
        case .top, .bottom, .dress:
            return false
        }
    }

    var icon: String {
        switch self {
        case .necklace:   return "link"
        case .earrings:   return "oval.fill"
        case .ring:       return "circle.hexagongrid.fill"
        case .bracelet:   return "circle"
        case .top:        return "tshirt.fill"
        case .bottom:     return "figure.walk"
        case .dress:      return "figure.stand.dress"
        case .jacket:     return "cloud.fill"
        case .shoes:      return "shoe.fill"
        case .bag:        return "bag.fill"
        case .sunglasses: return "eyeglasses"
        case .belt:       return "minus"
        }
    }

    enum SlotGroup: String {
        case jewelry     = "bijoux"
        case clothing    = "vêtements"
        case shoes       = "chaussures"
        case accessories = "accessoires"
    }

    var group: SlotGroup {
        switch self {
        case .necklace, .earrings, .ring, .bracelet:
            return .jewelry
        case .top, .bottom, .dress, .jacket:
            return .clothing
        case .shoes:
            return .shoes
        case .bag, .sunglasses, .belt:
            return .accessories
        }
    }

    // Catégories FashionCategory compatibles avec ce slot
    var compatibleCategories: [FashionCategory] {
        switch self {
        case .necklace:   return [.necklace, .brooch]
        case .earrings:   return [.earring]
        case .ring:       return [.ring]
        case .bracelet:   return [.bracelet, .watch]
        case .top:        return [.top]
        case .bottom:     return [.bottom]
        case .dress:      return [.dress, .suit]
        case .jacket:     return [.jacket, .coat]
        case .shoes:      return [.heels, .flats, .boots, .sneakers, .sandals, .loafers]
        case .bag:        return [.bag]
        case .sunglasses: return [.sunglasses]
        case .belt:       return [.belt]
        }
    }

    // Position normalisée sur la silhouette (0,0 = centre, -1..1 = plage)
    // x: -1=gauche, 1=droite ; y: -1=haut, 1=bas
    var silhouettePosition: CGPoint {
        switch self {
        case .necklace:   return CGPoint(x: 0.0,  y: -0.38)
        case .earrings:   return CGPoint(x: 0.22, y: -0.47)
        case .ring:       return CGPoint(x: 0.38, y: -0.08)
        case .bracelet:   return CGPoint(x: -0.38, y: -0.05)
        case .top:        return CGPoint(x: 0.0,  y: -0.18)
        case .bottom:     return CGPoint(x: 0.0,  y: 0.22)
        case .dress:      return CGPoint(x: 0.15, y: 0.05)
        case .jacket:     return CGPoint(x: -0.20, y: -0.15)
        case .shoes:      return CGPoint(x: 0.0,  y: 0.62)
        case .bag:        return CGPoint(x: -0.42, y: 0.12)
        case .sunglasses: return CGPoint(x: 0.0,  y: -0.56)
        case .belt:       return CGPoint(x: 0.0,  y: 0.08)
        }
    }
}

// MARK: - OutfitOccasion

enum OutfitOccasion: String, CaseIterable, Codable {
    case casual   = "Casual"
    case work     = "Travail"
    case evening  = "Soirée"
    case gala     = "Gala"
    case beach    = "Plage"
    case wedding  = "Mariage"
    case sport    = "Sport"
    case date     = "Date"

    var icon: String {
        switch self {
        case .casual:  return "sun.max.fill"
        case .work:    return "briefcase.fill"
        case .evening: return "moon.stars.fill"
        case .gala:    return "sparkles"
        case .beach:   return "beach.umbrella.fill"
        case .wedding: return "heart.fill"
        case .sport:   return "figure.run"
        case .date:    return "flame.fill"
        }
    }

    var styleKeywords: String {
        switch self {
        case .casual:  return "casual chic, relaxed, everyday elegance"
        case .work:    return "professional, polished, business attire"
        case .evening: return "evening wear, sophisticated, glamorous"
        case .gala:    return "black tie, couture, ultra-luxury, red carpet"
        case .beach:   return "resort wear, breezy, sun-kissed, summery"
        case .wedding: return "bridal, romantic, timeless, ethereal"
        case .sport:   return "active, sleek, performance luxury"
        case .date:    return "romantic, alluring, feminine, intimate"
        }
    }
}

// MARK: - FashionItemRef — Référence légère à un item

struct FashionItemRef: Codable, Hashable {
    let itemId: UUID
    let name: String
    let category: String
    let icon: String
    let prompt: String

    init(from item: FashionItem) {
        self.itemId   = item.id
        self.name     = item.name
        self.category = item.category.rawValue
        self.icon     = item.category.icon
        self.prompt   = item.tryOnPrompt
    }
}
