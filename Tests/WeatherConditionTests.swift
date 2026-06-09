import XCTest
@testable import EcrinVirtuel

final class WeatherConditionTests: XCTestCase {

    func testClearSkyWMO0() {
        XCTAssertEqual(WeatherCondition(wmoCode: 0), .clearSky)
    }

    func testPartlyCloudyWMO1to3() {
        XCTAssertEqual(WeatherCondition(wmoCode: 1), .partlyCloudy)
        XCTAssertEqual(WeatherCondition(wmoCode: 3), .partlyCloudy)
    }

    func testFoggyWMO45and48() {
        XCTAssertEqual(WeatherCondition(wmoCode: 45), .foggy)
        XCTAssertEqual(WeatherCondition(wmoCode: 48), .foggy)
    }

    func testDrizzleWMO51to57() {
        XCTAssertEqual(WeatherCondition(wmoCode: 51), .drizzle)
        XCTAssertEqual(WeatherCondition(wmoCode: 57), .drizzle)
    }

    func testRainWMO61to67andShowers() {
        XCTAssertEqual(WeatherCondition(wmoCode: 61), .rain)
        XCTAssertEqual(WeatherCondition(wmoCode: 80), .rain)
        XCTAssertEqual(WeatherCondition(wmoCode: 82), .rain)
    }

    func testSnowWMO71to77() {
        XCTAssertEqual(WeatherCondition(wmoCode: 71), .snow)
        XCTAssertEqual(WeatherCondition(wmoCode: 77), .snow)
    }

    func testThunderstormWMO95to99() {
        XCTAssertEqual(WeatherCondition(wmoCode: 95), .thunderstorm)
        XCTAssertEqual(WeatherCondition(wmoCode: 99), .thunderstorm)
    }

    func testUnknownCodeDefaultsToPartlyCloudy() {
        XCTAssertEqual(WeatherCondition(wmoCode: 42), .partlyCloudy)
    }

    func testFrenchLabelsAreNonEmpty() {
        for condition in WeatherCondition.allCases {
            XCTAssertFalse(condition.label.isEmpty)
            XCTAssertFalse(condition.emoji.isEmpty)
        }
    }
}
