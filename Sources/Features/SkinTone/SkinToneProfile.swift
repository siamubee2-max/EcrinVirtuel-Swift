import Foundation

// MARK: - Skin Tone Models

struct SkinToneProfile: Codable, Equatable {
    var undertone: Undertone
    var depth: SkinDepth
    var recommendedMetals: [MetalRecommendation]
    var avoidMetals: [String]
    var powerStones: [String]

    var undertoneLabel: String {
        switch undertone {
        case .warm:    return "Chaud"
        case .cool:    return "Froid"
        case .neutral: return "Neutre"
        }
    }

    var undertoneDescription: String {
        switch undertone {
        case .warm:
            return "Votre teint révèle des reflets dorés et pêche. L'or chaud sublimera chaque éclat de votre peau."
        case .cool:
            return "Votre carnation porte des nuances rosées et bleutées. Les métaux froids exaltent votre lumière naturelle."
        case .neutral:
            return "Votre peau possède un équilibre rare entre chaud et froid. Tous les métaux précieux vous honorent."
        }
    }

    var undertoneColor: String {
        switch undertone {
        case .warm:    return "#CA8A04"
        case .cool:    return "#7DD3FC"
        case .neutral: return "#A78BFA"
        }
    }

    var topMetal: MetalRecommendation? {
        recommendedMetals.max(by: { $0.score < $1.score })
    }
}

enum Undertone: String, Codable, CaseIterable {
    case warm    = "warm"
    case cool    = "cool"
    case neutral = "neutral"
}

enum SkinDepth: String, CaseIterable, Codable {
    case fair   = "Claire"
    case light  = "Lumineuse"
    case medium = "Mate"
    case tan    = "Dorée"
    case deep   = "Profonde"

    var poeticDescription: String {
        switch self {
        case .fair:   return "Une peau d'une clarté laiteuse, délicate comme la nacre."
        case .light:  return "Une carnation lumineuse aux reflets translucides."
        case .medium: return "Une teinte mate et veloutée, d'une beauté solaire."
        case .tan:    return "Un teint doré, vibrant comme le sable chaud."
        case .deep:   return "Une peau profonde et riche, d'une intensité magnétique."
        }
    }
}

struct MetalRecommendation: Identifiable, Codable, Equatable {
    let id: String
    let metal: String
    let reason: String
    let score: Int // 1-5
    let icon: String

    var stars: [Bool] {
        (1...5).map { $0 <= score }
    }
}
