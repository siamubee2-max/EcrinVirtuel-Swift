import Foundation

// MARK: - WeatherSeason (saison dérivée météo + calendrier)

enum WeatherSeason: String, Codable, Sendable, CaseIterable {
    case printemps
    case ete
    case automne
    case hiver

    /// Hémisphère nord — dérivé principalement du mois civil.
    /// La température affine uniquement le cas extrême (printemps glacial → hiver).
    static func from(month: Int, temperatureC: Double) -> WeatherSeason {
        switch month {
        case 3...5:
            // Printemps calendaire ; si température vraiment hivernale, traiter comme hiver
            return temperatureC > 5 ? .printemps : .hiver
        case 6...8:
            return .ete
        case 9...11:
            // Automne calendaire quelle que soit la température
            return .automne
        default:
            // Décembre, janvier, février
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
