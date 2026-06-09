import Foundation

// MARK: - Community Post

struct CommunityPost: Identifiable, Codable {
    let id: UUID
    let author: User
    let jewelry: JewelryItem
    let tryOnImage: Data
    /// URL de la photo (Unsplash CDN — libre de droits).
    /// Si présent, `PostCard` affiche cette image au lieu du placeholder.
    let imageURL: String?
    /// Localisation affichée sous le nom de l'auteur (Paris, Lyon, etc.) — optionnel.
    let location: String?
    let caption: String
    var likes: Int
    let comments: Int
    var isLiked: Bool
    let challenge: CommunityChallenge?
    let tags: [String]
    let createdAt: Date
}

// MARK: - Community Challenge

struct CommunityChallenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let endDate: Date
    var participantCount: Int
    let prize: String
    /// Icône SF Symbol pour la récompense (ex: "sparkles", "crown.fill", "gift.fill")
    let prizeIcon: String
    let hashtag: String
    let coverImageName: String
    /// L'utilisateur a-t-il rejoint ce défi ?
    var isParticipating: Bool = false
}

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable, Codable {
    let id: UUID
    let user: User
    let score: Int
    let rank: Int
    let badge: String
}

// MARK: - Sample Data

extension CommunityChallenge {
    static let samples: [CommunityChallenge] = [
        CommunityChallenge(
            id: UUID(),
            title: "Soirée Dorée",
            description: "Montrez votre plus bel essayage pour une soirée de gala. Le bijou le plus glamour remporte le prix.",
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
            participantCount: 342,
            prize: "20 crédits essayage IA",
            prizeIcon: "sparkles",
            hashtag: "#EcrinSoireeDoree",
            coverImageName: "crown.fill"
        ),
        CommunityChallenge(
            id: UUID(),
            title: "Minimalisme Chic",
            description: "Un seul bijou, un impact maximal. Démontrez que la simplicité est le summum de la sophistication.",
            endDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
            participantCount: 218,
            prize: "1 mois Premium offert",
            prizeIcon: "star.circle.fill",
            hashtag: "#EcrinMinimal",
            coverImageName: "minus.circle.fill"
        ),
        CommunityChallenge(
            id: UUID(),
            title: "Héritage & Modernité",
            description: "Associez un bijou vintage à une tenue contemporaine. Racontez l'histoire de votre pièce.",
            endDate: Calendar.current.date(byAdding: .day, value: 18, to: .now)!,
            participantCount: 156,
            prize: "Badge collector + 10 crédits",
            prizeIcon: "rosette",
            hashtag: "#EcrinHeritage",
            coverImageName: "clock.fill"
        ),
        CommunityChallenge(
            id: UUID(),
            title: "Pluie de Diamants",
            description: "Mettez en scène un essayage avec un bijou serti de pierres précieuses. Les plus beaux essayages seront mis en avant.",
            endDate: Calendar.current.date(byAdding: .day, value: 8, to: .now)!,
            participantCount: 274,
            prize: "Featured sur le feed pendant 7 jours",
            prizeIcon: "megaphone.fill",
            hashtag: "#EcrinDiamants",
            coverImageName: "diamond.fill"
        ),
    ]
}

extension LeaderboardEntry {
    static let samples: [LeaderboardEntry] = {
        let names = [
            ("Sophie M.", "💎"), ("Clara R.", "👑"), ("Amélie D.", "✨"),
            ("Isabelle F.", "🌟"), ("Nathalie B.", "💫"), ("Camille L.", "🏆"),
            ("Julie P.", "🎖️"), ("Marine T.", "⭐"), ("Léa G.", "🔮"),
            ("Emma W.", "💍"), ("Sarah K.", "🌙"), ("Alice N.", "🦋"),
            ("Charlotte V.", "🌺"), ("Lucie H.", "🎀"), ("Marie O.", "🌹"),
            ("Pauline E.", "💐"), ("Chloé S.", "🌸"), ("Audrey C.", "🍀"),
            ("Céline M.", "🌼"), ("Véronique T.", "🌻")
        ]
        return names.enumerated().map { index, item in
            LeaderboardEntry(
                id: UUID(),
                user: User(
                    id: UUID(),
                    email: "\(item.0.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
                    displayName: item.0
                ),
                score: max(100, 2000 - index * 95 + Int.random(in: -20...20)),
                rank: index + 1,
                badge: item.1
            )
        }
    }()
}

extension CommunityPost {
    /// Génère dynamiquement des posts samples à partir de VRAIS bijoux du catalogue
    /// Moniattitude (Supabase). Chaque post a la VRAIE photo du bijou et une caption
    /// templated cohérente avec son nom et sa catégorie. Plus jamais de décalage.
    static func buildDynamicSamples(from realJewelry: [JewelryItem]) -> [CommunityPost] {
        // Si pas de bijoux réels disponibles, retourne les samples statiques en fallback.
        guard !realJewelry.isEmpty else { return samples }

        // (displayName, location, likes, comments, hoursAgo)
        let authorSeeds: [(String, String, Int, Int, Int)] = [
            ("Morgane T.",      "Paris 8ᵉ",          248,  37,  2),
            ("Camille_L",        "Bordeaux",          412,  58,  4),
            ("Inès B.",          "Lyon",              189,  21,  7),
            ("Sarah_K.",         "Genève",            156,  14,  9),
            ("Léa_M",            "Marseille",         287,  42, 11),
            ("Charlotte_V",      "Bruxelles",         198,  19, 14),
            ("Amélie D.",        "Nantes",            521,  87, 18),
            ("Julie_P",          "Toulouse",          134,  11, 22),
            ("Clara R.",         "Montréal",          376,  64, 26),
            ("Pauline E.",       "Lille",             167,  18, 30),
            ("Mathilde_F",       "Nice",              489,  93, 34),
            ("Audrey C.",        "Strasbourg",        145,   9, 38),
            ("Élodie B.",        "Rennes",            308,  47, 42),
            ("Naïma S.",         "Casablanca",        421,  72, 50),
            ("Hélène D.",        "Paris 16ᵉ",         267,  31, 54),
            ("Romane L.",        "Annecy",            178,  16, 62),
            ("Margot_T",         "Aix-en-Provence",   612, 124, 70),
            ("Yasmine R.",       "Bruxelles",         234,  41, 78),
            ("Cécile M.",        "Lausanne",          192,  23, 86),
            ("Florence V.",      "Paris 6ᵉ",          354,  68, 94),
        ]

        let challenges = CommunityChallenge.samples
        let count = min(authorSeeds.count, realJewelry.count * 3)

        return (0..<count).map { index in
            let seed = authorSeeds[index]
            let jewelry = realJewelry[index % realJewelry.count]
            let challenge: CommunityChallenge? = index < 6 ? challenges[index % challenges.count] : nil
            let tags = ["essayageVirtuel", "ecrin", jewelry.category.rawValue.lowercased(), "bijou"]
            let user = User(
                id: UUID(),
                email: "\(seed.0.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: ""))@example.com",
                displayName: seed.0
            )
            return CommunityPost(
                id: UUID(),
                author: user,
                jewelry: jewelry,
                tryOnImage: Data(),
                // Pas de photo de fond — la photo du bijou (Moniattitude) est dans jewelry.imageURL
                imageURL: nil,
                location: seed.1,
                caption: captionTemplate(for: jewelry, variant: index),
                likes: seed.2,
                comments: seed.3,
                isLiked: index % 4 == 0,
                challenge: challenge,
                tags: tags,
                createdAt: Calendar.current.date(byAdding: .hour, value: -seed.4, to: .now)!
            )
        }
    }

    /// Templates de captions par catégorie qui mentionnent le NOM réel du bijou,
    /// garantissant la cohérence caption/photo.
    private static func captionTemplate(for jewelry: JewelryItem, variant: Int) -> String {
        let name = jewelry.name
        let templates: [String]
        switch jewelry.category {
        case .ring:
            templates = [
                "Cette \(name) essayée virtuellement ✨ Le rendu sur ma main a tout décidé — commande passée !",
                "\(name) avec mon look casual du dimanche 💛 L'essayage virtuel m'a convaincue.",
                "Première fois avec \(name) — testée avant d'acheter, et j'adore le résultat 💫"
            ]
        case .necklace:
            templates = [
                "\(name) avec ma robe d'été 🌙 Testée en essayage avant de commander — parfait sur moi !",
                "\(name) pour la soirée gala ✨ Magnifique en lumière tamisée — je ne l'enlève plus !",
                "Mon \(name) au quotidien 💗 Le rendu virtuel m'a permis de visualiser avant achat."
            ]
        case .earring:
            templates = [
                "\(name) pour l'anniversaire de ma sœur ce week-end 🩷 Le rendu en lumière naturelle est dingue.",
                "Minimalisme assumé : juste \(name). La pureté d'un bijou parfait 🤍",
                "Mes \(name) avec une coiffure relevée — tellement élégantes ✨"
            ]
        case .bracelet:
            templates = [
                "\(name) avec ses reflets… impossible de résister 💙 Essayage validé, commande passée !",
                "\(name) au poignet — il scintille différemment selon la lumière ♾️✨",
                "Mon \(name) en superposition avec ma montre 🤎 Le combo parfait."
            ]
        case .watch:
            templates = [
                "Cette \(name) tellement élégante — validée virtuellement avant d'acheter ⌚ Pas déçue !",
                "\(name) pour un look boho chic 🌴 Tellement élégante au quotidien.",
                "Ma \(name) avec une tenue minimaliste — sobriété parfaite 🤍"
            ]
        case .nosePiercing:
            templates = [
                "Enfin décidée pour ce \(name) 💎 L'essayage virtuel m'a donné le courage de sauter le pas !",
                "Mon \(name) avec ma petite robe noire 🖤 Le piercing + tenue classique, j'adore ce contraste !",
                "\(name) — testé avant le rendez-vous chez le perceur. Décision prise ✨"
            ]
        case .eyebrowPiercing:
            templates = [
                "\(name) — j'hésitais depuis 6 mois 🔮 Testé virtuellement, décision prise, je le fais !",
                "\(name) + look décontracté 🔥 J'hésitais — finalement c'est parfait !",
                "Mon \(name) pour pimper mon style — l'essayage virtuel a tout décidé."
            ]
        case .lipPiercing:
            templates = [
                "Ce \(name)… ma nouvelle obsession ☀️ L'essayage virtuel a tout décidé, je l'ai commandé !",
                "\(name) validé grâce à l'essayage virtuel 💛 Je n'aurais jamais osé sans ça !",
                "\(name) avec un make-up nude — le contraste parfait ✨"
            ]
        case .tonguePiercing:
            templates = [
                "\(name) validé en essayage virtuel 💗 Plus d'hésitation après avoir vu le rendu !",
                "\(name) — émue de voir le rendu virtuel avant de me lancer 💗 Décision prise !",
                "Mon \(name) testé virtuellement avant le grand jour ✨"
            ]
        }
        return templates[variant % templates.count]
    }

    /// 20 publications de fallback — utilisées si le catalogue Moniattitude n'a pas pu charger.
    /// (Pour le rendu immédiat avant que les bijoux Supabase arrivent.)
    static let samples: [CommunityPost] = {

        // (displayName, location, caption, unsplashID — portrait personne, likes, comments, hoursAgo)
        // Captions alignées sur le type de bijou assigné (JewelryItem.samples[index % 9]) :
        //  0=bague, 1=collier, 2=boucles, 3=bracelet, 4=montre,
        //  5=piercing nez, 6=piercing arcade, 7=piercing lèvre, 8=piercing langue
        let seeds: [(String, String, String, String, Int, Int, Int)] = [
            // index 0 → bague améthyste
            ("Morgane T.",      "Paris 8ᵉ",          "Cette bague améthyste brute essayée virtuellement ✨ J'attendais de voir le rendu — je valide complètement !",  "1517841905240-472988babdf9", 248,  37, 2),
            // index 1 → sautoir pierre de lune
            ("Camille_L",        "Bordeaux",          "Mon sautoir pierre de lune avec ma robe d'été 🌙 Testé en essayage avant de commander — parfait sur moi !",       "1488426862026-3ee34a7d66df", 412,  58, 4),
            // index 2 → créoles quartz rose
            ("Inès B.",          "Lyon",              "Ces créoles quartz rose pour l'anniversaire de ma sœur ce week-end 🩷 Le rendu en lumière naturelle est dingue", "1531123897727-8f129e1688ce", 189,  21, 7),
            // index 3 → bracelet labradorite
            ("Sarah_K.",         "Genève",            "Ce bracelet labradorite avec ses reflets bleu-vert… impossible de résister 💙 Essayage validé, commande passée !","1494790108377-be9c29b29330", 156,  14, 9),
            // index 4 → montre cuir naturel
            ("Léa_M",            "Marseille",         "Cette montre cuir naturel tellement élégante — validée virtuellement avant d'acheter ⌚ Pas déçue du tout !",     "1438761681033-6461ffad8d80", 287,  42, 11),
            // index 5 → anneau nez opale
            ("Charlotte_V",      "Bruxelles",         "Enfin décidée pour l'anneau de nez opale 💎 L'essayage virtuel m'a donné le courage de sauter le pas !",         "1500917293891-ef795e70e1f6", 198,  19, 14),
            // index 6 → barbell arcade améthyste
            ("Amélie D.",        "Nantes",            "Mon barbell arcade améthyste — j'hésitais depuis 6 mois 🔮 Testé virtuellement, décision prise, je le fais !",    "1592621385612-4d7129426394", 521,  87, 18),
            // index 7 → anneau lèvre citrine
            ("Julie_P",          "Toulouse",          "L'anneau lèvre citrine doré… ma nouvelle obsession ☀️ L'essayage virtuel a tout décidé, je l'ai commandé !",     "1529626455594-4ff0802cfb7e", 134,  11, 22),
            // index 8 → piercing langue quartz rose
            ("Clara R.",         "Montréal",          "Piercing langue quartz rose validé en essayage virtuel 💗 Plus d'hésitation après avoir vu le rendu !",           "1485463611174-f302f6a5c1c9", 376,  64, 26),
            // index 9 → bague améthyste (cycle)
            ("Pauline E.",       "Lille",             "Ma bague améthyste brute avec mon look casual du dimanche 💜 Un bijou artisanal qui sublime tout !",               "1525134479668-1bee5c7c6845", 167,  18, 30),
            // index 10 → sautoir pierre de lune
            ("Mathilde_F",       "Nice",              "Mon sautoir pierre de lune pour la soirée de gala 🌙✨ Magnifique en lumière tamisée — je ne l'enlève plus !",    "1531746020798-e6953c6e8e04", 489,  93, 34),
            // index 11 → créoles quartz rose
            ("Audrey C.",        "Strasbourg",        "Minimalisme assumé : juste ces créoles quartz rose. La pureté d'un seul bijou parfait 🤍",                        "1487412720507-e7ab37603c6f", 145,   9, 38),
            // index 12 → bracelet labradorite
            ("Élodie B.",        "Rennes",            "Le bracelet labradorite scintille différemment selon la lumière ♾️✨ Ecrin m'a permis de valider avant achat !", "1518882570152-31e26ec03f1f", 308,  47, 42),
            // index 13 → montre cuir naturel
            ("Naïma S.",         "Casablanca",        "Montre cuir naturel pour un look boho chic — sur la plage du Maroc en plus 🌴 Tellement élégante !",              "1502823403499-6ccfcf4fb453", 421,  72, 50),
            // index 14 → anneau nez opale
            ("Hélène D.",        "Paris 16ᵉ",         "Mon anneau de nez opale avec ma petite robe noire 🖤 Le piercing + tenue classique, j'adore ce contraste !",     "1492106087820-71f1a00d2b11", 267,  31, 54),
            // index 15 → barbell arcade améthyste
            ("Romane L.",        "Annecy",            "Barbell arcade améthyste + look décontracté 🔮 J'hésitais — finalement les deux ensemble c'est parfait 🔥",       "1496440737103-cd596325d314", 178,  16, 62),
            // index 16 → anneau lèvre citrine
            ("Margot_T",         "Aix-en-Provence",   "Mon anneau lèvre citrine doré validé grâce à l'essayage virtuel 💛 Je n'aurais jamais osé sans ça !",             "1517365830460-955ce3ccd263", 612, 124, 70),
            // index 17 → piercing langue quartz rose
            ("Yasmine R.",       "Bruxelles",         "Piercing langue quartz rose — émue de voir le rendu virtuel avant de me lancer 💗 Décision prise !",              "1495887633562-0d1f5fae8d8f", 234,  41, 78),
            // index 18 → bague améthyste
            ("Cécile M.",        "Lausanne",          "Bague améthyste brute pour ce soir 💜 Première sortie avec, tellement fière de mon choix artisanal !",             "1573496359142-b8d87734a5a2", 192,  23, 86),
            // index 19 → sautoir pierre de lune
            ("Florence V.",      "Paris 6ᵉ",          "Sautoir pierre de lune pour le réveillon 🍾🌙 Officiellement la pièce dont je ne peux plus me passer !",          "1539571696357-5a69c17a67c6", 354,  68, 94),
        ]

        let challenges = CommunityChallenge.samples

        return seeds.enumerated().map { index, seed in
            let (name, location, caption, photoID, likes, comments, hoursAgo) = seed
            let jewelry = JewelryItem.samples[index % JewelryItem.samples.count]
            let challenge: CommunityChallenge? = index < 6 ? challenges[index % challenges.count] : nil
            let tags = ["essayageVirtuel", "ecrin", jewelry.category.rawValue.lowercased(), "bijou"]
            let user = User(
                id: UUID(),
                email: "\(name.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: ""))@example.com",
                displayName: name
            )
            return CommunityPost(
                id: UUID(),
                author: user,
                jewelry: jewelry,
                tryOnImage: Data(),
                imageURL: "https://images.unsplash.com/photo-\(photoID)?w=600&q=80&auto=format&fit=crop",
                location: location,
                caption: caption,
                likes: likes,
                comments: comments,
                isLiked: index % 4 == 0,
                challenge: challenge,
                tags: tags,
                createdAt: Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: .now)!
            )
        }
    }()
}
