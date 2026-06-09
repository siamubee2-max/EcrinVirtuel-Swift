import Foundation

// MARK: - Stone Detector

/// Analyses a JewelryItem's name and prompt to identify the associated stone.
struct StoneDetector {

    // Maps of keywords to stone names (French and English)
    private static let keywordMap: [String: String] = [
        // French names
        "améthyste": "Améthyste",
        "amethyste": "Améthyste",
        "quartz rose": "Rose Quartz",
        "rose quartz": "Rose Quartz",
        "lapis lazuli": "Lapis Lazuli",
        "labradorite": "Labradorite",
        "turquoise": "Turquoise",
        "malachite": "Malachite",
        "citrine": "Citrine",
        "obsidienne": "Obsidienne",
        "obsidian": "Obsidienne",
        "aventurine": "Aventurine",
        "moonstone": "Moonstone",
        "pierre de lune": "Moonstone",
        "oeil de tigre": "Tiger Eye",
        "tiger eye": "Tiger Eye",
        "tiger's eye": "Tiger Eye",
        "onyx": "Onyx",
        "rhodonite": "Rhodonite",
        "amazonite": "Amazonite",
        "cornaline": "Cornaline",
        "carnelian": "Cornaline",
        "pyrite": "Pyrite",
        "selenite": "Sélénite",
        "sélénite": "Sélénite",
        "howlite": "Howlite",
        "sodalite": "Sodalite",
        "jaspe rouge": "Jaspe Rouge",
        "red jasper": "Jaspe Rouge",
        "jasper": "Jaspe Rouge",
        "aigue-marine": "Aigue-Marine",
        "aigue marine": "Aigue-Marine",
        "aquamarine": "Aigue-Marine",
        "fluorite": "Fluorite",
        "chrysocolla": "Chrysocolla",
        "unakite": "Unakite",
        "sunstone": "Sunstone",
        "pierre de soleil": "Sunstone",
        "shungite": "Shungite",
        "prehnite": "Prehnite",
        "kunzite": "Kunzite",
        "larimar": "Larimar",
        "charoite": "Charoïte",
        "charoïte": "Charoïte",
        // Material keywords
        "améthyste sertie": "Améthyste",
        "serti améthyste": "Améthyste",
        "camée labradorite": "Labradorite",
    ]

    /// Detects a stone from a JewelryItem's name and prompt.
    static func detectStone(in item: JewelryItem) -> Stone? {
        let haystack = "\(item.name) \(item.prompt) \(item.material)"
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        // Sort by length descending to prefer longer matches (e.g. "quartz rose" before "quartz")
        let sortedKeys = keywordMap.keys.sorted { $0.count > $1.count }

        for keyword in sortedKeys {
            let normalized = keyword
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            if haystack.contains(normalized) {
                let stoneName = keywordMap[keyword]!
                return StoneDatabase.stone(named: stoneName)
            }
        }
        return nil
    }

    /// Detects a stone from arbitrary text (prompt, description, etc.)
    static func detectStone(inText text: String) -> Stone? {
        let haystack = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        let sortedKeys = keywordMap.keys.sorted { $0.count > $1.count }

        for keyword in sortedKeys {
            let normalized = keyword
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            if haystack.contains(normalized) {
                let stoneName = keywordMap[keyword]!
                return StoneDatabase.stone(named: stoneName)
            }
        }
        return nil
    }
}
