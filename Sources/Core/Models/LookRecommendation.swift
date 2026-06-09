import Foundation

// MARK: - LookRecommendation

struct LookRecommendation: Identifiable, Sendable {
    let id: UUID
    let weather: WeatherSnapshot
    let gender: ClothingGender
    /// Articles catalogue sélectionnés par le recommandeur (slots non couverts par la garde-robe).
    let items: [CatalogClothingItem]
    /// Articles de la garde-robe de l'utilisateur préférés pour cette tenue.
    /// Vide si aucun article compatible n'existe dans la garde-robe.
    let wardrobeItems: [FashionItem]
    let headline: String
    let subline: String
    let styleTag: String
    let generatedAt: Date
    let weatherEmoji: String

    /// Tous les articles de la tenue sous forme QuickTryOnItem : garde-robe en priorité, catalogue en complément.
    var allItems: [QuickTryOnItem] {
        var result: [QuickTryOnItem] = wardrobeItems.map { .wardrobe($0) }
        let wardrobeCats = Set(wardrobeItems.map(\.category))
        for catalogItem in items where !wardrobeCats.contains(catalogItem.asFashionItem.category) {
            result.append(.catalog(catalogItem))
        }
        return result
    }

    init(
        id: UUID = UUID(),
        weather: WeatherSnapshot,
        gender: ClothingGender,
        items: [CatalogClothingItem],
        wardrobeItems: [FashionItem] = [],
        headline: String,
        subline: String,
        styleTag: String,
        generatedAt: Date = .now,
        weatherEmoji: String? = nil
    ) {
        self.id = id
        self.weather = weather
        self.gender = gender
        self.items = items
        self.wardrobeItems = wardrobeItems
        self.headline = headline
        self.subline = subline
        self.styleTag = styleTag
        self.generatedAt = generatedAt
        self.weatherEmoji = weatherEmoji ?? weather.weatherEmojiLine
    }
}
