import SwiftUI
import UIKit

// MARK: - QuickTryOnResultView — Révélation, partage, nudge, paywall émotionnel

struct QuickTryOnResultView: View {
    let image: UIImage
    let modeName: String
    let onRetry: () -> Void
    let onClose: () -> Void
    var onNextJewelry: (() -> Void)? = nil
    var creditsRemaining: Int? = nil
    var nudgePicks: [JewelryItem] = []
    var onSelectNudgeJewelry: ((JewelryItem) -> Void)? = nil
    /// Photo d'origine — active le comparateur Avant/Après quand fournie.
    var beforeImage: UIImage? = nil

    @State private var appeared = false
    @State private var showParticles = true
    @State private var showBrandedShare = false
    @State private var showEmotionalPaywall = false
    @State private var saveFeedback: SaveFeedback = .idle
    @State private var showCompare = false

    private var shouldShowNudge: Bool {
        guard let credits = creditsRemaining else { return false }
        return credits > 0 && !nudgePicks.isEmpty
    }

    private var shouldShowPaywallOnClose: Bool {
        creditsRemaining == 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if showCompare, let before = beforeImage {
                    // Comparateur Avant/Après — glisser pour révéler la transformation
                    BeforeAfterSliderView(beforeLabel: "AVANT", afterLabel: "APRÈS") {
                        Image(uiImage: before).resizable().scaledToFill()
                    } afterContent: {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                }
            }
            .ignoresSafeArea()
            .scaleEffect(appeared ? 1 : 1.06)
            .opacity(appeared ? 1 : 0)

            if showParticles {
                WeddingParticlesCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(appeared ? 0.85 : 0)
            }

            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: shouldShowNudge ? 380 : 280)
                .ignoresSafeArea(edges: .bottom)
            }

            VStack {
                Spacer()

                VStack(spacing: EcrinSpacing.md) {
                    Text(modeName.uppercased())
                        .font(EcrinFont.label)
                        .kerning(3)
                        .foregroundStyle(EcrinColor.gold)

                    // Primaire — partage
                    GoldButton(title: "PARTAGER →") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showBrandedShare = true
                    }
                    .padding(.horizontal, EcrinSpacing.lg)

                    // Secondaires — sauvegarder + télécharger + comparateur
                    HStack(spacing: EcrinSpacing.md) {
                        SaveButton(feedback: saveFeedback) {
                            saveToPhotos()
                        }
                        ActionButton(icon: "arrow.down.to.line", label: "Télécharger") {
                            downloadBranded()
                        }
                        if beforeImage != nil {
                            ActionButton(
                                icon: showCompare ? "sparkles" : "arrow.left.arrow.right",
                                label: showCompare ? "Résultat" : "Avant/Après"
                            ) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(EcrinAnimation.springSnap) { showCompare.toggle() }
                            }
                        }
                    }

                    // Tertiaires
                    HStack(spacing: EcrinSpacing.lg) {
                        Button(action: onRetry) {
                            Text(L10n.Common.retry)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                        }
                        .buttonStyle(.plain)

                        if let onNextJewelry {
                            Button(action: onNextJewelry) {
                                HStack(spacing: 4) {
                                    Text("Bijou suivant")
                                    Text("→")
                                }
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if shouldShowNudge {
                        PostResultNudgeView(
                            creditsRemaining: creditsRemaining ?? 0,
                            picks: nudgePicks,
                            onSelect: { jewelry in
                                onSelectNudgeJewelry?(jewelry)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Button(action: handleClose) {
                        Text("FERMER")
                            .font(EcrinFont.cta)
                            .kerning(2.5)
                            .foregroundStyle(EcrinColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, EcrinSpacing.xl)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: handleClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(EcrinColor.textSecondary)
                            .padding(10)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, EcrinSpacing.lg)
                    .padding(.top, 60)
                }
                Spacer()
            }
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Haptic "wow" moment on result reveal
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.8)) { showParticles = false }
            }
            // Rendez-vous quotidien : on propose la notification « Look du jour »
            // UNE seule fois, au meilleur moment — juste après le premier résultat wow.
            let askedKey = "ecrin.notif.askedAfterFirstResult"
            if !UserDefaults.standard.bool(forKey: askedKey),
               !LookNotificationService.shared.userWantsNotification {
                UserDefaults.standard.set(true, forKey: askedKey)
                Task {
                    try? await Task.sleep(for: .seconds(2.5))  // laisser le wow s'installer
                    await LookNotificationService.shared.requestAndSchedule()
                }
            }
        }
        .sheet(isPresented: $showBrandedShare) {
            BrandedShareSheet(image: image, jewelryName: modeName)
        }
        .fullScreenCover(isPresented: $showEmotionalPaywall, onDismiss: onClose) {
            EmotionalPaywallView(generatedImages: SessionCreationsStore.images + [image])
        }
    }

    private func handleClose() {
        if shouldShowPaywallOnClose {
            showEmotionalPaywall = true
        } else {
            onClose()
        }
    }

    private func saveToPhotos() {
        saveFeedback = .saving
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation(EcrinAnimation.springSnap) {
            saveFeedback = .saved
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { saveFeedback = .idle }
        }
    }

    private func downloadBranded() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let branded = BrandedShareSheet.renderBranded(image: image, jewelryName: modeName)
        UIImageWriteToSavedPhotosAlbum(branded, nil, nil, nil)
        withAnimation(EcrinAnimation.springSnap) {
            saveFeedback = .saved
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { saveFeedback = .idle }
        }
    }

    enum SaveFeedback {
        case idle, saving, saved
    }
}

// MARK: - PostResultNudgeView

private struct PostResultNudgeView: View {
    let creditsRemaining: Int
    let picks: [JewelryItem]
    let onSelect: (JewelryItem) -> Void

    var body: some View {
        VStack(spacing: EcrinSpacing.sm) {
            HStack {
                Text("Encore un ?")
                    .font(EcrinFont.cardTitle)
                    .foregroundStyle(EcrinColor.textPrimary)
                Spacer()
                Text("\(creditsRemaining) crédit\(creditsRemaining > 1 ? "s" : "")")
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.gold)
            }

            HStack(spacing: EcrinSpacing.sm) {
                ForEach(picks) { jewelry in
                    Button {
                        onSelect(jewelry)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: jewelry.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(EcrinColor.gold)
                            Text(jewelry.name)
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EcrinSpacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(EcrinColor.glassFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(EcrinColor.glassStroke, lineWidth: 0.5)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(EcrinSpacing.md)
        .padding(.horizontal, EcrinSpacing.lg)
    }
}

// MARK: - ActionButton

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 52, height: 52)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(EcrinColor.textPrimary)
                }
                Text(label)
                    .font(EcrinFont.caption)
                    .foregroundStyle(EcrinColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SaveButton

private struct SaveButton: View {
    let feedback: QuickTryOnResultView.SaveFeedback
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            feedback == .saved
                                ? EcrinColor.gold.opacity(0.25)
                                : Color.white.opacity(0.12)
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().strokeBorder(
                                feedback == .saved ? EcrinColor.gold : Color.white.opacity(0.15),
                                lineWidth: feedback == .saved ? 1 : 0.5
                            )
                        )

                    Image(systemName: feedback == .saved ? "checkmark" : "heart")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(
                            feedback == .saved ? EcrinColor.gold : EcrinColor.textPrimary
                        )
                }
                Text(feedback == .saved ? "Sauvegardé" : "Sauvegarder")
                    .font(EcrinFont.caption)
                    .foregroundStyle(
                        feedback == .saved ? EcrinColor.gold : EcrinColor.textSecondary
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: feedback == .saved)
        .disabled(feedback == .saving || feedback == .saved)
    }
}
