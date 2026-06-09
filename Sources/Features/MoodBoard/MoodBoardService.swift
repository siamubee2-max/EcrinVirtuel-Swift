import Foundation

// MARK: - Mood Board Generation Service
// Namespace de fonctions statiques — pas d'état, pas de conformance ObservableObject nécessaire.

enum MoodBoardService {

    // MARK: - Generation

    static func generate(
        prompt: String,
        occasion: MoodOccasion?,
        style: MoodStyle?,
        season: MoodSeason?
    ) async throws -> MoodBoard {
        // Simulate AI generation delay
        try await Task.sleep(nanoseconds: 1_800_000_000)

        let keywords  = extractKeywords(prompt: prompt, occasion: occasion, style: style, season: season)
        let items     = selectJewelry(keywords: keywords, style: style, occasion: occasion)
        let palette   = buildPalette(season: season, occasion: occasion, style: style)
        let desc      = generateDescription(
            prompt: prompt, occasion: occasion, style: style,
            season: season, topItem: items.first
        )
        let title     = generateTitle(occasion: occasion, style: style, prompt: prompt)

        return MoodBoard(
            title: title,
            prompt: prompt,
            occasion: occasion?.rawValue ?? "",
            style: style?.rawValue ?? "",
            jewelryItems: items,
            generatedDescription: desc,
            colorPalette: palette,
            keywords: keywords,
            createdAt: .now
        )
    }

    // MARK: - Keyword Extraction

    private static func extractKeywords(
        prompt: String,
        occasion: MoodOccasion?,
        style: MoodStyle?,
        season: MoodSeason?
    ) -> [String] {
        var kw: [String] = []

        if let o = occasion { kw.append(o.rawValue) }
        if let s = style    { kw.append(s.rawValue) }
        if let s = season   { kw.append(s.rawValue) }

        // Parse prompt
        let lower = prompt.lowercased()
        let enrichments: [String: [String]] = [
            "paris":    ["Parisien", "Chic", "Élégance"],
            "soirée":   ["Nuit", "Glamour", "Sophistiqué"],
            "mariage":  ["Bridal", "Éternel", "Raffiné"],
            "été":      ["Solaire", "Léger", "Lumineux"],
            "hiver":    ["Précieux", "Intime", "Profond"],
            "plage":    ["Aquatique", "Naturel", "Libre"],
            "business": ["Confiant", "Puissant", "Structuré"],
            "voyage":   ["Aventurier", "Libre", "Découverte"],
            "date":     ["Séduisant", "Sensuel", "Magnétique"],
            "gala":     ["Grandiose", "Aristocratique", "Somptueux"],
        ]

        for (key, tags) in enrichments {
            if lower.contains(key) { kw.append(contentsOf: tags) }
        }

        return Array(Set(kw)).prefix(6).map { $0 }
    }

    // MARK: - Jewelry Selection

    private static func selectJewelry(
        keywords: [String],
        style: MoodStyle?,
        occasion: MoodOccasion?
    ) -> [JewelryItem] {
        var pool = JewelryItem.samples

        // Extended catalog for mood board
        let extended: [JewelryItem] = [
            JewelryItem(id: UUID(), name: "Manchette", category: .bracelet,
                        imageURL: nil, icon: "rectangle.roundedtop.fill",
                        material: "Or jaune · Diamants",
                        prompt: "gold diamond cuff bracelet on wrist"),
            JewelryItem(id: UUID(), name: "Chandelier", category: .earring,
                        imageURL: nil, icon: "drop.fill",
                        material: "Or blanc · Émeraudes",
                        prompt: "emerald chandelier earrings"),
            JewelryItem(id: UUID(), name: "Multi-rangs", category: .necklace,
                        imageURL: nil, icon: "circles.hexagonpath.fill",
                        material: "Perles naturelles · Or",
                        prompt: "multi strand pearl necklace"),
            JewelryItem(id: UUID(), name: "Pavé",  category: .ring,
                        imageURL: nil, icon: "square.grid.3x3.fill",
                        material: "Or blanc · Diamants pavé",
                        prompt: "diamond pave ring on finger"),
            JewelryItem(id: UUID(), name: "Chevalière", category: .ring,
                        imageURL: nil, icon: "seal.fill",
                        material: "Or jaune 18k",
                        prompt: "signet ring gold on hand"),
        ]
        pool.append(contentsOf: extended)

        // Style-based filtering
        var selected: [JewelryItem] = []

        switch style {
        case .minimaliste:
            selected = pool.filter { ["Solitaire", "Chevalière", "Jonc"].contains($0.name) }
        case .boheme:
            selected = pool.filter { ["Créoles", "Multi-rangs", "Chandelier"].contains($0.name) }
        case .classique, .vintage:
            selected = pool.filter { ["Rivière", "Solitaire", "Pendentif"].contains($0.name) }
        case .romantique:
            selected = pool.filter { ["Pendentif", "Chandelier", "Pavé"].contains($0.name) }
        case .avantGarde, .modern:
            selected = pool.filter { ["Manchette", "Pavé", "Chevalière"].contains($0.name) }
        case .sportyChic:
            selected = pool.filter { ["Créoles", "Jonc", "Solitaire"].contains($0.name) }
        default:
            break
        }

        // Occasion-based override if needed
        if selected.count < 3 {
            switch occasion {
            case .gala, .mariage:
                selected = pool.filter { ["Rivière", "Chandelier", "Solitaire", "Pavé", "Pendentif"].contains($0.name) }
            case .plage, .quotidien:
                selected = pool.filter { ["Créoles", "Jonc", "Solitaire"].contains($0.name) }
            case .business:
                selected = pool.filter { ["Solitaire", "Chevalière", "Pendentif"].contains($0.name) }
            default:
                selected = Array(pool.prefix(5))
            }
        }

        // Ensure between 3 and 5 items
        let uniqueSelected = Array(Set(selected.map { $0.id }).compactMap { id in selected.first(where: { $0.id == id }) })
        if uniqueSelected.count < 3 {
            return Array(pool.shuffled().prefix(4))
        }
        return Array(uniqueSelected.prefix(5))
    }

    // MARK: - Color Palette

    private static func buildPalette(
        season: MoodSeason?,
        occasion: MoodOccasion?,
        style: MoodStyle?
    ) -> [String] {
        // Start with season base
        var palette = season?.palette ?? ["#1A1A1A", "#CA8A04", "#FAFAF9", "#374151"]

        // Override for specific occasions
        switch occasion {
        case .mariage:
            palette = ["#FAFAF9", "#F5D37A", "#E8D5C4", "#D4B8A0", "#8B7355"]
        case .gala:
            palette = ["#080808", "#CA8A04", "#F5D37A", "#1A1A2E", "#4A4080"]
        case .plage:
            palette = ["#0EA5E9", "#38BDF8", "#7DD3FC", "#FCD34D", "#FBBF24"]
        case .date:
            palette = ["#1A0A0A", "#7F1D1D", "#DC2626", "#CA8A04", "#F5D37A"]
        default:
            break
        }

        // Style tint
        switch style {
        case .minimaliste:
            palette = ["#FAFAF9", "#E5E7EB", "#9CA3AF", "#374151", "#111827"]
        case .boheme:
            palette = ["#78350F", "#92400E", "#B45309", "#D97706", "#FEF3C7"]
        default:
            break
        }

        return Array(palette.prefix(5))
    }

    // MARK: - Poetic Description Generator

    private static func generateDescription(
        prompt: String,
        occasion: MoodOccasion?,
        style: MoodStyle?,
        season: MoodSeason?,
        topItem: JewelryItem?
    ) -> String {
        let metalName = topItem?.material.components(separatedBy: " · ").first ?? "l'or"
        let jewelName = topItem?.name.lowercased() ?? "bijou"

        // Templates by occasion
        switch occasion {
        case .soiree:
            return "Pour cette soirée d'exception, \(metalName) s'impose avec grâce. Le \(jewelName) devient la signature lumineuse d'une nuit inoubliable, où chaque reflet raconte une histoire précieuse."
        case .mariage:
            return "En ce jour singulier où l'éternité prend forme, \(metalName) célèbre la beauté du lien. Le \(jewelName) porte le serment du temps, précieux comme le bonheur qui s'annonce."
        case .gala:
            return "Dans la magnificence du gala, \(metalName) s'élève au rang de trophée. Le \(jewelName) parachève une silhouette royale, affirmant avec éclat votre souveraineté."
        case .plage:
            return "Sous la lumière dorée du soleil, \(metalName) danse avec les reflets marins. Le \(jewelName) se fait léger comme l'écume, naturel comme la beauté sans artifice."
        case .business:
            return "Dans l'arène de l'ambition, \(metalName) parle le langage du pouvoir. Le \(jewelName) souligne votre autorité naturelle, précis comme vos décisions."
        case .date:
            return "En cette soirée de séduction, \(metalName) révèle vos zones d'ombre et de lumière. Le \(jewelName) vous drape d'un magnétisme irrésistible, promesse d'une nuit mémorable."
        case .voyage:
            return "Entre deux continents, \(metalName) accompagne votre liberté conquérante. Le \(jewelName) devient l'amulette du voyageur élégant, témoin de chaque horizon nouveau."
        case .quotidien:
            return "Dans la grâce du quotidien sublimé, \(metalName) illumine l'ordinaire. Le \(jewelName) transforme chaque instant en parenthèse de beauté, comme un luxe discret mais constant."
        default:
            // Parse prompt for custom description
            if !prompt.isEmpty {
                return "Pour \"\(prompt.prefix(40))\", \(metalName) traduit en métal précieux l'essence de votre intention. Le \(jewelName) s'inscrit comme le détail qui transforme le look en déclaration."
            }
            return "\(metalName) s'impose comme une évidence. Le \(jewelName) complète avec raffinement votre vision stylistique, affirmant une personnalité qui ne se contente jamais du banal."
        }
    }

    // MARK: - Title Generation

    private static func generateTitle(
        occasion: MoodOccasion?,
        style: MoodStyle?,
        prompt: String
    ) -> String {
        if let o = occasion, let s = style {
            return "\(s.rawValue) · \(o.rawValue)"
        }
        if let o = occasion { return "Look \(o.rawValue)" }
        if let s = style    { return "Univers \(s.rawValue)" }
        if !prompt.isEmpty  { return String(prompt.prefix(28)) + "…" }
        return "Mon Look Signature"
    }
}
