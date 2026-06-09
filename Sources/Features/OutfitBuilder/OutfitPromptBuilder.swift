import Foundation

// MARK: - OutfitPromptBuilder — Construction du prompt GPT Image 2.0

final class OutfitPromptBuilder {

    // Construit un prompt éditorial cohérent pour l'ensemble de la tenue
    static func build(outfit: Outfit, userContext: String) -> String {
        let slots = outfit.slots

        // --- Extraction des composants ---
        let topDesc      = slots[.top]?.name
        let bottomDesc   = slots[.bottom]?.name
        let dressDesc    = slots[.dress]?.name
        let jacketDesc   = slots[.jacket]?.name
        let necklace     = slots[.necklace]?.name
        let earrings     = slots[.earrings]?.name
        let ring         = slots[.ring]?.name
        let bracelet     = slots[.bracelet]?.name
        let shoes        = slots[.shoes]?.name
        let bag          = slots[.bag]?.name
        let sunglasses   = slots[.sunglasses]?.name
        let belt         = slots[.belt]?.name

        // Résolution compatibilité : robe OU (haut + bas)
        let clothingDesc = resolveClothing(
            dress: dressDesc,
            top: topDesc,
            bottom: bottomDesc,
            jacket: jacketDesc
        )

        // --- Jewellery segment ---
        let jewelryParts: [String] = [
            necklace.map  { "\($0) necklace" },
            earrings.map  { "\($0) earrings" },
            ring.map      { "\($0) ring" },
            bracelet.map  { "\($0) bracelet" }
        ].compactMap { $0 }

        let jewelryLine = jewelryParts.isEmpty
            ? ""
            : "Fine jewelry: \(jewelryParts.joined(separator: ", "))."

        // --- Accessories segment ---
        let accessoryParts: [String] = [
            bag.map        { "carrying a \($0) bag" },
            sunglasses.map { "wearing \($0) sunglasses" },
            belt.map       { "with a \($0) belt" }
        ].compactMap { $0 }

        let accessoriesLine = accessoryParts.isEmpty
            ? ""
            : "Accessories: \(accessoryParts.joined(separator: ", "))."

        // --- Shoes segment ---
        let shoesLine = shoes.map { "Wearing \($0) shoes." } ?? ""

        // --- Occasion style cue ---
        let styleLine = outfit.occasion.styleKeywords

        // --- Assembly ---
        let parts: [String] = [
            "Fashion editorial photograph of \(userContext).",
            clothingDesc,
            jewelryLine,
            shoesLine,
            accessoriesLine,
            "Style: \(styleLine), luxury editorial.",
            "Keep the person's face, skin tone, hair, and body proportions exactly the same.",
            "Ultra-high-end fashion photography, cinematic lighting, sharp focus, 8K resolution.",
            "Shot on medium format camera, editorial magazine quality."
        ].filter { !$0.isEmpty }

        return parts.joined(separator: " ")
    }

    // Détecte les incompatibilités et résout logiquement la description vestimentaire
    private static func resolveClothing(
        dress: String?,
        top: String?,
        bottom: String?,
        jacket: String?
    ) -> String {
        var parts: [String] = []

        if let d = dress {
            // Robe présente → ignore haut + bas séparément
            parts.append("wearing a \(d) dress")
            if let j = jacket { parts.append("with a \(j) over it") }
        } else {
            if let t = top    { parts.append("wearing a \(t) top") }
            if let b = bottom { parts.append("with \(b) trousers") }
            if let j = jacket { parts.append("and a \(j) jacket") }
        }

        return parts.isEmpty ? "" : parts.joined(separator: " ") + "."
    }

    // Suggestions d'items manquants selon l'occasion
    static func suggestMissingSlots(for outfit: Outfit) -> [OutfitSlot] {
        let filled = Set(outfit.slots.keys)
        let occasion = outfit.occasion

        var essential: [OutfitSlot] = []

        // Règle de base : au moins haut OU robe
        if !filled.contains(.top) && !filled.contains(.dress) {
            essential.append(.top)
        }

        // Chaussures toujours utiles sauf sport sans
        if !filled.contains(.shoes) {
            essential.append(.shoes)
        }

        // Suggestions selon occasion
        switch occasion {
        case .gala, .evening, .wedding:
            if !filled.contains(.necklace) { essential.append(.necklace) }
            if !filled.contains(.earrings) { essential.append(.earrings) }
        case .work:
            if !filled.contains(.jacket)   { essential.append(.jacket) }
            if !filled.contains(.bag)      { essential.append(.bag) }
        case .casual, .date:
            if !filled.contains(.bag)      { essential.append(.bag) }
        case .beach:
            if !filled.contains(.sunglasses) { essential.append(.sunglasses) }
        default:
            break
        }

        return essential.filter { !filled.contains($0) }
    }

    // Détecte et retourne les combinaisons problématiques
    static func detectConflicts(in outfit: Outfit) -> [String] {
        var warnings: [String] = []
        let slots = outfit.slots

        if slots[.dress] != nil && slots[.bottom] != nil {
            warnings.append("Robe + Bas : le bas sera ignoré lors de la génération.")
        }
        if slots[.dress] != nil && slots[.top] != nil {
            warnings.append("Robe + Haut : le haut sera ignoré lors de la génération.")
        }

        return warnings
    }
}
