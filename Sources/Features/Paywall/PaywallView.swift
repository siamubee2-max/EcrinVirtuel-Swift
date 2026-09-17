import SwiftUI
import RevenueCat

// MARK: - Error Types

enum PaywallError: LocalizedError {
    case productNotFound(String)
    case entitlementNotActivated
    case creditGrantFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id): return "Produit introuvable : \(id)"
        case .entitlementNotActivated: return "L'achat n'a pas pu être activé. Essayez 'Restaurer mes achats'."
        case .creditGrantFailed: return "Votre achat a bien été validé, mais vos crédits n'ont pas encore été ajoutés. Ils arrivent sous peu — utilisez 'Restaurer mes achats' si le solde ne se met pas à jour."
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
    /// Chargement des produits en cours — le CTA reste désactivé tant qu'il tourne.
    @Published var isLoadingProducts = false
    /// Aucun produit n'a pu être chargé : la vue affiche l'avertissement + « Réessayer »
    /// au lieu de laisser croire que les prix statiques sont achetables.
    @Published var productsUnavailable = false
    /// Plan acheté avec succès — observé par PaywallView pour mettre à jour AppState.
    @Published var purchasedPlan: PaywallPlan?
    /// Statut restauré avec succès — observé par PaywallView (même mécanique).
    @Published var restoredStatus: SubscriptionStatus?

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
    }

    /// Identifiants des 7 produits affichés par le paywall.
    private var allProductIds: [String] { allPlans.map(\.rcIdentifier) }

    /// Tâche de chargement en cours — évite qu'un `.task` rejoué (réouverture de
    /// la feuille, changement de période) empile plusieurs appels RevenueCat.
    private var loadTask: Task<Void, Never>?

    /// Point d'entrée appelé par la vue. Le chargement était auparavant lancé
    /// depuis `init()` : au lancement, `Purchases.configure` venait tout juste
    /// d'être appelé et l'appel partait avant que la config RevenueCat ne soit
    /// redescendue — le paywall restait alors sans aucun produit jusqu'au
    /// relaunch, sans trace ni possibilité de réessayer.
    func loadProductsIfNeeded() async {
        // Skip live product loading in UI-test mode — RC is not configured,
        // and Purchases.shared.offerings() would fatalError. Static fallback
        // prices in PaywallPlan are used instead (the paywall UI is fully assertable).
        guard !AppLaunchEnvironment.isUITesting else { return }
        guard liveProducts.count < allProductIds.count else { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await loadLiveProducts() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Relance explicite depuis le bouton « Réessayer ».
    func retryLoadingProducts() async {
        productsUnavailable = false
        await loadProductsIfNeeded()
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
            // RevenueCat 5.x ne throw pas sur l'annulation utilisateur — sans ce check,
            // annuler affichait « L'achat n'a pas pu être activé » + un faux mismatch.
            if result.userCancelled { return }
            // Résolution par productIdentifier — même convention que le launch et le
            // customerInfoStream, quel que soit le découpage des entitlements RC.
            if RevenueCatService.resolveStatus(from: result.customerInfo) != .free {
                // L'identifiant de transaction DOIT venir d'Apple : le serveur le
                // confronte à RevenueCat — un identifiant fabriqué (UUID local) ne
                // serait jamais vérifiable, donc achat payé sans crédits accordés.
                guard let txnId = result.transaction?.transactionIdentifier else {
                    MonitoringService.shared.recordCreditGrantFailure(
                        nil, productId: plan.rcIdentifier, transactionId: nil
                    )
                    purchaseError = PaywallError.creditGrantFailed.errorDescription
                    return
                }

                do {
                    _ = try await SupabaseService.shared.creditGenerations(
                        productId: plan.rcIdentifier,
                        transactionId: txnId
                    )
                } catch {
                    // L'achat Apple a abouti mais l'octroi a échoué : ne PAS fermer en
                    // silence. L'entitlement reste actif ; seuls les crédits manquent
                    // (le webhook revenuecat-webhook reste le filet serveur).
                    MonitoringService.shared.recordCreditGrantFailure(
                        error, productId: plan.rcIdentifier, transactionId: txnId
                    )
                    await CreditsManager.shared.sync()
                    purchaseError = PaywallError.creditGrantFailed.errorDescription
                    return
                }

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

    func restore(dismiss: @escaping () -> Void) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
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

    private func loadLiveProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        let ids = allProductIds
        // Trois tentatives espacées : au démarrage, la config RevenueCat ou le
        // réseau peuvent n'arriver qu'après le premier appel. Une seule tentative
        // laissait le paywall vide pour toute la session.
        for attempt in 0..<3 {
            let products = await RevenueCatService.loadProducts(identifiers: ids)
            if !products.isEmpty {
                // Fusion : un rechargement partiel ne doit pas effacer ce qui
                // avait déjà été récupéré.
                liveProducts.merge(products) { _, new in new }
            }
            if liveProducts.count == ids.count { break }
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))
            }
        }

        productsUnavailable = liveProducts.isEmpty
        if productsUnavailable {
            // L'échec était auparavant avalé par un `catch` vide : plus aucune
            // trace côté monitoring alors que l'écran d'achat était inutilisable.
            MonitoringService.shared.recordProductsUnavailable(identifiers: ids)
        }
    }

    private func fetchProduct(_ plan: PaywallPlan) async throws -> StoreProduct {
        // 1. Cache en mémoire
        if let cached = liveProducts[plan.rcIdentifier] {
            return cached
        }
        // 2. Rechargement via la même cascade que l'affichage. La version
        //    précédente n'interrogeait que `offerings.current` : un produit rangé
        //    hors de l'offering courante était déclaré introuvable alors qu'il
        //    était parfaitement achetable.
        let refreshed = await RevenueCatService.loadProducts(identifiers: [plan.rcIdentifier])
        liveProducts.merge(refreshed) { _, new in new }
        guard let product = liveProducts[plan.rcIdentifier] else {
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

                        // Produits indisponibles : le paywall affichait jusqu'ici
                        // ses prix statiques sans rien dire, et l'achat échouait
                        // ensuite sur un « Produit introuvable » incompréhensible.
                        if viewModel.productsUnavailable {
                            VStack(spacing: EcrinSpacing.sm) {
                                Text("Les offres n'ont pas pu être chargées depuis l'App Store. Vérifiez votre connexion.")
                                    .font(EcrinFont.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(EcrinColor.textSecondary)

                                Button("Réessayer") {
                                    Task { await viewModel.retryLoadingProducts() }
                                }
                                .font(EcrinFont.caption)
                                .foregroundStyle(EcrinColor.gold)
                                .accessibilityIdentifier("paywall.retryProducts")
                            }
                            .padding(.horizontal, EcrinSpacing.lg)
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
                            .disabled(viewModel.isPurchasing || viewModel.isLoadingProducts)
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
        // Charger les produits à l'ouverture de la feuille — et non depuis
        // l'init du view model, qui courait avant la config RevenueCat.
        .task { await viewModel.loadProductsIfNeeded() }
        // Mettre à jour AppState dès qu'un achat est confirmé
        .onChange(of: viewModel.purchasedPlan?.id) { _, _ in
            guard let plan = viewModel.purchasedPlan else { return }
            appState.subscription = plan.resolvedSubscriptionStatus
            CreditsManager.shared.handleSubscriptionUpgrade(to: appState.subscription)
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
