import SwiftUI
import RevenueCat

// MARK: - Error Types

enum PaywallError: LocalizedError {
    case productNotFound(String)
    // `entitlementNotActivated` supprimé : un achat encaissé ne doit jamais
    // produire de message d'erreur — voir `activationPending`.

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id): return "Produit introuvable : \(id)"
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
    static let starterMonthly   = "ecrin.starter.monthly"
    static let premiumMonthly   = "ecrin.premium.month"   // ecrin.premium.monthly locked by legacy app
    static let eliteMonthly     = "ecrin.elite.monthly"

    // ── Abonnements annuels ───────────────────────────────────────────
    static let starterYearly    = "ecrin.starter.yearly"
    static let premiumYearly    = "ecrin.premium.year"    // ecrin.premium.yearly locked by legacy app
    static let eliteYearly      = "ecrin.elite.yearly"

    // ── Accès à vie ───────────────────────────────────────────────────
    static let founderLifetime  = "ecrin.founder.lifetime"
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
        // Plan Fondateur à vie : accès maximal — sans ce mapping, l'acheteur
        // du lifetime retombait en .free avec 3 crédits.
        if id.contains("founder") || id.contains("lifetime") { return .elite }
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
    /// Statut résolu après un achat abouti — observé par PaywallView pour mettre à jour AppState.
    @Published var purchasedStatus: SubscriptionStatus?
    /// Statut restauré avec succès — observé par PaywallView (même mécanique).
    @Published var restoredStatus: SubscriptionStatus?
    /// Achat encaissé mais entitlement/crédits pas encore visibles : message
    /// NEUTRE d'attente, jamais une erreur (motif de refus 2.1(b)).
    @Published var activationPending = false
    /// Aucune session Supabase : la vue présente GenerationSignInSheet et
    /// relance l'achat une fois la connexion obtenue.
    @Published var needsSignIn = false

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
        return isPurchasing ? L10n.PaywallUI.inProgress : "Commencer avec \(plan.name)"
    }

    // MARK: Init

    init() {
        selectedPlan = allPlans.first { $0.id == "premium_monthly" }
        // Skip live product loading in UI-test mode — RC is not configured,
        // and Purchases.shared.offerings() would fatalError. Static fallback
        // prices in PaywallPlan are used instead (the paywall UI is fully assertable).
        if !AppLaunchEnvironment.isUITesting {
            Task { await loadLiveProducts() }
        }
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
        activationPending = false
        defer { isPurchasing = false }

        // Identité EXIGÉE avant de lancer le paiement. Sans session Supabase,
        // l'app_user_id RevenueCat reste `$RCAnonymousID:…` et le webhook ignore
        // l'événement : abonnement encaissé, jamais attribué. Le résultat de cette
        // garde n'est plus ignorable — on ne descend pas dans le `do` sans identité.
        guard await GenerationAuthGate.requirePurchaseIdentity() else {
            needsSignIn = true
            return
        }

        do {
            let product = try await fetchProduct(plan)
            // Référence FRAÎCHE avant paiement (voir CreditsPackViewModel).
            await CreditsManager.shared.sync()
            let baseline = CreditsManager.shared.remaining
            let result = try await Purchases.shared.purchase(product: product)
            // RevenueCat 5.x ne throw pas sur l'annulation utilisateur — sans ce check,
            // annuler affichait « L'achat n'a pas pu être activé » + un faux mismatch.
            if result.userCancelled { return }

            // ─ À partir d'ici Apple a encaissé : plus AUCUN message d'erreur. ─
            // Résolution par productIdentifier — même convention que le launch et le
            // customerInfoStream, quel que soit le découpage des entitlements RC.
            let status = await resolvedStatusAllowingPropagation(from: result.customerInfo)

            // Les crédits d'abonnement sont accordés par `revenuecat-webhook`
            // (INITIAL_PURCHASE / RENEWAL, barème starter 15 / premium 40 / elite 100).
            // L'app n'appelle pas `credit-generations` pour un abonnement : cette
            // fonction est réservée aux packs consommables.
            let credited = await CreditsManager.shared.syncUntilIncrease(above: baseline)

            if status != .free {
                purchasedStatus = status      // ← notifie la vue (AppState)
                dismiss()
            } else {
                // L'entitlement RevenueCat n'est toujours pas actif : on n'invente
                // pas de succès (aucun statut appliqué) et on n'affiche pas d'échec.
                MonitoringService.shared.recordEntitlementMismatch(productId: plan.rcIdentifier)
                activationPending = true
            }
            if !credited && status != .free {
                MonitoringService.shared.recordCreditGrantFailure(
                    nil, productId: plan.rcIdentifier, transactionId: result.transaction?.transactionIdentifier
                )
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

    func restore(dismiss: @escaping () -> Void) async {
        isPurchasing = true
        purchaseError = nil
        activationPending = false
        defer { isPurchasing = false }
        // Restaurer sans session rattacherait les achats à un id anonyme —
        // même exigence que l'achat.
        guard await GenerationAuthGate.requirePurchaseIdentity() else {
            needsSignIn = true
            return
        }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let status = RevenueCatService.resolveStatus(from: info)
            if status == .free {
                purchaseError = "Aucun achat trouvé à restaurer."
            } else {
                // Observé par la vue : applique le statut à AppState, resynchronise
                // les crédits et ferme le paywall — avant, une restauration réussie
                // ne produisait aucun effet visible jusqu'au relaunch.
                restoredStatus = status
                dismiss()
            }
        } catch {
            MonitoringService.shared.recordRestoreError(error)
            purchaseError = "Restauration impossible : \(error.localizedDescription)"
        }
    }

    // MARK: Private

    /// Statut RevenueCat, en tolérant le délai de propagation de l'entitlement.
    ///
    /// Le `CustomerInfo` renvoyé par `purchase` peut précéder l'activation
    /// côté RevenueCat. On relit donc le cache serveur quelques fois avant de
    /// conclure — sans cette tolérance, un achat encaissé finissait sur
    /// « L'achat n'a pas pu être activé » (motif 2.1(b) du 5 mai).
    private func resolvedStatusAllowingPropagation(
        from info: CustomerInfo,
        attempts: Int = 3
    ) async -> SubscriptionStatus {
        var status = RevenueCatService.resolveStatus(from: info)
        var remaining = attempts
        while status == .free && remaining > 0 {
            remaining -= 1
            try? await Task.sleep(for: .seconds(2))
            guard let fresh = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent) else { continue }
            status = RevenueCatService.resolveStatus(from: fresh)
        }
        return status
    }

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
            // paywall.root accessibility anchor — stable even when RC offerings are empty

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
                    .accessibilityIdentifier("paywall.close")
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

                            Text(L10n.PaywallUI.ecrinPremiumTitle)
                                .font(EcrinFont.heroTitle)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(EcrinColor.textPrimary)

                            Text(L10n.PaywallUI.premiumFeaturesLine)
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

                            // Achat encaissé, activation encore en attente : ton
                            // neutre (or), jamais rouge — ce n'est pas un échec.
                            if viewModel.activationPending {
                                Text("Achat confirmé. L'activation peut prendre quelques instants — vos crédits apparaîtront automatiquement.")
                                    .font(EcrinFont.caption)
                                    .foregroundStyle(EcrinColor.gold)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, EcrinSpacing.sm)
                                    .accessibilityIdentifier("paywall.activationPending")
                            }

                            GoldButton(title: viewModel.ctaTitle) {
                                Task { await viewModel.purchase(dismiss: { dismiss() }) }
                            }
                            .disabled(viewModel.isPurchasing)
                            .accessibilityIdentifier("paywall.cta")

                            Button(L10n.PaywallUI.restorePurchases) {
                                Task { await viewModel.restore(dismiss: { dismiss() }) }
                            }
                            .font(EcrinFont.caption)
                            .foregroundStyle(EcrinColor.textMuted)
                            .accessibilityIdentifier("paywall.restore")

                            // Mentions abonnement + liens légaux (App Store 3.1.2)
                            VStack(spacing: 6) {
                                Text("Abonnement à renouvellement automatique. Le paiement est débité sur votre compte Apple. L'abonnement se renouvelle sauf annulation au moins 24 h avant la fin de la période. Gérez-le dans vos réglages App Store.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(EcrinColor.textMuted.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 4) {
                                    Link("CGU", destination: URL(string: "https://inferencevision.store/ecrin/terms")!)
                                    Text("·").foregroundStyle(EcrinColor.textMuted)
                                    Link("Confidentialité", destination: URL(string: "https://inferencevision.store/ecrin/privacy")!)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(EcrinColor.gold.opacity(0.7))
                            }
                            .padding(.top, EcrinSpacing.sm)
                        }
                        .padding(.horizontal, EcrinSpacing.lg)
                        .padding(.bottom, EcrinSpacing.xxl)
                    }
                }
            }
        }
        .accessibilityIdentifier("paywall.root")
        // Connexion exigée avant paiement : on présente la feuille puis on
        // relance l'achat une fois la session ouverte.
        .sheet(isPresented: $viewModel.needsSignIn) {
            GenerationSignInSheet {
                Task { await viewModel.purchase(dismiss: { dismiss() }) }
            }
        }
        // Mettre à jour AppState dès qu'un achat est confirmé.
        // Le solde n'est PLUS écrit ici : `syncUntilIncrease` (dans le
        // ViewModel) a déjà posé la valeur serveur. L'ancienne affectation
        // locale courait contre ce sync et affichait « 15 » puis « 3 ».
        .onChange(of: viewModel.purchasedStatus) { _, status in
            guard let status else { return }
            appState.subscription = status
        }
        // Appliquer une restauration réussie (statut + crédits) puis fermer
        .onChange(of: viewModel.restoredStatus) { _, status in
            guard let status else { return }
            appState.subscription = status
            CreditsManager.shared.syncDetached()
            dismiss()
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
                            Text(L10n.PaywallUI.bestOffer)
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
