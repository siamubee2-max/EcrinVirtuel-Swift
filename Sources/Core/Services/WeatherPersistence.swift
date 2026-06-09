import Foundation

// MARK: - Clés UserDefaults météo / localisation

enum WeatherPersistence {
    static let userCityKey = "weather.userCity"
    static let lastLatitudeKey = "weather.lastLatitude"
    static let lastLongitudeKey = "weather.lastLongitude"
    static let locationSourceKey = "weather.locationSource"
    static let locationDeniedKey = "weather.locationDenied"
    static let snapshotCacheKey = "weather.snapshot"
    static let preferredGenderKey = "weather.preferredGender"

    static let cacheDuration: TimeInterval = 30 * 60
    static let significantMoveKm: Double = 20

    static let defaultLatitude = 48.8566
    static let defaultLongitude = 2.3522
    static let defaultCityName = "Paris"
}

enum WeatherLocationSource: String, Sendable {
    case gps
    case manual
    case ip
    case `default`
}
