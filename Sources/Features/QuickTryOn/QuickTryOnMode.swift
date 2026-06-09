import Foundation

// MARK: - QuickTryOnMode — Modes d'essayage partiel ou complet

enum QuickTryOnMode: String, CaseIterable, Identifiable {
    case topOnly        = "Haut seul"
    case bottomOnly     = "Bas seul"
    case topAndBottom   = "Haut + Bas"
    case shoesOnly      = "Chaussures seules"
    case shoesAndBottom = "Chaussures + Bas"
    case fullOutfit     = "Tenue complète"
    case accessoryOnly  = "Accessoire seul"
    case jewelsOnly     = "Bijoux seuls"

    var id: String { rawValue }

    // SF Symbol représentant chaque mode
    var icon: String {
        switch self {
        case .topOnly:        return "tshirt.fill"
        case .bottomOnly:     return "figure.walk"
        case .topAndBottom:   return "person.fill"
        case .shoesOnly:      return "shoe.fill"
        case .shoesAndBottom: return "figure.walk.treadmill"
        case .fullOutfit:     return "person.crop.rectangle.fill"
        case .accessoryOnly:  return "bag.fill"
        case .jewelsOnly:     return "diamond.fill"
        }
    }

    // Zones corporelles nécessaires pour la photo
    var requiredZones: [BodyZone] {
        switch self {
        case .topOnly:        return [.fullBody]
        case .bottomOnly:     return [.legs]
        case .topAndBottom:   return [.fullBody]
        case .shoesOnly:      return [.feet]
        case .shoesAndBottom: return [.legs, .feet]
        case .fullOutfit:     return [.fullBody, .feet]
        case .accessoryOnly:  return [.fullBody]
        case .jewelsOnly:     return [.neck, .ears, .wrist, .finger]
        }
    }

    // Conseil photo contextuel affiché sous la grille de modes.
    // Pour TOUS les modes vêtements/chaussures on demande une photo en pied :
    // l'IA a besoin du corps entier pour intégrer correctement le vêtement
    // et l'utilisateur veut voir le rendu de la tête aux pieds.
    var photoTip: String {
        switch self {
        case .topOnly:
            return "Photo en pied, de la tête aux pieds — face à la caméra, fond neutre."
        case .bottomOnly:
            return "Photo en pied, de la tête aux pieds — fond neutre."
        case .topAndBottom:
            return "Photo en pied complète, tête aux pieds, fond uni."
        case .shoesOnly:
            return "Photo en pied, de la tête aux pieds — chaussures bien visibles."
        case .shoesAndBottom:
            return "Photo en pied, de la tête aux pieds — fond neutre."
        case .fullOutfit:
            return "Photo en pied complète, tête aux pieds, fond clair ou neutre."
        case .accessoryOnly:
            return "Photo en pied — montrez où porte l'accessoire (sac, lunettes…)."
        case .jewelsOnly:
            return "Gros plan sur la zone du bijou : cou, oreilles, poignet ou doigt."
        }
    }

    // Suffixe injecté dans le prompt GPT Image selon le mode.
    // Par défaut TOUS les modes vêtements demandent un full body shot —
    // l'utilisateur doit voir le vêtement entier (longueur, coupe, tombé)
    // et son intégration au reste de la silhouette.
    var promptSuffix: String {
        switch self {
        case .topOnly:
            return "full body editorial shot from head to toe, the entire person visible from head to feet, strong focus on the top/jacket/suit garment showing its full length, fit, and how it falls, professional standing pose, neutral background"
        case .bottomOnly:
            return "full body editorial shot from head to toe, strong focus on the bottom garment showing its full length, fit and silhouette, professional standing pose"
        case .topAndBottom:
            return "full body editorial shot from head to toe, both top and bottom garments clearly visible in their entirety, professional standing pose"
        case .shoesOnly:
            return "full body editorial shot from head to toe, strong focus on the footwear and how it integrates with the outfit, professional standing pose"
        case .shoesAndBottom:
            return "full body editorial shot from head to toe, shoes and bottom garment both clearly visible in their entirety, professional standing pose"
        case .fullOutfit:
            return "full body editorial shot from head to toe, all garment zones (top, bottom, shoes) clearly visible, professional standing pose"
        case .accessoryOnly:
            return "full body editorial shot, accessory naturally integrated into a real-world pose, person clearly visible with the accessory in context"
        case .jewelsOnly:
            return "close-up luxury jewelry photography, skin and jewelry sharp, soft bokeh background"
        }
    }

    // Catégories FashionCategory compatibles avec ce mode
    var compatibleCategories: [FashionCategory] {
        switch self {
        case .topOnly:
            return [.top, .jacket, .coat, .suit]
        case .bottomOnly:
            return [.bottom]
        case .topAndBottom:
            return [.top, .jacket, .coat, .suit, .bottom, .dress]
        case .shoesOnly:
            return [.heels, .flats, .boots, .sneakers, .sandals, .loafers]
        case .shoesAndBottom:
            return [.heels, .flats, .boots, .sneakers, .sandals, .loafers, .bottom]
        case .fullOutfit:
            return FashionCategory.allCases
        case .accessoryOnly:
            return [.bag, .sunglasses, .hat, .scarf, .belt, .gloves]
        case .jewelsOnly:
            return [.ring, .necklace, .earring, .bracelet, .watch, .brooch]
        }
    }

    // Nombre max d'articles sélectionnables simultanément
    var maxItemCount: Int {
        switch self {
        case .topOnly:        return 1
        case .bottomOnly:     return 1
        case .topAndBottom:   return 2
        case .shoesOnly:      return 1
        case .shoesAndBottom: return 2
        case .fullOutfit:     return 6
        case .accessoryOnly:  return 2
        case .jewelsOnly:     return 3
        }
    }

    // Zone de la silhouette à surligner dans PhotoGuideOverlay
    var highlightedBodySegments: [BodySegment] {
        switch self {
        case .topOnly:        return [.torso, .shoulders]
        case .bottomOnly:     return [.waistToKnees, .lowerLegs]
        case .topAndBottom:   return [.torso, .shoulders, .waistToKnees, .lowerLegs]
        case .shoesOnly:      return [.feet]
        case .shoesAndBottom: return [.waistToKnees, .lowerLegs, .feet]
        case .fullOutfit:     return BodySegment.allCases
        case .accessoryOnly:  return [.torso, .head]
        case .jewelsOnly:     return [.neck, .head, .hands]
        }
    }
}

// MARK: - BodySegment — Segments de silhouette pour le guide visuel

enum BodySegment: String, CaseIterable {
    case head
    case neck
    case shoulders
    case torso
    case waistToKnees
    case lowerLegs
    case feet
    case hands
}

// MARK: - TryOnMode — Modes d'essayage et coût en crédits

/// Distingue les trois grandes familles d'essayage selon leur coût en crédits.
///
/// - `arLive`  : Essayage AR temps réel via ARKit + LiDAR → **0 crédit** consommé
/// - `aiPhoto` : Essayage IA sur photo statique via Gemini Flash → **1 crédit** consommé
/// - `aiOutfit`: Essayage tenue complète via Gemini Pro (haute qualité) → **2 crédits** consommés
///
/// Règle : les essayages AR chaussures (`arLive`) ne consomment **jamais** de crédit.
enum TryOnMode {
    case arLive      // ARKit LiDAR temps réel  → 0 crédit consommé
    case aiPhoto     // Gemini Flash Image        → 1 crédit consommé
    case aiOutfit    // Gemini Pro Image           → 2 crédits consommés

    /// Nombre de crédits débités pour un essayage dans ce mode.
    var creditCost: Int {
        switch self {
        case .arLive:   return 0
        case .aiPhoto:  return 1
        case .aiOutfit: return 2
        }
    }

    /// Libellé affiché en UI.
    var displayName: String {
        switch self {
        case .arLive:   return "AR en direct"
        case .aiPhoto:  return "Photo IA"
        case .aiOutfit: return "Tenue complète"
        }
    }

    /// SF Symbol représentatif.
    var icon: String {
        switch self {
        case .arLive:   return "arkit"
        case .aiPhoto:  return "photo.badge.sparkles"
        case .aiOutfit: return "person.crop.square.filled.and.at.rectangle"
        }
    }
}
