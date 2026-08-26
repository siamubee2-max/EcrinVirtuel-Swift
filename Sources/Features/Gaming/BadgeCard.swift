import SwiftUI

// MARK: - Badge Card (grid item)

struct BadgeCard: View {
    let badge: Badge
    @State private var glowPulse: Bool = false
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: EcrinSpacing.xs) {
            // Badge icon container
            ZStack {
                // Background glow for earned/legendary
                if badge.isEarned && badge.rarity == .legendary {
                    Circle()
                        .fill(badge.rarityColor.opacity(glowPulse ? 0.25 : 0.10))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(
                        badge.isEarned
                            ? badge.rarityColor.opacity(0.15)
                            : EcrinColor.glassFill
                    )
                    .frame(width: 54, height: 54)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                badge.isEarned
                                    ? badge.rarityColor.opacity(glowPulse ? 0.8 : 0.5)
                                    : EcrinColor.glassStroke,
                                lineWidth: badge.isEarned ? 1.5 : 0.5
                            )
                    }

                if badge.isEarned {
                    Image(systemName: badge.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(badge.rarityColor)
                        .shadow(color: badge.rarityColor.opacity(0.4), radius: badge.rarity.glowRadius)
                } else {
                    // Locked state
                    VStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(EcrinColor.textMuted)
                    }
                }

                // Shimmer overlay for legendary earned badges
                if badge.isEarned && badge.rarity == .legendary {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, EcrinColor.ivory.opacity(0.3), Color.clear],
                                startPoint: UnitPoint(x: shimmerOffset, y: 0),
                                endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 1)
                            )
                        )
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                }
            }
            .onAppear {
                if badge.isEarned {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        glowPulse = true
                    }
                    if badge.rarity == .legendary {
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false).delay(0.5)) {
                            shimmerOffset = 1.5
                        }
                    }
                }
            }

            // Badge name
            Text(badge.isEarned ? badge.name : "???")
                .font(EcrinFont.caption)
                .foregroundStyle(badge.isEarned ? EcrinColor.textPrimary : EcrinColor.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .frame(width: 78)
        .opacity(badge.isEarned ? 1.0 : 0.5)
    }
}

// MARK: - Badge Detail View

struct BadgeDetailView: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss

    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var glowPulse: Bool = false
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            VStack(spacing: EcrinSpacing.xl) {
                // Handle
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(EcrinColor.glassStroke)
                    .frame(width: 40, height: 4)
                    .padding(.top, EcrinSpacing.md)

                // Badge icon — large
                ZStack {
                    // Multi-ring glow for legendary
                    if badge.rarity == .legendary || badge.rarity == .epic {
                        Circle()
                            .fill(badge.rarityColor.opacity(glowPulse ? 0.15 : 0.06))
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)

                        Circle()
                            .strokeBorder(badge.rarityColor.opacity(glowPulse ? 0.3 : 0.1), lineWidth: 1)
                            .frame(width: 155, height: 155)
                    }

                    Circle()
                        .fill(badge.rarityColor.opacity(0.12))
                        .frame(width: 130, height: 130)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [badge.rarityColor, badge.rarityColor.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: badge.isEarned ? 2 : 1
                                )
                        }
                        .shadow(color: badge.rarityColor.opacity(glowPulse ? 0.6 : 0.2), radius: badge.rarity.glowRadius * 1.5)

                    // Shimmer for legendary
                    if badge.isEarned && badge.rarity == .legendary {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, EcrinColor.ivory.opacity(0.25), Color.clear],
                                    startPoint: UnitPoint(x: shimmerOffset, y: 0),
                                    endPoint: UnitPoint(x: shimmerOffset + 0.4, y: 1)
                                )
                            )
                            .frame(width: 130, height: 130)
                            .clipShape(Circle())
                    }

                    if badge.isEarned {
                        Image(systemName: badge.icon)
                            .font(.system(size: 56, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [badge.rarityColor, EcrinColor.ivory.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: badge.rarityColor.opacity(0.6), radius: 16)
                    } else {
                        VStack(spacing: EcrinSpacing.xs) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundStyle(EcrinColor.textMuted)
                            Text("?")
                                .font(EcrinFont.serif(28, weight: .thin))
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    }
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                // Badge info
                VStack(spacing: EcrinSpacing.md) {
                    // Rarity chip
                    HStack(spacing: EcrinSpacing.xs) {
                        Circle()
                            .fill(badge.rarityColor)
                            .frame(width: 6, height: 6)
                        Text(badge.rarity.label)
                            .font(EcrinFont.label)
                            .kerning(2)
                            .textCase(.uppercase)
                            .foregroundStyle(badge.rarityColor)
                    }
                    .padding(.horizontal, EcrinSpacing.md)
                    .padding(.vertical, 6)
                    .background(badge.rarityColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(badge.rarityColor.opacity(0.3), lineWidth: 0.5)
                    }

                    // Name
                    Text(badge.name)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .multilineTextAlignment(.center)

                    // Description
                    Text(badge.description)
                        .font(EcrinFont.body)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, EcrinSpacing.lg)

                    // Earned date OR how to earn
                    if badge.isEarned, let date = badge.earnedAt {
                        HStack(spacing: EcrinSpacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(badge.rarityColor)
                                .font(.system(size: 13))
                            Text("Obtenu le \(date.formatted(date: .long, time: .omitted))")
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                        }
                        .padding(.top, EcrinSpacing.xs)
                    } else {
                        VStack(spacing: EcrinSpacing.xs) {
                            Text(L10n.GamingUI.howToGetIt)
                                .font(EcrinFont.label)
                                .kerning(2)
                                .textCase(.uppercase)
                                .foregroundStyle(EcrinColor.textMuted)

                            Text(badge.condition)
                                .font(EcrinFont.body)
                                .foregroundStyle(EcrinColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, EcrinSpacing.xl)
                        .padding(.vertical, EcrinSpacing.md)
                        .background(EcrinColor.glassFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                        }
                        .padding(.horizontal, EcrinSpacing.lg)
                    }
                }

                Spacer()

                // Dismiss
                GhostButton(title: L10n.Common.close, action: { dismiss() })
                    .padding(.bottom, EcrinSpacing.xl)
            }
        }
        .onAppear {
            withAnimation(EcrinAnimation.springBounce.delay(0.1)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                glowPulse = true
            }
            if badge.rarity == .legendary && badge.isEarned {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(0.8)) {
                    shimmerOffset = 1.5
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Earned Legendary") {
    BadgeDetailView(badge: {
        var b = Badge.catalog.first(where: { $0.rarity == .legendary })!
        b.earnedAt = .now
        return b
    }())
}

#Preview("Locked") {
    BadgeDetailView(badge: Badge.catalog.first(where: { $0.id == "tryon_500" })!)
}
#endif
