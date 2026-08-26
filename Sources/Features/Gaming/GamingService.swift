import SwiftUI
import Foundation

// MARK: - Gaming Service

@MainActor
final class GamingService: ObservableObject {

    static let shared = GamingService()

    // MARK: Published State

    @Published var profile: GamingProfile = GamingProfile()
    @Published var pendingRewards: [GamingReward] = []
    @Published var activeQuests: [Quest] = []
    @Published var showLevelUp: Bool = false
    @Published var levelUpTo: StyleLevel? = nil

    // MARK: Private

    private let profileKey = "ecrin_gaming_profile_v2"
    private let questsKey  = "ecrin_gaming_quests_v2"
    private var questsLastRefresh: Date = .distantPast

    // MARK: Init

    private init() {
        loadProfile()
        refreshQuestsIfNeeded()
    }

    // MARK: - Record Action

    func record(_ action: GamingAction) {
        let previousLevel = profile.currentLevel

        // Award XP
        profile.totalXP += action.xp

        // Update counters for badge tracking
        updateCounters(for: action)

        // Recalculate level
        let newLevel = computeLevel(for: profile.totalXP)
        profile.currentLevel = newLevel

        // Update quest progress
        updateQuestProgress(for: action)

        // Check newly earned badges
        let newBadges = checkBadges()

        // Build pending rewards
        pendingRewards.append(GamingReward(
            xp: action.xp,
            message: action.message,
            badge: newBadges.first,
            levelUp: newLevel != previousLevel ? newLevel : nil
        ))

        // Trigger level-up overlay
        if newLevel != previousLevel {
            levelUpTo = newLevel
            showLevelUp = true
        }

        saveProfile()
    }

    // MARK: - Daily Login / Streak

    func recordLogin() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let lastDay = calendar.startOfDay(for: profile.lastLoginDate)

        guard !calendar.isDate(today, inSameDayAs: profile.lastLoginDate) else { return }

        let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if diff == 1 {
            profile.streak += 1
        } else if diff > 1 {
            profile.streak = 1
        }

        profile.longestStreak = max(profile.longestStreak, profile.streak)
        profile.lastLoginDate = .now

        record(.dailyLogin)

        if profile.streak == 7  { record(.streakMilestone7) }
        if profile.streak == 30 { record(.streakMilestone30) }
    }

    // MARK: - Level Up

    func checkLevelUp() -> StyleLevel? {
        let computed = computeLevel(for: profile.totalXP)
        if computed != profile.currentLevel {
            profile.currentLevel = computed
            return computed
        }
        return nil
    }

    // MARK: - Badge Check

    func checkBadges() -> [Badge] {
        var newBadges: [Badge] = []

        for badge in Badge.catalog where !profile.earnedBadgeIDs.contains(badge.id) {
            if shouldEarn(badge: badge) {
                var earned = badge
                earned.earnedAt = .now
                profile.earnedBadgeIDs.append(badge.id)
                newBadges.append(earned)
            }
        }
        return newBadges
    }

    // MARK: - Quest Management

    func claimQuestReward(_ quest: Quest) {
        guard quest.isCompleted,
              !profile.completedQuestIDs.contains(quest.id) else { return }
        profile.completedQuestIDs.append(quest.id)
        profile.totalXP += quest.xpReward
        profile.currentLevel = computeLevel(for: profile.totalXP)
        pendingRewards.append(GamingReward(
            xp: quest.xpReward,
            message: "+\(quest.xpReward) XP · Quête accomplie !",
            badge: nil,
            levelUp: nil
        ))
        saveProfile()
        saveQuests()
    }

    func dismissReward(_ id: UUID) {
        pendingRewards.removeAll { $0.id == id }
    }

    // MARK: - Leaderboard Rank

    func updateRank(_ rank: Int) {
        profile.rank = rank
        saveProfile()
    }

    // MARK: - Internal Helpers

    private func computeLevel(for xp: Int) -> StyleLevel {
        let levels = StyleLevel.allCases.reversed()
        for level in levels {
            if xp >= level.minXP { return level }
        }
        return .debutante
    }

    private func updateCounters(for action: GamingAction) {
        switch action {
        case .tryOnGenerated:        profile.tryOnCount += 1
        case .outfitCompleted:       profile.outfitCount += 1
        case .lookShared:            profile.shareCount += 1
        case .challengeWon:          profile.challengeWinCount += 1
        case .friendReferred:        profile.referralCount += 1
        case .profileCompleted:      profile.profileCompletedRecorded = true
        default: break
        }
    }

    private func updateQuestProgress(for action: GamingAction) {
        for i in activeQuests.indices {
            guard !activeQuests[i].isCompleted else { continue }
            switch action {
            case .tryOnGenerated:
                if activeQuests[i].title.contains("Essayage") { activeQuests[i].progress += 1 }
                if activeQuests[i].title.contains("Active") { activeQuests[i].progress += 1 }
            case .outfitCompleted:
                if activeQuests[i].title.contains("Tenue") { activeQuests[i].progress += 1 }
                if activeQuests[i].title.contains("Styliste") { activeQuests[i].progress += 1 }
                if activeQuests[i].title.contains("Grande Styliste") { activeQuests[i].progress += 1 }
            case .lookShared:
                if activeQuests[i].title.contains("Partage") { activeQuests[i].progress += 1 }
                if activeQuests[i].title.contains("Voix") { activeQuests[i].progress += 1 }
            case .friendReferred:
                if activeQuests[i].title.contains("Réseau") { activeQuests[i].progress += 1 }
            default: break
            }
        }
        saveQuests()
    }

    // Badge condition evaluator
    private func shouldEarn(badge: Badge) -> Bool {
        switch badge.id {
        case "first_tryon":          return profile.tryOnCount >= 1
        case "tryon_10":             return profile.tryOnCount >= 10
        case "tryon_50":             return profile.tryOnCount >= 50
        case "tryon_100":            return profile.tryOnCount >= 100
        case "tryon_500":            return profile.tryOnCount >= 500
        case "tryon_1000":           return profile.tryOnCount >= 1000
        case "first_outfit":         return profile.outfitCount >= 1
        case "outfit_5":             return profile.outfitCount >= 5
        case "outfit_10":            return profile.outfitCount >= 10
        case "outfit_25":            return profile.outfitCount >= 25
        case "daily_3":              return profile.streak >= 3
        case "streak_7":             return profile.streak >= 7
        case "streak_30":            return profile.streak >= 30
        case "streak_100":           return profile.streak >= 100
        case "streak_365":           return profile.streak >= 365
        case "first_share":          return profile.shareCount >= 1
        case "share_10":             return profile.shareCount >= 10
        case "share_50":             return profile.shareCount >= 50
        case "profile_done":         return profile.profileCompletedRecorded
        case "first_challenge":      return profile.challengeWinCount >= 1  // awarded on first challenge win
        case "challenge_3":          return profile.challengeWinCount >= 3
        case "challenge_won":        return profile.challengeWinCount >= 1
        case "challenge_won_3":      return profile.challengeWinCount >= 3
        case "challenge_won_10":     return profile.challengeWinCount >= 10
        case "partner_first":        return false  // tracked via partnerPurchase event counter — add if needed
        case "refer_first":          return profile.referralCount >= 1
        case "refer_3":              return profile.referralCount >= 3
        case "refer_10":             return profile.referralCount >= 10
        case "gift_first":           return false  // tracked via giftSent event counter
        case "level_haute_couture":  return profile.currentLevel == .hauteCouture || profile.currentLevel == .legendaire
        case "level_legendaire":     return profile.currentLevel == .legendaire
        default: return false
        }
    }

    // MARK: - Persistence

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
        // Cloud sync — fire-and-forget, ne bloque pas le Main Actor.
        let snapshot = profile
        Task.detached { await SupabaseService.shared.saveGamingProfile(snapshot) }
    }

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(GamingProfile.self, from: data) {
            profile = saved
        }
        refreshQuestsIfNeeded()
        // Sync cloud au démarrage : prend le profil cloud s'il a plus d'XP.
        Task { await syncFromSupabase() }
    }

    // MARK: - Cloud Sync

    /// Récupère le profil cloud et fusionne : conserve le profil avec le plus d'XP.
    /// Appelable depuis l'app après login pour forcer la sync.
    func syncFromSupabase() async {
        guard let cloud = try? await SupabaseService.shared.fetchGamingProfile() else { return }
        // Merge conservatif : le profil le plus avancé (totalXP) gagne.
        if cloud.totalXP > profile.totalXP {
            profile = cloud
            // Persiste localement le profil cloud reçu (sans re-déclencher cloud save).
            if let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: profileKey)
            }
        }
    }

    private func saveQuests() {
        if let data = try? JSONEncoder().encode(activeQuests) {
            UserDefaults.standard.set(data, forKey: questsKey)
        }
    }

    private func refreshQuestsIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        if Calendar.current.isDate(today, inSameDayAs: questsLastRefresh) { return }
        questsLastRefresh = today

        var newQuests = Quest.dailyQuests() + Quest.weeklyQuests() + Quest.achievements
        // Restore progress for quests that already exist
        if let data = UserDefaults.standard.data(forKey: questsKey),
           let saved = try? JSONDecoder().decode([Quest].self, from: data) {
            for i in newQuests.indices {
                if let existing = saved.first(where: { $0.id == newQuests[i].id }) {
                    newQuests[i].progress = existing.progress
                    newQuests[i].completedAt = existing.completedAt
                }
            }
        }
        activeQuests = newQuests
    }
}
