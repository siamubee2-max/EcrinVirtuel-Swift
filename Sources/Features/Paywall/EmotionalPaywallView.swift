import SwiftUI

// MARK: - EmotionalPaywallView
// Presented from result screen (0 credits).
// Shows an emotional header with user's generated images + 2 plan previews,
// then delegates to the full PaywallView for purchase.

struct EmotionalPaywallView: View {
    let generatedImages: [UIImage]

    @Environment(\.dismiss) private var dismiss
    @State private var showFullPaywall = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────────
            EcrinColor.background.ignoresSafeArea()

            RadialGradient(
                colors: [EcrinColor.gold.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: EcrinSpacing.lg) {
                    // ── Close button ────────────────────────────────────
                    closeButton

                    // ── Emotional header ────────────────────────────────
                    emotionalHeader

                    // ── Images strip ────────────────────────────────────
                    imagesStrip

                    // ── Social proof ────────────────────────────────────
                    socialProof

                    // ── Plan cards ──────────────────────────────────────
                    planCards

                    // ── Primary CTA ─────────────────────────────────────
                    // Pas de mention d'essai gratuit : aucune intro offer n'existe
                    // dans le flow d'achat (risque App Review 2.3.1 sinon).
                    GoldButton(title: L10n.PaywallUI.continueMyTryOns) {
                        showFullPaywall = true
                    }
                    .padding(.horizontal, EcrinSpacing.xl)
                    .padding(.top, EcrinSpacing.sm)

                    // ── Footer ──────────────────────────────────────────
                    footer
                        .padding(.bottom, EcrinSpacing.xl)
                }
                .padding(.top, EcrinSpacing.sm)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(EcrinAnimation.glassReveal) { appeared = true }
        }
        .sheet(isPresented: $showFullPaywall) {
            PaywallView()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Close button

    @ViewBuilder
    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(EcrinColor.textSecondary)
                    .padding(10)
                    .background(EcrinColor.glassFill, in: Circle())
                    .overlay(Circle().strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, EcrinSpacing.lg)
        }
    }

    // MARK: - Emotional header

    @ViewBuilder
    private var emotionalHeader: some View {
        VStack(spacing: EcrinSpacing.sm) {
            Text(L10n.PaywallUI.yourCreations)
                .font(EcrinFont.label)
                .kerning(2)
                .foregroundStyle(EcrinColor.gold)

            VStack(spacing: 0) {
                Text(L10n.PaywallUI.youFoundYourStyle)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.PaywallUI.continueTheStory)
                    .font(EcrinFont.sectionHead)
                    .foregroundStyle(EcrinColor.gold)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, EcrinSpacing.xl)
    }

    // MARK: - Images strip

    @ViewBuilder
    private var imagesStrip: some View {
        let displayImages = Array(generatedImages.prefix(2))
        let needsPlaceholder = generatedImages.count < 3

        HStack(spacing: EcrinSpacing.sm) {
            ForEach(0..<displayImages.count, id: \.self) { index in
                Image(uiImage: displayImages[index])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(EcrinColor.gold.opacity(0.4), lineWidth: 1)
                    )
            }

            if needsPlaceholder {
                // Placeholder "+∞" card
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(EcrinColor.glassFill)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                EcrinColor.gold.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                    )
                    .overlay(
                        VStack(spacing: 2) {
                            Text("∞")
                                .font(EcrinFont.serif(24, weight: .light))
                                .foregroundStyle(EcrinColor.gold)
                            Text(L10n.PaywallUI.unlimited)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textMuted)
                        }
                    )
            }
        }
        .padding(.horizontal, EcrinSpacing.xl)
    }

    // MARK: - Social proof

    @ViewBuilder
    private var socialProof: some View {
        HStack(spacing: EcrinSpacing.sm) {
            // Avatars superposés
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(avatarColor(for: index))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                        .overlay(Circle().strokeBorder(EcrinColor.background, lineWidth: 1.5))
                        .offset(x: CGFloat(index) * 16)
                }
            }
            .frame(width: 28 + 16 * 2)

            Text(L10n.PaywallUI.socialProof)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, EcrinSpacing.xl)
    }

    private func avatarColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#8B5CF6"),
            Color(hex: "#EC4899"),
            Color(hex: "#F59E0B")
        ]
        return colors[index % colors.count]
    }

    // MARK: - Plan cards
    // Quotas depuis SubscriptionStatus (aligné serveur : 25/60) ; prix = les
    // MÊMES fallbacks que PaywallView.allPlans (6,99 / 14,99). Cet écran et le
    // paywall complet appartiennent au même tunnel d'achat : deux chiffres
    // différents à trois secondes d'écart, c'est la famille de défaut qui a
    // fait retirer la version (« Économisez 35 % », « Essayages illimités »).

    @ViewBuilder
    private var planCards: some View {
        VStack(spacing: EcrinSpacing.sm) {
            // Essentiel — glass background
            PlanRow(
                name: "Essentiel",
                description: "\(SubscriptionStatus.starter.monthlyGenerations) crédits/mois",
                price: "6,99€",
                isPopular: false
            )

            // Signature — gold border + badge
            PlanRow(
                name: "Signature",
                description: "\(SubscriptionStatus.premium.monthlyGenerations) crédits/mois",
                price: "14,99€",
                isPopular: true
            )
        }
        .padding(.horizontal, EcrinSpacing.xl)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        Button(action: { showFullPaywall = true }) {
            Text(L10n.PaywallUI.seeAllPlansRestore)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, EcrinSpacing.xl)
    }
}

// MARK: - PlanRow

private struct PlanRow: View {
    let name: String
    let description: String
    let price: String
    let isPopular: Bool

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            // Left: name + description
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: EcrinSpacing.sm) {
                    Text(name)
                        .font(isPopular ? EcrinFont.cardTitle : EcrinFont.body)
                        .foregroundStyle(EcrinColor.textPrimary)

                    if isPopular {
                        Text(L10n.PaywallUI.popular)
                            .font(EcrinFont.label)
                            .kerning(1)
                            .foregroundStyle(EcrinColor.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(EcrinColor.gold, in: Capsule())
                    }
                }

                Text(description)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textMuted)
            }

            Spacer()

            // Right: price
            Text(price)
                .font(isPopular ? EcrinFont.cardTitle : EcrinFont.body)
                .foregroundStyle(isPopular ? EcrinColor.gold : EcrinColor.textPrimary)
        }
        .padding(.horizontal, EcrinSpacing.md)
        .padding(.vertical, isPopular ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(EcrinColor.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isPopular ? EcrinColor.gold.opacity(0.5) : EcrinColor.glassStroke,
                    lineWidth: isPopular ? 1 : 0.5
                )
        )
    }
}
