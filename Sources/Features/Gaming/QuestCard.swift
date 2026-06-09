import SwiftUI

// MARK: - Quest Card

struct QuestCard: View {
    let quest: Quest
    let onClaim: () -> Void

    @State private var progressAnim: Double = 0

    private var questColor: Color {
        switch quest.type {
        case .daily:       return Color(hex: "#34D399")
        case .weekly:      return EcrinColor.gold
        case .achievement: return Color(hex: "#A78BFA")
        case .special:     return Color(hex: "#F472B6")
        }
    }

    private var typeLabel: String {
        switch quest.type {
        case .daily:       return "Quotidienne"
        case .weekly:      return "Hebdomadaire"
        case .achievement: return "Succès"
        case .special:     return "Spéciale"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EcrinSpacing.sm) {
            // Header
            HStack(alignment: .top, spacing: EcrinSpacing.sm) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(questColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: quest.icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(questColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Type badge
                    Text(typeLabel)
                        .font(EcrinFont.label)
                        .kerning(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(questColor)

                    Text(quest.title)
                        .font(EcrinFont.cardTitle)
                        .foregroundStyle(EcrinColor.textPrimary)
                        .lineLimit(1)

                    Text(quest.description)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                // Expiry
                if let label = quest.expiresInLabel {
                    Text(label)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: EcrinSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(EcrinColor.glassFill)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [questColor, questColor.opacity(0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressAnim, height: 6)
                            .shadow(color: questColor.opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(quest.progress) / \(quest.target)")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                    Spacer()
                    Text(quest.rewardDescription)
                        .font(EcrinFont.caption)
                        .foregroundStyle(questColor)
                }
            }

            // Claim button if completed
            if quest.isCompleted {
                Button(action: onClaim) {
                    HStack(spacing: EcrinSpacing.xs) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 11))
                        Text("Réclamer la récompense")
                            .font(EcrinFont.cta)
                            .kerning(1.5)
                    }
                    .textCase(.uppercase)
                    .foregroundStyle(EcrinColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EcrinSpacing.sm)
                    .background(questColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: questColor.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EcrinSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EcrinColor.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            quest.isCompleted
                                ? questColor.opacity(0.5)
                                : EcrinColor.glassStroke,
                            lineWidth: quest.isCompleted ? 1 : 0.5
                        )
                }
        }
        .onAppear {
            withAnimation(EcrinAnimation.easeSlide.delay(0.2)) {
                progressAnim = quest.progressFraction
            }
        }
        .onChange(of: quest.progress) { _, _ in
            withAnimation(EcrinAnimation.springSnap) {
                progressAnim = quest.progressFraction
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        EcrinColor.background.ignoresSafeArea()
        VStack(spacing: EcrinSpacing.md) {
            QuestCard(
                quest: Quest(
                    id: UUID(), title: "Essayage du Jour",
                    description: "Testez un bijou aujourd'hui",
                    icon: "sparkles", type: .daily, xpReward: 15,
                    rewardDescription: "+15 XP",
                    progress: 0, target: 1, expiresAt: nil
                ),
                onClaim: {}
            )
            QuestCard(
                quest: Quest(
                    id: UUID(), title: "Semaine Active",
                    description: "Réalisez 7 essayages cette semaine",
                    icon: "flame.fill", type: .weekly, xpReward: 80,
                    rewardDescription: "+80 XP",
                    progress: 4, target: 7, expiresAt: nil
                ),
                onClaim: {}
            )
        }
        .padding()
    }
}
#endif
