import SwiftUI
import RevenueCat

// MARK: - Error Types

enum PaywallError: LocalizedError {
    case productNotFound(String)
    case entitlementNotActivated

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id): return "Produit introuvable : \(id)"
        case .entitlementNotActivated: return "L'achat n'a pas pu être activé. Essayez 'Restaurer mes achats'."
        }
    }
}

// MARK: - Plan Period

enum PlanPeriod: String, CaseIterable {
    case monthly  = "Mensuel"
    case yearly   = "Annuel"
    case lifetime = "À vie"
}

// MARK: - Product Identifiers (RevenueCat / App Store Connect)

enum PaywallProductID {
    // ── Abonnements mensuels ──────────────────────────────────────────
    static let starterMonthly   = "ecrin_starter_monthly"
    static let premiumMonthly   = "ecrin_premium_monthly"
    static let eliteMonthly     = "ecrin_elite_monthly"

    // ── Abonnements annuels ───────────────────────────────────────────
    static let starterYearly    = "ecrin_starter_yearly"
    static let premiumYearly    = "ecrin_premium_yearly"
    static let eliteYearly      = "ecrin_elite_yearly"

    // ── Accès à vie ───────────────────────────────────────────────────
    static let founderLifetime  = "ecrin_founder_lifetime"
}

// MARK: - Models

struct PaywallPlan: Identifiable {
    let id: String
    let name: String
    let price: String        // fallback — remplacé par localizedPriceString en runtime
    let period: String
    let priceDescription: String
    let savings: String
    let isBestValue: Bool
    let rcIdentifier: String
    let planPeriod: PlanPeriod

    /// Traduit le plan RevenueCat en SubscriptionStatus de l'app.
    var resolvedSubscriptionStatus: SubscriptionStatus {
        let id = rcIdentifier.lowercased()
        if id.contains("elite")   { return .elite }
        if id.contains("premium") { return .premium }
        if id.contains("starter") { return .starter }
        return .free
    }
}

struct PaywallFeature: Identifiable {
    let id = UUID()
    let text: String

    static let all: [PaywallFeature] = [
        PaywallFeature(text: "Essayage IA bijoux, piercings & vêtements"),
        PaywallFeature(text: "Styliste IA personnalisé"),
        PaywallFeature(text: "Dressing virtuel illimité"),
        PaywallFeature(text: "Partage communauté & défis"),
        PaywallFeature(text: "Accès boutiques partenaires"),
        PaywallFeature(text: "Support prioritaire"),
    ]
}

// MARK: - ViewModel

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var purchaseError: String?
    @Published var selectedPlan: PaywallPlan?
    @Published var isPurchasing = false
    @Published var selectedPeriod: PlanPeriod = .monthly
    @Published var liveProducts: [String: StoreProduct] = [:]
    /// Plan acheté avec succès — observé par PaywallView pour mettre à jour AppState.
    @Published var purchasedPlan: PaywallPlan?

    // MARK: All Plans (7 plans complets)

    private let allPlans: [PaywallPlan] = [
        // ── Mensuels ──────────────────────────────────────────────────
        PaywallPlan(
            id: "elite_monthly",
            name: "Elite",
            price: "24,99€",
            period: "/ mois",
            priceDescription: "100 crédits inclus/mois",
            savings: "Le meilleur volume",
            isBestValue: false,
            rcIdentifier: PaywallProductID.eliteMonthly,
            planPeriod: .monthly
        ),
        PaywallPlan(
            id: "premium_monthly",
            name: "Premium",
            price: "12,99€",
            period: "/ mois",
            priceDescription: "40 crédits inclus/mois",
            savings: "Le meilleur rapport qualité/prix",
            isBestValue: true,
            rcIdentifier: PaywallProductID.premiumMonthly,
            planPeriod: .monthly
        ),
        PaywallPlan(
            id: "starter_monthly",
            name: "Starter",
            price: "6,99€",
            period: "/ mois",
            priceDescription: "15 crédits inclus/mois",
            savings: "Parfait pour découvrir",
            isBestValue: false,
            rcIdentifier: PaywallProductID.starterMonthly,
            planPeriod: .monthly
        ),
        // ── Annuels (–35% vs mensuel) ──────────────────────────────────
        PaywallPlan(
            id: "elite_yearly",
            name: "Elite",
            price: "194,99€",
            period: "/ an",
            priceDescription: "100 crédits/mois · 16,25€/mois",
            savings: "Économisez 35% vs mensuel",
            isBestValue: false,
            rcIdentifier: PaywallProductID.eliteYearly,
            planPeriod: .yearly
        ),
        PaywallPlan(
            id: "premium_yearly",
            name: "Premium",
            price: "99,99€",
            period: "/ an",
            priceDescription: "40 crédits/mois · 8,33€/mois",
            savings: "Économisez 35% vs mensuel",
            isBestValue: true,
            rcIdentifier: PaywallProductID.premiumYearly,
            planPeriod: .yearly
        ),
        PaywallPlan(
            id: "starter_yearly",
            name: "Starter",
            price: "54,99€",
            period: "/ an",
            priceDescription: "15 crédits/mois · 4,58€/mois",
            savings: "Économisez 35% vs mensuel",
            isBestValue: false,
            rcIdentifier: PaywallProductID.starterYearly,
            planPeriod: .yearly
        ),
        // ── À vie ─────────────────────────────────────────────────────
        PaywallPlan(
            id: "founder_lifetime",
            name: "Fondateur",
            price: "349,99€",
            period: "une fois",
            priceDescription: "100 crédits/mois · À vie",
            savings: "Accès permanent · Plus jamais de frais",
            isBestValue: false,
            rcIdentifier: PaywallProductID.founderLifetime,
            planPeriod: .lifetime
        ),
    ]

    // MARK: Computed

    var currentPlans: [PaywallPlan] {
        allPlans.filter { $0.planPeriod == selectedPeriod }
    }

    var ctaTitle: String {
        guard let plan = selectedPlan else { return "Choisir un plan" }
        return isPurchasing ? "En cours…" : "Commencer avec \(plan.name)"
    }

    // MARK: Init

    init() {
        selectedPlan = allPlans.first { $0.id == "premium_monthly" }
        Task { await loadLiveProducts() }
    }

    // MARK: Display Price (dynamique via RC, fallback statique)

    func displayPrice(for plan: PaywallPlan) -> String {
        liveProducts[plan.rcIdentifier]?.localizedPriceString ?? plan.price
    }

    // MARK: Purchase

    func purchase(dismiss: @escaping () -> Void) async {
        guard let plan = selectedPlan else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let product = try await fetchProduct(plan)
            let result = try await Purchases.shared.purchase(product: product)
            if result.customerInfo.entitlements["premium"]?.isActive == true {
                _ = try? await SupabaseService.shared.creditGenerations(
                    productId: plan.rcIdentifier,
                    transactionId: result.transaction?.transactionIdentifier ?? UUID().uuidString
                )
                purchasedPlan = plan          // ← notifie la vue
                await CreditsManager.shared.sync() // ← rafraîchit le compteur
                dismiss()
            } else {
                MonitoringService.shared.recordEntitlementMismatch(productId: plan.rcIdentifier)
                purchaseError = PaywallError.entitlementNotActivated.errorDescription
            }
        } catch {
            let nsError = error as NSError
            // Code 2 = annulation utilisateur — silencieux
            if !(nsError.domain == "SKErrorDomain" && nsError.code == 2) {
                MonitoringService.shared.recordPurchaseError(error, productId: plan.rcIdentifier)
                purchaseError = "Achat impossible : \(error.localizedDescription)"
            }
        }
    }

    // MARK: Restore

    func restore() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements["premium"]?.isActive != true {
                purchaseError = "Aucun achat trouvé à restaurer."
            }
        } catch {
            MonitoringService.shared.recordRestoreError(error)
            purchaseError = "Restauration impossible : \(error.localizedDescription)"
        }
    }

    // MARK: Private

    private func loadLiveProducts() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            let packages = offerings.current?.availablePackages ?? []
            var map: [String: StoreProduct] = [:]
            for pkg in packages {
                map[pkg.storeProduct.productIdentifier] = pkg.storeProduct
            }
            liveProducts = map
        } catch {
            // Fallback silencieux — les prix statiques seront utilisés
        }
    }

    private func fetchProduct(_ plan: PaywallPlan) async throws -> StoreProduct {
        // 1. Cache en mémoire
        if let cached = liveProducts[plan.rcIdentifier] {
            return cached
        }
        // 2. Rechargement depuis RC
        let offerings = try await Purchases.shared.offerings()
        guard let product = offerings.current?.availablePackages
            .first(where: { $0.storeProduct.productIdentifier == plan.rcIdentifier })?
            .storeProduct
        else {
            throw PaywallError.productNotFound(plan.rcIdentifier)
        }
        return product
    }
}

// MARK: - PaywallView

struct PaywallView: View {
    @Environment(\.dismiss)   private var dismiss
    @Environment(AppState.self) private var appState
    @StateObject private var viewModel = PaywallViewModel()

    var body: some View {
        ZStack {
            EcrinColor.background.ignoresSafeArea()

            // Gold ambient
            Ellipse()
                .fill(EcrinColor.gold.opacity(0.07))
                .frame(width: 300, height: 200)
                .blur(radius: 60)
                .offset(y: -200)

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(EcrinColor.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(L10n.Common.close)
                }
                .padding(.horizontal, EcrinSpacing.lg)
                .padding(.top, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EcrinSpacing.xl) {
                        // Header
                        VStack(spacing: EcrinSpacing.md) {
                            Text("✦")
                                .font(.system(size: 32))
                                .foregroundStyle(EcrinColor.gold)

                            Text("L'Écrin\nPremium")
                                .font(EcrinFont.heroTitle)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(EcrinColor.textPrimary)

                            Text("Essayage illimité · Styliste IA · Dressing premium")
                                .font(EcrinFont.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(EcrinColor.textSecondary)
                                .kerning(0.5)
                        }
                        .padding(.top, EcrinSpacing.lg)

                        // Period selector
                        Picker("Période", selection: $viewModel.selectedPeriod) {
                            ForEach(PlanPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, EcrinSpacing.lg)
                        .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                            // Sélectionner automatiquement le plan Best Value de la nouvelle période
                            let plans = viewModel.currentPlans
                            if let best = plans.first(where: { $0.isBestValue }) {
                                viewModel.selectedPlan = best
                            } else {
                                viewModel.selectedPlan = plans.first
                            }
                        }

                        // Plans
                        VStack(spacing: EcrinSpacing.md) {
                            ForEach(viewModel.currentPlans) { plan in
                                PlanCard(
                                    plan: plan,
                                    displayPrice: viewModel.displayPrice(for: plan),
                                    isSelected: viewModel.selectedPlan?.id == plan.id,
                                    onSelect: { viewModel.selectedPlan = plan }
                                )
                            }
                        }
                        .padding(.horizontal, EcrinSpacing.lg)

                        // Value proposition
                        GlassCard {
                            VStack(spacing: EcrinSpacing.md) {
                                ForEach(PaywallFeature.all) { feature in
                                    HStack(spacing: EcrinSpacing.md) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(EcrinColor.gold)
                                            .frame(width: 20)

                                        Text(feature.text)
                                            .font(EcrinFont.body)
                                            .foregroundStyle(EcrinColor.textSecondary)

                                        Spacer()
                                    }
                                }
                            }
                            .padding(EcrinSpacing.lg)
                        }
                        .padding(.horizontal, EcrinSpacing.lg)

                        // CTA
                        VStack(spacing: EcrinSpacing.md) {
                            if let error = viewModel.purchaseError {
                                Text(error)
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(.red.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, EcrinSpacing.sm)
                            }

                            GoldButton(title: viewModel.ctaTitle) {
                                Task { await viewModel.purchase(dismiss: { dismiss() }) }
                            }
                            .disabled(viewModel.isPurchasing)

                            Button("Restaurer mes achats") {
                                Task { await viewModel.restore() }
                            }
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                        }
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xxl)
                    }
                }
            }
        }
        // Mettre à jour AppState dès qu'un achat est confirmé
        .onChange(of: viewModel.purchasedPlan?.id) { _, _ in
            guard let plan = viewModel.purchasedPlan else { return }
            appState.subscription = plan.resolvedSubscriptionStatus
            CreditsManager.shared.handleSubscriptionUpgrade(to: appState.subscription)
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: PaywallPlan
    let displayPrice: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(EcrinFont.cardTitle)
                            .foregroundStyle(EcrinColor.textPrimary)

                        if plan.isBestValue {
                            Text("MEILLEURE OFFRE")
                                .font(.system(size: 8, weight: .semibold))
                                .kerning(1.5)
                                .foregroundStyle(EcrinColor.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(EcrinColor.gold)
                                .clipShape(Capsule())
                        }
                    }
                    Text(plan.priceDescription)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                    Text(plan.savings)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(EcrinColor.gold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayPrice)
                        .font(EcrinFont.sectionHead)
                        .foregroundStyle(EcrinColor.textPrimary)
                    Text(plan.period)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textMuted)
                }
            }
            .padding(EcrinSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? EcrinColor.gold.opacity(0.08) : EcrinColor.glassFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? EcrinColor.gold : EcrinColor.glassStroke, lineWidth: isSelected ? 1.5 : 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .animation(EcrinAnimation.springSnap, value: isSelected)
    }
}
