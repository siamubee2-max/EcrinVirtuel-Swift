import Foundation

struct JewelryItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: JewelryCategory
    let imageURL: URL?
    let icon: String
    let material: String
    let prompt: String

    enum JewelryCategory: String, Codable, CaseIterable {
        case ring            = "Bague"
        case necklace        = "Collier"
        case earring         = "Boucles"
        case bracelet        = "Bracelet"
        case watch           = "Montre"
        case nosePiercing    = "Piercing Nez"
        case eyebrowPiercing = "Piercing Arcade"
        case lipPiercing     = "Piercing Lèvre"
        case tonguePiercing  = "Piercing Langue"
    }

    /// URL Unsplash de fallback par catégorie quand `imageURL` est nil.
    /// Garantit une vraie photo du bijou même sans entrée DB Supabase.
    /// Photos curatées (Unsplash CDN, libres de droits, focus produit/bijou).
    var displayImageURL: URL? {
        if let url = imageURL { return url }
        let unsplashID: String = switch category {
        case .ring:            "1605100804763-247f67b3557e" // bague pierre
        case .necklace:        "1599643478518-a784e5dc4c8f" // collier pendentif
        case .earring:         "1535632066927-ab7c9ab60908" // boucles d'oreilles
        case .bracelet:        "1611652022419-a9419f74343d" // bracelet
        case .watch:           "1524805444758-089113d48a6d" // montre cuir
        case .nosePiercing:    "1583292650898-7d22cd27ca6f" // piercing nez
        case .eyebrowPiercing: "1564859228273-274232fdb516" // piercing arcade
        case .lipPiercing:     "1551589273-86b9d9d5e1e0"   // piercing lèvre
        case .tonguePiercing:  "1577037834103-31fcdbdda03e" // piercing
        }
        return URL(string: "https://images.unsplash.com/photo-\(unsplashID)?w=800&q=85&auto=format&fit=crop")
    }

    var asFashionItem: FashionItem {
        let fashionCategory: FashionCategory = switch category {
        case .ring:            .ring
        case .necklace:        .necklace
        case .earring:         .earring
        case .bracelet:        .bracelet
        case .watch:           .watch
        case .nosePiercing:    .nosePiercing
        case .eyebrowPiercing: .eyebrowPiercing
        case .lipPiercing:     .lipPiercing
        case .tonguePiercing:  .tonguePiercing
        }
        return FashionItem(
            id: id,
            name: name,
            category: fashionCategory,
            material: material.isEmpty ? nil : material,
            imageURL: imageURL,
            tryOnPrompt: prompt,
            source: .userPhoto
        )
    }

    static let samples: [JewelryItem] = [
        JewelryItem(id: UUID(), name: "Bague Améthyste", category: .ring, imageURL: nil, icon: "hexagon.fill", material: "Laiton doré · Améthyste", prompt: "raw amethyst crystal ring on finger, artisanal boho style"),
        JewelryItem(id: UUID(), name: "Sautoir Pierre de Lune", category: .necklace, imageURL: nil, icon: "moonphase.last.quarter", material: "Argent 925 · Pierre de lune", prompt: "moonstone pendant necklace on neck, boho artisanal style"),
        JewelryItem(id: UUID(), name: "Créoles Quartz Rose", category: .earring, imageURL: nil, icon: "oval.fill", material: "Argent 925 · Quartz rose", prompt: "rose quartz drop earrings on ears, artisanal handmade"),
        JewelryItem(id: UUID(), name: "Bracelet Labradorite", category: .bracelet, imageURL: nil, icon: "square.on.circle", material: "Cuir · Labradorite", prompt: "labradorite wrap bracelet on wrist, bohemian wellness style"),
        JewelryItem(id: UUID(), name: "Montre Cuir Naturel", category: .watch, imageURL: nil, icon: "applewatch", material: "Cuir · Acier brossé", prompt: "minimal leather watch on wrist, artisanal style"),
        JewelryItem(id: UUID(), name: "Anneau Nez Opale", category: .nosePiercing, imageURL: nil, icon: "circle.fill", material: "Argent 925 · Opale", prompt: "person wearing delicate opal nose ring, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Barbell Arcade Améthyste", category: .eyebrowPiercing, imageURL: nil, icon: "minus.circle.fill", material: "Acier · Améthyste", prompt: "person with amethyst eyebrow barbell piercing, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Anneau Lèvre Citrine", category: .lipPiercing, imageURL: nil, icon: "moon.fill", material: "Plaqué or · Citrine", prompt: "person with gold citrine lip ring, close-up portrait, natural light"),
        JewelryItem(id: UUID(), name: "Barbell Langue Quartz Rose", category: .tonguePiercing, imageURL: nil, icon: "capsule.fill", material: "Acier · Quartz rose", prompt: "person with rose quartz tongue barbell, mouth slightly open, close-up portrait"),
    ]
}
