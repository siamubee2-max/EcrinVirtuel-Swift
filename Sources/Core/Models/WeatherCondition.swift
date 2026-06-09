import Foundation

// MARK: - WeatherCondition (codes WMO Open-Meteo)

enum WeatherCondition: String, CaseIterable, Codable, Sendable {
    case clearSky
    case partlyCloudy
    case foggy
    case drizzle
    case rain
    case snow
    case thunderstorm

    init(wmoCode: Int) {
        switch wmoCode {
        case 0:
            self = .clearSky
        case 1...3:
            self = .partlyCloudy
        case 45, 48:
            self = .foggy
        case 51...57:
            self = .drizzle
        case 61...67, 80...82:
            self = .rain
        case 71...77:
            self = .snow
        case 95...99:
            self = .thunderstorm
        default:
            self = .partlyCloudy
        }
    }

    var emoji: String {
        switch self {
        case .clearSky:     return "☀️"
        case .partlyCloudy: return "⛅"
        case .foggy:        return "🌫"
        case .drizzle:      return "🌦"
        case .rain:         return "🌧"
        case .snow:         return "❄️"
        case .thunderstorm: return "⛈"
        }
    }

    var label: String {
        switch self {
        case .clearSky:     return "Ciel dégagé"
        case .partlyCloudy: return "Partiellement nuageux"
        case .foggy:        return "Brouillard"
        case .drizzle:      return "Bruine"
        case .rain:         return "Pluie"
        case .snow:         return "Neige"
        case .thunderstorm: return "Orage"
        }
    }
}
