import Foundation

// MARK: - BodyContext — Contexte corporel extrait de la photo utilisateur

struct BodyContext: Sendable {

    // MARK: Peau
    var skinTone: SkinToneLevel
    var skinUndertone: SkinUndertone
    var skinHex: String            // Couleur hex approx. de la peau ex. "#C68642"

    // MARK: Morphologie
    var bodyShape: BodyShape
    var estimatedHeight: HeightRange
    var shoulderWidth: ShoulderWidth

    // MARK: Eclairage
    var lightingType: LightingType
    var lightingDirection: LightingDirection
    var brightnessLevel: Double         // 0.0 (sombre) → 1.0 (très lumineux)
    var colorTemperature: ColorTemperature

    // MARK: Vetements portes
    var detectedClothing: [DetectedGarment]

    // MARK: Prompts construits
    var promptContext: String           // Résumé textuel pour GPT Image 2.0
    var transitionInstructions: String  // Instructions de transition pour le nouveau vêtement

    // MARK: - Default (fallback si analyse impossible)

    static var `default`: BodyContext {
        BodyContext(
            skinTone: .medium,
            skinUndertone: .neutral,
            skinHex: "#C68642",
            bodyShape: .hourglass,
            estimatedHeight: .medium,
            shoulderWidth: .medium,
            lightingType: .natural,
            lightingDirection: .front,
            brightnessLevel: 0.65,
            colorTemperature: .neutral,
            detectedClothing: [],
            promptContext: "Fashion editorial photograph of a woman with medium warm-toned skin.",
            transitionInstructions: "Maintain natural skin texture and body proportions from reference photo."
        )
    }
}

// MARK: - SkinToneLevel

enum SkinToneLevel: String, Sendable {
    case fair   = "fair"
    case light  = "light"
    case medium = "medium"
    case tan    = "tan"
    case deep   = "deep"

    var description: String {
        switch self {
        case .fair:   return "fair porcelain skin"
        case .light:  return "light skin"
        case .medium: return "medium skin"
        case .tan:    return "tan skin"
        case .deep:   return "deep rich skin"
        }
    }
}

// MARK: - SkinUndertone

enum SkinUndertone: String, Sendable {
    case warm    = "warm"
    case cool    = "cool"
    case neutral = "neutral"

    var adjective: String {
        switch self {
        case .warm:    return "warm-toned"
        case .cool:    return "cool-toned"
        case .neutral: return "neutral-toned"
        }
    }
}

// MARK: - BodyShape

enum BodyShape: String, Sendable {
    case pear             = "pear-shaped body"
    case hourglass        = "hourglass figure"
    case rectangle        = "rectangular body type"
    case apple            = "apple-shaped body"
    case invertedTriangle = "inverted triangle body type"
}

// MARK: - HeightRange

enum HeightRange: String, Sendable {
    case petite = "petite frame"
    case medium = "average height"
    case tall   = "tall frame"
}

// MARK: - ShoulderWidth

enum ShoulderWidth: String, Sendable {
    case narrow = "narrow shoulders"
    case medium = "medium shoulder width"
    case broad  = "broad shoulders"
}

// MARK: - LightingType

enum LightingType: String, Sendable {
    case natural  = "natural daylight"
    case studio   = "studio lighting"
    case indoor   = "indoor ambient light"
    case outdoor  = "outdoor sunlight"
    case dark     = "low light environment"
}

// MARK: - LightingDirection

enum LightingDirection: String, Sendable {
    case front   = "front"
    case left    = "left"
    case right   = "right"
    case top     = "top"
    case backlit = "back"

    var description: String {
        switch self {
        case .front:   return "from the front"
        case .left:    return "from the left"
        case .right:   return "from the right"
        case .top:     return "from above"
        case .backlit: return "backlit"
        }
    }
}

// MARK: - ColorTemperature

enum ColorTemperature: String, Sendable {
    case warm    = "warm"
    case cool    = "cool"
    case neutral = "neutral"

    var description: String {
        switch self {
        case .warm:    return "Warm color temperature"
        case .cool:    return "Cool color temperature"
        case .neutral: return "Neutral color temperature"
        }
    }
}

// MARK: - DetectedGarment

struct DetectedGarment: Sendable {
    var type: GarmentType
    var description: String     // ex. "blue jeans", "white sneakers"
    var isBeingReplaced: Bool
}

// MARK: - GarmentType

enum GarmentType: String, Sendable {
    case top         = "top"
    case bottom      = "bottom"
    case dress       = "dress"
    case shoes       = "shoes"
    case jacket      = "jacket"
    case accessory   = "accessory"
    case underwear   = "underwear"

    /// Traduit un FashionCategory vers GarmentType
    static func from(fashionCategory: FashionCategory) -> GarmentType {
        switch fashionCategory {
        case .top, .suit:                           return .top
        case .bottom:                               return .bottom
        case .dress:                                return .dress
        case .jacket, .coat:                        return .jacket
        case .heels, .flats, .boots, .sneakers, .sandals, .loafers: return .shoes
        case .ring, .necklace, .earring, .bracelet, .watch, .brooch,
             .bag, .sunglasses, .hat, .scarf, .belt, .gloves,
             .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing: return .accessory
        }
    }
}
