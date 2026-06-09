import Foundation

// MARK: - MoodBoard Model

struct MoodBoard: Identifiable, Codable {
    var id: String
    var title: String
    var prompt: String
    var occasion: String
    var style: String
    var jewelryItems: [JewelryItem]
    var generatedDescription: String
    var colorPalette: [String]  // hex colors
    var keywords: [String]
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        prompt: String,
        occasion: String = "",
        style: String = "",
        jewelryItems: [JewelryItem] = [],
        generatedDescription: String = "",
        colorPalette: [String] = [],
        keywords: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.occasion = occasion
        self.style = style
        self.jewelryItems = jewelryItems
        self.generatedDescription = generatedDescription
        self.colorPalette = colorPalette
        self.keywords = keywords
        self.createdAt = createdAt
    }
}

// MARK: - Selection Enums

enum MoodOccasion: String, CaseIterable {
    case soiree   = "Soirée"
    case mariage  = "Mariage"
    case quotidien = "Quotidien"
    case plage    = "Plage"
    case business = "Business"
    case gala     = "Gala"
    case voyage   = "Voyage"
    case date     = "Date"

    var icon: String {
        switch self {
        case .soiree:    return "moon.stars.fill"
        case .mariage:   return "heart.fill"
        case .quotidien: return "sun.max.fill"
        case .plage:     return "beach.umbrella.fill"
        case .business:  return "briefcase.fill"
        case .gala:      return "crown.fill"
        case .voyage:    return "airplane"
        case .date:      return "flame.fill"
        }
    }
}

enum MoodStyle: String, CaseIterable {
    case minimaliste  = "Minimaliste"
    case boheme       = "Bohème"
    case classique    = "Classique"
    case modern       = "Modern"
    case vintage      = "Vintage"
    case romantique   = "Romantique"
    case sportyChic   = "Sporty Chic"
    case avantGarde   = "Avant-garde"

    var icon: String {
        switch self {
        case .minimaliste: return "minus.circle"
        case .boheme:      return "leaf.fill"
        case .classique:   return "building.columns"
        case .modern:      return "square.fill"
        case .vintage:     return "clock.fill"
        case .romantique:  return "heart.circle.fill"
        case .sportyChic:  return "bolt.fill"
        case .avantGarde:  return "sparkles"
        }
    }
}

enum MoodSeason: String, CaseIterable {
    case printemps = "Printemps"
    case ete       = "Été"
    case automne   = "Automne"
    case hiver     = "Hiver"

    var icon: String {
        switch self {
        case .printemps: return "camera.macro"
        case .ete:       return "sun.max.fill"
        case .automne:   return "leaf.fill"
        case .hiver:     return "snowflake"
        }
    }

    var palette: [String] {
        switch self {
        case .printemps: return ["#FECDD3", "#BBF7D0", "#FEF3C7", "#DDD6FE"]
        case .ete:       return ["#FEF9C3", "#BAE6FD", "#A7F3D0", "#FFE4E6"]
        case .automne:   return ["#78350F", "#B45309", "#CA8A04", "#D97706"]
        case .hiver:     return ["#1E3A5F", "#374151", "#6B7280", "#E5E7EB"]
        }
    }
}
