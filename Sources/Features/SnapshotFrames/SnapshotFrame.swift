import SwiftUI

// MARK: - Frame Category

enum FrameCategory: String, CaseIterable, Codable, Identifiable {
    case classic  = "Classique"
    case polaroid = "Polaroid"
    case magazine = "Magazine"
    case story    = "Story"
    case luxury   = "Luxe"
    case seasonal = "Saison"
    case branded  = "Partenaire"
    case gaming   = "Gaming"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .classic:  return "rectangle"
        case .polaroid: return "photo.on.rectangle"
        case .magazine: return "newspaper"
        case .story:    return "iphone"
        case .luxury:   return "crown"
        case .seasonal: return "leaf"
        case .branded:  return "storefront"
        case .gaming:   return "gamecontroller"
        }
    }
}

// MARK: - Frame Overlay

enum FrameOverlay: Codable, Equatable {
    case goldPattern
    case diamondSparkles
    case floral(season: String)
    case magazineLogo(name: String)
    case partnerBadge(brand: String)
    case gamingCrown(level: String)
}

// MARK: - Frame Style

struct FrameStyle: Codable, Equatable {
    var borderColor: String
    var borderWidth: CGFloat
    var cornerRadius: CGFloat
    var innerPadding: CGFloat
    var backgroundColor: String?
    var topText: String?
    var bottomText: String?
    var overlay: FrameOverlay?
    var showDate: Bool
    var showJewelryName: Bool
}

// MARK: - Snapshot Frame

struct SnapshotFrame: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: FrameCategory
    let isPremium: Bool
    let isUnlockableByXP: Bool
    let xpRequired: Int
    var style: FrameStyle
}

// MARK: - Catalog

extension SnapshotFrame {
    static let catalog: [SnapshotFrame] = classic + polaroid + magazine + story + luxury + seasonal + gaming

    // MARK: Classic
    static let classic: [SnapshotFrame] = [
        SnapshotFrame(
            id: "classic_or_fin",
            name: "Or Fin",
            category: .classic,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 4,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "classic_argent",
            name: "Argent",
            category: .classic,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#C0C0C0",
                borderWidth: 4,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "classic_noir_mat",
            name: "Noir Mat",
            category: .classic,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#1A1A1A",
                borderWidth: 6,
                cornerRadius: 2,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "classic_ivoire",
            name: "Blanc Ivoire",
            category: .classic,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#FAFAF9",
                borderWidth: 8,
                cornerRadius: 4,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "classic_double_or",
            name: "Double Trait Or",
            category: .classic,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 2,
                cornerRadius: 6,
                innerPadding: 6,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: false,
                showJewelryName: false
            )
        ),
    ]

    // MARK: Polaroid
    static let polaroid: [SnapshotFrame] = [
        SnapshotFrame(
            id: "polaroid_blanc",
            name: "Polaroid Blanc",
            category: .polaroid,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#E8E8E4",
                borderWidth: 12,
                cornerRadius: 4,
                innerPadding: 0,
                backgroundColor: "#FAFAF9",
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: true,
                showJewelryName: true
            )
        ),
        SnapshotFrame(
            id: "polaroid_vintage",
            name: "Polaroid Vintage",
            category: .polaroid,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#E8D870",
                borderWidth: 12,
                cornerRadius: 4,
                innerPadding: 0,
                backgroundColor: "#F5EFA0",
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: true,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "polaroid_kraft",
            name: "Kraft Brun",
            category: .polaroid,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#8B6040",
                borderWidth: 14,
                cornerRadius: 3,
                innerPadding: 0,
                backgroundColor: "#A87850",
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: true,
                showJewelryName: true
            )
        ),
        SnapshotFrame(
            id: "polaroid_noir",
            name: "Polaroid Noir",
            category: .polaroid,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#1A1A1A",
                borderWidth: 12,
                cornerRadius: 3,
                innerPadding: 0,
                backgroundColor: "#222222",
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: true,
                showJewelryName: true
            )
        ),
    ]

    // MARK: Magazine
    static let magazine: [SnapshotFrame] = [
        SnapshotFrame(
            id: "magazine_ecrin",
            name: "ÉCRIN Magazine",
            category: .magazine,
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 3,
                cornerRadius: 2,
                innerPadding: 0,
                backgroundColor: nil,
                topText: "L'ÉCRIN",
                bottomText: "VIRTUAL COUTURE",
                overlay: .magazineLogo(name: "ÉCRIN"),
                showDate: false,
                showJewelryName: true
            )
        ),
        SnapshotFrame(
            id: "magazine_vogue",
            name: "Vogue-Style Doré",
            category: .magazine,
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#D4AF37",
                borderWidth: 4,
                cornerRadius: 0,
                innerPadding: 0,
                backgroundColor: nil,
                topText: "VOGUE",
                bottomText: "ÉDITION BIJOUX",
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: true
            )
        ),
        SnapshotFrame(
            id: "magazine_harper",
            name: "Harper-Style Minimal",
            category: .magazine,
            isPremium: true,
            isUnlockableByXP: true,
            xpRequired: 800,
            style: FrameStyle(
                borderColor: "#1A1A1A",
                borderWidth: 2,
                cornerRadius: 0,
                innerPadding: 0,
                backgroundColor: nil,
                topText: "HARPER'S",
                bottomText: "JEWELRY EDITION",
                overlay: nil,
                showDate: false,
                showJewelryName: true
            )
        ),
    ]

    // MARK: Story
    static let story: [SnapshotFrame] = [
        SnapshotFrame(
            id: "story_rose_gold",
            name: "Rose Gold",
            category: .story,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#E8A0B0",
                borderWidth: 3,
                cornerRadius: 24,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "story_violet_luxe",
            name: "Violet Luxe",
            category: .story,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#8A3AAA",
                borderWidth: 3,
                cornerRadius: 24,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .diamondSparkles,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "story_or_noir",
            name: "Or & Nuit",
            category: .story,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 4,
                cornerRadius: 24,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "story_arc_ciel",
            name: "Arc-en-Ciel Discret",
            category: .story,
            isPremium: false,
            isUnlockableByXP: true,
            xpRequired: 100,
            style: FrameStyle(
                borderColor: "#CC88DD",
                borderWidth: 3,
                cornerRadius: 24,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: nil,
                showDate: false,
                showJewelryName: false
            )
        ),
    ]

    // MARK: Luxury
    static let luxury: [SnapshotFrame] = [
        SnapshotFrame(
            id: "luxury_diamants",
            name: "Or & Diamants",
            category: .luxury,
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 8,
                cornerRadius: 12,
                innerPadding: 4,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .diamondSparkles,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "luxury_baroque",
            name: "Baroque Doré",
            category: .luxury,
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#D4AF37",
                borderWidth: 14,
                cornerRadius: 6,
                innerPadding: 2,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "luxury_art_deco",
            name: "Art Déco",
            category: .luxury,
            isPremium: true,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#C4A030",
                borderWidth: 6,
                cornerRadius: 0,
                innerPadding: 8,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .goldPattern,
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "luxury_versailles",
            name: "Versailles",
            category: .luxury,
            isPremium: true,
            isUnlockableByXP: true,
            xpRequired: 1200,
            style: FrameStyle(
                borderColor: "#D4AF37",
                borderWidth: 18,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "versailles"),
                showDate: false,
                showJewelryName: true
            )
        ),
    ]

    // MARK: Seasonal
    static let seasonal: [SnapshotFrame] = [
        SnapshotFrame(
            id: "seasonal_noel",
            name: "Noël Doré",
            category: .seasonal,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CA8A04",
                borderWidth: 10,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "noel"),
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "seasonal_valentin",
            name: "Saint-Valentin",
            category: .seasonal,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#CC3355",
                borderWidth: 8,
                cornerRadius: 10,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "valentin"),
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "seasonal_printemps",
            name: "Cerisiers en Fleurs",
            category: .seasonal,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#E890A8",
                borderWidth: 8,
                cornerRadius: 10,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "printemps"),
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "seasonal_ete",
            name: "Été — Coquillages",
            category: .seasonal,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#40A0C8",
                borderWidth: 8,
                cornerRadius: 10,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "ete"),
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "seasonal_halloween",
            name: "Halloween Mystique",
            category: .seasonal,
            isPremium: false,
            isUnlockableByXP: false,
            xpRequired: 0,
            style: FrameStyle(
                borderColor: "#8A2AAA",
                borderWidth: 10,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: nil,
                overlay: .floral(season: "halloween"),
                showDate: false,
                showJewelryName: false
            )
        ),
    ]

    // MARK: Gaming
    static let gaming: [SnapshotFrame] = [
        SnapshotFrame(
            id: "gaming_legendary",
            name: "Legendary Frame",
            category: .gaming,
            isPremium: false,
            isUnlockableByXP: true,
            xpRequired: 2000,
            style: FrameStyle(
                borderColor: "#FFD700",
                borderWidth: 12,
                cornerRadius: 8,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: "LEGENDAIRE",
                overlay: .gamingCrown(level: "LÉGENDAIRE"),
                showDate: false,
                showJewelryName: false
            )
        ),
        SnapshotFrame(
            id: "gaming_champion",
            name: "Champion Frame",
            category: .gaming,
            isPremium: false,
            isUnlockableByXP: true,
            xpRequired: 3500,
            style: FrameStyle(
                borderColor: "#E8C040",
                borderWidth: 14,
                cornerRadius: 10,
                innerPadding: 0,
                backgroundColor: nil,
                topText: nil,
                bottomText: "CHAMPION",
                overlay: .gamingCrown(level: "CHAMPION"),
                showDate: false,
                showJewelryName: true
            )
        ),
    ]
}
