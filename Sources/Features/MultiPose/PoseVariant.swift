import Foundation

// MARK: - PoseCategory

enum PoseCategory: String, CaseIterable, Identifiable {
    case angle   = "Angles"
    case dynamic = "Mouvement"
    case staticPose = "Statique"
    case seated  = "Assis"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .angle:       return "viewfinder.rectangular"
        case .dynamic:     return "figure.walk"
        case .staticPose:  return "figure.stand"
        case .seated:      return "figure.seated.seatbelt"
        }
    }
}

// MARK: - PoseItemType

enum PoseItemType: Hashable {
    case clothing
    case shoes
    case earrings
    case necklace
    case ring
    case bracelet
    case watch
}

// MARK: - PoseVariant

struct PoseVariant: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: PoseCategory
    let promptSuffix: String
    let itemTypes: Set<PoseItemType>
    let isMotion: Bool

    static func == (lhs: PoseVariant, rhs: PoseVariant) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - PoseVariant catalogue

extension PoseVariant {

    // MARK: Vêtements & Chaussures

    static let front = PoseVariant(
        id: "front",
        name: "Face",
        icon: "arrow.down.to.line.compact",
        category: .angle,
        promptSuffix: "front view, facing directly toward camera, neutral standing pose, full body visible, confident posture",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let sideLeft = PoseVariant(
        id: "sideLeft",
        name: "Côté gauche",
        icon: "arrow.left.to.line.compact",
        category: .angle,
        promptSuffix: "left side profile view, body turned 90 degrees left, looking straight ahead, full body visible",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let threeQuarterLeft = PoseVariant(
        id: "threeQuarterLeft",
        name: "3/4 gauche",
        icon: "angle",
        category: .angle,
        promptSuffix: "three-quarter view from left side, body at 45-degree angle to camera, face slightly turned toward camera",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let back = PoseVariant(
        id: "back",
        name: "Derrière",
        icon: "arrow.up.to.line.compact",
        category: .angle,
        promptSuffix: "rear view, back facing camera, looking away or slightly over shoulder, full body visible",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let walking = PoseVariant(
        id: "walking",
        name: "Marchant",
        icon: "figure.walk",
        category: .dynamic,
        promptSuffix: "dynamic walking pose, mid-stride, one leg forward, natural arm swing, motion energy, shot from front at slight angle, urban chic background suggestion",
        itemTypes: [.clothing, .shoes],
        isMotion: true
    )

    static let powerPose = PoseVariant(
        id: "powerPose",
        name: "Power pose",
        icon: "figure.stand",
        category: .staticPose,
        promptSuffix: "confident power pose, standing tall, shoulders back, hands loosely at sides or one hand on hip, strong assertive stance, editorial fashion pose",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let stoolSeated = PoseVariant(
        id: "stoolSeated",
        name: "Tabouret",
        icon: "chair.lounge.fill",
        category: .seated,
        promptSuffix: "seated on elegant high bar stool, legs slightly crossed at ankle, upright elegant posture, one hand resting on knee, sophisticated studio setting, shoes fully visible",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let catwalk = PoseVariant(
        id: "catwalk",
        name: "Catwalk",
        icon: "figure.runway",
        category: .dynamic,
        promptSuffix: "catwalk runway walk pose, mid-stride on imaginary runway, head slightly tilted, editorial fashion photography, dynamic but controlled movement",
        itemTypes: [.clothing, .shoes],
        isMotion: true
    )

    static let casualLean = PoseVariant(
        id: "casualLean",
        name: "Appuyé",
        icon: "figure.cooldown",
        category: .staticPose,
        promptSuffix: "casual leaning pose, one shoulder against invisible wall, relaxed stance, weight on one hip, effortlessly chic",
        itemTypes: [.clothing, .shoes],
        isMotion: false
    )

    static let crouching = PoseVariant(
        id: "crouching",
        name: "Accroupi",
        icon: "figure.flexibility",
        category: .dynamic,
        promptSuffix: "crouching pose, knees bent, body lowered, shoes prominently visible and in focus, fashion editorial style",
        itemTypes: [.shoes],
        isMotion: false
    )

    // MARK: Boucles d'oreilles

    static let earFront = PoseVariant(
        id: "earFront",
        name: "Face",
        icon: "arrow.down.to.line.compact",
        category: .angle,
        promptSuffix: "close-up frontal portrait, face forward, both ears and earrings clearly visible, professional jewelry photography, soft studio lighting",
        itemTypes: [.earrings],
        isMotion: false
    )

    static let earThreeQuarter = PoseVariant(
        id: "earThreeQuarter",
        name: "3/4",
        icon: "angle",
        category: .angle,
        promptSuffix: "three-quarter head turn (45 degrees), keep the close-up head-and-shoulders framing of the input photo, chin slightly down, one earring prominently visible with the other partially visible, jewelry editorial style",
        itemTypes: [.earrings],
        isMotion: false
    )

    static let earSideProfile = PoseVariant(
        id: "earSideProfile",
        name: "Profil",
        icon: "arrow.left.to.line.compact",
        category: .angle,
        promptSuffix: "STRICT SIDE PROFILE: rotate the head a full 90 degrees so only one side of the face is visible, nose pointing to the side of the frame, the full ear visible and centered, earring detail sharp and in focus, clean background, macro-style jewelry photography. PROFILE SCALE RULE: even in this close-up the earring stays true-to-life dainty - total length no more than 1.5x the height of the ear, never reaching below the jawline, never dominating the frame",
        itemTypes: [.earrings],
        isMotion: false
    )

    // MARK: Colliers & bijoux cou

    static let necklaceFront = PoseVariant(
        id: "necklaceFront",
        name: "Face",
        icon: "arrow.down.to.line.compact",
        category: .angle,
        promptSuffix: "portrait shot, décolleté visible, necklace centered and in focus, soft jewelry photography lighting",
        itemTypes: [.necklace],
        isMotion: false
    )

    static let necklaceThreeQuarter = PoseVariant(
        id: "necklaceThreeQuarter",
        name: "3/4",
        icon: "angle",
        category: .angle,
        promptSuffix: "three-quarter portrait, necklace draped naturally, slight head turn",
        itemTypes: [.necklace],
        isMotion: false
    )

    static let necklaceDetail = PoseVariant(
        id: "necklaceDetail",
        name: "Gros plan",
        icon: "magnifyingglass",
        category: .angle,
        promptSuffix: "close-up on necklace, face slightly out of frame top, necklace texture and details sharp",
        itemTypes: [.necklace],
        isMotion: false
    )

    // MARK: Bagues

    static let ringHand = PoseVariant(
        id: "ringHand",
        name: "Main",
        icon: "hand.raised.fill",
        category: .angle,
        promptSuffix: "elegant hand pose, fingers extended, ring prominently featured, natural lighting, clean background",
        itemTypes: [.ring],
        isMotion: false
    )

    static let ringDetail = PoseVariant(
        id: "ringDetail",
        name: "Détail",
        icon: "magnifyingglass",
        category: .angle,
        promptSuffix: "macro-style close-up of ring on finger, jewelry details sharp, shallow depth of field",
        itemTypes: [.ring],
        isMotion: false
    )
}

// MARK: - Catalogues par item type

extension PoseVariant {

    static let clothingPoses: [PoseVariant] = [
        .front, .threeQuarterLeft, .sideLeft, .back,
        .walking, .catwalk, .powerPose, .casualLean, .stoolSeated
    ]

    static let shoesPoses: [PoseVariant] = [
        .front, .sideLeft, .threeQuarterLeft,
        .walking, .catwalk, .stoolSeated, .crouching
    ]

    static let earringsPoses: [PoseVariant] = [
        .earFront, .earThreeQuarter, .earSideProfile
    ]

    static let necklacePoses: [PoseVariant] = [
        .necklaceFront, .necklaceThreeQuarter, .necklaceDetail
    ]

    static let ringPoses: [PoseVariant] = [
        .ringHand, .ringDetail
    ]

    static let braceletPoses: [PoseVariant] = [
        .ringHand, .ringDetail
    ]

    static let watchPoses: [PoseVariant] = [
        .ringHand, .ringDetail
    ]

    /// Retourne les poses disponibles pour un type de FashionCategory
    static func poses(for category: FashionCategory) -> [PoseVariant] {
        switch category {
        case .top, .bottom, .dress, .jacket, .coat, .suit:
            return clothingPoses
        case .heels, .flats, .boots, .sneakers, .sandals, .loafers:
            return shoesPoses
        case .earring:
            return earringsPoses
        case .necklace, .brooch:
            return necklacePoses
        case .ring:
            return ringPoses
        case .bracelet:
            return braceletPoses
        case .watch:
            return watchPoses
        case .bag, .sunglasses, .hat, .scarf, .belt, .gloves:
            return clothingPoses
        case .nosePiercing, .eyebrowPiercing, .lipPiercing, .tonguePiercing:
            return earringsPoses // face-tracking poses work for all facial piercings
        }
    }

    /// Poses groupées par catégorie pour un FashionCategory
    static func groupedPoses(for fashionCategory: FashionCategory) -> [(category: PoseCategory, poses: [PoseVariant])] {
        let available = poses(for: fashionCategory)
        return PoseCategory.allCases.compactMap { cat in
            let filtered = available.filter { $0.category == cat }
            return filtered.isEmpty ? nil : (category: cat, poses: filtered)
        }
    }
}
