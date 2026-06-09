import SwiftUI

// MARK: - Chakra

enum Chakra: String, CaseIterable, Identifiable {
    case crown      = "Couronne"
    case thirdEye   = "Troisième Oeil"
    case throat     = "Gorge"
    case heart      = "Coeur"
    case solarPlexus = "Plexus Solaire"
    case sacral     = "Sacré"
    case root       = "Racine"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .crown:       Color(hex: "#9B59B6")
        case .thirdEye:    Color(hex: "#5B2D8E")
        case .throat:      Color(hex: "#3498DB")
        case .heart:       Color(hex: "#2ECC71")
        case .solarPlexus: Color(hex: "#F1C40F")
        case .sacral:      Color(hex: "#E67E22")
        case .root:        Color(hex: "#E74C3C")
        }
    }

    var sfSymbol: String {
        switch self {
        case .crown:       "sparkles"
        case .thirdEye:    "eye.fill"
        case .throat:      "waveform"
        case .heart:       "heart.fill"
        case .solarPlexus: "sun.max.fill"
        case .sacral:      "flame.fill"
        case .root:        "leaf.fill"
        }
    }

    var number: Int {
        switch self {
        case .root:        1
        case .sacral:      2
        case .solarPlexus: 3
        case .heart:       4
        case .throat:      5
        case .thirdEye:    6
        case .crown:       7
        }
    }
}

// MARK: - Element

enum StoneElement: String, CaseIterable {
    case water = "Eau"
    case fire  = "Feu"
    case earth = "Terre"
    case air   = "Air"

    var sfSymbol: String {
        switch self {
        case .water: "drop.fill"
        case .fire:  "flame.fill"
        case .earth: "mountain.2.fill"
        case .air:   "wind"
        }
    }

    var color: Color {
        switch self {
        case .water: Color(hex: "#3498DB")
        case .fire:  Color(hex: "#E74C3C")
        case .earth: Color(hex: "#8B6914")
        case .air:   Color(hex: "#95A5A6")
        }
    }
}

// MARK: - Intention

enum StoneIntentionCategory: String, CaseIterable, Identifiable {
    case love       = "Amour"
    case protection = "Protection"
    case clarity    = "Clarté"
    case abundance  = "Abondance"
    case healing    = "Guérison"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .love:       "heart.fill"
        case .protection: "shield.fill"
        case .clarity:    "eye.fill"
        case .abundance:  "star.fill"
        case .healing:    "cross.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .love:       Color(hex: "#E91E8C")
        case .protection: Color(hex: "#5B2D8E")
        case .clarity:    Color(hex: "#3498DB")
        case .abundance:  Color(hex: "#F1C40F")
        case .healing:    Color(hex: "#2ECC71")
        }
    }
}

// MARK: - Stone Model

struct Stone: Identifiable, Equatable {
    let id: UUID
    let name: String
    let englishName: String
    let stoneColor: Color
    let chakra: Chakra
    let virtues: [String]
    let zodiac: [String]
    let element: StoneElement
    let intention: String
    let pairsWith: [String]
    let intentionCategories: [StoneIntentionCategory]
    let usageGuide: String

    // Computed gradient for UI (very dark tint)
    var darkGradient: LinearGradient {
        LinearGradient(
            colors: [
                stoneColor.opacity(0.18),
                Color(hex: "#080808")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [stoneColor.opacity(0.12), stoneColor.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func == (lhs: Stone, rhs: Stone) -> Bool { lhs.id == rhs.id }
}

// MARK: - Stone Database

enum StoneDatabase {
    static let all: [Stone] = [
        Stone(
            id: UUID(),
            name: "Améthyste",
            englishName: "Amethyst",
            stoneColor: Color(hex: "#9B59B6"),
            chakra: .crown,
            virtues: ["Apaise l'anxiété", "Favorise la clarté mentale", "Renforce l'intuition"],
            zodiac: ["Poissons", "Verseau", "Capricorne"],
            element: .air,
            intention: "Laisse entrer la lumière, libère ce qui pèse",
            pairsWith: ["Rose Quartz", "Labradorite", "Sélénite"],
            intentionCategories: [.clarity, .healing],
            usageGuide: "Portez ce bijou lors de méditations du soir. Tenez-le dans la main gauche pour absorber son énergie apaisante. Placez-le sous votre oreiller pour des rêves lucides."
        ),
        Stone(
            id: UUID(),
            name: "Rose Quartz",
            englishName: "Rose Quartz",
            stoneColor: Color(hex: "#F4A7B9"),
            chakra: .heart,
            virtues: ["Ouvre le coeur à l'amour", "Apporte douceur et compassion", "Favorise l'estime de soi"],
            zodiac: ["Taureau", "Balance", "Cancer"],
            element: .water,
            intention: "Je m'accueille avec tendresse, j'aime et je suis aimé(e)",
            pairsWith: ["Améthyste", "Moonstone", "Rhodonite"],
            intentionCategories: [.love, .healing],
            usageGuide: "Ce bijou est idéal pour les rituels d'amour propre. Portez-le proche du coeur. Méditez en visualisant un halo rose enveloppant votre poitrine."
        ),
        Stone(
            id: UUID(),
            name: "Lapis Lazuli",
            englishName: "Lapis Lazuli",
            stoneColor: Color(hex: "#1A4F8C"),
            chakra: .throat,
            virtues: ["Libère la parole authentique", "Stimule la sagesse intérieure", "Favorise la vérité"],
            zodiac: ["Sagittaire", "Capricorne", "Verseau"],
            element: .water,
            intention: "Ma voix porte la vérité de mon âme",
            pairsWith: ["Sodalite", "Amazonite", "Turquoise"],
            intentionCategories: [.clarity, .protection],
            usageGuide: "Portez-le lors de présentations ou de conversations importantes. Touchez la pierre avant de parler pour ancrer votre intention de vérité."
        ),
        Stone(
            id: UUID(),
            name: "Labradorite",
            englishName: "Labradorite",
            stoneColor: Color(hex: "#4A7C9E"),
            chakra: .thirdEye,
            virtues: ["Révèle la magie intérieure", "Protège contre les énergies négatives", "Amplifie l'intuition"],
            zodiac: ["Scorpion", "Sagittaire", "Cancer"],
            element: .water,
            intention: "Je perçois au-delà du voile, ma magie s'éveille",
            pairsWith: ["Améthyste", "Moonstone", "Obsidienne"],
            intentionCategories: [.protection, .clarity],
            usageGuide: "Portez ce bijou lors de transitions importantes. Tenez-le sous la lumière pour observer ses reflets changeants — une métaphore de vos propres facettes cachées."
        ),
        Stone(
            id: UUID(),
            name: "Turquoise",
            englishName: "Turquoise",
            stoneColor: Color(hex: "#40C4AA"),
            chakra: .throat,
            virtues: ["Protège lors des voyages", "Harmonise corps et esprit", "Porte chance et prospérité"],
            zodiac: ["Sagittaire", "Scorpion", "Poissons"],
            element: .air,
            intention: "Je navigue la vie avec grâce et protection",
            pairsWith: ["Lapis Lazuli", "Amazonite", "Chrysocolla"],
            intentionCategories: [.protection, .abundance],
            usageGuide: "Pierre de voyage par excellence, portez-la lors de déplacements. Ses propriétés protectrices créent un bouclier énergétique autour de vous."
        ),
        Stone(
            id: UUID(),
            name: "Malachite",
            englishName: "Malachite",
            stoneColor: Color(hex: "#1B7A4A"),
            chakra: .heart,
            virtues: ["Libère les blocages émotionnels", "Favorise la transformation", "Amplifie toutes les énergies"],
            zodiac: ["Taureau", "Capricorne", "Scorpion"],
            element: .earth,
            intention: "Je lâche l'ancien, je m'ouvre à ma renaissance",
            pairsWith: ["Rose Quartz", "Labradorite", "Obsidienne"],
            intentionCategories: [.healing, .protection],
            usageGuide: "Pierre de transformation puissante. Portez-la lors de moments de changement. Attention : amplifie toutes les énergies, purifiez-la régulièrement."
        ),
        Stone(
            id: UUID(),
            name: "Citrine",
            englishName: "Citrine",
            stoneColor: Color(hex: "#F5A623"),
            chakra: .solarPlexus,
            virtues: ["Attire l'abondance et la prospérité", "Renforce la confiance en soi", "Dissipe les énergies négatives"],
            zodiac: ["Lion", "Gémeaux", "Balance"],
            element: .fire,
            intention: "J'accueille l'abondance sous toutes ses formes",
            pairsWith: ["Pyrite", "Tiger Eye", "Aventurine"],
            intentionCategories: [.abundance, .clarity],
            usageGuide: "La pierre du soleil ne retient jamais l'énergie négative. Portez-la pour manifester vos intentions de prospérité. Idéale pour les rituels du nouvel an ou de nouvelle lune."
        ),
        Stone(
            id: UUID(),
            name: "Obsidienne",
            englishName: "Obsidian",
            stoneColor: Color(hex: "#1C1C1C"),
            chakra: .root,
            virtues: ["Vérité miroir sans concessions", "Protège contre la négativité", "Ancre dans le présent"],
            zodiac: ["Sagittaire", "Scorpion", "Capricorne"],
            element: .earth,
            intention: "Je vois clairement, je me protège avec amour",
            pairsWith: ["Labradorite", "Malachite", "Shungite"],
            intentionCategories: [.protection, .clarity],
            usageGuide: "Pierre de protection puissante. À porter avec discernement car elle révèle les vérités cachées. Purifiez-la souvent à l'eau salée ou en la plaçant sur la terre."
        ),
        Stone(
            id: UUID(),
            name: "Aventurine",
            englishName: "Aventurine",
            stoneColor: Color(hex: "#4CAF50"),
            chakra: .heart,
            virtues: ["Porte chance et opportunités", "Apaise le stress", "Renforce l'optimisme"],
            zodiac: ["Taureau", "Balance", "Verseau"],
            element: .earth,
            intention: "La chance me sourit, je suis ouvert(e) aux miracles",
            pairsWith: ["Citrine", "Rose Quartz", "Prehnite"],
            intentionCategories: [.abundance, .healing],
            usageGuide: "Surnommée la pierre du joueur chanceux, portez-la lors d'entretiens, d'examens ou de nouveaux projets. Elle attire les opportunités favorables."
        ),
        Stone(
            id: UUID(),
            name: "Moonstone",
            englishName: "Moonstone",
            stoneColor: Color(hex: "#B0C4DE"),
            chakra: .crown,
            virtues: ["Honore les cycles féminins", "Amplifie l'intuition", "Favorise les nouveaux débuts"],
            zodiac: ["Cancer", "Balance", "Scorpion"],
            element: .water,
            intention: "Comme la lune, je me renouvelle à chaque cycle",
            pairsWith: ["Rose Quartz", "Labradorite", "Améthyste"],
            intentionCategories: [.clarity, .healing, .love],
            usageGuide: "Chargez ce bijou sous la pleine lune. Portez-le lors de nouvelles lunes pour amplifier vos intentions. Idéal pour les rituels cycliques et féminins."
        ),
        Stone(
            id: UUID(),
            name: "Tiger Eye",
            englishName: "Tiger's Eye",
            stoneColor: Color(hex: "#B5691E"),
            chakra: .solarPlexus,
            virtues: ["Renforce la volonté et la détermination", "Clarifie les intentions", "Protège contre les manipulations"],
            zodiac: ["Lion", "Capricorne", "Gémeaux"],
            element: .fire,
            intention: "Je vois loin, j'agis avec puissance et clarté",
            pairsWith: ["Citrine", "Pyrite", "Obsidienne"],
            intentionCategories: [.protection, .abundance, .clarity],
            usageGuide: "Pierre du guerrier intérieur. Portez-la pour les décisions importantes ou lors de négociations. Elle renforce votre ancrage tout en élevant votre vision."
        ),
        Stone(
            id: UUID(),
            name: "Onyx",
            englishName: "Onyx",
            stoneColor: Color(hex: "#2C2C2C"),
            chakra: .root,
            virtues: ["Ancre et stabilise", "Absorbe les énergies négatives", "Renforce la discipline"],
            zodiac: ["Capricorne", "Lion", "Scorpion"],
            element: .earth,
            intention: "Je suis ancré(e), stable, inébranlable",
            pairsWith: ["Tiger Eye", "Obsidienne", "Shungite"],
            intentionCategories: [.protection, .clarity],
            usageGuide: "Pierre d'ancrage et de force. Portez-le lors de périodes de turbulences pour rester centré. Sa présence sombre crée un bouclier protecteur solide."
        ),
        Stone(
            id: UUID(),
            name: "Rhodonite",
            englishName: "Rhodonite",
            stoneColor: Color(hex: "#C2185B"),
            chakra: .heart,
            virtues: ["Guérit les blessures amoureuses", "Favorise le pardon", "Équilibre yin et yang"],
            zodiac: ["Taureau", "Balance", "Cancer"],
            element: .earth,
            intention: "Je pardonne, je me libère, j'avance avec amour",
            pairsWith: ["Rose Quartz", "Chrysocolla", "Amazonite"],
            intentionCategories: [.love, .healing],
            usageGuide: "Pierre du pardon par excellence. Tenez-la lors de méditations sur la guérison émotionnelle. Elle aide à transformer la douleur en compassion."
        ),
        Stone(
            id: UUID(),
            name: "Amazonite",
            englishName: "Amazonite",
            stoneColor: Color(hex: "#00BCD4"),
            chakra: .throat,
            virtues: ["Apaise les tensions nerveuses", "Encourage la communication claire", "Favorise l'harmonie"],
            zodiac: ["Verseau", "Vierge", "Balance"],
            element: .water,
            intention: "Je dis ma vérité avec douceur et assurance",
            pairsWith: ["Turquoise", "Lapis Lazuli", "Rhodonite"],
            intentionCategories: [.healing, .love],
            usageGuide: "Portez-la lors de conversations délicates. Elle adoucit les échanges tout en maintenant votre authenticité. Idéale pour les médiations et réconciliations."
        ),
        Stone(
            id: UUID(),
            name: "Cornaline",
            englishName: "Carnelian",
            stoneColor: Color(hex: "#E64A19"),
            chakra: .sacral,
            virtues: ["Stimule la créativité et le désir", "Renforce la vitalité", "Courage et motivation"],
            zodiac: ["Bélier", "Lion", "Taureau"],
            element: .fire,
            intention: "Mon feu créatif brûle, je crée avec passion",
            pairsWith: ["Citrine", "Sunstone", "Tiger Eye"],
            intentionCategories: [.abundance, .healing],
            usageGuide: "Pierre du feu créatif, portez-la pour les projets artistiques ou pour raviver la flamme intérieure. Elle stimule l'énergie vitale et le désir de vivre pleinement."
        ),
        Stone(
            id: UUID(),
            name: "Pyrite",
            englishName: "Pyrite",
            stoneColor: Color(hex: "#B8A840"),
            chakra: .solarPlexus,
            virtues: ["Attire la richesse et la réussite", "Renforce la confiance", "Énergie de manifestation"],
            zodiac: ["Lion", "Gémeaux", "Capricorne"],
            element: .earth,
            intention: "Je manifeste l'abondance dorée dans ma vie",
            pairsWith: ["Citrine", "Tiger Eye", "Aventurine"],
            intentionCategories: [.abundance],
            usageGuide: "L'or des fous devient l'or des sages. Portez-la pour amplifier votre énergie de manifestation. Idéale pour les rituels de prospérité et les intentions financières."
        ),
        Stone(
            id: UUID(),
            name: "Sélénite",
            englishName: "Selenite",
            stoneColor: Color(hex: "#FFFFFF"),
            chakra: .crown,
            virtues: ["Purifie l'énergie", "Clarifie l'esprit", "Connexion au divin"],
            zodiac: ["Cancer", "Gémeaux", "Taureau"],
            element: .air,
            intention: "Je suis pur(e) de lumière, connecté(e) au cosmos",
            pairsWith: ["Améthyste", "Moonstone", "Howlite"],
            intentionCategories: [.clarity, .healing],
            usageGuide: "Pierre de lumière pure, n'a jamais besoin d'être rechargée. Portez-la pour purifier votre champ énergétique. Placez-la dans votre espace pour élever la vibration."
        ),
        Stone(
            id: UUID(),
            name: "Howlite",
            englishName: "Howlite",
            stoneColor: Color(hex: "#E8E8E8"),
            chakra: .crown,
            virtues: ["Apaise l'insomnie", "Calme la colère", "Favorise la patience"],
            zodiac: ["Gémeaux", "Balance", "Vierge"],
            element: .air,
            intention: "Je lâche prise, je m'abandonne au silence intérieur",
            pairsWith: ["Améthyste", "Sélénite", "Moonstone"],
            intentionCategories: [.healing, .clarity],
            usageGuide: "Placez ce bijou sur votre table de chevet ou portez-le le soir pour faciliter l'endormissement. Il absorbe les pensées agitées et invite à la sérénité."
        ),
        Stone(
            id: UUID(),
            name: "Sodalite",
            englishName: "Sodalite",
            stoneColor: Color(hex: "#1565C0"),
            chakra: .thirdEye,
            virtues: ["Stimule la logique et l'objectivité", "Favorise la paix intérieure", "Clarifie la perception"],
            zodiac: ["Sagittaire", "Verseau", "Vierge"],
            element: .water,
            intention: "Ma perception est claire, je vois la vérité",
            pairsWith: ["Lapis Lazuli", "Amazonite", "Labradorite"],
            intentionCategories: [.clarity, .protection],
            usageGuide: "Pierre de l'intellect éclairé. Portez-la lors d'études, de réflexions profondes ou de prises de décision importantes. Elle harmonise logique et intuition."
        ),
        Stone(
            id: UUID(),
            name: "Jaspe Rouge",
            englishName: "Red Jasper",
            stoneColor: Color(hex: "#B71C1C"),
            chakra: .root,
            virtues: ["Ancre dans le présent", "Renforce l'endurance", "Stabilise les émotions"],
            zodiac: ["Bélier", "Taureau", "Scorpion"],
            element: .earth,
            intention: "Mes racines sont profondes, ma force est immense",
            pairsWith: ["Obsidienne", "Onyx", "Tiger Eye"],
            intentionCategories: [.protection, .healing],
            usageGuide: "La pierre guerrière par excellence. Portez-la lors d'efforts physiques ou de périodes épuisantes. Elle nourrit l'endurance et rappelle votre force fondamentale."
        ),
        Stone(
            id: UUID(),
            name: "Aigue-Marine",
            englishName: "Aquamarine",
            stoneColor: Color(hex: "#00BCD4"),
            chakra: .throat,
            virtues: ["Apaise les peurs", "Courage lors des épreuves", "Communication du coeur"],
            zodiac: ["Poissons", "Bélier", "Gémeaux"],
            element: .water,
            intention: "Comme l'océan, je suis vaste, calme et puissant(e)",
            pairsWith: ["Turquoise", "Amazonite", "Chrysocolla"],
            intentionCategories: [.healing, .clarity],
            usageGuide: "Pierre des navigateurs et des courages. Portez-la lors de périodes de changement ou d'incertitude. Elle donne la force de traverser les tempêtes avec sérénité."
        ),
        Stone(
            id: UUID(),
            name: "Fluorite",
            englishName: "Fluorite",
            stoneColor: Color(hex: "#7E57C2"),
            chakra: .thirdEye,
            virtues: ["Clarifie la confusion mentale", "Absorbe les énergies négatives", "Favorise la concentration"],
            zodiac: ["Capricorne", "Poissons", "Vierge"],
            element: .air,
            intention: "Mon esprit est vif, clair et libéré du chaos",
            pairsWith: ["Améthyste", "Sodalite", "Howlite"],
            intentionCategories: [.clarity, .protection],
            usageGuide: "Idéale sur un bureau ou portée lors d'études. La fluorite nettoie le champ énergétique des interférences et permet une concentration cristalline."
        ),
        Stone(
            id: UUID(),
            name: "Chrysocolla",
            englishName: "Chrysocolla",
            stoneColor: Color(hex: "#00796B"),
            chakra: .throat,
            virtues: ["Pierre des femmes sages", "Apaise les conflits", "Enseigne la sagesse par l'expérience"],
            zodiac: ["Taureau", "Gémeaux", "Vierge"],
            element: .water,
            intention: "Ma sagesse est un cadeau que je partage avec douceur",
            pairsWith: ["Turquoise", "Amazonite", "Rhodonite"],
            intentionCategories: [.love, .healing, .clarity],
            usageGuide: "Pierre de la grande mère et de la sagesse féminine. Portez-la pour enseigner, guider ou lors de processus de guérison émotionnelle profonde."
        ),
        Stone(
            id: UUID(),
            name: "Unakite",
            englishName: "Unakite",
            stoneColor: Color(hex: "#6D8C3E"),
            chakra: .heart,
            virtues: ["Réconcilie passé et présent", "Favorise la croissance spirituelle", "Soutient les relations harmonieuses"],
            zodiac: ["Scorpion", "Capricorne", "Taureau"],
            element: .earth,
            intention: "J'intègre mon passé et fleuris dans le présent",
            pairsWith: ["Aventurine", "Rose Quartz", "Prehnite"],
            intentionCategories: [.healing, .love],
            usageGuide: "Pierre de croissance et d'intégration. Portez-la lors de thérapies ou de processus de réconciliation. Elle aide à extraire les leçons du passé sans y rester."
        ),
        Stone(
            id: UUID(),
            name: "Sunstone",
            englishName: "Sunstone",
            stoneColor: Color(hex: "#FF6F00"),
            chakra: .sacral,
            virtues: ["Insuffle la joie et l'enthousiasme", "Libère des dépendances", "Énergie du leadership"],
            zodiac: ["Lion", "Balance", "Bélier"],
            element: .fire,
            intention: "Je rayonne ma lumière, je suis une source de joie",
            pairsWith: ["Cornaline", "Citrine", "Tiger Eye"],
            intentionCategories: [.abundance, .healing],
            usageGuide: "La pierre du soleil intérieur. Portez-la les jours de grisaille ou de manque de motivation. Elle libère l'énergie solaire qui sommeille en vous."
        ),
        Stone(
            id: UUID(),
            name: "Shungite",
            englishName: "Shungite",
            stoneColor: Color(hex: "#1A1A1A"),
            chakra: .root,
            virtues: ["Protection contre les EMF", "Purifie l'eau et l'énergie", "Ancrage profond"],
            zodiac: ["Cancer", "Scorpion", "Capricorne"],
            element: .earth,
            intention: "Je suis protégé(e) et purifié(e) par la force de la terre",
            pairsWith: ["Obsidienne", "Onyx", "Tourmaline Noire"],
            intentionCategories: [.protection],
            usageGuide: "Pierre de protection absolue. Portez-la dans les environnements technologiques intenses. Sa matière ancienne (2 milliards d'années) porte une protection primordiale."
        ),
        Stone(
            id: UUID(),
            name: "Prehnite",
            englishName: "Prehnite",
            stoneColor: Color(hex: "#8BC34A"),
            chakra: .heart,
            virtues: ["Guérit le guérisseur", "Favorise la paix inconditionnelle", "Connexion à la nature"],
            zodiac: ["Balance", "Capricorne", "Vierge"],
            element: .earth,
            intention: "Je suis en paix avec ce qui est, la nature me guide",
            pairsWith: ["Aventurine", "Unakite", "Chrysocolla"],
            intentionCategories: [.healing, .clarity],
            usageGuide: "Pierre des guérisseurs et des soignants. Portez-la si vous avez tendance à donner plus que vous ne recevez. Elle rappelle l'importance de prendre soin de soi."
        ),
        Stone(
            id: UUID(),
            name: "Kunzite",
            englishName: "Kunzite",
            stoneColor: Color(hex: "#E91E8C"),
            chakra: .heart,
            virtues: ["Ouvre le coeur aux miracles", "Apporte un amour inconditionnel", "Dissout les résistances"],
            zodiac: ["Taureau", "Lion", "Scorpion"],
            element: .water,
            intention: "Mon coeur est ouvert, l'amour circule librement",
            pairsWith: ["Rose Quartz", "Rhodonite", "Moonstone"],
            intentionCategories: [.love, .healing],
            usageGuide: "Pierre de l'amour inconditionnel et de la grâce. Portez-la lors de rituels d'amour ou de périodes de vulnérabilité. Sa vibration douce enveloppe le coeur."
        ),
        Stone(
            id: UUID(),
            name: "Larimar",
            englishName: "Larimar",
            stoneColor: Color(hex: "#29B6F6"),
            chakra: .throat,
            virtues: ["Apaise comme l'océan", "Libère la parole de l'âme", "Connexion aux guides spirituels"],
            zodiac: ["Lion", "Scorpion", "Sagittaire"],
            element: .water,
            intention: "Ma parole coule comme l'eau, pure et profonde",
            pairsWith: ["Aigue-Marine", "Turquoise", "Chrysocolla"],
            intentionCategories: [.healing, .clarity, .love],
            usageGuide: "Pierre rare des Caraïbes, elle porte l'énergie de l'Atlantide et de l'océan. Portez-la pour accéder à des vérités profondes et communiquer avec l'âme."
        ),
        Stone(
            id: UUID(),
            name: "Charoïte",
            englishName: "Charoite",
            stoneColor: Color(hex: "#7B1FA2"),
            chakra: .crown,
            virtues: ["Transformation spirituelle rapide", "Accepte les dons psychiques", "Surpasse les peurs"],
            zodiac: ["Scorpion", "Sagittaire", "Vierge"],
            element: .water,
            intention: "Je transcende mes limites et m'éveille à ma grandeur",
            pairsWith: ["Améthyste", "Labradorite", "Fluorite"],
            intentionCategories: [.clarity, .healing, .protection],
            usageGuide: "Pierre de transformation spirituelle accélérée. Uniquement extraite en Russie, elle est rare et puissante. Portez-la lors de passages initiatiques ou de grandes transitions."
        ),
    ]

    // MARK: - Search helpers

    static func stone(named name: String) -> Stone? {
        all.first { stone in
            stone.name.lowercased() == name.lowercased() ||
            stone.englishName.lowercased() == name.lowercased()
        }
    }

    static func stones(forChakra chakra: Chakra) -> [Stone] {
        all.filter { $0.chakra == chakra }
    }

    static func stones(forIntention intention: StoneIntentionCategory) -> [Stone] {
        all.filter { $0.intentionCategories.contains(intention) }
    }
}
