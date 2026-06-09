import XCTest
@testable import EcrinVirtuel

final class WeatherLookRecommenderTests: XCTestCase {

    private let recommender = WeatherLookRecommender()

    private func rainyWeather() -> WeatherSnapshot {
        WeatherSnapshot(
            latitude: 48.85,
            longitude: 2.35,
            cityName: "Paris",
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000), // hiver
            temperatureC: 8,
            feelsLikeC: 6,
            precipitationMM: 1.2,
            windspeedKmh: 15,
            uvIndex: 1,
            weatherCode: 61
        )
    }

    private func hotWeather() -> WeatherSnapshot {
        WeatherSnapshot(
            latitude: 43.6,
            longitude: 1.44,
            cityName: "Toulouse",
            fetchedAt: Date(timeIntervalSince1970: 1_720_000_000), // été
            temperatureC: 28,
            feelsLikeC: 30,
            precipitationMM: 0,
            windspeedKmh: 10,
            uvIndex: 7,
            weatherCode: 0
        )
    }

    private func makeItem(
        name: String,
        gender: ClothingGender,
        category: String,
        styleTags: [String] = [],
        season: [String] = [],
        material: String? = nil,
        isFeatured: Bool = false
    ) -> CatalogClothingItem {
        CatalogClothingItem(
            id: UUID(),
            name: name,
            gender: gender,
            category: category,
            subcategory: nil,
            brand: nil,
            color: nil,
            material: material,
            styleTags: styleTags,
            season: season,
            imageURL: nil,
            tryOnPrompt: name,
            isFeatured: isFeatured,
            priceEur: nil,
            purchaseURL: nil
        )
    }

    func testScoreBoostsCoatInRain() {
        let weather = rainyWeather()
        let coat = makeItem(name: "Trench", gender: .femme, category: "coat", styleTags: ["imperméable"], season: ["automne"])
        let dress = makeItem(name: "Robe", gender: .femme, category: "dress", season: ["été"])

        let coatScore = recommender.score(item: coat, weather: weather, gender: .femme)
        let dressScore = recommender.score(item: dress, weather: weather, gender: .femme)

        XCTAssertGreaterThan(coatScore, dressScore)
        XCTAssertGreaterThan(coatScore, 0)
    }

    func testScorePenalizesWrongGender() {
        let weather = rainyWeather()
        let hommeItem = makeItem(name: "Blazer", gender: .homme, category: "jacket")
        XCTAssertEqual(recommender.score(item: hommeItem, weather: weather, gender: .femme), 0)
    }

    func testUnisexItemEligibleForFemme() {
        let weather = rainyWeather()
        let unisex = makeItem(name: "Parka", gender: .unisexe, category: "coat", season: ["hiver"])
        XCTAssertGreaterThan(recommender.score(item: unisex, weather: weather, gender: .femme), 0)
    }

    func testRecommendReturnsUpToSixItems() {
        let catalog = (0..<12).map { i in
            makeItem(
                name: "Manteau \(i)",
                gender: .femme,
                category: "coat",
                styleTags: ["imperméable"],
                season: ["hiver", "automne"]
            )
        }
        let result = recommender.recommend(weather: rainyWeather(), gender: .femme, catalog: catalog, limit: 6)
        XCTAssertLessThanOrEqual(result.items.count, 6)
        XCTAssertGreaterThan(result.items.count, 0)
        XCTAssertFalse(result.headline.isEmpty)
        XCTAssertFalse(result.subline.isEmpty)
    }

    func testHotWeatherPrefersDressOverCoat() {
        let weather = hotWeather()
        let dress = makeItem(name: "Robe lin", gender: .femme, category: "dress", styleTags: ["été"], season: ["été"], material: "lin")
        let coat = makeItem(name: "Doudoune", gender: .femme, category: "coat", season: ["hiver"])

        let dressScore = recommender.score(item: dress, weather: weather, gender: .femme)
        let coatScore = recommender.score(item: coat, weather: weather, gender: .femme)

        XCTAssertGreaterThan(dressScore, coatScore)
    }

    func testFallbackUsesFeaturedWhenCatalogThin() {
        let weather = rainyWeather()
        let catalog = [
            makeItem(name: "Featured", gender: .femme, category: "top", isFeatured: true),
            makeItem(name: "Other", gender: .homme, category: "coat"),
        ]
        let result = recommender.recommend(weather: weather, gender: .femme, catalog: catalog, limit: 6)
        XCTAssertFalse(result.items.isEmpty)
    }
}
