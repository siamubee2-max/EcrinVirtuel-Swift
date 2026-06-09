import SwiftUI

// MARK: - XP Toast View

struct XPToastView: View {
    let reward: GamingReward
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -120
    @State private var opacity: Double = 0
    @State private var badgeScale: CGFloat = 0
    @State private var badgeRotation: Double = -15
    @State private var glowPulse: Bool = false

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            // XP star icon
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [EcrinColor.gold, EcrinColor.goldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EcrinColor.gold)
            }

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("✦ \(reward.message)")
                    .font(EcrinFont.serif(15, weight: .medium))
                    .foregroundStyle(EcrinColor.ivory)

                if let badge = reward.badge {
                    HStack(spacing: 4) {
                        Image(systemName: badge.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(badge.rarityColor)
                            .scaleEffect(badgeScale)
                            .rotationEffect(.degrees(badgeRotation))

                        Text("Badge débloqué · \(badge.name)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(badge.rarityColor)
                    }
                }

                if let level = reward.levelUp {
                    HStack(spacing: 4) {
                        Image(systemName: level.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(level.color)
                        Text("Niveau : \(level.title)")
                            .font(EcrinFont.caption)
                            .foregroundStyle(level.color)
                    }
                }
            }

            Spacer(minLength: 0)

            // XP amount
            Text("+\(reward.xp)")
                .font(EcrinFont.serif(18, weight: .semibold))
                .foregroundStyle(EcrinColor.gold)
        }
        .padding(.horizontal, EcrinSpacing.lg)
        .padding(.vertical, EcrinSpacing.md)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    EcrinColor.gold.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    EcrinColor.gold.opacity(glowPulse ? 0.7 : 0.3),
                                    EcrinColor.gold.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: EcrinColor.gold.opacity(0.25), radius: glowPulse ? 18 : 8, y: 4)
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear { animate() }
    }

    private func animate() {
        // Slide in
        withAnimation(EcrinAnimation.springBounce) {
            offset = 0
            opacity = 1
        }

        // Badge animation if present
        if reward.badge != nil {
            withAnimation(EcrinAnimation.springBounce.delay(0.2)) {
                badgeScale = 1
                badgeRotation = 0
            }
        }

        // Gold glow pulse
        withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true).delay(0.3)) {
            glowPulse = true
        }

        // Auto dismiss after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(EcrinAnimation.easeSlide) {
                offset = -120
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        }
    }
}

// MARK: - Toast Queue Overlay

struct XPToastQueueOverlay: View {
    @ObservedObject var gaming: GamingService

    var body: some View {
        VStack {
            if let first = gaming.pendingRewards.first {
                XPToastView(reward: first) {
                    gaming.dismissReward(first.id)
                }
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(EcrinAnimation.springSnap, value: gaming.pendingRewards.map(\.id))
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        EcrinColor.background.ignoresSafeArea()
        VStack {
            XPToastView(
                reward: GamingReward(
                    xp: 25,
                    message: "+25 XP · Tenue complète !",
                    badge: Badge.catalog.first(where: { $0.id == "outfit_5" }),
                    levelUp: nil
                ),
                onDismiss: {}
            )
            .padding()

            XPToastView(
                reward: GamingReward(
                    xp: 10,
                    message: "+10 XP · Essayage réussi !",
                    badge: nil,
                    levelUp: nil
                ),
                onDismiss: {}
            )
            .padding()
        }
    }
}
#endif
