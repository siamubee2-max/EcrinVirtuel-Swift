import SwiftUI

// MARK: - Metal Score Card

struct MetalScoreCard: View {
    let recommendation: MetalRecommendation
    let rank: Int
    var isTopChoice: Bool { rank == 0 }

    @State private var starsVisible = false
    @State private var cardVisible  = false

    var body: some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: EcrinSpacing.sm) {

                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Rank badge
                        if isTopChoice {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(EcrinColor.background)
                                Text(L10n.SkinToneUI.topPick)
                                    .font(EcrinFont.label)
                                    .kerning(1.5)
                                    .foregroundStyle(EcrinColor.background)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(EcrinColor.gold)
                            .clipShape(Capsule())
                        }

                        Text(recommendation.metal)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)
                    }

                    Spacer()

                    // Metal icon
                    ZStack {
                        Circle()
                            .fill(isTopChoice ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill)
                            .frame(width: 44, height: 44)
                        Image(systemName: recommendation.icon)
                            .font(.system(size: 18, weight: .thin))
                            .foregroundStyle(isTopChoice ? EcrinColor.gold : EcrinColor.textSecondary)
                    }
                }

                // Stars
                HStack(spacing: 4) {
                    ForEach(Array(recommendation.stars.enumerated()), id: \.offset) { index, filled in
                        Image(systemName: filled ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundStyle(filled ? EcrinColor.gold : EcrinColor.textMuted)
                            .scaleEffect(starsVisible ? 1 : 0.3)
                            .opacity(starsVisible ? 1 : 0)
                            .animation(
                                EcrinAnimation.springBounce.delay(Double(index) * 0.08),
                                value: starsVisible
                            )
                    }
                }
                .padding(.top, 2)

                // Reason text
                Text(recommendation.reason)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(EcrinSpacing.md)
        }
        .overlay {
            if isTopChoice {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [EcrinColor.gold, EcrinColor.goldLight.opacity(0.4), EcrinColor.gold.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .scaleEffect(cardVisible ? 1 : 0.92)
        .opacity(cardVisible ? 1 : 0)
        .animation(
            EcrinAnimation.springSnap.delay(Double(rank) * 0.12),
            value: cardVisible
        )
        .onAppear {
            cardVisible  = true
            starsVisible = true
        }
    }
}

// MARK: - Podium layout (top 3)

struct MetalPodium: View {
    let recommendations: [MetalRecommendation]

    var body: some View {
        VStack(spacing: EcrinSpacing.sm) {
            ForEach(Array(recommendations.prefix(3).enumerated()), id: \.element.id) { index, rec in
                MetalScoreCard(recommendation: rec, rank: index)
            }
        }
    }
}

#Preview {
    ZStack {
        EcrinColor.background.ignoresSafeArea()
        ScrollView {
            MetalPodium(recommendations: [
                MetalRecommendation(
                    id: "1", metal: "Or jaune 18k",
                    reason: "Le métal roi pour les teints chauds. Son éclat solaire prolonge naturellement votre carnation.",
                    score: 5, icon: "circle.fill"
                ),
                MetalRecommendation(
                    id: "2", metal: "Or rose",
                    reason: "La fusion parfaite entre chaleur cuivrée et raffinement.",
                    score: 4, icon: "heart.fill"
                ),
            ])
            .padding()
        }
    }
}
