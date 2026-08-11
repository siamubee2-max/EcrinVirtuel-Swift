import Foundation

// MARK: - WeatherLookRecommender

/// Moteur pur de scoring catalogue × météo × genre (testable unitairement).
/// Supporte optionnellement la garde-robe de l'utilisateur : les articles
/// de la garde-robe sont préférés pour chaque slot de la tenue.
/// Le paramètre `undertone` affine le choix des bijoux (sous-ton chaud → or, froid → argent).
struct WeatherLookRecommender: Sendable {

    func recommend(
        weather: WeatherSnapshot,
        gender: ClothingGender,
        catalog: [CatalogClothingItem],
        wardrobeItems: [FashionItem] = [],
        undertone: SkinUndertone? = nil,
        maxBudget: Double? = nil,
        limit: Int = 6
    ) -> LookRecommendation {
        let eligible = catalog.filter {
            matchesGender($0, userGender: gender)
            && (maxBudget == nil || ($0.priceEur ?? 0) <= maxBudget!)
        }

        // Scorer tous les articles éligibles (saison stricte d'abord)
        var scoredPool = eligible
            .map { ($0, score(item: $0, weather: weather, gender: gender)) }
            .sorted { $0.1 > $1.1 }

        // Si peu d'articles scorés positivement, élargir à toutes saisons
        if scoredPool.filter({ $0.1 > 0 }).count < 6 {
            scoredPool = eligible
                .map { ($0, max(score(item: $0, weather: weather, gender: gender, ignoreSeason: true), 0.1)) }
                .sorted { $0.1 > $1.1 }
        }

        // Assemblage mixte : préférence garde-robe > catalogue pour chaque slot
        let (catalogResult, wardrobeResult) = assembleMixed(
            from: scoredPool,
            wardrobe: wardrobeItems,
            weather: weather,
            undertone: undertone,
            limit: limit
        )

        // Subline : articles garde-robe en premier, puis catalogue
        let allNames = (wardrobeResult.prefix(2).map(\.name) + catalogResult.prefix(2).map(\.name)).prefix(3)
        let subline = allNames.joined(separator: " + ")
        let headline = makeHeadline(weather: weather, gender: gender)
        let styleTag = pickStyleTag(weather: weather, items: catalogResult)

        return LookRecommendation(
            weather: weather,
            gender: gender,
            items: catalogResult,
            wardrobeItems: wardrobeResult,
            headline: headline,
            subline: subline.isEmpty ? "Sélectionnez des pièces du catalogue" : subline,
            styleTag: styleTag
        )
    }

    // MARK: - Assemblage tenue complète (haut + bas + chaussures)

    /// Construit une tenue garantissant haut, bas et chaussures.
    /// Une robe compte comme haut + bas simultanément.
    private func assemble(
        from scoredPool: [(CatalogClothingItem, Double)],
        weather: WeatherSnapshot,
        limit: Int
    ) -> [CatalogClothingItem] {
        var result: [CatalogClothingItem] = []
        var usedIDs = Set<String>()

        func best(for categories: [String]) -> CatalogClothingItem? {
            scoredPool.first { item, _ in
                categories.contains(item.category.lowercased()) && !usedIDs.contains(item.id.uuidString)
            }.map(\.0)
        }

        func pick(_ item: CatalogClothingItem) {
            result.append(item)
            usedIDs.insert(item.id.uuidString)
        }

        // 1. Slot HAUT — top ou jacket, sinon dress (couvre aussi le bas)
        let hasDress: Bool
        if let topItem = best(for: ["top", "jacket"]) {
            pick(topItem)
            hasDress = false
        } else if let dress = best(for: ["dress"]) {
            pick(dress)
            hasDress = true
        } else {
            hasDress = false
        }

        // 2. Slot BAS — bottom (sauf si une robe a déjà été choisie)
        if !hasDress {
            if let bottomItem = best(for: ["bottom"]) {
                pick(bottomItem)
            } else if let dress = best(for: ["dress"]) {
                // Aucun bas dispo → remplacer le slot par une robe
                pick(dress)
            }
        }

        // 3. Slot CHAUSSURES
        if let shoes = best(for: ["shoes"]) {
            pick(shoes)
        }

        // 4. Compléter jusqu'à la limite avec les meilleurs articles restants
        //    (jacket, accessory, coat…)
        for (item, _) in scoredPool {
            guard result.count < limit else { break }
            guard !usedIDs.contains(item.id.uuidString) else { continue }
            pick(item)
        }

        return result
    }

    // MARK: - Assemblage mixte garde-robe + catalogue

    /// Construit une tenue en préférant les articles de la garde-robe pour chaque slot,
    /// et en complétant avec le catalogue pour les slots non couverts.
    /// Retourne (catalogItems, wardrobeItems) séparément pour LookRecommendation.
    /// Le `undertone` affine le choix du bijou (chaud → or, froid → argent).
    private func assembleMixed(
        from scoredPool: [(CatalogClothingItem, Double)],
        wardrobe: [FashionItem],
        weather: WeatherSnapshot,
        undertone: SkinUndertone? = nil,
        limit: Int
    ) -> ([CatalogClothingItem], [FashionItem]) {
        var wardrobeUsed = Set<UUID>()
        var catalogUsedIDs = Set<String>()
        var wardrobeResult: [FashionItem] = []
        var catalogResult: [CatalogClothingItem] = []

        // Cherche le meilleur article de garde-robe pour les catégories données
        func bestWardrobeItem(for categories: [FashionCategory]) -> FashionItem? {
            wardrobe.first { !wardrobeUsed.contains($0.id) && categories.contains($0.category) }
        }

        // Cherche le meilleur article catalogue pour les catégories (noms de cat catalogue)
        func bestCatalogItem(for categories: [String]) -> CatalogClothingItem? {
            scoredPool.first { item, _ in
                categories.contains(item.category.lowercased()) && !catalogUsedIDs.contains(item.id.uuidString)
            }.map(\.0)
        }

        // Slot HAUT
        let topWardrobeCategories: [FashionCategory] = [.top, .jacket, .coat, .dress]
        if let wTop = bestWardrobeItem(for: topWardrobeCategories) {
            wardrobeResult.append(wTop)
            wardrobeUsed.insert(wTop.id)
        } else if let cTop = bestCatalogItem(for: ["top", "jacket"]) {
            catalogResult.append(cTop)
            catalogUsedIDs.insert(cTop.id.uuidString)
        } else if let cDress = bestCatalogItem(for: ["dress"]) {
            // Robe couvre haut + bas
            catalogResult.append(cDress)
            catalogUsedIDs.insert(cDress.id.uuidString)
        }

        // Slot BAS (sauf si robe déjà prise côté catalogue)
        let hasCatalogDress = catalogResult.first?.category.lowercased() == "dress"
        let hasWardrobeDress = wardrobeResult.first?.category == .dress
        if !hasCatalogDress && !hasWardrobeDress {
            let bottomWardrobeCategories: [FashionCategory] = [.bottom]
            if let wBottom = bestWardrobeItem(for: bottomWardrobeCategories) {
                wardrobeResult.append(wBottom)
                wardrobeUsed.insert(wBottom.id)
            } else if let cBottom = bestCatalogItem(for: ["bottom"]) {
                catalogResult.append(cBottom)
                catalogUsedIDs.insert(cBottom.id.uuidString)
            } else if let cDress = bestCatalogItem(for: ["dress"]) {
                catalogResult.append(cDress)
                catalogUsedIDs.insert(cDress.id.uuidString)
            }
        }

        // Slot CHAUSSURES
        let shoesWardrobeCategories: [FashionCategory] = [.heels, .flats, .boots, .sneakers, .sandals, .loafers]
        if let wShoes = bestWardrobeItem(for: shoesWardrobeCategories) {
            wardrobeResult.append(wShoes)
            wardrobeUsed.insert(wShoes.id)
        } else if let cShoes = bestCatalogItem(for: ["shoes"]) {
            catalogResult.append(cShoes)
            catalogUsedIDs.insert(cShoes.id.uuidString)
        }

        // Slot BIJOU (optionnel — pris depuis la garde-robe, trié par affinité métal + isFavorite)
        let jewelryCategories: [FashionCategory] = [.necklace, .ring, .earring, .bracelet, .watch, .brooch]
        let jewelryCandidates = wardrobe
            .filter { jewelryCategories.contains($0.category) && !wardrobeUsed.contains($0.id) }
            .sorted { a, b in
                let scoreA = metalAffinityScore(item: a, undertone: undertone) + (a.isFavorite ? 2.0 : 0.0)
                let scoreB = metalAffinityScore(item: b, undertone: undertone) + (b.isFavorite ? 2.0 : 0.0)
                return scoreA > scoreB
            }
        if let wJewel = jewelryCandidates.first {
            wardrobeResult.append(wJewel)
            wardrobeUsed.insert(wJewel.id)
        }

        // Compléter avec les meilleurs articles catalogue restants jusqu'à la limite
        let totalCount = wardrobeResult.count + catalogResult.count
        if totalCount < limit {
            for (item, _) in scoredPool {
                guard wardrobeResult.count + catalogResult.count < limit else { break }
                guard !catalogUsedIDs.contains(item.id.uuidString) else { continue }
                catalogResult.append(item)
                catalogUsedIDs.insert(item.id.uuidString)
            }
        }

        return (catalogResult, wardrobeResult)
    }

    // MARK: - Scoring métal × sous-ton de peau

    /// Retourne un score d'affinité entre un bijou de garde-robe et le sous-ton de peau.
    /// Sous-ton chaud  → or / doré / laiton : score +3
    /// Sous-ton froid  → argent / platine / acier : score +3
    /// Neutre ou nil   → score 0 (pas de biais)
    private func metalAffinityScore(item: FashionItem, undertone: SkinUndertone?) -> Double {
        guard let undertone, undertone != .neutral else { return 0 }

        let searchFields = [
            item.name,
            item.color ?? "",
            item.material ?? "",
            item.brand ?? ""
        ].joined(separator: " ").lowercased()

        let goldKeywords   = ["or ", "doré", "doree", "gold", "laiton", "brass", "bronze",
                              "vermeil", "rose gold", "rosé", "cuivre", "copper"]
        let silverKeywords = ["argent", "silver", "platine", "platinum", "rhodié", "925",
                              "acier", "steel", "or blanc", "white gold"]

        let isGold   = goldKeywords.contains   { searchFields.contains($0) }
        let isSilver = silverKeywords.contains { searchFields.contains($0) }

        switch undertone {
        case .warm:
            if isGold   { return 3.0 }
            if isSilver { return -1.0 }
            return 0
        case .cool:
            if isSilver { return 3.0 }
            if isGold   { return -1.0 }
            return 0
        case .neutral:
            return 0
        }
    }

    func score(
        item: CatalogClothingItem,
        weather: WeatherSnapshot,
        gender: ClothingGender,
        ignoreSeason: Bool = false
    ) -> Double {
        guard matchesGender(item, userGender: gender) else { return 0 }

        var total = 0.0
        if item.isFeatured { total += 10 }

        total += Double(categoryBoost(item: item, weather: weather)) * 30
        if !ignoreSeason {
            total += Double(seasonMatch(item: item, weather: weather)) * 20
        }
        total += Double(materialBoost(item: item, weather: weather)) * 15
        total += Double(styleTagBoost(item: item, weather: weather)) * 15

        return total
    }

    // MARK: - Filtres

    private func matchesGender(_ item: CatalogClothingItem, userGender: ClothingGender) -> Bool {
        item.gender == userGender || item.gender == .unisexe
    }

    // MARK: - Scoring

    private func categoryBoost(item: CatalogClothingItem, weather: WeatherSnapshot) -> Int {
        let cat = item.category.lowercased()
        var boost = 0
        var penalty = 0

        if weather.isRainy || weather.condition == .thunderstorm {
            boost += ["coat", "jacket"].contains(cat) ? 2 : 0
            if cat == "dress" { penalty += 2 }
            if cat == "shoes", isSandals(item) { penalty += 2 }
        }

        if weather.isCold {
            boost += ["coat", "jacket", "top"].contains(cat) ? 2 : 0
            if cat == "dress", isLightDress(item) { penalty += 1 }
            if cat == "shoes", isSandals(item) { penalty += 2 }
        }

        if weather.isHot {
            boost += ["dress", "top", "bottom"].contains(cat) ? 1 : 0
            if ["coat", "jacket"].contains(cat) { penalty += 2 }
        }

        if weather.isMild {
            boost += ["jacket", "top", "bottom"].contains(cat) ? 1 : 0
        }

        if weather.isWindy {
            boost += ["jacket", "coat"].contains(cat) ? 1 : 0
            if cat == "dress" { penalty += 1 }
        }

        if weather.isSunny && weather.uvIndex > 5 {
            boost += ["top", "accessory"].contains(cat) ? 1 : 0
        }

        if weather.condition == .snow {
            boost += ["coat"].contains(cat) ? 2 : 0
            if isSandals(item) || cat == "dress" { penalty += 2 }
        }

        return max(0, boost - penalty)
    }

    private func seasonMatch(item: CatalogClothingItem, weather: WeatherSnapshot) -> Int {
        // Le catalogue tague en anglais + "all" (cf. WeatherSeason.seasonTags) :
        // comparer au rawValue français ("ete"…) ne matchait jamais en production.
        let targets = Set(weather.weatherSeason.seasonTags.map { $0.lowercased() })
        if item.season.contains(where: { targets.contains($0.lowercased()) }) { return 2 }
        return 0
    }

    private func materialBoost(item: CatalogClothingItem, weather: WeatherSnapshot) -> Int {
        let material = (item.material ?? "").lowercased()
        let tags = item.styleTags.map { $0.lowercased() }
        var boost = 0

        if weather.isHot {
            if material.contains("lin") || material.contains("coton") { boost += 1 }
            if tags.contains(where: { $0.contains("lin") || $0.contains("été") || $0.contains("legere") || $0.contains("légère") }) {
                boost += 1
            }
        }

        if weather.isCold {
            if material.contains("laine") || material.contains("cachemire") { boost += 1 }
            if tags.contains(where: { $0.contains("laine") || $0.contains("hiver") || $0.contains("manteau") }) {
                boost += 1
            }
        }

        if weather.isRainy {
            if tags.contains(where: { $0.contains("imperméable") || $0.contains("trench") || $0.contains("ciré") || $0.contains("cire") }) {
                boost += 2
            }
        }

        return boost
    }

    private func styleTagBoost(item: CatalogClothingItem, weather: WeatherSnapshot) -> Int {
        let tags = item.styleTags.map { $0.lowercased() }
        var boost = 0

        if weather.isMild {
            if tags.contains(where: { ["casual", "bureau", "élégant", "elegant"].contains($0) }) { boost += 1 }
        }
        if weather.isHot {
            if tags.contains(where: { $0.contains("été") || $0.contains("ete") || $0.contains("casual") }) { boost += 1 }
        }
        if weather.isCold {
            if tags.contains(where: { $0.contains("cocooning") || $0.contains("hiver") }) { boost += 1 }
        }
        if weather.isRainy {
            if tags.contains(where: { $0.contains("urban") || $0.contains("chic") }) { boost += 1 }
        }

        return boost
    }

    private func isSandals(_ item: CatalogClothingItem) -> Bool {
        let sub = item.subcategory?.lowercased() ?? ""
        return sub.contains("sandale") || sub.contains("sandal")
    }

    private func isLightDress(_ item: CatalogClothingItem) -> Bool {
        let mat = item.material?.lowercased() ?? ""
        return mat.contains("soie") || mat.contains("lin") || mat.contains("viscose")
    }

    // MARK: - Copy

    private func makeHeadline(weather: WeatherSnapshot, gender: ClothingGender) -> String {
        let city = weather.cityName ?? "votre ville"
        let prefix: String
        switch weather.condition {
        case .rain, .drizzle, .thunderstorm:
            prefix = gender == .homme ? "Look Pluie" : "Look Pluie"
        case .snow:
            prefix = "Look Hiver"
        case .clearSky where weather.isHot:
            prefix = "Look Été"
        default:
            prefix = gender == .homme ? "Look du Jour" : "Journée"
        }
        return "\(prefix) \(city)"
    }

    private func pickStyleTag(weather: WeatherSnapshot, items: [CatalogClothingItem]) -> String {
        if weather.isRainy { return "Urban Chic" }
        if weather.isCold { return "Cocooning" }
        if weather.isHot { return "Été léger" }
        if let tag = items.flatMap(\.styleTags).first { return tag.capitalized }
        return "Casual"
    }
}
