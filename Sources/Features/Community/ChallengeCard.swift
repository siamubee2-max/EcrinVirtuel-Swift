import SwiftUI

// MARK: - Challenge Banner (featured / large)

struct ChallengeBanner: View {
    let challenge: CommunityChallenge
    let countdown: String
    let onParticipate: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1C1200"),
                            Color(hex: "#2D1E00"),
                            EcrinColor.gold.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [EcrinColor.gold.opacity(0.6), EcrinColor.gold.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .frame(height: 220)

            // Large icon background
            HStack {
                Spacer()
                Image(systemName: challenge.coverImageName)
                    .font(.system(size: 110, weight: .thin))
                    .foregroundStyle(EcrinColor.gold.opacity(0.12))
                    .offset(x: 20, y: -10)
            }

            // Content
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
                HStack(spacing: 6) {
                    // Active chip
                    Label(L10n.CommunityUI.activeChallenge, systemImage: "flame.fill")
                        .font(EcrinFont.label)
                        .kerning(1)
                        .foregroundStyle(EcrinColor.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(EcrinColor.gold)
                        .clipShape(Capsule())

                    if challenge.isParticipating {
                        Label(L10n.CommunityUI.joined, systemImage: "checkmark.seal.fill")
                            .font(EcrinFont.label)
                            .kerning(1)
                            .foregroundStyle(EcrinColor.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(EcrinColor.gold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(challenge.title)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.ivory)

                // Récompense — toujours visible
                HStack(spacing: 6) {
                    Image(systemName: challenge.prizeIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(EcrinColor.goldLight)
                    Text(L10n.CommunityUI.rewardPrefix)
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.textMuted)
                    + Text(challenge.prize)
                        .font(EcrinFont.label)
                        .foregroundStyle(EcrinColor.goldLight)
                }

                HStack(spacing: EcrinSpacing.md) {
                    // Countdown
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.CommunityUI.endsIn)
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textMuted)
                        Text(countdown)
                            .font(EcrinFont.sans(18, weight: .semibold))
                            .foregroundStyle(EcrinColor.gold)
                    }

                    Spacer()

                    // Participants
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(challenge.participantCount)")
                            .font(EcrinFont.sans(18, weight: .semibold))
                            .foregroundStyle(EcrinColor.ivory)
                        Text(L10n.CommunityUI.participantsCount)
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }

                GoldButton(
                    title: challenge.isParticipating ? L10n.CommunityUI.seeMyTryOns : L10n.CommunityUI.participate,
                    action: onParticipate
                )
                .padding(.top, 2)
            }
            .padding(EcrinSpacing.lg)
        }
    }
}

// MARK: - Challenge Card (compact)

struct ChallengeCard: View {
    let challenge: CommunityChallenge
    let countdown: String
    let onParticipate: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(alignment: .top, spacing: EcrinSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(EcrinColor.gold.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: challenge.coverImageName)
                        .font(.system(size: 22))
                        .foregroundStyle(EcrinColor.gold)
                }

                // Content
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(challenge.title)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)
                        if challenge.isParticipating {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(EcrinColor.gold)
                        }
                    }

                    Text(challenge.description)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: EcrinSpacing.md) {
                        // Countdown
                        Label(countdown, systemImage: "timer")
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.gold)

                        // Participants
                        Label("\(challenge.participantCount)", systemImage: "person.2.fill")
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                    .padding(.top, 2)

                    // Récompense
                    HStack(spacing: 5) {
                        Image(systemName: challenge.prizeIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(EcrinColor.goldLight)
                        Text(challenge.prize)
                            .font(EcrinFont.label)
                            .foregroundStyle(EcrinColor.goldLight)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Bouton dynamique selon état d'inscription
                Button(action: onParticipate) {
                    Text(challenge.isParticipating ? L10n.CommunityUI.joinedCheck : L10n.CommunityUI.joinShort)
                        .font(EcrinFont.label)
                        .kerning(1)
                        .foregroundStyle(challenge.isParticipating ? EcrinColor.background : EcrinColor.gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            challenge.isParticipating
                                ? AnyShapeStyle(EcrinColor.gold)
                                : AnyShapeStyle(Color.clear)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(EcrinColor.gold.opacity(0.5), lineWidth: challenge.isParticipating ? 0 : 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(EcrinSpacing.md)
        }
    }
}
