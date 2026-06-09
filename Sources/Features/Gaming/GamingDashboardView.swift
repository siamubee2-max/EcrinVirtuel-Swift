import SwiftUI

// MARK: - Gaming Dashboard View

struct GamingDashboardView: View {
    @ObservedObject private var gaming = GamingService.shared

    @State private var selectedTab: DashboardTab = .quests
    @State private var selectedBadge: Badge? = nil
    @State private var levelBarAnim: Double = 0
    @State private var streakScale: CGFloat = 0.8

    enum DashboardTab: String, CaseIterable {
        case quests       = "Quêtes"
        case badges       = "Badges"
        case leaderboard  = "Classement"
    }

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top header spacer
                    Spacer().frame(height: EcrinSpacing.lg)

                    // MARK: Title
                    VStack(spacing: 4) {
                        Text("Mon Espace Écrin")
                            .font(EcrinFont.heroTitle)
                            .foregroundStyle(EcrinColor.ivory)
                        Text("Progression & Récompenses")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .kerning(2)
                            .textCase(.uppercase)
                    }
                    .padding(.bottom, EcrinSpacing.xl)

                    // MARK: Level Card
                    levelCard
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.bottom, EcrinSpacing.lg)

                    // MARK: Streak Card
                    streakCard
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.bottom, EcrinSpacing.lg)

                    // MARK: Tab Selector
                    tabSelector
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.bottom, EcrinSpacing.md)

                    // MARK: Tab Content
                    tabContent
                        .padding(.horizontal, EcrinSpacing.md)

                    Spacer().frame(height: EcrinSpacing.xxl)
                }
            }
        }
        .onAppear { animateEntrance() }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
                .presentationDetents([.large])
                .presentationBackground(EcrinColor.background)
        }
    }

    // MARK: - Level Card

    private var levelCard: some View {
        let level = gaming.profile.currentLevel
        let nextLevel = StyleLevel(rawValue: level.rawValue + 1)

        return VStack(spacing: EcrinSpacing.md) {
            HStack(spacing: EcrinSpacing.md) {
                // Level icon
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle()
                                .strokeBorder(level.color.opacity(0.5), lineWidth: 1.5)
                        }
                    Image(systemName: level.icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(level.color)
                        .shadow(color: level.color.opacity(0.5), radius: 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Niveau \(level.rawValue)")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .kerning(2)
                        .textCase(.uppercase)
                    Text(level.title)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.ivory)
                }

                Spacer()

                // Total XP
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(gaming.profile.totalXP)")
                        .font(EcrinFont.serif(28, weight: .semibold))
                        .foregroundStyle(EcrinColor.gold)
                    Text("XP total")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                HStack {
                    Text(level.title)
                        .font(EcrinFont.caption)
                        .foregroundStyle(level.color)
                    Spacer()
                    if let next = nextLevel {
                        Text("\(gaming.profile.xpToNextLevel) XP → \(next.title)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    } else {
                        Text("Niveau maximum atteint")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.gold)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(EcrinColor.glassFill)
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [level.color, EcrinColor.goldLight],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * levelBarAnim, height: 10)
                            .shadow(color: level.color.opacity(0.6), radius: 6)
                    }
                }
                .frame(height: 10)
            }

            // Perks preview
            if !level.perks.isEmpty {
                HStack(spacing: EcrinSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(level.color)
                    Text(level.perks.first ?? "")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                    Spacer()
                    if level.perks.count > 1 {
                        Text("+\(level.perks.count - 1) avantages")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
            }
        }
        .padding(EcrinSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(level.color.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: level.color.opacity(0.1), radius: 20, y: 5)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: EcrinSpacing.lg) {
            // Flame
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: gaming.profile.streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 8)
            }
            .scaleEffect(streakScale)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(gaming.profile.streak) jours consécutifs")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.ivory)
                Text("Record : \(gaming.profile.longestStreak) jours")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }

            Spacer()

            // Milestones
            VStack(alignment: .trailing, spacing: 4) {
                streakMilestone(days: 7, current: gaming.profile.streak)
                streakMilestone(days: 30, current: gaming.profile.streak)
            }
        }
        .padding(EcrinSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            gaming.profile.streak >= 7
                                ? Color.orange.opacity(0.35)
                                : EcrinColor.glassStroke,
                            lineWidth: 0.5
                        )
                }
        }
    }

    private func streakMilestone(days: Int, current: Int) -> some View {
        let achieved = current >= days
        return HStack(spacing: 4) {
            Image(systemName: achieved ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(achieved ? Color.orange : EcrinColor.textMuted)
            Text("\(days)j")
                .font(EcrinFont.caption)
                .foregroundStyle(achieved ? EcrinColor.textPrimary : EcrinColor.textMuted)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(EcrinAnimation.springSnap) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(EcrinFont.sans(12, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? EcrinColor.gold : EcrinColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EcrinSpacing.sm + 2)
                }
                .buttonStyle(.plain)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                }
        }
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                let tabWidth = geo.size.width / CGFloat(DashboardTab.allCases.count)
                let index = DashboardTab.allCases.firstIndex(of: selectedTab) ?? 0
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(EcrinColor.gold)
                    .frame(width: tabWidth * 0.5, height: 2)
                    .offset(x: tabWidth * CGFloat(index) + tabWidth * 0.25, y: 0)
                    .animation(EcrinAnimation.springSnap, value: selectedTab)
            }
            .frame(height: 2)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .quests:      questsSection
        case .badges:      badgesSection
        case .leaderboard: leaderboardSection
        }
    }

    // MARK: Quests Section

    private var questsSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            let daily   = gaming.activeQuests.filter { $0.type == .daily }
            let weekly  = gaming.activeQuests.filter { $0.type == .weekly }
            let achieve = gaming.activeQuests.filter { $0.type == .achievement }

            if !daily.isEmpty {
                sectionHeader("Quotidiennes", icon: "sun.max.fill")
                ForEach(daily) { quest in
                    QuestCard(quest: quest) { gaming.claimQuestReward(quest) }
                }
            }

            if !weekly.isEmpty {
                sectionHeader("Hebdomadaires", icon: "calendar.badge.clock")
                ForEach(weekly) { quest in
                    QuestCard(quest: quest) { gaming.claimQuestReward(quest) }
                }
            }

            if !achieve.isEmpty {
                sectionHeader("Succès", icon: "medal.fill")
                ForEach(achieve) { quest in
                    QuestCard(quest: quest) { gaming.claimQuestReward(quest) }
                }
            }
        }
    }

    // MARK: Badges Section

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.lg) {
            // Stats row
            HStack(spacing: 0) {
                badgeStat(
                    label: "Obtenus",
                    value: "\(gaming.profile.earnedBadgeIDs.count)",
                    icon: "checkmark.seal.fill",
                    color: EcrinColor.gold
                )
                Divider().frame(height: 40).background(EcrinColor.glassStroke)
                badgeStat(
                    label: "Total",
                    value: "\(Badge.catalog.count)",
                    icon: "square.grid.3x3.fill",
                    color: EcrinColor.textSecondary
                )
                Divider().frame(height: 40).background(EcrinColor.glassStroke)
                badgeStat(
                    label: "Légendaires",
                    value: "\(gaming.profile.earnedBadges.filter { $0.rarity == .legendary }.count)",
                    icon: "diamond.fill",
                    color: EcrinColor.gold
                )
            }
            .padding(.vertical, EcrinSpacing.md)
            .background(EcrinColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
            }

            // Badge grid by rarity
            ForEach(BadgeRarity.allCases, id: \.self) { rarity in
                let rarityBadges = Badge.catalog.filter { $0.rarity == rarity }
                let earnedCount = rarityBadges.filter { gaming.profile.earnedBadgeIDs.contains($0.id) }.count

                VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                    HStack(spacing: EcrinSpacing.xs) {
                        Circle()
                            .fill(rarity.color)
                            .frame(width: 7, height: 7)
                        Text(rarity.label)
                            .font(EcrinFont.label)
                            .kerning(2)
                            .textCase(.uppercase)
                            .foregroundStyle(rarity.color)
                        Text("(\(earnedCount)/\(rarityBadges.count))")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }

                    // Horizontal scroll for badges
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EcrinSpacing.sm) {
                            ForEach(rarityBadges) { badge in
                                var displayBadge = badge
                                let _ = { if gaming.profile.earnedBadgeIDs.contains(badge.id) { displayBadge.earnedAt = displayBadge.earnedAt ?? .now } }()
                                Button {
                                    selectedBadge = Badge.catalog.first(where: { $0.id == badge.id }).map { b in
                                        var earned = b
                                        if gaming.profile.earnedBadgeIDs.contains(b.id) {
                                            earned.earnedAt = b.earnedAt ?? .now
                                        }
                                        return earned
                                    } ?? badge
                                } label: {
                                    BadgeCard(badge: {
                                        var b = badge
                                        if gaming.profile.earnedBadgeIDs.contains(badge.id) { b.earnedAt = .now }
                                        return b
                                    }())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, EcrinSpacing.xs)
                    }
                }
            }
        }
    }

    private func badgeStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(value)
                .font(EcrinFont.serif(20, weight: .semibold))
                .foregroundStyle(EcrinColor.textPrimary)
            Text(label)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Leaderboard Section

    private var leaderboardSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            // User rank card
            if let rank = gaming.profile.rank {
                HStack(spacing: EcrinSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(EcrinColor.gold)
                            .frame(width: 44, height: 44)
                        Text("#\(rank)")
                            .font(EcrinFont.sans(13, weight: .bold))
                            .foregroundStyle(EcrinColor.background)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Votre classement")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                        Text("Top \(rank) · Communauté Écrin")
                            .font(EcrinFont.sans(14, weight: .semibold))
                            .foregroundStyle(EcrinColor.ivory)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(gaming.profile.totalXP)")
                            .font(EcrinFont.serif(20, weight: .semibold))
                            .foregroundStyle(EcrinColor.gold)
                        Text("XP")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }
                .padding(EcrinSpacing.md)
                .background(EcrinColor.gold.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 1)
                }
            }

            // Podium (sample data)
            LeaderboardView(
                entries: LeaderboardEntry.samples,
                currentUserRank: gaming.profile.rank ?? 99
            )
            .frame(height: 600)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: EcrinSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(EcrinColor.gold)
            Text(title)
                .font(EcrinFont.label)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .padding(.top, EcrinSpacing.xs)
    }

    private func animateEntrance() {
        withAnimation(EcrinAnimation.easeSlide.delay(0.3)) {
            levelBarAnim = gaming.profile.levelProgress
        }
        withAnimation(EcrinAnimation.springBounce.delay(0.2)) {
            streakScale = 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    GamingDashboardView()
}
#endif
