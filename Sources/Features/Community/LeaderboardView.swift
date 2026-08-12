import SwiftUI

// MARK: - Leaderboard View

struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    let currentUserRank: Int

    var topThree: [LeaderboardEntry] { Array(entries.prefix(3)) }
    var rest: [LeaderboardEntry] { Array(entries.dropFirst(3)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: EcrinSpacing.lg) {
                    // Header
                    VStack(spacing: 4) {
                        Text(L10n.CommunityUI.leaderboard)
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                        Text(L10n.CommunityUI.topMembersThisMonth)
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    .padding(.top, EcrinSpacing.md)

                    // Podium
                    podiumView
                        .padding(.horizontal, EcrinSpacing.md)

                    // List 4-20
                    VStack(spacing: EcrinSpacing.sm) {
                        ForEach(rest) { entry in
                            LeaderboardRow(entry: entry, isCurrentUser: entry.rank == currentUserRank)
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.md)

                    // Bottom padding for sticky banner
                    Spacer().frame(height: 80)
                }
            }

            // Sticky current rank banner
            currentRankBanner
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: EcrinSpacing.md) {
            // 2nd place
            if topThree.count > 1 {
                PodiumColumn(entry: topThree[1], rank: 2, height: 110, color: .init(hex: "#9CA3AF"))
            }

            // 1st place (tallest)
            if topThree.count > 0 {
                PodiumColumn(entry: topThree[0], rank: 1, height: 145, color: EcrinColor.gold)
            }

            // 3rd place
            if topThree.count > 2 {
                PodiumColumn(entry: topThree[2], rank: 3, height: 85, color: .init(hex: "#92400E"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sticky Current Rank

    private var currentRankBanner: some View {
        let entry = entries.first(where: { $0.rank == currentUserRank })
        return HStack(spacing: EcrinSpacing.md) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(EcrinColor.gold)
                    .frame(width: 38, height: 38)
                Text("#\(currentUserRank)")
                    .font(EcrinFont.sans(12, weight: .bold))
                    .foregroundStyle(EcrinColor.background)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.CommunityUI.yourRanking)
                    .font(EcrinFont.label)
                    .foregroundStyle(EcrinColor.textSecondary)
                Text(entry?.user.displayName ?? "Vous")
                    .font(EcrinFont.sans(14, weight: .semibold))
                    .foregroundStyle(EcrinColor.textPrimary)
            }

            Spacer()

            Text("\(entry?.score ?? 0) pts")
                .font(EcrinFont.sans(15, weight: .semibold))
                .foregroundStyle(EcrinColor.gold)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EcrinColor.gold.opacity(0.3))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Podium Column

private struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let rank: Int
    let height: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: EcrinSpacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: rank == 1 ? 64 : 52, height: rank == 1 ? 64 : 52)
                    .overlay {
                        Circle()
                            .strokeBorder(color, lineWidth: rank == 1 ? 2 : 1)
                    }
                Text(initials(for: entry.user))
                    .font(EcrinFont.sans(rank == 1 ? 18 : 14, weight: .semibold))
                    .foregroundStyle(color)

                // Badge
                Text(entry.badge)
                    .font(.system(size: 14))
                    .offset(x: rank == 1 ? 20 : 16, y: rank == 1 ? -20 : -16)
            }

            // Name
            Text(entry.user.displayName ?? "")
                .font(EcrinFont.sans(11, weight: .medium))
                .foregroundStyle(EcrinColor.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 80)

            // Score
            Text("\(entry.score)")
                .font(EcrinFont.sans(12, weight: .semibold))
                .foregroundStyle(color)

            // Pedestal
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(color.opacity(0.4), lineWidth: 0.5)
                }
                .frame(height: height)
                .overlay(alignment: .top) {
                    Text("#\(rank)")
                        .font(EcrinFont.sans(13, weight: .bold))
                        .foregroundStyle(color)
                        .padding(.top, 8)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func initials(for user: User) -> String {
        let name = user.displayName ?? user.email
        let parts = name.components(separatedBy: .whitespacesAndNewlines)
        if parts.count >= 2 {
            return String((parts[0].first ?? "?")) + String((parts[1].first ?? "?"))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Rank
            Text("#\(entry.rank)")
                .font(EcrinFont.sans(13, weight: .semibold))
                .foregroundStyle(EcrinColor.textMuted)
                .frame(width: 28, alignment: .leading)

            // Avatar
            Circle()
                .fill(EcrinColor.glassFill)
                .frame(width: 36, height: 36)
                .overlay {
                    Circle()
                        .strokeBorder(isCurrentUser ? EcrinColor.gold : EcrinColor.glassStroke, lineWidth: isCurrentUser ? 1.5 : 0.5)
                }
                .overlay {
                    Text(initials(for: entry.user))
                        .font(EcrinFont.sans(12, weight: .medium))
                        .foregroundStyle(isCurrentUser ? EcrinColor.gold : EcrinColor.textSecondary)
                }

            // Name + badge
            HStack(spacing: 4) {
                Text(entry.user.displayName ?? "")
                    .font(EcrinFont.sans(13, weight: isCurrentUser ? .semibold : .regular))
                    .foregroundStyle(isCurrentUser ? EcrinColor.textPrimary : EcrinColor.textSecondary)
                Text(entry.badge)
                    .font(.system(size: 13))
            }

            Spacer()

            // Score
            Text("\(entry.score) pts")
                .font(EcrinFont.sans(13, weight: .semibold))
                .foregroundStyle(isCurrentUser ? EcrinColor.gold : EcrinColor.textSecondary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm + 2)
        .background(
            isCurrentUser ? EcrinColor.gold.opacity(0.06) : EcrinColor.glassFill
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if isCurrentUser {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 0.5)
            }
        }
    }

    private func initials(for user: User) -> String {
        let name = user.displayName ?? user.email
        let parts = name.components(separatedBy: .whitespacesAndNewlines)
        if parts.count >= 2 {
            return String((parts[0].first ?? "?")) + String((parts[1].first ?? "?"))
        }
        return String(name.prefix(2)).uppercased()
    }
}
