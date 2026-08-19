import Foundation
import SwiftUI

// MARK: - ClothingGender

enum ClothingGender: String, CaseIterable, Codable, Sendable {
    case femme
    case homme
    case unisexe

    var label: String {
        switch self {
        case .femme:   return "Femme"
        case .homme:   return "Homme"
        case .unisexe: return "Unisexe"
        }
    }

    var icon: String {
        switch self {
        case .femme:   return "figure.stand.dress"
        case .homme:   return "figure.stand"
        case .unisexe: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .femme:   return Color(hex: "#EC4899")
        case .homme:   return Color(hex: "#3B82F6")
        case .unisexe: return Color(hex: "#CA8A04")
        }
    }
}

// MARK: - ClothingCategoryGroup

enum ClothingCategoryGroup: String, CaseIterable, Sendable {
    case all       = "Tous"
    case top       = "Hauts"
    case bottom    = "Bas"
    case dress     = "Robes"
    case jacket    = "Vestes"
    case coat      = "Manteaux"
    case shoes     = "Chaussures"
    case bag       = "Sacs"
    case accessory = "Accessoires"

    var rawKey: String? {
        switch self {
        case .all:       return nil
        case .top:       return "top"
        case .bottom:    return "bottom"
        case .dress:     return "dress"
        case .jacket:    return "jacket"
        case .coat:      return "coat"
        case .shoes:     return "shoes"
        case .bag:       return "bag"
        case .accessory: return "accessory"
        }
    }

    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2.fill"
        case .top:       return "tshirt.fill"
        case .bottom:    return "figure.walk"
        case .dress:     return "figure.stand.dress"
        case .jacket:    return "cloud.fill"
        case .coat:      return "wind"
        case .shoes:     return "shoe.fill"
        case .bag:       return "bag.fill"
        case .accessory: return "eyeglasses"
        }
    }
}

// MARK: - CatalogClothingItem

struct CatalogClothingItem: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let gender: ClothingGender
    let category: String
    let subcategory: String?
    let brand: String?
    let color: String?
    let material: String?
    let styleTags: [String]
    let season: [String]
    let imageURL: URL?
    let tryOnPrompt: String
    let isFeatured: Bool
    let priceEur: Double?
    let purchaseURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, gender, category, subcategory, brand, color, material, season
        case styleTags   = "style_tags"
        case imageURL    = "image_url"
        case tryOnPrompt = "try_on_prompt"
        case isFeatured  = "is_featured"
        case priceEur    = "price_eur"
        case purchaseURL = "purchase_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        gender = try c.decode(ClothingGender.self, forKey: .gender)
        category = try c.decode(String.self, forKey: .category)
        subcategory = try c.decodeIfPresent(String.self, forKey: .subcategory)
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        material = try c.decodeIfPresent(String.self, forKey: .material)
        styleTags = try c.decodeIfPresent([String].self, forKey: .styleTags) ?? []
        season = try c.decodeIfPresent([String].self, forKey: .season) ?? []
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL).flatMap { URL(string: $0) }
        tryOnPrompt = try c.decodeIfPresent(String.self, forKey: .tryOnPrompt) ?? name
        isFeatured = try c.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        priceEur = try c.decodeFlexibleDouble(forKey: .priceEur)
        purchaseURL = try c.decodeIfPresent(String.self, forKey: .purchaseURL)
    }

    init(
        id: UUID,
        name: String,
        gender: ClothingGender,
        category: String,
        subcategory: String?,
        brand: String?,
        color: String?,
        material: String?,
        styleTags: [String],
        season: [String],
        imageURL: URL?,
        tryOnPrompt: String,
        isFeatured: Bool,
        priceEur: Double?,
        purchaseURL: String?
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.category = category
        self.subcategory = subcategory
        self.brand = brand
        self.color = color
        self.material = material
        self.styleTags = styleTags
        self.season = season
        self.imageURL = imageURL
        self.tryOnPrompt = tryOnPrompt
        self.isFeatured = isFeatured
        self.priceEur = priceEur
        self.purchaseURL = purchaseURL
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(gender, forKey: .gender)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(subcategory, forKey: .subcategory)
        try c.encodeIfPresent(brand, forKey: .brand)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(material, forKey: .material)
        try c.encode(styleTags, forKey: .styleTags)
        try c.encode(season, forKey: .season)
        try c.encodeIfPresent(imageURL?.absoluteString, forKey: .imageURL)
        try c.encode(tryOnPrompt, forKey: .tryOnPrompt)
        try c.encode(isFeatured, forKey: .isFeatured)
        try c.encodeIfPresent(priceEur, forKey: .priceEur)
        try c.encodeIfPresent(purchaseURL, forKey: .purchaseURL)
    }

    /// URL d'affichage avec fallback stock par catégorie quand `imageURL` est nil.
    var displayImageURL: URL? {
        if let url = imageURL { return url }
        return resolvedFashionCategory.stockImageURL
    }

    // Conversion vers FashionItem pour l'Outfit Builder
    var asFashionItem: FashionItem {
        FashionItem(
            id: id,
            name: name,
            category: resolvedFashionCategory,
            subcategory: subcategory,
            brand: brand,
            color: color,
            material: material,
            imageURL: imageURL,
            tags: styleTags,
            tryOnPrompt: tryOnPrompt,
            source: .catalog,
            price: priceEur,
            purchaseURL: purchaseURL
        )
    }

    private var resolvedFashionCategory: FashionCategory {
        switch category {
        case "top":       return .top
        case "bottom":    return .bottom
        case "dress":     return .dress
        case "jacket":    return .jacket
        case "coat":      return .coat
        case "shoes":
            if let sub = subcategory?.lowercased() {
                if sub.contains("boot")  { return .boots }
                if sub.contains("sandal") { return .sandals }
                if sub.contains("escarp") || sub.contains("talon") { return .heels }
                if sub.contains("mocassin") || sub.contains("loafer") { return .loafers }
            }
            return .sneakers
        case "bag":       return .bag
        case "accessory":
            if let sub = subcategory?.lowercased() {
                if sub.contains("lunette") { return .sunglasses }
                if sub.contains("ceinture") { return .belt }
                if sub.contains("chapeau") || sub.contains("bonnet") || sub.contains("casquette") { return .hat }
                if sub.contains("écharpe") || sub.contains("foulard") { return .scarf }
            }
            return .scarf
        default:          return .top
        }
    }

    // Couleur de fond de la carte basée sur `color`
    var cardBackgroundColor: Color {
        guard let col = color?.lowercased() else { return Color.white.opacity(0.05) }
        switch true {
        case col.contains("noir") || col.contains("black"):
            return Color.white.opacity(0.04)
        case col.contains("blanc") || col.contains("white") || col.contains("écru") || col.contains("ivoire"):
            return Color(hex: "#F5F5F0").opacity(0.08)
        case col.contains("beige") || col.contains("camel") || col.contains("nude") || col.contains("sable"):
            return Color(hex: "#D4B896").opacity(0.15)
        case col.contains("gris") || col.contains("anthracite") || col.contains("chiné"):
            return Color(hex: "#9CA3AF").opacity(0.12)
        case col.contains("bleu") || col.contains("navy") || col.contains("marine") || col.contains("indigo"):
            return Color(hex: "#3B82F6").opacity(0.15)
        case col.contains("rouge") || col.contains("bordeaux"):
            return Color(hex: "#EF4444").opacity(0.15)
        case col.contains("vert") || col.contains("kaki") || col.contains("sauge") || col.contains("olive"):
            return Color(hex: "#22C55E").opacity(0.12)
        case col.contains("rose") || col.contains("pink"):
            return Color(hex: "#EC4899").opacity(0.15)
        case col.contains("or ") || col.contains("gold") || col.contains("doré") || col == "or":
            return Color(hex: "#CA8A04").opacity(0.18)
        case col.contains("marron") || col.contains("cognac") || col.contains("brun"):
            return Color(hex: "#92400E").opacity(0.15)
        case col.contains("multicolore"):
            return Color(hex: "#8B5CF6").opacity(0.12)
        default:
            return Color.white.opacity(0.06)
        }
    }

    var categoryIcon: String {
        ClothingCategoryGroup.allCases
            .first { $0.rawKey == category }?.icon ?? "tag.fill"
    }

    var formattedPrice: String? {
        guard let price = priceEur else { return nil }
        return String(format: "%.0f €", price)
    }
}

// MARK: - Preview Data

extension CatalogClothingItem {

    // MARK: Mock samples — used only under -uitest (zero live backend)
    static let samples: [CatalogClothingItem] = [
        // Femme ×2
        CatalogClothingItem(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!,
            name: "Robe Cocktail Noire",
            gender: .femme,
            category: "dress",
            subcategory: "robe cocktail",
            brand: nil,
            color: "noir",
            material: "crêpe",
            styleTags: ["soirée", "élégant"],
            season: ["automne", "hiver"],
            imageURL: nil,
            tryOnPrompt: "wearing a sleek black cocktail dress, midi length, architectural cut",
            isFeatured: true,
            priceEur: nil,
            purchaseURL: nil
        ),
        CatalogClothingItem(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000002")!,
            name: "Blouse Soie Ivoire",
            gender: .femme,
            category: "top",
            subcategory: "blouse",
            brand: nil,
            color: "ivoire",
            material: "soie",
            styleTags: ["bureau", "chic"],
            season: ["printemps", "été"],
            imageURL: nil,
            tryOnPrompt: "wearing an ivory silk blouse, relaxed fit, editorial fashion",
            isFeatured: false,
            priceEur: nil,
            purchaseURL: nil
        ),
        // Homme ×2
        CatalogClothingItem(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000003")!,
            name: "Blazer Navy",
            gender: .homme,
            category: "jacket",
            subcategory: "blazer",
            brand: nil,
            color: "bleu marine",
            material: "laine",
            styleTags: ["bureau", "élégant"],
            season: ["printemps", "automne"],
            imageURL: nil,
            tryOnPrompt: "wearing a tailored navy blue wool blazer, single button, notched lapel",
            isFeatured: true,
            priceEur: nil,
            purchaseURL: nil
        ),
        CatalogClothingItem(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000004")!,
            name: "Chino Beige",
            gender: .homme,
            category: "bottom",
            subcategory: "chino",
            brand: nil,
            color: "beige",
            material: "coton",
            styleTags: ["casual", "bureau"],
            season: ["printemps", "été"],
            imageURL: nil,
            tryOnPrompt: "wearing beige cotton chino trousers, slim fit, casual style",
            isFeatured: false,
            priceEur: nil,
            purchaseURL: nil
        ),
        // Unisexe ×1
        CatalogClothingItem(
            id: UUID(uuidString: "A1000000-0000-0000-0000-000000000005")!,
            name: "Manteau Camel",
            gender: .unisexe,
            category: "coat",
            subcategory: "manteau droit",
            brand: nil,
            color: "camel",
            material: "cachemire",
            styleTags: ["hiver", "classique"],
            season: ["automne", "hiver"],
            imageURL: nil,
            tryOnPrompt: "wearing a camel cashmere overcoat, straight cut, luxury fashion",
            isFeatured: true,
            priceEur: nil,
            purchaseURL: nil
        ),
    ]

    static let preview = CatalogClothingItem(
        id: UUID(),
        name: "Robe Cocktail Noire",
        gender: .femme,
        category: "dress",
        subcategory: "robe cocktail",
        brand: nil,
        color: "noir",
        material: "crêpe",
        styleTags: ["soirée", "élégant"],
        season: ["automne", "hiver"],
        imageURL: nil,
        tryOnPrompt: "wearing a sleek black cocktail dress, midi length, architectural cut",
        isFeatured: true,
        priceEur: nil,
        purchaseURL: nil
    )

    static let previewMen = CatalogClothingItem(
        id: UUID(),
        name: "Blazer Navy",
        gender: .homme,
        category: "jacket",
        subcategory: "blazer",
        brand: nil,
        color: "bleu marine",
        material: "laine",
        styleTags: ["bureau", "élégant"],
        season: ["printemps", "automne"],
        imageURL: nil,
        tryOnPrompt: "wearing a tailored navy blue wool blazer, single button, notched lapel",
        isFeatured: true,
        priceEur: nil,
        purchaseURL: nil
    )
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let text = try? decodeIfPresent(String.self, forKey: key), let value = Double(text) { return value }
        return nil
    }
}
