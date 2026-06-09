import Foundation

// MARK: - WeatherSeason (saison dérivée météo + calendrier)

enum WeatherSeason: String, Codable, Sendable, CaseIterable {
    case printemps
    case ete
    case automne
    case hiver

    /// Hémisphère nord — combine mois civil et température actuelle.
    static func from(month: Int, temperatureC: Double) -> WeatherSeason {
        switch month {
        case 3...5 where temperatureC > 5:
            return .printemps
        case 6...8:
            return .ete
        case 9...11 where temperatureC < 20:
            return .automne
        default:
            return .hiver
        }
    }

    /// Tags utilisés pour matcher les articles du catalogue Supabase.
    /// Le catalogue utilise des tags anglais + "all" pour les articles toutes saisons.
    var seasonTags: [String] {
        switch self {
        case .printemps: return ["spring", "printemps", "all"]
        case .ete:       return ["summer", "ete", "été", "all"]
        case .automne:   return ["fall", "autumn", "automne", "all"]
        case .hiver:     return ["winter", "hiver", "all"]
        }
    }
}
