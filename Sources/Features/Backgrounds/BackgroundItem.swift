import SwiftUI

// MARK: - Background Category

enum BackgroundCategory: String, CaseIterable, Codable, Identifiable {
    case studio    = "Studio"
    case city      = "Ville"
    case nature    = "Nature"
    case interior  = "Intérieur"
    case abstract_ = "Abstrait"
    case seasonal  = "Saison"
    case custom    = "Personnel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .studio:    return "camera.aperture"
        case .city:      return "building.2"
        case .nature:    return "leaf"
        case .interior:  return "sofa"
        case .abstract_: return "rectangle.3.group"
        case .seasonal:  return "snowflake"
        case .custom:    return "person.crop.square"
        }
    }
}

// MARK: - Background Source

enum BackgroundSource: Codable, Equatable {
    case solidColor(hex: String)
    case gradient(colors: [String], angle: Double)
    case userPhoto(filename: String)
    case generated
}

// MARK: - Background Item

struct BackgroundItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: BackgroundCategory
    let previewColor: String
    let prompt: String
    let isPremium: Bool
    let isUnlockableByXP: Bool
    let xpRequired: Int
    var source: BackgroundSource
}

// MARK: - Catalog

extension BackgroundItem {
    static let catalog: [BackgroundItem] = studio + city + nature + interior + abstract_ + seasonal

    // MARK: Studio
    static let studio: [BackgroundItem] = [
        BackgroundItem(
            id: "studio_blanc",
            name: "Studio Blanc",
            category: .studio,
            previewColor: "#F8F8F6",
            prompt: "Professional white photography studio, soft diffused light, seamless white backdrop",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .solidColor(hex: "#F8F8F6")
        ),
        BackgroundItem(
            id: "studio_noir",
            name: "Studio Noir",
            category: .studio,
            previewColor: "#0A0A0A",
            prompt: "Luxury dark studio, dramatic side lighting, matte black seamless backdrop",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .solidColor(hex: "#0A0A0A")
        ),
        BackgroundItem(
            id: "studio_gris",
            name: "Gris Perle",
            category: .studio,
            previewColor: "#C8C8C4",
            prompt: "Pearl grey photography studio, neutral backdrop, soft studio lighting",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#D8D8D4", "#B8B8B4"], angle: 160)
        ),
        BackgroundItem(
            id: "studio_charcoal",
            name: "Charbon Profond",
            category: .studio,
            previewColor: "#1C1C1E",
            prompt: "Deep charcoal studio backdrop, professional fashion photography",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#2A2A2E", "#0E0E12"], angle: 180)
        ),
    ]

    // MARK: City
    static let city: [BackgroundItem] = [
        BackgroundItem(
            id: "paris_haussmann",
            name: "Paris Haussmann",
            category: .city,
            previewColor: "#8B7355",
            prompt: "Parisian Haussmann boulevard, golden hour light, elegant stone facades, blurred background",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#C4A882", "#8B6F4E", "#5C4A32"], angle: 170)
        ),
        BackgroundItem(
            id: "tour_eiffel",
            name: "Tour Eiffel",
            category: .city,
            previewColor: "#4A6B8A",
            prompt: "Eiffel Tower at dusk, Paris skyline, romantic blue-golden sunset bokeh",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#6B8FAD", "#3D5873", "#1A2A3A"], angle: 200)
        ),
        BackgroundItem(
            id: "cafe_de_flore",
            name: "Café de Flore",
            category: .city,
            previewColor: "#6B4226",
            prompt: "Famous Parisian café terrace, rattan chairs, warm amber light, artistic blur",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#8B5A38", "#5C3820", "#2E1A0E"], angle: 150)
        ),
        BackgroundItem(
            id: "palais_royal",
            name: "Palais Royal",
            category: .city,
            previewColor: "#5A7A5A",
            prompt: "Palais Royal gardens Paris, striped columns, lush greenery, soft golden light",
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#7A9A6A", "#4A6A4A", "#2A3A2A"], angle: 160)
        ),
        BackgroundItem(
            id: "new_york_loft",
            name: "Loft New-Yorkais",
            category: .city,
            previewColor: "#7A6A5A",
            prompt: "New York industrial loft, exposed brick, floor-to-ceiling windows, city view",
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#9A8A7A", "#6A5A4A", "#3A2A1A"], angle: 140)
        ),
    ]

    // MARK: Nature
    static let nature: [BackgroundItem] = [
        BackgroundItem(
            id: "plage_tropicale",
            name: "Plage Tropicale",
            category: .nature,
            previewColor: "#2A7A9A",
            prompt: "Tropical beach, turquoise water, white sand, palm trees, perfect sunny day",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#5ABFDF", "#2A90B0", "#1A5A70"], angle: 180)
        ),
        BackgroundItem(
            id: "cote_azur",
            name: "Côte d'Azur",
            category: .nature,
            previewColor: "#1A6A9A",
            prompt: "French Riviera, Azure coast, Mediterranean sea, cliffs and lavender fields",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#4AA0CA", "#1A6A9A", "#0A3A5A"], angle: 190)
        ),
        BackgroundItem(
            id: "foret_automne",
            name: "Forêt en Automne",
            category: .nature,
            previewColor: "#B55A1A",
            prompt: "Autumn forest, golden amber leaves, misty morning light, magical atmosphere",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#E07030", "#B04010", "#701A00"], angle: 160)
        ),
        BackgroundItem(
            id: "jardin_fleurs",
            name: "Jardin Fleuri",
            category: .nature,
            previewColor: "#7A4A8A",
            prompt: "English country garden, blooming roses and peonies, soft bokeh, golden afternoon",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#9A6AAA", "#6A3A7A", "#3A1A4A"], angle: 150)
        ),
        BackgroundItem(
            id: "serre_tropicale",
            name: "Serre Tropicale",
            category: .nature,
            previewColor: "#2A6A3A",
            prompt: "Tropical greenhouse, lush exotic plants, filtered light, botanical gardens",
            isPremium: true,
            isUnlockableByXP: true,
            xpRequired: 500,
            source: .gradient(colors: ["#4A8A5A", "#2A5A3A", "#0A2A1A"], angle: 170)
        ),
    ]

    // MARK: Interior
    static let interior: [BackgroundItem] = [
        BackgroundItem(
            id: "interieur_luxe",
            name: "Intérieur Luxe",
            category: .interior,
            previewColor: "#9A7A2A",
            prompt: "Luxury Parisian apartment interior, gilded moldings, velvet drapes, golden chandeliers",
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#C4A040", "#8A6A20", "#4A3A10"], angle: 155)
        ),
        BackgroundItem(
            id: "versailles",
            name: "Château de Versailles",
            category: .interior,
            previewColor: "#B8962A",
            prompt: "Hall of Mirrors Versailles, golden light through tall windows, baroque splendor",
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#D4B050", "#A07830", "#604810"], angle: 165)
        ),
        BackgroundItem(
            id: "bibliotheque",
            name: "Bibliothèque Ancienne",
            category: .interior,
            previewColor: "#6A4A2A",
            prompt: "Ancient library, floor to ceiling leather-bound books, warm reading lamp, dark wood",
            isPremium: false,
            isUnlockableByXP: true,
            xpRequired: 300,
            source: .gradient(colors: ["#8A6040", "#5A3820", "#2A1808"], angle: 140)
        ),
        BackgroundItem(
            id: "galerie_art",
            name: "Galerie d'Art Moderne",
            category: .interior,
            previewColor: "#E0D8D0",
            prompt: "Contemporary art gallery, white walls, track lighting, minimalist aesthetic",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#EEE8E0", "#D0C8C0", "#A8A098"], angle: 150)
        ),
    ]

    // MARK: Abstract
    static let abstract_: [BackgroundItem] = [
        BackgroundItem(
            id: "degrade_or",
            name: "Dégradé Or",
            category: .abstract_,
            previewColor: "#CA8A04",
            prompt: "Luxury golden gradient background, metallic sheen",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#F5D37A", "#CA8A04", "#7A5000"], angle: 145)
        ),
        BackgroundItem(
            id: "degrade_violet",
            name: "Violet Profond",
            category: .abstract_,
            previewColor: "#4A1A7A",
            prompt: "Deep purple luxury gradient, sophisticated dark violet",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#7A3AAA", "#4A1A7A", "#1A0030"], angle: 155)
        ),
        BackgroundItem(
            id: "degrade_rose",
            name: "Rose Poudré",
            category: .abstract_,
            previewColor: "#D4A0A8",
            prompt: "Powdery rose gradient, delicate pink hues, feminine elegance",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#EAC0C8", "#C4808A", "#8A4050"], angle: 165)
        ),
        BackgroundItem(
            id: "degrade_emeraude",
            name: "Émeraude Sombre",
            category: .abstract_,
            previewColor: "#0A4A30",
            prompt: "Dark emerald gradient, jewel-toned green luxury",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#1A7A50", "#0A4A30", "#001A12"], angle: 175)
        ),
        BackgroundItem(
            id: "degrade_encre",
            name: "Encre de Nuit",
            category: .abstract_,
            previewColor: "#0A0A2A",
            prompt: "Midnight ink gradient, deep blue-black, celestial depth",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#1A1A4A", "#0A0A2A", "#000008"], angle: 200)
        ),
        BackgroundItem(
            id: "degrade_champagne",
            name: "Champagne Doré",
            category: .abstract_,
            previewColor: "#E8D89A",
            prompt: "Champagne gold gradient, warm bubbly shimmer, festive luxury",
            isPremium: true,
            isUnlockableByXP: true,
            xpRequired: 200,
            source: .gradient(colors: ["#F8EEC0", "#D8B870", "#A87820"], angle: 160)
        ),
    ]

    // MARK: Seasonal
    static let seasonal: [BackgroundItem] = [
        BackgroundItem(
            id: "noel_dore",
            name: "Noël Doré",
            category: .seasonal,
            previewColor: "#8B4513",
            prompt: "Christmas golden background, warm fireplace, bokeh lights, festive luxury",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#C07030", "#8A3A10", "#3A1000"], angle: 155)
        ),
        BackgroundItem(
            id: "saint_valentin",
            name: "Saint-Valentin",
            category: .seasonal,
            previewColor: "#C0304A",
            prompt: "Valentines Day romantic background, red rose petals, soft golden candlelight",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#E05070", "#B02040", "#600020"], angle: 165)
        ),
        BackgroundItem(
            id: "printemps_cerisier",
            name: "Cerisiers en Fleurs",
            category: .seasonal,
            previewColor: "#E8A0B8",
            prompt: "Cherry blossom spring garden, sakura petals in the breeze, soft pink bokeh",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#F0B8CC", "#D07890", "#A04060"], angle: 160)
        ),
        BackgroundItem(
            id: "halloween_violet",
            name: "Halloween Mystique",
            category: .seasonal,
            previewColor: "#5A1A8A",
            prompt: "Halloween mysterious purple mist, gothic atmosphere, haunted elegance",
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            source: .gradient(colors: ["#8A3AAA", "#4A1A7A", "#1A0020"], angle: 180)
        ),
        BackgroundItem(
            id: "ete_soleil",
            name: "Été Méditerranée",
            category: .seasonal,
            previewColor: "#E8A020",
            prompt: "Summer mediterranean golden hour, warm sun, azure sky, lavender fields",
            isPremium: true,
            isUnlockableByXP: true,
            xpRequired: 150,
            source: .gradient(colors: ["#F0C040", "#D08010", "#804000"], angle: 150)
        ),
    ]
}
