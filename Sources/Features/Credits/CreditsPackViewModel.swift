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
    var purchasedCount = 0
    var errorMessage: String?
    var isLoadingCredits = false

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
            currentCredits = 0
        }
        isLoadingCredits = false
    }

    // MARK: - Produits StoreKit via RevenueCat

    private func loadStoreProducts() async {
        let ids = CreditsPack.all.map { $0.id }
        let products = await Purchases.shared.products(ids)
        for product in products {
            storeProducts[product.productIdentifier] = product
        }
        for (i, pack) in packs.enumerated() {
            if let sp = storeProducts[pack.id] {
                packs[i] = CreditsPack(
                    id: pack.id,
                    label: pack.label,
                    count: pack.count,
                    price: sp.localizedPriceString,
                    priceUSD: pack.priceUSD,
                    bonus: pack.bonus,
                    bonusCount: pack.bonusCount,
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
            errorMessage = "Produit indisponible. Vérifiez votre connexion."
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(product: storeProduct)

            // Récupérer l'ID de transaction Apple pour l'idempotence
            guard let transactionId = result.transaction?.transactionIdentifier else {
                errorMessage = "Achat incomplet. Contactez le support."
                return
            }

            // Créditer côté serveur via Edge Function
            let newTotal = try await SupabaseService.shared.creditGenerations(
                productId: pack.id,
                transactionId: transactionId
            )

            currentCredits = newTotal
            purchasedCount = pack.count + pack.bonusCount

            // Refresh the single source of truth so the generation paywall
            // reads the updated balance immediately (Bug C8).
            await CreditsManager.shared.sync()

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
}
