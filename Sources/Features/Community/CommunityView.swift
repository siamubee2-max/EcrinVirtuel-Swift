import SwiftUI

// MARK: - Community View

struct CommunityView: View {
    @StateObject private var vm = CommunityViewModel()

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation header
                communityHeader

                // Custom tab bar
                internalTabBar

                // Content
                TabView(selection: $vm.selectedTab) {
                    FeedTab(vm: vm)
                        .tag(CommunityViewModel.CommunityTab.feed)

                    ChallengesTab(vm: vm)
                        .tag(CommunityViewModel.CommunityTab.challenges)

                    LeaderboardView(
                        entries: vm.leaderboard,
                        currentUserRank: vm.currentUserRank
                    )
                    .tag(CommunityViewModel.CommunityTab.top)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(EcrinAnimation.easeSlide, value: vm.selectedTab)
            }
        }
    }

    // MARK: - Header

    private var communityHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Communauté")
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                Text("Inspirez et soyez inspirée")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(EcrinColor.textSecondary)
            }
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.top, EcrinSpacing.sm)
        .padding(.bottom, EcrinSpacing.md)
    }

    // MARK: - Tab Bar

    private var internalTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CommunityViewModel.CommunityTab.allCases, id: \.self) { tab in
                Button(action: { vm.selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(EcrinFont.label)
                            .kerning(1)
                    }
                    .foregroundStyle(vm.selectedTab == tab ? EcrinColor.gold : EcrinColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EcrinSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .background {
            Rectangle()
                .fill(EcrinColor.surface.opacity(0.8))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(EcrinColor.glassStroke)
                        .frame(height: 0.5)
                }
        }
        .overlay(alignment: .bottom) {
            // Sliding indicator
            GeometryReader { geo in
                let tabWidth = geo.size.width / CGFloat(CommunityViewModel.CommunityTab.allCases.count)
                let tabIndex = CommunityViewModel.CommunityTab.allCases.firstIndex(of: vm.selectedTab) ?? 0
                Capsule()
                    .fill(EcrinColor.gold)
                    .frame(width: 24, height: 2)
                    .offset(x: tabWidth * CGFloat(tabIndex) + (tabWidth - 24) / 2)
                    .animation(EcrinAnimation.springSnap, value: vm.selectedTab)
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Feed Tab

private struct FeedTab: View {
    @ObservedObject var vm: CommunityViewModel
    @State private var postForComments: CommunityPost?

    private var inspirationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(EcrinColor.gold)
            Text("Inspiration L'Écrin — exemples de rendus")
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, EcrinSpacing.sm)
        .background(EcrinColor.gold.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(EcrinColor.gold.opacity(0.2), lineWidth: 0.5))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: EcrinSpacing.md) {
                // Bandeau « Inspiration » — ce feed présente des exemples de rendus
                // L'Écrin (pas des publications d'utilisateurs réels). Transparence.
                inspirationBanner
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.top, EcrinSpacing.sm)

                // Stories row
                StoriesRow(entries: vm.leaderboard)

                // Posts — visiblePosts exclut auteurs bloqués & posts signalés (App Store 1.2)
                ForEach(vm.visiblePosts) { post in
                    PostCard(
                        post: post,
                        onLike: { vm.toggleLike(post: post) },
                        commentCount: vm.displayedCommentCount(for: post),
                        onComment: { postForComments = post },
                        onReport: { reason in vm.report(post: post, reason: reason) },
                        onBlock: { vm.blockAuthor(of: post) }
                    )
                    .padding(.horizontal, EcrinSpacing.md)
                }

                Spacer().frame(height: EcrinSpacing.xl)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("community.feed")
        .refreshable {
            await vm.refreshFeed()
        }
        .sheet(item: $postForComments) { post in
            CommentsSheet(post: post, vm: vm)
        }
    }
}

// MARK: - Stories Row

private struct StoriesRow: View {
    let entries: [LeaderboardEntry]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EcrinSpacing.md) {
                Spacer().frame(width: EcrinSpacing.md)

                // Add story button
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(EcrinColor.glassFill)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .strokeBorder(EcrinColor.glassStroke, lineWidth: 1)
                            }
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(EcrinColor.gold)
                    }
                    Text(L10n.Common.share)
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.textSecondary)
                }

                // Story items
                ForEach(entries.prefix(12)) { entry in
                    StoryAvatar(entry: entry)
                }

                Spacer().frame(width: EcrinSpacing.md)
            }
        }
    }
}

// MARK: - Story Avatar

private struct StoryAvatar: View {
    let entry: LeaderboardEntry
    // isActive is derived from rank so it's deterministic and doesn't flicker on re-render

    private var initials: String {
        let name = entry.user.displayName ?? entry.user.email
        let parts = name.components(separatedBy: .whitespacesAndNewlines)
        if parts.count >= 2 {
            return String((parts[0].first ?? "?")) + String((parts[1].first ?? "?"))
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Gold ring for active stories
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: entry.rank <= 5
                                ? [EcrinColor.goldLight, EcrinColor.gold]
                                : [EcrinColor.textMuted, EcrinColor.textMuted.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: entry.rank <= 5 ? 2 : 1
                    )
                    .frame(width: 64, height: 64)

                Circle()
                    .fill(EcrinColor.glassFill)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Text(initials)
                            .font(EcrinFont.sans(16, weight: .semibold))
                            .foregroundStyle(entry.rank <= 5 ? EcrinColor.gold : EcrinColor.textSecondary)
                    }
            }

            Text(entry.user.displayName?.components(separatedBy: " ").first ?? "")
                .font(EcrinFont.label)
                .foregroundStyle(EcrinColor.textSecondary)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

// MARK: - Challenges Tab

private struct ChallengesTab: View {
    @ObservedObject var vm: CommunityViewModel
    @State private var showParticipateSheet: Bool = false
    @State private var selectedChallenge: CommunityChallenge?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: EcrinSpacing.lg) {
                    // Featured banner
                    if let active = vm.activeChallenge {
                        ChallengeBanner(
                            challenge: active,
                            countdown: vm.countdown(to: active.endDate),
                            onParticipate: {
                                selectedChallenge = active
                                showParticipateSheet = true
                            }
                        )
                        .padding(.horizontal, EcrinSpacing.md)
                        .padding(.top, EcrinSpacing.sm)
                    }

                    // Section title
                    HStack {
                        Text("Tous les défis")
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, EcrinSpacing.md)

                    // Challenge cards
                    ForEach(vm.challenges) { challenge in
                        ChallengeCard(
                            challenge: challenge,
                            countdown: vm.countdown(to: challenge.endDate),
                            onParticipate: {
                                selectedChallenge = challenge
                                showParticipateSheet = true
                            }
                        )
                        .padding(.horizontal, EcrinSpacing.md)
                    }

                    Spacer().frame(height: EcrinSpacing.xl)
                }
            }
            .scrollIndicators(.hidden)

            // Toast de confirmation
            if let msg = vm.toastMessage {
                ToastBanner(message: msg)
                    .padding(.top, EcrinSpacing.sm)
                    .padding(.horizontal, EcrinSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(EcrinAnimation.springSnap, value: vm.toastMessage)
        .sheet(isPresented: $showParticipateSheet) {
            if let challenge = selectedChallenge {
                ParticipateSheet(
                    challenge: challenge,
                    countdown: vm.countdown(to: challenge.endDate),
                    onConfirm: {
                        vm.toggleParticipation(in: challenge)
                        showParticipateSheet = false
                    },
                    onTryOn: {
                        vm.startTryOnForChallenge(challenge)
                        showParticipateSheet = false
                    }
                )
            }
        }
    }
}

// MARK: - Toast Banner

private struct ToastBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(EcrinFont.body)
            .foregroundStyle(EcrinColor.background)
            .padding(.horizontal, EcrinSpacing.md)
            .padding(.vertical, EcrinSpacing.sm + 2)
            .background(EcrinColor.gold)
            .clipShape(Capsule())
            .shadow(color: EcrinColor.gold.opacity(0.35), radius: 12, y: 4)
    }
}

// MARK: - Participate Sheet

private struct ParticipateSheet: View {
    let challenge: CommunityChallenge
    let countdown: String
    let onConfirm: () -> Void
    let onTryOn: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: EcrinSpacing.lg) {
                    // Handle
                    Capsule()
                        .fill(EcrinColor.textMuted)
                        .frame(width: 36, height: 4)
                        .padding(.top, EcrinSpacing.md)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(EcrinColor.gold.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: challenge.coverImageName)
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(EcrinColor.gold)
                    }

                    VStack(spacing: EcrinSpacing.sm) {
                        Text(challenge.hashtag)
                            .font(EcrinFont.label)
                            .kerning(2)
                            .foregroundStyle(EcrinColor.gold)
                        Text(challenge.title)
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(challenge.description)
                            .font(EcrinFont.body)
                            .foregroundStyle(EcrinColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, EcrinSpacing.lg)
                    }

                    // Récompense — bloc visible et engageant
                    VStack(spacing: EcrinSpacing.sm) {
                        Text("VOTRE RÉCOMPENSE")
                            .font(EcrinFont.label)
                            .kerning(2)
                            .foregroundStyle(EcrinColor.textMuted)
                        HStack(spacing: EcrinSpacing.sm) {
                            Image(systemName: challenge.prizeIcon)
                                .font(.system(size: 22))
                                .foregroundStyle(EcrinColor.gold)
                            Text(challenge.prize)
                                .font(EcrinFont.cardTitle)
                                .foregroundStyle(EcrinColor.textPrimary)
                        }
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.vertical, EcrinSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(EcrinColor.gold.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(EcrinColor.gold.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, EcrinSpacing.md)

                    // Statistiques
                    HStack(spacing: EcrinSpacing.lg) {
                        VStack(spacing: 2) {
                            Text("\(challenge.participantCount)")
                                .font(EcrinFont.sans(20, weight: .semibold))
                                .foregroundStyle(EcrinColor.textPrimary)
                            Text("Participantes")
                                .font(EcrinFont.label)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                        Rectangle().fill(EcrinColor.glassStroke).frame(width: 1, height: 30)
                        VStack(spacing: 2) {
                            Text(countdown)
                                .font(EcrinFont.sans(20, weight: .semibold))
                                .foregroundStyle(EcrinColor.gold)
                            Text("Restant")
                                .font(EcrinFont.label)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                    .padding(.vertical, EcrinSpacing.sm)

                    VStack(spacing: EcrinSpacing.md) {
                        if challenge.isParticipating {
                            GoldButton(title: "Essayer un bijou maintenant", action: onTryOn)
                            GhostButton(title: "Retirer mon inscription", action: onConfirm)
                        } else {
                            GoldButton(title: "Rejoindre ce défi", action: onConfirm)
                            GhostButton(title: "Plus tard", action: { dismiss() })
                        }
                    }
                    .padding(.horizontal, EcrinSpacing.md)

                    Spacer().frame(height: EcrinSpacing.xl)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(EcrinColor.background)
    }
}
