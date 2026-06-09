import Foundation

// MARK: - WeatherSnapshot

struct WeatherSnapshot: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let cityName: String?
    let fetchedAt: Date

    let temperatureC: Double
    let feelsLikeC: Double
    let precipitationMM: Double
    let windspeedKmh: Double
    let uvIndex: Double
    let weatherCode: Int

    var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }

    var formattedTemp: String { "\(Int(temperatureC.rounded()))°C" }

    var isRainy: Bool {
        precipitationMM > 0.2 || condition == .rain || condition == .drizzle || condition == .thunderstorm
    }

    var isHot: Bool { temperatureC >= 25 }
    var isCold: Bool { temperatureC < 10 }
    var isMild: Bool { !isHot && !isCold }
    var isWindy: Bool { windspeedKmh > 30 }
    var isSunny: Bool { [0, 1].contains(weatherCode) && uvIndex > 3 }

    var weatherSeason: WeatherSeason {
        let month = Calendar.current.component(.month, from: fetchedAt)
        return WeatherSeason.from(month: month, temperatureC: temperatureC)
    }

    var weatherEmojiLine: String {
        let city = cityName ?? "Votre ville"
        return "\(condition.emoji) \(city) · \(formattedTemp) · \(condition.label)"
    }

    /// Distance en km entre deux coordonnées (formule haversine simplifiée).
    func distanceKm(to otherLat: Double, otherLon: Double) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (otherLat - latitude) * .pi / 180
        let dLon = (otherLon - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(otherLat * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }
}
