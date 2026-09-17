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
    /// Repli affiché tant que le produit StoreKit n'est pas chargé. Ne contient
    /// AUCUN montant : les montants sont dérivés du prix réel par
    /// `displayDescription(for:)`.
    let priceDescription: String
    /// Repli pour les formules mensuelles et à vie. Pour l'annuel, l'économie
    /// est calculée par `displaySavings(for:)` — jamais annoncée en dur.
    let savings: String
    let isBestValue: Bool
    let rcIdentifier: String
    let planPeriod: PlanPeriod
    /// Crédits accordés chaque mois par ce plan — source unique des libellés.
    let creditsPerMonth: Int
    /// Pour une formule annuelle : identifiant du mensuel du MÊME palier,
    /// nécessaire au calcul de l'économie réelle. `nil` ailleurs.
    let monthlyCounterpart: String?

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

    // MARK: Formules proposées

    /// Deux formules, mensuelles uniquement.
    ///
    /// Elles s'insèrent dans UNE seule échelle avec les packs de crédits,
    /// triée par montant débité, où le prix au crédit décroît strictement :
    ///
    ///   2,99 €  Spark (pack)         10 cr  -> 0,299 €/cr
    ///   6,99 €  Essentiel            25 cr  -> 0,280 €/cr
    ///  10,99 €  Éclat (pack)         40 cr  -> 0,275 €/cr
    ///  14,99 €  Signature            60 cr  -> 0,250 €/cr
    ///  29,99 €  Diamant (pack)      140 cr  -> 0,214 €/cr
    ///
    /// Ce qui a été RETIRÉ, et pourquoi :
    /// - Elite mensuel (100 cr, 29,99 €) était strictement dominé par le pack
    ///   Diamant : même prix, moins de crédits, et un engagement en plus.
    /// - Starter mensuel (15 cr, 4,99 €) affichait 0,333 €/cr, le PIRE prix du
    ///   catalogue : s'abonner coûtait plus cher que ne pas s'abonner.
    /// - Les formules annuelles attendent : demander 120 € d'avance à quelqu'un
    ///   qui ne peut lire aucun avis, c'est se refuser soi-même. Elles
    ///   reviendront en montée en gamme après quelques mois d'usage réel.
    /// - Fondateur (100 cr/mois à vie, 349,99 €) : point mort à 106 mois nets
    ///   d'Apple. Retiré tant qu'il n'a aucun acheteur — au premier, il devient
    ///   une dette perpétuelle irréversible.
    ///
    /// Aucun badge « meilleure offre ». Signature bat Essentiel au crédit
    /// (0,250 contre 0,280) mais pas le pack Diamant (0,214) : toute mention
    /// de « meilleure » serait fausse quelque part, et c'est exactement le
    /// défaut qui a fait retirer la version précédente.
    // Non privé : le test qui verrouille la monotonie de l'échelle doit
    // pouvoir lire les formules réelles, pas une copie qui dériverait.
    let allPlans: [PaywallPlan] = [
        PaywallPlan(
            id: "essentiel_monthly",
            name: "Essentiel",
            price: "6,99€",
            period: "/ mois",
            priceDescription: "25 crédits inclus/mois",
            savings: "Pour essayer régulièrement",
            isBestValue: false,
            rcIdentifier: PaywallProductID.starterMonthly,
            planPeriod: .monthly,
            creditsPerMonth: 25,
            monthlyCounterpart: nil
        ),
        PaywallPlan(
            id: "signature_monthly",
            name: "Signature",
            price: "14,99€",
            period: "/ mois",
            priceDescription: "60 crédits inclus/mois",
            savings: "Deux essayages par jour",
            isBestValue: false,
            rcIdentifier: PaywallProductID.premiumMonthly,
            planPeriod: .monthly,
            creditsPerMonth: 60,
            monthlyCounterpart: nil
        ),
    ]

    // MARK: Computed

    var currentPlans: [PaywallPlan] {
        allPlans.filter { $0.planPeriod == selectedPeriod }
    }

    /// Périodes qui portent au moins une formule. Dérivée des formules et non
    /// de `PlanPeriod.allCases` : un segment « Annuel » qui n'ouvre sur aucune
    /// carte est un cul-de-sac, et l'annuel n'est pas proposé au lancement.
    var availablePeriods: [PlanPeriod] {
        PlanPeriod.allCases.filter { period in
            allPlans.contains { $0.planPeriod == period }
        }
    }

    var ctaTitle: String {
        guard let plan = selectedPlan else { return "Choisir un plan" }
        return isPurchasing ? L10n.PaywallUI.inProgress : "Commencer avec \(plan.name)"
    }

    // MARK: Init

    init() {
        // Entrée de gamme présélectionnée : sans aucun avis à lire, la
        // question « est-ce que ça vaut 7 € » est la seule qu'un inconnu
        // accepte de trancher.
        selectedPlan = allPlans.first { $0.id == "essentiel_monthly" } ?? allPlans.first
    }

    /// Identifiants de tous les produits affichés par le paywall.
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

    /// Sous-titre du plan. Le montant mensualisé d'une formule annuelle est
    /// DÉRIVÉ du prix réel : il était figé dans `priceDescription`, si bien que
    /// Premium annuel annonçait « 8,33€/mois » sous un prix de 79,99 € (soit
    /// 6,67 €) dès que le prix App Store s'écartait du repli codé en dur.
    func displayDescription(for plan: PaywallPlan) -> String {
        guard plan.planPeriod == .yearly,
              let product = liveProducts[plan.rcIdentifier],
              let perMonth = Self.money((product.price as NSDecimalNumber).doubleValue / 12, like: product)
        else { return plan.priceDescription }
        return "\(plan.creditsPerMonth) crédits/mois · \(perMonth)/mois"
    }

    /// Économie annoncée, CALCULÉE contre le mensuel du même palier.
    /// « Économisez 35% » s'affichait à l'identique sur les trois formules
    /// annuelles alors que l'économie réelle va de 8 % à 46 % — une allégation
    /// commerciale fausse, et un motif de rejet App Store 2.3.7.
    /// Sans les deux prix réels, on n'annonce AUCUN chiffre.
    func displaySavings(for plan: PaywallPlan) -> String {
        guard plan.planPeriod == .yearly,
              let counterpart = plan.monthlyCounterpart,
              let yearly  = liveProducts[plan.rcIdentifier]?.price,
              let monthly = liveProducts[counterpart]?.price
        else { return plan.savings }

        let full = (monthly as NSDecimalNumber).doubleValue * 12
        let paid = (yearly as NSDecimalNumber).doubleValue
        guard full > 0 else { return plan.savings }

        let pct = Int(((full - paid) / full * 100).rounded())
        // Un annuel plus cher que douze mensualités ne se vante pas.
        guard pct > 0 else { return plan.savings }
        return "Économisez \(pct)% vs mensuel"
    }

    /// Formate un montant dans la devise et la locale du produit StoreKit,
    /// pour ne jamais mêler un montant à un symbole d'une autre devise.
    private static func money(_ amount: Double, like product: StoreProduct) -> String? {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = product.priceFormatter?.locale ?? .current
        if let code = product.currencyCode { f.currencyCode = code }
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: amount))
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

                        // Sélecteur de période — masqué tant qu'une seule
                        // période porte des formules.
                        if viewModel.availablePeriods.count > 1 {
                            Picker("Période", selection: $viewModel.selectedPeriod) {
                                ForEach(viewModel.availablePeriods, id: \.self) { period in
                                    Text(period.rawValue).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, EcrinSpacing.lg)
                            .onChange(of: viewModel.selectedPeriod) { _, _ in
                                let plans = viewModel.currentPlans
                                viewModel.selectedPlan = plans.first(where: { $0.isBestValue }) ?? plans.first
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
                                    displayDescription: viewModel.displayDescription(for: plan),
                                    displaySavings: viewModel.displaySavings(for: plan),
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
    /// Calculés par le view-model à partir des prix RÉELS — ne jamais lire
    /// `plan.priceDescription` ni `plan.savings` ici : ce sont des replis.
    let displayDescription: String
    let displaySavings: String
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
                    Text(displayDescription)
                        .font(EcrinFont.caption)
                        .foregroundStyle(EcrinColor.textSecondary)
                    if !displaySavings.isEmpty {
                        Text(displaySavings)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EcrinColor.gold)
                    }
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
