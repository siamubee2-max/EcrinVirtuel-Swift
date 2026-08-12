import CryptoKit
import SwiftUI
import Foundation

// MARK: - Style Level

enum StyleLevel: Int, CaseIterable, Codable, Equatable {
    case debutante   = 1
    case fashionista = 2
    case styleIcon   = 3
    case hauteCouture = 4
    case legendaire  = 5

    var title: String {
        switch self {
        case .debutante:   return "Débutante"
        case .fashionista: return "Fashionista"
        case .styleIcon:   return "Style Icon"
        case .hauteCouture: return "Haute Couture"
        case .legendaire:  return "Légende"
        }
    }

    var minXP: Int {
        switch self {
        case .debutante:   return 0
        case .fashionista: return 200
        case .styleIcon:   return 600
        case .hauteCouture: return 1400
        case .legendaire:  return 3000
        }
    }

    var maxXP: Int {
        let next = StyleLevel(rawValue: rawValue + 1)
        return next?.minXP ?? minXP + 2000
    }

    var color: Color {
        switch self {
        case .debutante:   return Color(hex: "#9CA3AF")
        case .fashionista: return Color(hex: "#34D399")
        case .styleIcon:   return Color(hex: "#60A5FA")
        case .hauteCouture: return EcrinColor.gold
        case .legendaire:  return Color(hex: "#F472B6")
        }
    }

    var icon: String {
        switch self {
        case .debutante:   return "sparkles"
        case .fashionista: return "star.fill"
        case .styleIcon:   return "crown"
        case .hauteCouture: return "crown.fill"
        case .legendaire:  return "diamond.fill"
        }
    }

    var perks: [String] {
        switch self {
        case .debutante:
            return ["3 essayages gratuits/mois", "Accès aux tendances"]
        case .fashionista:
            return ["10 essayages gratuits/mois", "Badge profil exclusif", "Accès aux challenges"]
        case .styleIcon:
            return ["25 essayages gratuits/mois", "Fonds exclusifs débloqués", "Vote aux challenges"]
        case .hauteCouture:
            return ["Essayages illimités", "Conseils personnalisés", "Accès VIP aux ventes privées"]
        case .legendaire:
            return ["Essayages illimités", "Badge Légende doré", "Invitation aux événements exclusifs", "Consultation styliste offerte"]
        }
    }
}

// MARK: - Gaming Action

enum GamingAction: String, Codable, CaseIterable {
    case tryOnGenerated        = "try_on_generated"
    case outfitCompleted       = "outfit_completed"
    case lookShared            = "look_shared"
    case challengeParticipated = "challenge_participated"
    case challengeWon          = "challenge_won"
    case dailyLogin            = "daily_login"
    case streakMilestone7      = "streak_milestone_7"
    case streakMilestone30     = "streak_milestone_30"
    case partnerPurchase       = "partner_purchase"
    case friendReferred        = "friend_referred"
    case giftSent              = "gift_sent"
    case profileCompleted      = "profile_completed"

    var xp: Int {
        switch self {
        case .tryOnGenerated:        return 10
        case .outfitCompleted:       return 25
        case .lookShared:            return 15
        case .challengeParticipated: return 30
        case .challengeWon:          return 100
        case .dailyLogin:            return 5
        case .streakMilestone7:      return 50
        case .streakMilestone30:     return 150
        case .partnerPurchase:       return 20
        case .friendReferred:        return 75
        case .giftSent:              return 20
        case .profileCompleted:      return 40
        }
    }

    var message: String {
        switch self {
        case .tryOnGenerated:        return "+\(xp) XP · Essayage réussi !"
        case .outfitCompleted:       return "+\(xp) XP · Tenue complète !"
        case .lookShared:            return "+\(xp) XP · Look partagé !"
        case .challengeParticipated: return "+\(xp) XP · Défi relevé !"
        case .challengeWon:          return "+\(xp) XP · Victoire au défi !"
        case .dailyLogin:            return "+\(xp) XP · Connexion du jour !"
        case .streakMilestone7:      return "+\(xp) XP · 7 jours consécutifs !"
        case .streakMilestone30:     return "+\(xp) XP · 30 jours consécutifs !"
        case .partnerPurchase:       return "+\(xp) XP · Achat partenaire !"
        case .friendReferred:        return "+\(xp) XP · Amie parrainée !"
        case .giftSent:              return "+\(xp) XP · Cadeau envoyé !"
        case .profileCompleted:      return "+\(xp) XP · Profil complété !"
        }
    }
}

// MARK: - Badge Rarity

enum BadgeRarity: String, Codable, CaseIterable {
    case common, rare, epic, legendary

    var color: Color {
        switch self {
        case .common:    return Color(hex: "#9CA3AF")
        case .rare:      return Color(hex: "#60A5FA")
        case .epic:      return Color(hex: "#A78BFA")
        case .legendary: return EcrinColor.gold
        }
    }

    var label: String {
        switch self {
        case .common:    return "Commun"
        case .rare:      return "Rare"
        case .epic:      return "Épique"
        case .legendary: return "Légendaire"
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .common:    return 0
        case .rare:      return 6
        case .epic:      return 10
        case .legendary: return 18
        }
    }
}

// MARK: - Badge

struct Badge: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    let condition: String
    var earnedAt: Date?

    var isEarned: Bool { earnedAt != nil }

    // Coding keys to handle Color encoding via hex
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, condition, earnedAt
    }

    var rarityColor: Color { rarity.color }
}

// MARK: - Badge Catalog (30+ badges)

extension Badge {
    static let catalog: [Badge] = [
        // --- Common ---
        Badge(id: "first_tryon",        name: "Premier Essayage",     description: "Réalisez votre tout premier essayage virtuel.",             icon: "sparkles",             rarity: .common, condition: "Effectuer 1 essayage"),
        Badge(id: "tryon_10",           name: "Essayeuse Active",     description: "10 essayages au compteur — vous adorez ça !",               icon: "tshirt.fill",          rarity: .common, condition: "Effectuer 10 essayages"),
        Badge(id: "first_outfit",       name: "Première Tenue",       description: "Votre première tenue complète est une réussite.",           icon: "hanger",               rarity: .common, condition: "Créer 1 tenue complète"),
        Badge(id: "daily_3",            name: "Habituée",             description: "Connectez-vous 3 jours de suite.",                          icon: "calendar",             rarity: .common, condition: "Streak de 3 jours"),
        Badge(id: "first_share",        name: "Première Vitrine",     description: "Partagez votre premier look avec la communauté.",           icon: "square.and.arrow.up",  rarity: .common, condition: "Partager 1 look"),
        Badge(id: "profile_done",       name: "Profil Complet",       description: "Complétez toutes les informations de votre profil.",        icon: "person.crop.circle.badge.checkmark", rarity: .common, condition: "Compléter le profil"),
        Badge(id: "first_challenge",    name: "Première Candidate",   description: "Participez à votre premier défi de la communauté.",        icon: "flag.fill",            rarity: .common, condition: "Participer à 1 défi"),

        // --- Rare ---
        Badge(id: "tryon_50",           name: "Reine du Style",       description: "50 essayages : vous êtes une vraie professionnelle.",       icon: "crown",                rarity: .rare,   condition: "Effectuer 50 essayages"),
        Badge(id: "outfit_5",           name: "Créatrice",            description: "5 tenues complètes — votre œil s'affine.",                  icon: "paintbrush.fill",      rarity: .rare,   condition: "Créer 5 tenues complètes"),
        Badge(id: "streak_7",           name: "Semaine Parfaite",     description: "7 jours de connexion consécutifs. Impressionnant !",        icon: "flame.fill",           rarity: .rare,   condition: "Streak de 7 jours"),
        Badge(id: "share_10",           name: "Social Queen",         description: "10 looks partagés avec votre communauté.",                  icon: "person.2.fill",        rarity: .rare,   condition: "Partager 10 looks"),
        Badge(id: "challenge_3",        name: "Compétitrice",         description: "Participé à 3 défis différents.",                          icon: "medal.fill",           rarity: .rare,   condition: "Participer à 3 défis"),
        Badge(id: "partner_first",      name: "Acheteuse Avertie",    description: "Votre premier achat chez un partenaire Écrin.",             icon: "bag.fill",             rarity: .rare,   condition: "Effectuer 1 achat partenaire"),
        Badge(id: "refer_first",        name: "Ambassadrice Débutante", description: "Invitez votre première amie à rejoindre l'Écrin.",       icon: "person.badge.plus",    rarity: .rare,   condition: "Parrainer 1 amie"),
        Badge(id: "tryon_100",          name: "Fashionista Confirmée", description: "100 essayages ! Vous êtes une icône.",                    icon: "star.fill",            rarity: .rare,   condition: "Effectuer 100 essayages"),
        Badge(id: "gift_first",         name: "Généreuse",            description: "Envoyez votre premier cadeau surprise à une amie.",         icon: "gift.fill",            rarity: .rare,   condition: "Envoyer 1 cadeau"),
        Badge(id: "outfit_10",          name: "Styliste",             description: "10 tenues complètes — vous avez le don.",                   icon: "eyedropper.halffull",  rarity: .rare,   condition: "Créer 10 tenues complètes"),

        // --- Epic ---
        Badge(id: "streak_30",          name: "Dévotion Absolue",     description: "30 jours consécutifs — vous êtes irrésistible.",           icon: "flame",                rarity: .epic,   condition: "Streak de 30 jours"),
        Badge(id: "challenge_won",      name: "Challenge Winner",     description: "Remporter un défi de la communauté.",                       icon: "trophy.fill",          rarity: .epic,   condition: "Gagner 1 défi"),
        Badge(id: "refer_3",            name: "Ambassadrice",         description: "3 amies parrainées — votre réseau brille.",                 icon: "network",              rarity: .epic,   condition: "Parrainer 3 amies"),
        Badge(id: "tryon_500",          name: "Icône de Style",       description: "500 essayages — une légende s'écrit.",                      icon: "diamond",              rarity: .epic,   condition: "Effectuer 500 essayages"),
        Badge(id: "challenge_won_3",    name: "Triple Couronne",      description: "Gagnez 3 défis différents.",                               icon: "crown.fill",           rarity: .epic,   condition: "Gagner 3 défis"),
        Badge(id: "share_50",           name: "Influenceuse",         description: "50 looks partagés — votre style inspire.",                  icon: "megaphone.fill",       rarity: .epic,   condition: "Partager 50 looks"),
        Badge(id: "outfit_25",          name: "Couturière Virtuelle", description: "25 tenues complètes — vous êtes une artiste.",              icon: "scissors",             rarity: .epic,   condition: "Créer 25 tenues complètes"),
        Badge(id: "streak_100",         name: "Centurion du Style",   description: "100 jours consécutifs — une discipline royale.",           icon: "bolt.fill",            rarity: .epic,   condition: "Streak de 100 jours"),

        // --- Legendary ---
        Badge(id: "level_haute_couture", name: "Haute Couture",       description: "Atteindre le niveau Haute Couture.",                        icon: "crown.fill",           rarity: .legendary, condition: "Atteindre le niveau 4"),
        Badge(id: "level_legendaire",    name: "La Légende",           description: "Atteindre le rang suprême de Légende.",                     icon: "diamond.fill",         rarity: .legendary, condition: "Atteindre le niveau 5"),
        Badge(id: "tryon_1000",          name: "Maîtresse de l'Écrin", description: "1000 essayages — votre nom sera gravé dans l'histoire.",   icon: "infinity",             rarity: .legendary, condition: "Effectuer 1000 essayages"),
        Badge(id: "refer_10",            name: "Grande Ambassadrice",  description: "10 amies parrainées — vous êtes une bâtisseuse de rêves.", icon: "person.3.fill",        rarity: .legendary, condition: "Parrainer 10 amies"),
        Badge(id: "challenge_won_10",    name: "Invincible",           description: "Gagner 10 défis — aucune ne vous résiste.",                icon: "shield.fill",          rarity: .legendary, condition: "Gagner 10 défis"),
        Badge(id: "streak_365",          name: "Année Écrin",          description: "365 jours consécutifs — une dévotion totale.",             icon: "sun.max.fill",         rarity: .legendary, condition: "Streak de 365 jours"),
    ]
}

// MARK: - Quest Type

enum QuestType: String, Codable, CaseIterable {
    case daily, weekly, achievement, special
}

// MARK: - Quest

struct Quest: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let type: QuestType
    let xpReward: Int
    let rewardDescription: String
    var progress: Int
    let target: Int
    var completedAt: Date?
    let expiresAt: Date?

    var isCompleted: Bool { progress >= target }

    var progressFraction: Double {
        guard target > 0 else { return 1.0 }
        return min(1.0, Double(progress) / Double(target))
    }

    var expiresInLabel: String? {
        guard let exp = expiresAt else { return nil }
        let diff = exp.timeIntervalSince(.now)
        guard diff > 0 else { return "Expirée" }
        let hours = Int(diff / 3600)
        if hours < 24 { return "\(hours)h restantes" }
        let days = hours / 24
        return "\(days)j restants"
    }
}

// MARK: - Quest Catalog

extension UUID {
    /// UUID déterministe dérivé d'une clé stable (SHA-256 tronqué à 16 octets).
    /// Les quêtes DOIVENT garder le même id d'un lancement à l'autre : la
    /// restauration de progression et l'anti-re-claim (completedQuestIDs)
    /// matchent par id — des UUID() frais rendaient les deux inopérants.
    static func stable(_ key: String) -> UUID {
        let digest = SHA256.hash(data: Data(key.utf8))
        let b = Array(digest.prefix(16))
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

extension Quest {
    /// Clé de période : l'id d'une quête quotidienne/hebdo inclut le début de
    /// sa fenêtre — même id toute la journée/semaine, nouvel id (donc quête
    /// fraîche) à la période suivante.
    private static func periodKey(_ start: Date) -> String {
        String(Int(start.timeIntervalSinceReferenceDate))
    }

    static func dailyQuests() -> [Quest] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let day = periodKey(startOfDay)
        return [
            Quest(id: .stable("quest.daily.tryon.\(day)"), title: "Essayage du Jour", description: "Testez un bijou aujourd'hui", icon: "sparkles", type: .daily, xpReward: 15, rewardDescription: "+15 XP", progress: 0, target: 1, expiresAt: tomorrow),
            Quest(id: .stable("quest.daily.outfit.\(day)"), title: "Tenue du Jour", description: "Assemblez une tenue complète", icon: "hanger", type: .daily, xpReward: 30, rewardDescription: "+30 XP + fond exclusif", progress: 0, target: 1, expiresAt: tomorrow),
            Quest(id: .stable("quest.daily.share.\(day)"), title: "Partage Quotidien", description: "Partagez un look avec la communauté", icon: "square.and.arrow.up", type: .daily, xpReward: 20, rewardDescription: "+20 XP", progress: 0, target: 1, expiresAt: tomorrow),
        ]
    }

    static func weeklyQuests() -> [Quest] {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        let weekStart = week?.start ?? Calendar.current.startOfDay(for: .now)
        let weekEnd = week?.end ?? Calendar.current.date(byAdding: .weekOfYear, value: 1, to: .now)!
        let key = periodKey(weekStart)
        return [
            Quest(id: .stable("quest.weekly.active.\(key)"), title: "Semaine Active", description: "Réalisez 7 essayages cette semaine", icon: "flame.fill", type: .weekly, xpReward: 80, rewardDescription: "+80 XP + 3 essayages bonus", progress: 0, target: 7, expiresAt: weekEnd),
            Quest(id: .stable("quest.weekly.stylist.\(key)"), title: "Styliste de la Semaine", description: "Créez 3 tenues complètes", icon: "paintbrush.fill", type: .weekly, xpReward: 100, rewardDescription: "+100 XP + badge exclusif", progress: 0, target: 3, expiresAt: weekEnd),
            Quest(id: .stable("quest.weekly.voice.\(key)"), title: "Voix de la Communauté", description: "Partagez 5 looks cette semaine", icon: "megaphone.fill", type: .weekly, xpReward: 60, rewardDescription: "+60 XP + mise en avant profil", progress: 0, target: 5, expiresAt: weekEnd),
        ]
    }

    static let achievements: [Quest] = [
        Quest(id: .stable("quest.achievement.collector"), title: "Collectionneuse", description: "Essayez 50 bijoux différents", icon: "diamond", type: .achievement, xpReward: 200, rewardDescription: "+200 XP + badge Reine du Style", progress: 0, target: 50, expiresAt: nil),
        Quest(id: .stable("quest.achievement.stylist"), title: "Grande Styliste", description: "Créez 10 tenues complètes", icon: "scissors", type: .achievement, xpReward: 300, rewardDescription: "+300 XP + accès fonds premium", progress: 0, target: 10, expiresAt: nil),
        Quest(id: .stable("quest.achievement.network"), title: "Bâtisseuse de Réseau", description: "Parrainez 3 amies", icon: "person.badge.plus", type: .achievement, xpReward: 250, rewardDescription: "+250 XP + mois offert", progress: 0, target: 3, expiresAt: nil),
    ]
}

// MARK: - Gaming Reward (Pending display)

struct GamingReward: Identifiable {
    let id = UUID()
    let xp: Int
    let message: String
    let badge: Badge?
    let levelUp: StyleLevel?
}

// MARK: - Gaming Profile

struct GamingProfile: Codable {
    var totalXP: Int = 0
    var currentLevel: StyleLevel = .debutante
    var streak: Int = 0
    var longestStreak: Int = 0
    var lastLoginDate: Date = .distantPast
    var earnedBadgeIDs: [String] = []
    var completedQuestIDs: [UUID] = []
    var rank: Int? = nil
    var tryOnCount: Int = 0
    var outfitCount: Int = 0
    var shareCount: Int = 0
    var challengeWinCount: Int = 0
    var referralCount: Int = 0
    var profileCompletedRecorded: Bool = false

    var levelProgress: Double {
        let next = StyleLevel(rawValue: currentLevel.rawValue + 1)
        guard let next else { return 1.0 }
        let range = next.minXP - currentLevel.minXP
        let gained = totalXP - currentLevel.minXP
        guard range > 0 else { return 1.0 }
        return min(1.0, Double(max(0, gained)) / Double(range))
    }

    var xpToNextLevel: Int {
        let next = StyleLevel(rawValue: currentLevel.rawValue + 1)
        guard let next else { return 0 }
        return max(0, next.minXP - totalXP)
    }

    var earnedBadges: [Badge] {
        Badge.catalog.filter { earnedBadgeIDs.contains($0.id) }
    }
}
