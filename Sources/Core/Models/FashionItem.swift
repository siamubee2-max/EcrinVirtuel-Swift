import Foundation
import SwiftUI

// MARK: - FashionItem — Modèle universel garde-robe

struct FashionItem: Identifiable, Codable, Equatable {
    static func == (lhs: FashionItem, rhs: FashionItem) -> Bool { lhs.id == rhs.id }
    let id: UUID
    var name: String
    var category: FashionCategory
    var subcategory: String?
    var brand: String?
    var color: String?
    var material: String?
    var imageURL: URL?
    var tags: [String]
    var tryOnPrompt: String
    var source: ItemSource
    var price: Double?
    var purchaseURL: String?
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: FashionCategory,
        subcategory: String? = nil,
        brand: String? = nil,
        color: String? = nil,
        material: String? = nil,
        imageURL: URL? = nil,
        tags: [String] = [],
        tryOnPrompt: String = "",
        source: ItemSource = .userPhoto,
        price: Double? = nil,
        purchaseURL: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.color = color
        self.material = material
        self.imageURL = imageURL
        self.tags = tags
        self.tryOnPrompt = tryOnPrompt.isEmpty ? category.defaultPrompt(name: name) : tryOnPrompt
        self.source = source
        self.price = price
        self.purchaseURL = purchaseURL
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    // La photo de l'utilisateur n'est PAS une propriété de ce modèle : elle vit
    // dans un fichier nommé par `id`, via `WardrobePhotoStore`. Elle ne transite
    // donc ni par `UserDefaults` ni par `Codable`.
    //
    // Aucune propriété calculée ne la ramène ici volontairement : elle lirait le
    // disque de façon synchrone sur le thread de son appelant, thread principal
    // compris. Pour AFFICHER : `WardrobePhotoStore.shared.image(for: item.id)`.
    // Pour GÉNÉRER : `ImageGenerationService.localReferenceData(for: item.id)`.

    /// URL d'affichage : URL réelle > stock URL Unsplash par catégorie.
    /// Garantit qu'on a toujours une image à afficher (la photo de l'utilisateur,
    /// elle, se lit par `WardrobePhotoStore.shared.image(for: item.id)`).
    var displayImageURL: URL? {
        if let url = imageURL { return url }
        return category.stockImageURL
    }
}

// MARK: - FashionCategory

enum FashionCategory: String, CaseIterable, Codable {
    // Bijoux
    case ring       = "Bague"
    case necklace   = "Collier"
    case earring    = "Boucles"
    case bracelet   = "Bracelet"
    case watch      = "Montre"
    case brooch     = "Broche"
    // Piercings
    case nosePiercing    = "Piercing Nez"
    case eyebrowPiercing = "Piercing Arcade"
    case lipPiercing     = "Piercing Lèvre"
    case tonguePiercing  = "Piercing Langue"
    // Vêtements
    case top        = "Haut"
    case bottom     = "Bas"
    case dress      = "Robe"
    case jacket     = "Veste"
    case coat       = "Manteau"
    case suit       = "Tailleur"
    // Chaussures
    case heels      = "Talons"
    case flats      = "Ballerines"
    case boots      = "Bottes"
    case sneakers   = "Sneakers"
    case sandals    = "Sandales"
    case loafers    = "Mocassins"
    // Accessoires
    case bag        = "Sac"
    case sunglasses = "Lunettes"
    case hat        = "Chapeau"
    case scarf      = "Écharpe"
    case belt       = "Ceinture"
    case gloves     = "Gants"

    var group: FashionGroup {
        switch self {
        case .ring, .necklace, .earring, .bracelet, .watch, .brooch,
             .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing:
            return .jewelry
        case .top, .bottom, .dress, .jacket, .coat, .suit:
            return .clothing
        case .heels, .flats, .boots, .sneakers, .sandals, .loafers:
            return .shoes
        case .bag, .sunglasses, .hat, .scarf, .belt, .gloves:
            return .accessories
        }
    }

    var icon: String {
        switch self {
        case .ring:       return "circle.hexagongrid.fill"
        case .necklace:   return "link"
        case .earring:    return "oval.fill"
        case .bracelet:   return "circle"
        case .watch:      return "applewatch"
        case .brooch:          return "diamond.fill"
        case .nosePiercing:    return "circle.fill"
        case .eyebrowPiercing: return "minus.circle.fill"
        case .lipPiercing:     return "moon.fill"
        case .tonguePiercing:  return "capsule.fill"
        case .top:        return "tshirt.fill"
        case .bottom:     return "figure.walk"
        case .dress:      return "figure.stand.dress"
        case .jacket:     return "cloud.fill"
        case .coat:       return "wind"
        case .suit:       return "person.fill"
        case .heels:      return "figure.walk.treadmill"
        case .flats:      return "shoe.fill"
        case .boots:      return "boot.fill"
        case .sneakers:   return "shoe"
        case .sandals:    return "leaf.fill"
        case .loafers:    return "shoe.2.fill"
        case .bag:        return "bag.fill"
        case .sunglasses: return "eyeglasses"
        case .hat:        return "theatermask.fill"
        case .scarf:      return "tornado"
        case .belt:       return "minus"
        case .gloves:     return "hand.raised.fill"
        }
    }

    /// URL Unsplash de stock par catégorie — utilisée comme fallback quand
    /// l'item n'a ni `imageURL` ni photo sur disque. Garantit une vraie photo
    /// au lieu d'une icône SF Symbol grise.
    var stockImageURL: URL? {
        let unsplashID: String? = switch self {
        // Vêtements
        case .top:        "1556905055-8f358a7a47b2" // chemisier blanc plié
        case .bottom:     "1542272604-787c3835535d" // pantalon
        case .dress:      "1539109136881-3be0616acf4b" // robe noire
        case .jacket:     "1551028719-00167b16eac5" // veste denim
        case .coat:       "1544022613-e87ca75a784a" // manteau
        case .suit:       "1594938298603-c8148c4dae35" // costume
        // Chaussures
        case .heels:      "1543163521-1bf539c55dd2" // talons
        case .flats:      "1535043934128-cf0b28d52f95" // ballerines
        case .boots:      "1542838132-92c53300491e" // bottes
        case .sneakers:   "1542291026-7eec264c27ff" // sneakers
        case .sandals:    "1603487742131-4160ec999306" // sandales
        case .loafers:    "1581873372796-635b67ca2008" // mocassins
        // Bijoux
        case .ring:            "1605100804763-247f67b3557e"
        case .necklace:        "1599643478518-a784e5dc4c8f"
        case .earring:         "1535632066927-ab7c9ab60908"
        case .bracelet:        "1611652022419-a9419f74343d"
        case .watch:           "1524805444758-089113d48a6d"
        case .brooch:          "1599643478518-a784e5dc4c8f"
        case .nosePiercing:    "1583292650898-7d22cd27ca6f"
        case .eyebrowPiercing: "1564859228273-274232fdb516"
        case .lipPiercing:     "1551589273-86b9d9d5e1e0"
        case .tonguePiercing:  "1577037834103-31fcdbdda03e"
        // Accessoires
        case .bag:        "1591561954557-26941169b49e" // sac
        case .sunglasses: "1572635196237-14b3f281503f" // lunettes
        case .hat:        "1521369909029-2afed882baee" // chapeau
        case .scarf:      "1601925260368-ae2f83cf8b7f" // écharpe
        case .belt:       "1624222247344-550fb60583dc" // ceinture
        case .gloves:     nil
        }
        guard let id = unsplashID else { return nil }
        return URL(string: "https://images.unsplash.com/photo-\(id)?w=600&q=85&auto=format&fit=crop")
    }

    var bodyZone: BodyZone {
        switch self {
        case .ring:                          return .finger
        case .necklace, .brooch:            return .neck
        case .earring:                       return .ears
        case .bracelet, .watch:              return .wrist
        case .top, .jacket, .coat, .suit:   return .fullBody
        case .bottom:                        return .legs
        case .dress:                         return .fullBody
        case .heels, .flats, .boots, .sneakers, .sandals, .loafers: return .feet
        case .bag:                           return .fullBody
        case .sunglasses:                    return .face
        case .hat:                           return .head
        case .scarf:                         return .neck
        case .belt, .gloves:                 return .waist
        case .nosePiercing:                  return .nose
        case .eyebrowPiercing:               return .eyebrow
        case .lipPiercing:                   return .lip
        case .tonguePiercing:                return .tongue
        }
    }

    func defaultPrompt(name: String) -> String {
        switch group {
        case .jewelry:
            switch self {
            case .nosePiercing:
                return "person wearing \(name) nose ring, close-up portrait, natural light, minimal background"
            case .eyebrowPiercing:
                return "person with \(name) eyebrow barbell piercing, close-up portrait, natural light"
            case .lipPiercing:
                return "person with \(name) lip ring, close-up portrait, natural light"
            case .tonguePiercing:
                return "person with \(name) tongue barbell, mouth slightly open, close-up, natural light"
            default:
                return "add the \(name) \(rawValue.lowercased()) worn on the person, realistic scale, close-up on the jewelry zone"
            }
        // Descriptions volontairement SANS décor ni « editorial/luxury » : on décrit
        // seulement l'article ajouté, la photo de départ (fond, lumière) est conservée.
        case .clothing:
            switch self {
            case .top, .jacket, .coat, .suit:
                return "dress the person in a \(name) \(rawValue.lowercased()), realistic fit"
            case .bottom:
                return "dress the person in \(name) \(rawValue.lowercased()), realistic fit, full body"
            case .dress:
                return "dress the person in a \(name) dress, realistic fit, full body"
            default:
                return "dress the person in \(name), realistic fit"
            }
        case .shoes:
            return "put \(name) \(rawValue.lowercased()) on the person's feet, feet visible, realistic fit"
        case .accessories:
            switch self {
            case .bag:
                return "add a \(name) bag carried by the person, realistic scale"
            case .sunglasses:
                return "add \(name) sunglasses on the person's face, realistic fit"
            case .hat:
                return "add a \(name) hat on the person's head, realistic fit"
            case .scarf:
                return "add a \(name) scarf on the person, realistic drape"
            default:
                return "add \(name) \(rawValue.lowercased()) worn by the person, realistic scale"
            }
        }
    }
}

// MARK: - FashionGroup

enum FashionGroup: String, CaseIterable, Codable {
    case jewelry     = "Bijoux"
    case clothing    = "Vêtements"
    case shoes       = "Chaussures"
    case accessories = "Accessoires"

    var icon: String {
        switch self {
        case .jewelry:     return "diamond.fill"
        case .clothing:    return "tshirt.fill"
        case .shoes:       return "shoe.fill"
        case .accessories: return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .jewelry:     return Color(hex: "#C8A85A")  // champagne (aligné EcrinColor.gold)
        case .clothing:    return Color(hex: "#6366F1")
        case .shoes:       return Color(hex: "#EC4899")
        case .accessories: return Color(hex: "#14B8A6")
        }
    }

    var categories: [FashionCategory] {
        FashionCategory.allCases.filter { $0.group == self }
    }
}

// MARK: - BodyZone

enum BodyZone: String, Codable {
    case face, ears, neck, wrist, finger, waist, legs, feet, fullBody, hands, head
    case nose, eyebrow, lip, tongue
}

// MARK: - ItemSource

enum ItemSource: String, Codable {
    case userPhoto    // uploadé par l'utilisateur depuis sa garde-robe
    case catalog      // catalogue boutique partenaire
    case generated    // créé par l'IA Styliste
}

// MARK: - ShootingAngle (partagé entre ShoesTryOnView et ImageGenerationService)

enum ShootingAngle: String, CaseIterable {
    case front = "Face"
    case side  = "Profil"
    case down  = "Vue du dessus"

    var icon: String {
        switch self {
        case .front: return "arrow.down.to.line"
        case .side:  return "arrow.right.to.line"
        case .down:  return "arrow.up.and.down.circle"
        }
    }
}

// MARK: - Sample Data

extension FashionItem {
    // Garde-robe d'exemple sans marques de luxe.
    // Bijoux = fantaisie en pierres semi-précieuses (style Moni'attitude).
    // Vêtements / chaussures / accessoires = descriptions matière sans label.

    /// Articles vêtements + chaussures de la garde-robe démo.
    /// Utilisés par WeatherLookRecommender pour proposer des tenues mixant
    /// la garde-robe de l'utilisateur et le catalogue.
    static var clothingSamples: [FashionItem] {
        samples.filter { $0.category.group == .clothing || $0.category.group == .shoes }
    }

    static let samples: [FashionItem] = [
        // BIJOUX (fantaisie, pierres semi-précieuses)
        FashionItem(name: "Bague Améthyste Brute", category: .ring,
                    color: "Violet", material: "Laiton doré · Améthyste",
                    tags: ["wellness", "boho"], source: .catalog, price: nil, isFavorite: true),
        FashionItem(name: "Sautoir Pierre de Lune", category: .necklace,
                    color: "Iridescent", material: "Argent 925 · Pierre de lune",
                    tags: ["wellness", "artisanal"], source: .catalog),
        FashionItem(name: "Créoles Quartz Rose", category: .earring,
                    color: "Rose", material: "Argent 925 · Quartz rose",
                    tags: ["quotidien", "boho"], source: .userPhoto),
        FashionItem(name: "Bracelet Mala Cristal", category: .bracelet,
                    color: "Transparent", material: "Élastique · Cristal de roche",
                    tags: ["wellness"], source: .userPhoto, isFavorite: true),
        FashionItem(name: "Montre Cuir Naturel", category: .watch,
                    color: "Cognac", material: "Cuir · Acier brossé",
                    tags: ["quotidien"], source: .catalog),
        FashionItem(name: "Broche Émail Fleur", category: .brooch,
                    color: "Vert", material: "Laiton · Émail",
                    tags: ["vintage"], source: .userPhoto),

        // VÊTEMENTS (sans marque)
        FashionItem(name: "Chemise Blanche", category: .top,
                    color: "Blanc", material: "Coton bio",
                    tags: ["classique", "bureau"], source: .userPhoto),
        FashionItem(name: "Blazer Crème", category: .jacket,
                    color: "Crème", material: "Laine mérinos",
                    tags: ["chic", "bureau"], source: .catalog, price: nil, isFavorite: true),
        FashionItem(name: "Robe Midi Noire", category: .dress,
                    color: "Noir", material: "Satin",
                    tags: ["soirée", "élégant"], source: .userPhoto, isFavorite: true),
        FashionItem(name: "Pantalon Palazzo", category: .bottom,
                    color: "Camel", material: "Laine",
                    tags: ["confort", "chic"], source: .catalog),
        FashionItem(name: "Manteau Camel", category: .coat,
                    color: "Camel", material: "Cachemire",
                    tags: ["hiver"], source: .catalog),
        FashionItem(name: "Tailleur Ivoire", category: .suit,
                    color: "Ivoire", material: "Tweed",
                    tags: ["mariage"], source: .catalog),

        // CHAUSSURES (sans marque)
        FashionItem(name: "Escarpins Nude", category: .heels,
                    color: "Nude", material: "Cuir",
                    tags: ["soirée", "classique"], source: .catalog),
        FashionItem(name: "Ballerines Dorées", category: .flats,
                    color: "Or", material: "Cuir verni",
                    tags: ["quotidien"], source: .userPhoto, isFavorite: true),
        FashionItem(name: "Bottes Chelsea", category: .boots,
                    color: "Noir", material: "Cuir grainé",
                    tags: ["hiver", "chic"], source: .catalog),
        FashionItem(name: "Sneakers Blanches", category: .sneakers,
                    color: "Blanc", material: "Coton organique · Cuir",
                    tags: ["casual"], source: .userPhoto),
        FashionItem(name: "Sandales Dorées", category: .sandals,
                    color: "Or", material: "Cuir tressé",
                    tags: ["été", "fête"], source: .userPhoto, isFavorite: true),
        FashionItem(name: "Mocassins Bordeaux", category: .loafers,
                    color: "Bordeaux", material: "Cuir",
                    tags: ["chic", "bureau"], source: .catalog),

        // ACCESSOIRES (sans marque)
        FashionItem(name: "Sac à Main Camel", category: .bag,
                    color: "Camel", material: "Cuir naturel",
                    tags: ["quotidien", "élégant"], source: .catalog, price: nil, isFavorite: true),
        FashionItem(name: "Lunettes Cat-Eye", category: .sunglasses,
                    color: "Noir", material: "Acétate",
                    tags: ["été", "glamour"], source: .userPhoto),
        FashionItem(name: "Chapeau Capeline", category: .hat,
                    color: "Beige", material: "Paille naturelle",
                    tags: ["été", "plage"], source: .userPhoto),
        FashionItem(name: "Foulard Soie", category: .scarf,
                    color: "Multicolore", material: "Soie 90cm",
                    tags: ["classique"], source: .catalog, isFavorite: true),
        FashionItem(name: "Ceinture Tressée", category: .belt,
                    color: "Camel", material: "Cuir tressé",
                    tags: ["classique"], source: .userPhoto),
        FashionItem(name: "Gants Cuir Noir", category: .gloves,
                    color: "Noir", material: "Cuir agneau",
                    tags: ["hiver", "élégant"], source: .userPhoto),

        // PIERCINGS (semi-précieux, fantaisie)
        FashionItem(name: "Anneau Nez Opale", category: .nosePiercing,
                    color: "Iridescent", material: "Argent 925 · Opale",
                    tags: ["piercing", "boho", "wellness"], source: .userPhoto),
        FashionItem(name: "Barbell Arcade Améthyste", category: .eyebrowPiercing,
                    color: "Violet", material: "Acier chirurgical · Améthyste",
                    tags: ["piercing", "boho"], source: .userPhoto),
        FashionItem(name: "Anneau Lèvre Citrine", category: .lipPiercing,
                    color: "Jaune doré", material: "Plaqué or · Citrine",
                    tags: ["piercing", "bold"], source: .userPhoto),
        FashionItem(name: "Barbell Langue Quartz Rose", category: .tonguePiercing,
                    color: "Rose", material: "Acier · Quartz rose",
                    tags: ["piercing", "wellness"], source: .userPhoto),
    ]
}
