import Foundation

// MARK: - EnrichedPromptBuilder — Construction du prompt enrichi pour GPT Image 2.0

/// Remplace et étend OutfitPromptBuilder en intégrant le BodyContext
/// pour des résultats photorealistic de haute fidélité.
final class EnrichedPromptBuilder {

    // MARK: - QuickTryOn (item unique ou multi)

    /// Construit un prompt enrichi pour le try-on d'un QuickTryOnItem.
    static func build(
        for item: QuickTryOnItem,
        mode: QuickTryOnMode,
        bodyContext: BodyContext
    ) -> String {
        let garmentType = GarmentType.from(fashionCategory: item.fashionCategory)
        let newItemDescription = buildItemDescription(item)

        let transition = BodyContextAnalyzer.shared.buildTransitionInstructions(
            current: bodyContext.detectedClothing,
            replacing: garmentType,
            withNew: newItemDescription
        )

        return assemblePrompt(
            subject: subjectSection(bodyContext: bodyContext),
            item: itemSection(description: newItemDescription, mode: mode),
            transition: transition,
            lighting: lightingSection(bodyContext: bodyContext),
            quality: qualitySection(bodyContext: bodyContext)
        )
    }

    /// Construit un prompt enrichi pour un OutfitBuilder complet.
    static func buildOutfit(
        for outfit: Outfit,
        bodyContext: BodyContext
    ) -> String {
        let slots = outfit.slots

        // Description des vêtements portés (haut + bas ou robe)
        let topDesc    = slots[.top]?.name
        let bottomDesc = slots[.bottom]?.name
        let dressDesc  = slots[.dress]?.name
        let jacketDesc = slots[.jacket]?.name
        let shoesDesc  = slots[.shoes]?.name

        var clothingParts: [String] = []
        if let d = dressDesc {
            clothingParts.append("wearing a \(d) dress")
            if let j = jacketDesc { clothingParts.append("with a \(j) over it") }
        } else {
            if let t = topDesc    { clothingParts.append("wearing a \(t) top") }
            if let b = bottomDesc { clothingParts.append("with \(b)") }
            if let j = jacketDesc { clothingParts.append("and a \(j) jacket") }
        }
        if let s = shoesDesc { clothingParts.append("wearing \(s) shoes") }

        // Bijoux
        let jewelryParts: [String] = [
            slots[.necklace].name.map { "\($0) necklace" },
            slots[.earrings].name.map { "\($0) earrings" },
            slots[.ring].name.map     { "\($0) ring" },
            slots[.bracelet].name.map { "\($0) bracelet" }
        ].compactMap { $0 }

        // Accessoires
        let accessoryParts: [String] = [
            slots[.bag].name.map        { "carrying a \($0) bag" },
            slots[.sunglasses].name.map { "wearing \($0) sunglasses" },
            slots[.belt].name.map       { "with a \($0) belt" }
        ].compactMap { $0 }

        var itemDesc = clothingParts.joined(separator: ", ")
        if !jewelryParts.isEmpty {
            itemDesc += ". Fine jewelry: \(jewelryParts.joined(separator: ", "))"
        }
        if !accessoryParts.isEmpty {
            itemDesc += ". Accessories: \(accessoryParts.joined(separator: ", "))"
        }
        itemDesc += ". Style: \(outfit.occasion.styleKeywords)."

        let transition = buildOutfitTransition(outfit: outfit, bodyContext: bodyContext)

        return assemblePrompt(
            subject: subjectSection(bodyContext: bodyContext),
            item: itemDesc,
            transition: transition,
            lighting: lightingSection(bodyContext: bodyContext),
            quality: qualitySection(bodyContext: bodyContext)
        )
    }

    /// Construit un prompt enrichi pour un JewelryItem (TryOn bijou).
    static func buildJewelry(
        for jewelry: JewelryItem,
        bodyContext: BodyContext
    ) -> String {
        let itemDesc = "wearing luxurious \(jewelry.name) (\(jewelry.material)) \(jewelry.category.rawValue.lowercased()). \(jewelry.prompt)."

        let transition: String
        switch jewelry.category {
        case .necklace:
            transition = "Show the décolleté area in exact skin tone \(bodyContext.skinHex). Collar bone and neck skin visible."
        case .earring:
            transition = "Show ears and side of neck in exact skin tone \(bodyContext.skinHex). Hair styled to display earrings."
        case .bracelet, .watch:
            transition = "Show wrist and forearm in exact skin tone \(bodyContext.skinHex). Natural wrist position."
        case .ring:
            transition = "Show hand and fingers in exact skin tone \(bodyContext.skinHex). Natural elegant hand pose."
        case .nosePiercing:
            transition = "Show face in exact skin tone \(bodyContext.skinHex), focusing on nose area. Natural light, close-up portrait."
        case .eyebrowPiercing:
            transition = "Show face in exact skin tone \(bodyContext.skinHex), focusing on brow area. Natural light, close-up portrait."
        case .lipPiercing:
            transition = "Show lower face in exact skin tone \(bodyContext.skinHex), focusing on lips. Natural light, close-up portrait."
        case .tonguePiercing:
            transition = "Show face in exact skin tone \(bodyContext.skinHex), mouth slightly open to reveal tongue. Natural light."
        }

        return assemblePrompt(
            subject: subjectSection(bodyContext: bodyContext),
            item: itemDesc,
            transition: transition,
            lighting: lightingSection(bodyContext: bodyContext),
            quality: "Photorealistic luxury jewelry photography, 8K. Skin texture ultra-detailed. Metal and gem reflections perfectly rendered. Preserve exact skin tone \(bodyContext.skinHex) from reference photo. Shot on 100mm macro lens."
        )
    }

    // MARK: - Multi-item outfit (Look du Jour — haut + bas + chaussures)

    /// Construit un prompt enrichi à partir d'une liste d'articles (look complet OU bijoux multiples).
    /// Catégorise les pièces (haut/bas/chaussures/robe/bijoux) pour une description fidèle.
    static func buildItems(
        _ items: [QuickTryOnItem],
        mode: QuickTryOnMode,
        bodyContext: BodyContext
    ) -> String {
        guard !items.isEmpty else { return "" }

        // Détection : si tous les articles sont des bijoux → router vers prompt bijou spécifique
        let allJewelry = items.allSatisfy { $0.fashionCategory.group == .jewelry }
        if allJewelry {
            return buildJewelryItemsPrompt(items, bodyContext: bodyContext)
        }

        // Si un seul article non bijou, déléguer à la méthode standard
        guard items.count > 1 else {
            guard let first = items.first else { return "" }
            return build(for: first, mode: mode, bodyContext: bodyContext)
        }

        // Catégoriser les pièces par slot
        let dressItem   = items.first { $0.fashionCategory == .dress }
        let topItem     = items.first { [.top, .jacket, .coat, .suit].contains($0.fashionCategory) }
        let bottomItem  = items.first { $0.fashionCategory == .bottom }
        let shoesItems  = items.filter { $0.fashionCategory.group == .shoes }
        let usedIDs     = Set([dressItem?.id, topItem?.id, bottomItem?.id].compactMap { $0 }
                              + shoesItems.map(\.id))
        let extraItems  = items.filter { !usedIDs.contains($0.id) }

        // Construire la description structurée en liste — chaque pièce DOIT être présente
        var outfitLines: [String] = ["OUTFIT — ALL GARMENTS LISTED MUST BE WORN SIMULTANEOUSLY ON THE SUBJECT:"]
        if let dress = dressItem {
            outfitLines.append("  • Dress (covers torso + lower body): \(buildItemDescription(dress))")
        } else {
            if let top = topItem    { outfitLines.append("  • Top (covers torso and chest): \(buildItemDescription(top))") }
            if let bot = bottomItem { outfitLines.append("  • Bottom (covers waist to ankles — pants/skirt): \(buildItemDescription(bot))") }
        }
        for shoe in shoesItems {
            outfitLines.append("  • Shoes (on feet): \(buildItemDescription(shoe))")
        }
        for extra in extraItems {
            outfitLines.append("  • Additional: \(buildItemDescription(extra))")
        }
        outfitLines.append("STRICT RULE: Do NOT omit any garment listed above. Do NOT substitute or invent different clothing. The subject MUST simultaneously wear all \(items.count) pieces.")

        let outfitBlock = outfitLines.joined(separator: "\n")

        let transition = """
        FULL BODY HEAD-TO-TOE composition required. Frame the subject from the top of the head down to the feet — every garment zone (chest, waist, legs, feet) must be visible in a single shot. \
        Do NOT crop above the ankles. Do NOT crop above the knees. \
        Any skin exposed by the outfit (arms, collarbone, ankles) must exactly match skin tone \(bodyContext.skinHex) and reference texture. \
        Maintain body proportions exactly. Keep face and hair identical to the reference photo.
        """

        return assemblePrompt(
            subject: subjectSection(bodyContext: bodyContext),
            item: "\(outfitBlock)\n\(mode.promptSuffix).",
            transition: transition,
            lighting: lightingSection(bodyContext: bodyContext),
            quality: qualitySection(bodyContext: bodyContext)
        )
    }

    /// Prompt dédié bijoux (boucles d'oreilles, colliers, bagues, bracelets) en multi-vue.
    /// Force l'IA à afficher EXACTEMENT le bijou demandé sur la bonne zone du corps,
    /// sans en inventer un autre.
    private static func buildJewelryItemsPrompt(
        _ items: [QuickTryOnItem],
        bodyContext: BodyContext
    ) -> String {
        var jewelryLines: [String] = ["JEWELRY — THE SUBJECT MUST WEAR EXACTLY THESE PIECES AND NO OTHER JEWELRY:"]
        var zonesNeeded: Set<String> = []

        for item in items {
            let zone: String
            switch item.fashionCategory {
            case .earring:
                zone = "BOTH ears (visible earrings on left AND right ear)"
                zonesNeeded.insert("ears")
            case .necklace:
                zone = "around the neck (visible on collarbone area)"
                zonesNeeded.insert("neck/collarbone")
            case .ring:
                zone = "on a finger (hand visible in frame)"
                zonesNeeded.insert("hand")
            case .bracelet, .watch:
                zone = "on the wrist (wrist visible in frame)"
                zonesNeeded.insert("wrist")
            default:
                zone = "on the appropriate body zone"
            }
            jewelryLines.append("  • \(item.categoryLabel.capitalized) — \(buildItemDescription(item)) — worn \(zone)")
        }

        jewelryLines.append("STRICT RULES:")
        jewelryLines.append("  - Do NOT add, invent, or substitute any other jewelry (no extra necklace, no random pendant, no broche).")
        jewelryLines.append("  - The subject must keep bare skin where no jewelry is listed.")
        jewelryLines.append("  - Each listed jewelry piece must be CLEARLY VISIBLE in the shot.")

        let jewelryBlock = jewelryLines.joined(separator: "\n")

        let zoneList = zonesNeeded.sorted().joined(separator: ", ")
        let transition = """
        Frame the shot so the following zones are clearly visible: \(zoneList.isEmpty ? "the jewelry area" : zoneList). \
        Show skin exactly matching tone \(bodyContext.skinHex). Keep face, hair, and identity unchanged from the reference photo. \
        Natural realistic pose — head turned slightly to reveal earrings if relevant.
        """

        let quality = "Photorealistic luxury jewelry photography, 8K. Metal and gem reflections perfectly rendered. Skin texture ultra-detailed. Shot on 100mm macro lens. Preserve exact skin tone \(bodyContext.skinHex)."

        return assemblePrompt(
            subject: subjectSection(bodyContext: bodyContext),
            item: jewelryBlock,
            transition: transition,
            lighting: lightingSection(bodyContext: bodyContext),
            quality: quality
        )
    }

    // MARK: - Legacy compatibility (remplace OutfitPromptBuilder.build)

    /// Compatibilité descendante — appelle buildOutfit avec un contexte par défaut.
    static func buildLegacy(outfit: Outfit, userContext: String) -> String {
        return OutfitPromptBuilder.build(outfit: outfit, userContext: userContext)
    }

    // MARK: - Private sections

    /// Section 1 — Subject (édition de la photo source, PAS une nouvelle photo)
    /// On formule une consigne d'ÉDITION : la sortie doit rester la même photo que
    /// l'entrée (même personne, même décor, même ambiance), on ne fait qu'ajouter
    /// l'article. Éviter tout vocabulaire « editorial / studio » qui pousse le modèle
    /// à re-générer une image léchée au lieu de respecter la photo de départ.
    private static func subjectSection(bodyContext: BodyContext) -> String {
        "EDIT the reference photograph of this real person (skin tone \(bodyContext.skinTone.description), \(bodyContext.skinUndertone.adjective) \(bodyContext.skinHex)). "
        + "This is the SAME photo: keep the person's face, hair, body, pose, the background and the overall atmosphere exactly as they are. "
        + "Do NOT turn it into a studio, editorial or beautified shot — only add the item described below."
    }

    /// Section 2 — Item (description précise du vêtement/bijou)
    private static func itemSection(description: String, mode: QuickTryOnMode) -> String {
        "\(description). \(mode.promptSuffix)."
    }

    /// Section 4 — Lighting (correspondance éclairage source)
    private static func lightingSection(bodyContext: BodyContext) -> String {
        "LIGHTING: Match the \(bodyContext.lightingType.rawValue) \(bodyContext.lightingDirection.description) detected in the reference photo. \(bodyContext.colorTemperature.description). Brightness: \(Int(bodyContext.brightnessLevel * 100))% — preserve this exact atmosphere."
    }

    /// Section 5 — Quality directives (fidélité à la photo source avant tout)
    private static func qualitySection(bodyContext: BodyContext) -> String {
        "QUALITY REQUIREMENTS: The result must look like the ORIGINAL photo with only the item added — same background, same lighting, same colours and white balance, same mood. "
        + "Do NOT relight, recolour, beautify, smooth skin, or replace the background. "
        + "Preserve exact skin texture and tone (\(bodyContext.skinHex)), keep body proportions exactly as shown (no body modification), and keep the face and hair completely unchanged. "
        + "Photorealistic and seamlessly composited, sharp. Vertical \(GenerationAspectRatio.tryOn) portrait, full-body head-to-toe when outfit try-on applies — never a square 1:1 crop."
    }

    /// Section 3 — Transition (spécifique outfit)
    private static func buildOutfitTransition(outfit: Outfit, bodyContext: BodyContext) -> String {
        var instructions: [String] = []

        let current = bodyContext.detectedClothing

        // Instruction par type de vêtement remplacé dans l'outfit
        let slots = outfit.slots
        if slots[.bottom] != nil || slots[.dress] != nil {
            if !current.filter({ $0.type == .bottom || $0.type == .dress }).isEmpty {
                let desc = current.first(where: { $0.type == .bottom || $0.type == .dress })?.description ?? "previous clothing"
                instructions.append("Previously wearing \(desc).")
            }
            instructions.append("Show legs and lower body in exact skin tone \(bodyContext.skinHex) if garment reveals them.")
        }

        if slots[.shoes] != nil {
            instructions.append("Adjust foot posture naturally for the specified footwear type.")
        }

        instructions.append("Any skin area exposed by the new outfit must exactly match skin tone \(bodyContext.skinHex) and reference texture.")

        return instructions.joined(separator: " ")
    }

    /// Assemblage final des 5 sections
    private static func assemblePrompt(
        subject: String,
        item: String,
        transition: String,
        lighting: String,
        quality: String
    ) -> String {
        [subject + ".", item, "CRITICAL TRANSITIONS: \(transition)", lighting, quality]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Description textuelle d'un QuickTryOnItem
    private static func buildItemDescription(_ item: QuickTryOnItem) -> String {
        var parts = [item.tryOnPrompt]
        if let color = item.color  { parts.append("color: \(color)") }
        if let brand = item.brand  { parts.append("by \(brand)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Optional<String> convenience

private extension Optional where Wrapped == String {
    func map<T>(_ transform: (String) -> T) -> T? {
        flatMap { $0.isEmpty ? nil : transform($0) }
    }
}

// MARK: - FashionItemRef name accessor

private extension Optional where Wrapped == FashionItemRef {
    var name: String? { self?.name }
}
