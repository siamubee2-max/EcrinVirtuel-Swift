import SwiftUI

// MARK: - CreditsPackView — Recharge d'essais IA

struct CreditsPackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CreditsPackViewModel()

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Ambient glow
            Ellipse()
                .fill(EcrinColor.gold.opacity(0.06))
                .frame(width: 360, height: 240)
                .blur(radius: 80)
                .offset(y: -120)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Barre de navigation
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(L10n.Common.close)
                    Spacer()
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.xl) {

                        // MARK: Header + solde actuel
                        headerSection

                        // MARK: Packs
                        VStack(spacing: EcrinSpacing.md) {
                            ForEach(vm.packs) { pack in
                                PackCard(
                                    pack: pack,
                                    displayPrice: vm.displayPrice(for: pack),
                                    isSelected: vm.selectedPack?.id == pack.id
                                ) {
                                    withAnimation(EcrinAnimation.springSnap) {
                                        vm.selectedPack = pack
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.lg)

                        // MARK: Explication
                        reassuranceCard

                        // MARK: CTA
                        ctaSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, EcrinSpacing.md)
                }
            }

            // MARK: Overlay succès
            if vm.purchaseSuccess {
                PurchaseSuccessOverlay(count: vm.purchasedCount) {
                    dismiss()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .task { await vm.onAppear() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: EcrinSpacing.md) {
            // Icône animée
            ZStack {
                Circle()
                    .fill(EcrinColor.gold.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(EcrinColor.gold)
            }

            Text("Recharger mes essais")
                .font(EcrinFont.sectionHead)
                .foregroundStyle(EcrinColor.textPrimary)

            Text("Achetez des essais supplémentaires\nsans changer d'abonnement.")
                .font(EcrinFont.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(EcrinColor.textSecondary)
                .lineSpacing(4)

            // Solde actuel
            GlassCard(cornerRadius: 16) {
                HStack(spacing: EcrinSpacing.md) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 16))
                        .foregroundStyle(EcrinColor.gold)

                    if vm.isLoadingCredits {
                        ProgressView()
                            .tint(EcrinColor.gold)
                            .scaleEffect(0.8)
                    } else {
                        Text("Solde actuel : ")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)
                        +
                        Text("\(vm.currentCredits) essai\(vm.currentCredits != 1 ? "s" : "")")
                            .font(EcrinFont.caption).bold()
                            .foregroundStyle(EcrinColor.textPrimary)
                    }

                    Spacer()
                }
                .padding(.horizontal, EcrinSpacing.md)
                .padding(.vertical, EcrinSpacing.sm)
            }
            .padding(.horizontal, EcrinSpacing.lg)
        }
    }

    // MARK: - Reassurance

    private var reassuranceCard: some View {
        GlassCard(cornerRadius: 16) {
            VStack(spacing: EcrinSpacing.sm) {
                ReassuranceRow(icon: "checkmark.shield", text: "Les essais achetés n'expirent pas")
                ReassuranceRow(icon: "arrow.triangle.2.circlepath", text: "S'ajoutent à votre solde existant")
                ReassuranceRow(icon: "bolt.badge.checkmark", text: "Crédités instantanément après l'achat")
            }
            .padding(EcrinSpacing.md)
        }
        .padding(.horizontal, EcrinSpacing.lg)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: EcrinSpacing.sm) {
            if let error = vm.errorMessage {
                Text(error)
                    .font(EcrinFont.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EcrinSpacing.lg)
            }

            GoldButton(
                title: vm.isPurchasing ? "Achat en cours…"
                    : vm.selectedPack.map { "Acheter \($0.count) essais · \(vm.displayPrice(for: $0))" }
                    ?? "Choisir un pack"
            ) {
                Task { await vm.purchase() }
            }
            .disabled(vm.isPurchasing || vm.selectedPack == nil)
            .padding(.horizontal, EcrinSpacing.lg)

            Text("Achat unique · Non renouvelable · Géré par Apple")
                .font(.system(size: 10))
                .foregroundStyle(EcrinColor.textDecorative)

            HStack(spacing: 4) {
                Link("CGU", destination: URL(string: "https://inferencevision.store/ecrin/terms")!)
                Text("·").foregroundStyle(EcrinColor.textMuted)
                Link("Confidentialité", destination: URL(string: "https://inferencevision.store/ecrin/privacy")!)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(EcrinColor.gold.opacity(0.7))
            .padding(.top, 2)
        }
    }
}

// MARK: - PackCard

private struct PackCard: View {
    let pack: CreditsPack
    let displayPrice: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: EcrinSpacing.md) {
                // Icône
                ZStack {
                    Circle()
                        .fill(isSelected ? EcrinColor.gold.opacity(0.15) : EcrinColor.glassFill)
                        .frame(width: 48, height: 48)
                    Image(systemName: pack.icon)
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(isSelected ? EcrinColor.gold : EcrinColor.textSecondary)
                }

                // Infos
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(pack.label)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)

                        if let badge = pack.badge {
                            Text(badge)
                                .font(.system(size: 7, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(EcrinColor.background)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(EcrinColor.gold)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(pack.count) essais")
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textSecondary)

                        if let bonus = pack.bonus {
                            Text(bonus)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(EcrinColor.gold)
                        }
                    }
                }

                Spacer()

                // Prix + indicateur sélection
                VStack(alignment: .trailing, spacing: 3) {
                    Text(displayPrice)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(pack.perTrial)
                        .font(.system(size: 10))
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }
            .padding(EcrinSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? EcrinColor.gold.opacity(0.07) : EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                isSelected ? EcrinColor.gold : EcrinColor.glassStroke,
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
        .accessibilityLabel("\(pack.label), \(pack.count) essais, \(displayPrice)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Helpers

private struct ReassuranceRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: EcrinSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(EcrinColor.gold)
                .frame(width: 20)
            Text(text)
                .font(EcrinFont.caption)
                .foregroundStyle(EcrinColor.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Overlay succès avec sparkles

struct PurchaseSuccessOverlay: View {
    let count: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: EcrinSpacing.lg) {
                // Animation sparkles
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 14))
                            .foregroundStyle(EcrinColor.gold.opacity(Double.random(in: 0.4...1)))
                            .offset(
                                x: CGFloat.random(in: -60...60),
                                y: CGFloat.random(in: -60...60)
                            )
                    }

                    Circle()
                        .fill(EcrinColor.gold.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(EcrinColor.gold)
                }
                .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    Text("Recharge effectuée !")
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text("+\(count) essai\(count > 1 ? "s" : "") ajouté\(count > 1 ? "s" : "") à votre compte")
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                }

                GoldButton(title: "Commencer à essayer") {
                    onDismiss()
                }
                .padding(.horizontal, EcrinSpacing.xxl)
            }
            .padding(EcrinSpacing.xl)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(EcrinAnimation.springBounce) {
                scale = 1
                opacity = 1
            }
        }
    }
}
