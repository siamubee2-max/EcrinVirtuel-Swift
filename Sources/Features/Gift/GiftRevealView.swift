import SwiftUI

// MARK: - Gift Reveal View
/// Displayed when the recipient opens a gift deeplink
struct GiftRevealView: View {
    let giftID: UUID
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GiftViewModel()
    @State private var showTryOn = false
    @State private var particlesVisible = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            EcrinColor.background.ignoresSafeArea()

            if let gift = viewModel.revealedGift {
                // Revealed state
                RevealedGiftContent(
                    gift: gift,
                    isBoxOpen: viewModel.isBoxOpen,
                    onOpenBox: { viewModel.openBox() },
                    onTryOn: { showTryOn = true },
                    onBuy: { /* open boutique URL */ }
                )
                .transition(.opacity)
            } else if let error = viewModel.errorMessage {
                // Error state — sans cette branche, un cadeau expiré ou une
                // erreur réseau laissait le spinner « Ouverture… » à l'infini.
                GiftErrorView(message: error) { dismiss() }
            } else {
                // Loading state
                GiftLoadingView()
            }

            // Fermeture — la vue est présentée en fullScreenCover.
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EcrinColor.textMuted)
                    .padding(12)
                    .background(Circle().fill(EcrinColor.glassStroke.opacity(0.3)))
            }
            .padding(.top, EcrinSpacing.lg)
            .padding(.trailing, EcrinSpacing.lg)
            .accessibilityLabel(L10n.Common.close)
        }
        .task { await viewModel.receive(giftID: giftID) }
        .sheet(isPresented: $showTryOn) {
            if let gift = viewModel.revealedGift {
                // Pré-sélectionner le bijou offert — TryOnView() nu ignorait
                // complètement le cadeau.
                QuickTryOnView(
                    preselectedItem: .wardrobe(gift.jewelryItem.asFashionItem),
                    preselectedMode: .jewelsOnly
                )
                .environment(appState)
                .environment(ClothingCatalogService.shared)
                .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Error
private struct GiftErrorView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: EcrinSpacing.lg) {
            Image(systemName: "gift")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(EcrinColor.textMuted)
            Text(message)
                .font(EcrinFont.body)
                .foregroundStyle(EcrinColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, EcrinSpacing.xl)
            GhostButton(title: L10n.Common.close) { onClose() }
                .padding(.horizontal, EcrinSpacing.xxl)
        }
    }
}

// MARK: - Loading
private struct GiftLoadingView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: EcrinSpacing.lg) {
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.05))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.2 : 1)
                    .animation(.easeInOut(duration: 1.5).repeatForever(), value: pulse)

                Image(systemName: "gift.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(EcrinColor.gold)
            }
            Text(L10n.GiftUI.openingGift)
                .font(EcrinFont.serif(20, weight: .light))
                .foregroundStyle(EcrinColor.textSecondary)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Revealed Content
private struct RevealedGiftContent: View {
    let gift: GiftCard
    let isBoxOpen: Bool
    let onOpenBox: () -> Void
    let onTryOn: () -> Void
    let onBuy: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 40

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Box animation zone
                GiftBoxAnimation(isOpen: isBoxOpen, jewelry: gift.jewelryItem)
                    .frame(height: 280)
                    .padding(.top, EcrinSpacing.xl)

                if !isBoxOpen {
                    // Pre-open state
                    VStack(spacing: EcrinSpacing.lg) {
                        Text(L10n.GiftUI.giftAwaitsYou)
                            .font(EcrinFont.sectionHead)
                            .foregroundStyle(EcrinColor.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("De la part de \(gift.fromUser.displayName ?? "quelqu'un de spécial")")
                            .font(EcrinFont.body)
                            .foregroundStyle(EcrinColor.textSecondary)

                        GoldButton(title: L10n.GiftUI.openGift) { onOpenBox() }
                    }
                    .padding(.top, EcrinSpacing.xl)
                    .padding(.horizontal, EcrinSpacing.lg)
                    .transition(.opacity)
                } else {
                    // Revealed content
                    VStack(spacing: EcrinSpacing.xl) {
                        // Jewelry detail
                        VStack(spacing: EcrinSpacing.md) {
                            Text(gift.occasionType.displayLabel)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                                .kerning(2)
                                .textCase(.uppercase)

                            Text(gift.jewelryItem.name)
                                .font(EcrinFont.heroTitle)
                                .foregroundStyle(EcrinColor.ivory)

                            Text(gift.jewelryItem.material)
                                .font(EcrinFont.label)
                                .foregroundStyle(EcrinColor.gold.opacity(0.8))
                                .kerning(2)
                                .textCase(.uppercase)
                        }
                        .multilineTextAlignment(.center)

                        // Try-on image if available
                        if let imageData = gift.tryOnImageData,
                           let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(EcrinColor.gold.opacity(0.2), lineWidth: 1)
                                }
                                .padding(.horizontal, EcrinSpacing.lg)
                        }

                        // Message
                        MessageBubble(
                            message: gift.message,
                            senderName: gift.fromUser.displayName ?? "Expéditeur"
                        )
                        .padding(.horizontal, EcrinSpacing.lg)

                        // CTAs
                        VStack(spacing: EcrinSpacing.md) {
                            GoldButton(title: L10n.GiftUI.tryOnMe) { onTryOn() }

                            GhostButton(title: L10n.GiftUI.buyItNow) { onBuy() }
                        }
                        .padding(.bottom, EcrinSpacing.xxl)
                    }
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                            contentOpacity = 1
                            contentOffset = 0
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }
}

// MARK: - Gift Box Animation
private struct GiftBoxAnimation: View {
    let isOpen: Bool
    let jewelry: JewelryItem

    @State private var lidOffset: CGFloat = 0
    @State private var lidOpacity: Double = 1
    @State private var jewelryScale: CGFloat = 0.3
    @State private var jewelryOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0

    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [EcrinColor.gold.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(isOpen ? 1 : 0)
                .animation(EcrinAnimation.springBounce.delay(0.3), value: isOpen)

            if !isOpen {
                // Gift box closed
                VStack(spacing: 0) {
                    // Lid
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [EcrinColor.gold, Color(hex: "#92600A")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 120, height: 34)
                        .overlay {
                            // Ribbon on lid
                            Rectangle()
                                .fill(Color(hex: "#1A0E00").opacity(0.4))
                                .frame(width: 16, height: 34)
                        }
                        .offset(y: lidOffset)
                        .opacity(lidOpacity)

                    // Box body
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#B8760A"), Color(hex: "#7A4F07")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 90)
                        .overlay {
                            Rectangle()
                                .fill(Color(hex: "#1A0E00").opacity(0.4))
                                .frame(width: 16, height: 90)
                        }
                }
                .shadow(color: EcrinColor.gold.opacity(0.3), radius: 20, x: 0, y: 10)
                .transition(.opacity.combined(with: .scale))
            } else {
                // Jewelry revealed
                VStack(spacing: EcrinSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(EcrinColor.gold.opacity(0.1))
                            .frame(width: 140, height: 140)
                        Circle()
                            .strokeBorder(EcrinColor.gold.opacity(0.3), lineWidth: 1)
                            .frame(width: 140, height: 140)

                        Image(systemName: jewelry.icon)
                            .font(.system(size: 58, weight: .thin))
                            .foregroundStyle(EcrinColor.gold)
                    }
                    .scaleEffect(jewelryScale)
                    .opacity(jewelryOpacity)
                    .shadow(color: EcrinColor.gold.opacity(0.5), radius: glowRadius, x: 0, y: 0)
                }
                .onAppear {
                    withAnimation(EcrinAnimation.springBounce) {
                        jewelryScale = 1
                        jewelryOpacity = 1
                        glowRadius = 30
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: isOpen) { _, open in
            if open {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    lidOffset = -60
                    lidOpacity = 0
                }
            }
        }
    }
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: String
    let senderName: String

    var body: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: EcrinSpacing.md) {
                HStack {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(EcrinColor.gold.opacity(0.5))
                    Spacer()
                }

                Text(message)
                    .font(EcrinFont.serif(18, weight: .light))
                    .italic()
                    .foregroundStyle(EcrinColor.ivory)
                    .lineSpacing(6)

                HStack {
                    Spacer()
                    Text("— \(senderName)")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.gold)
                        .kerning(1)
                }
            }
            .padding(EcrinSpacing.lg)
        }
    }
}
