import SwiftUI
import RevenueCat

// MARK: - CreditsPackViewModel

@Observable
@MainActor
final class CreditsPackViewModel {

    var packs: [CreditsPack] = CreditsPack.all
    var storeProducts: [String: StoreProduct] = [:]
    var currentCredits: Int = 0
    var selectedPack: CreditsPack? = CreditsPack.all[1]  // Glow par défaut (30 crédits)
    var isPurchasing = false
    var purchaseSuccess = false
    /// Crédits RÉELLEMENT constatés côté serveur après l'achat (0 = octroi
    /// encore en attente). Jamais le total annoncé du pack : afficher
    /// « +75 crédits » pendant que le solde ne bouge pas est un mensonge.
    var purchasedCount = 0
    var errorMessage: String?
    var isLoadingCredits = false
    /// Aucune session Supabase : la vue présente GenerationSignInSheet puis
    /// relance l'achat. Aucun paiement n'est lancé sans identité.
    var needsSignIn = false

    // MARK: - Lifecycle

    func onAppear() async {
        await fetchCurrentCredits()
        await loadStoreProducts()
    }

    // MARK: - Crédits actuels depuis Supabase

    func fetchCurrentCredits() async {
        isLoadingCredits = true
        do {
            currentCredits = try await SupabaseService.shared.fetchRemainingCredits()
        } catch {
            // Pas de session (ou fetch échoué) : solde local plutôt qu'un faux "0"
            // incohérent avec le badge "restants" de l'écran Essayage.
            await CreditsManager.shared.sync()
            currentCredits = CreditsManager.shared.remaining
        }
        isLoadingCredits = false
    }

    // MARK: - Produits StoreKit via RevenueCat

    private func loadStoreProducts() async {
        let ids = CreditsPack.all.map { $0.id }
        // Même cascade que le paywall abonnements, et même raison : au lancement
        // le premier appel peut partir avant que RevenueCat ne soit prêt, et
        // l'écran restait alors sur ses prix statiques, tout achat répondant
        // « produit indisponible ».
        for attempt in 0..<3 {
            let products = await RevenueCatService.loadProducts(identifiers: ids)
            storeProducts.merge(products) { _, new in new }
            if storeProducts.count == ids.count { break }
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))
            }
        }
        if storeProducts.isEmpty {
            MonitoringService.shared.recordProductsUnavailable(identifiers: ids)
        }
        for (i, pack) in packs.enumerated() {
            if let sp = storeProducts[pack.id] {
                packs[i] = CreditsPack(
                    id: pack.id,
                    label: pack.label,
                    count: pack.count,
                    price: sp.localizedPriceString,
                    referencePrice: pack.referencePrice,
                    badge: pack.badge,
                    icon: pack.icon
                )
            }
        }
    }

    // MARK: - Achat

    func purchase() async {
        guard let pack = selectedPack else { return }
        guard let storeProduct = storeProducts[pack.id] else {
            errorMessage = L10n.CreditsUI.productUnavailable
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        // Identité EXIGÉE : sans session, `credit-generations` répond 401 et le
        // webhook ignore l'événement (`non_uuid_app_user_id`). Le résultat de la
        // garde n'est plus ignorable — pas d'achat sans identité.
        guard await GenerationAuthGate.requirePurchaseIdentity() else {
            needsSignIn = true
            return
        }

        do {
            // Référence FRAÎCHE avant paiement : `remaining` peut être obsolète
            // (jamais synchronisé), et un baseline trop bas ferait passer le
            // solde préexistant pour des crédits fraîchement achetés.
            await CreditsManager.shared.sync()
            let baseline = CreditsManager.shared.remaining
            let result = try await Purchases.shared.purchase(product: storeProduct)

            // RevenueCat 5.x ne throw pas sur l'annulation utilisateur — il la signale ici.
            if result.userCancelled { return }

            // À partir d'ici Apple a validé l'achat : l'écran affiche TOUJOURS le succès.
            // Un octroi qui échoue (RevenueCat pas encore synchronisé, réseau, 402/503)
            // est journalisé et rattrapé par `revenuecat-webhook` puis par la resync du
            // solde — jamais présenté comme un achat raté (refus App Review 2.1(b)).
            let transactionId = result.transaction?.transactionIdentifier
            if let transactionId {
                do {
                    _ = try await SupabaseService.shared.creditGenerations(
                        productId: pack.id,
                        transactionId: transactionId
                    )
                } catch {
                    MonitoringService.shared.recordCreditGrantFailure(
                        error, productId: pack.id, transactionId: transactionId
                    )
                }
            } else {
                MonitoringService.shared.recordCreditGrantFailure(
                    nil, productId: pack.id, transactionId: nil
                )
            }

            // Solde serveur = source de vérité unique, y compris pour le NOMBRE
            // affiché : on annonce l'augmentation constatée, pas celle promise.
            // Sans octroi constaté, l'overlay bascule sur « attribution en cours »
            // (purchasedCount == 0) au lieu d'afficher un « +75 » imaginaire.
            let credited = await CreditsManager.shared.syncUntilIncrease(above: baseline)
            currentCredits = CreditsManager.shared.remaining
            purchasedCount = credited ? max(0, currentCredits - baseline) : 0
            if !credited {
                MonitoringService.shared.recordCreditGrantFailure(
                    nil, productId: pack.id, transactionId: transactionId
                )
            }

            withAnimation(EcrinAnimation.springBounce) {
                purchaseSuccess = true
            }

        } catch {
            let err = error as NSError
            if err.domain == "SKErrorDomain" && err.code == 2 {
                return // Annulation utilisateur — silencieux
            }
            errorMessage = "Achat impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - Prix affiché

    func displayPrice(for pack: CreditsPack) -> String {
        storeProducts[pack.id]?.localizedPriceString ?? pack.price
    }

    /// Coût par crédit, dérivé du prix RÉEL et de SA devise.
    /// Sans produit StoreKit, on retombe sur le repli en euros du catalogue —
    /// jamais sur un montant d'une devise mêlé au symbole d'une autre.
    func perCredit(for pack: CreditsPack) -> String {
        guard let sp = storeProducts[pack.id], pack.count > 0 else {
            return pack.perTrialFallback
        }
        let unit = (sp.price as NSDecimalNumber).doubleValue / Double(pack.count)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = sp.priceFormatter?.locale ?? .current
        if let code = sp.currencyCode { f.currencyCode = code }
        f.maximumFractionDigits = 2
        let amount = f.string(from: NSNumber(value: unit)) ?? String(format: "%.2f", unit)
        return "\(amount)/crédit"
    }
}
