import Foundation
import OSLog
import RevenueCat

// MARK: - RevenueCatService
// Point unique pour le câblage RevenueCat :
//  - identité : logIn/logOut alignés sur le compte Supabase — le webhook
//    revenuecat-webhook ne peut attribuer un événement à un utilisateur que
//    si l'app_user_id RevenueCat est l'UUID Supabase ; sans logIn, les
//    entitlements restaient scoppés au device (2e compte héritant de
//    l'abonnement du 1er, nouvel iPhone vu comme free).
//  - résolution de tier : déduite du productIdentifier qui a activé un
//    entitlement — robuste quel que soit le découpage côté Dashboard RC
//    (un entitlement unique "premium" ou un par tier), là où l'achat et le
//    launch utilisaient deux conventions incompatibles.

enum RevenueCatService {

    private static let logger = Logger(subsystem: "com.ecrin.jewelry", category: "revenuecat")

    // MARK: - Identité

    static func logIn(userId: String) async {
        do {
            _ = try await Purchases.shared.logIn(userId)
        } catch {
            logger.error("RC logIn failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func logOut() async {
        // logOut() throw si l'utilisateur RC est déjà anonyme — sans gravité.
        _ = try? await Purchases.shared.logOut()
    }

    // MARK: - Résolution de tier

    /// Tier le plus élevé parmi les entitlements actifs, déduit des ids produit.
    static func resolveStatus(from info: CustomerInfo) -> SubscriptionStatus {
        let productIds = info.entitlements.all.values
            .filter(\.isActive)
            .map { $0.productIdentifier.lowercased() }

        func matches(_ needle: String) -> Bool {
            productIds.contains { $0.contains(needle) }
        }

        if matches("elite") || matches("founder") || matches("lifetime") { return .elite }
        if matches("premium") { return .premium }
        if matches("starter") { return .starter }
        return .free
    }
}

// MARK: - Chargement des produits

extension RevenueCatService {

    /// Charge les `StoreProduct` correspondant aux identifiants demandés.
    ///
    /// La cascade est volontairement tolérante : un écran d'achat ne doit JAMAIS
    /// dépendre de la seule offering « current » du dashboard RevenueCat. Quand
    /// elle n'est pas configurée — ou ne contient qu'une partie des produits —
    /// `offerings.current` est vide et le paywall n'affichait plus aucun prix
    /// réel, tout achat échouant ensuite en `productNotFound`.
    ///   1. offering courante ;
    ///   2. toutes les offerings (produits rangés dans une offering non courante) ;
    ///   3. StoreKit en direct via `Purchases.products(_:)` — indépendant des
    ///      offerings, c'est le chemin qui fait déjà fonctionner les packs de crédits.
    ///
    /// - Returns: les produits trouvés, indexés par `productIdentifier`. Le
    ///   dictionnaire ne contient que des identifiants demandés, et peut être
    ///   partiel (ou vide) — l'appelant décide quoi afficher.
    static func loadProducts(identifiers: [String]) async -> [String: StoreProduct] {
        guard !identifiers.isEmpty else { return [:] }
        var map: [String: StoreProduct] = [:]
        let wanted = Set(identifiers)

        func collect(_ packages: [Package]) {
            for package in packages {
                let id = package.storeProduct.productIdentifier
                guard wanted.contains(id), map[id] == nil else { continue }
                map[id] = package.storeProduct
            }
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            collect(offerings.current?.availablePackages ?? [])
            if map.count < wanted.count {
                for offering in offerings.all.values {
                    collect(offering.availablePackages)
                }
            }
        } catch {
            // Non bloquant : l'étape StoreKit ci-dessous reste disponible.
            logger.error("RC offerings failed: \(error.localizedDescription, privacy: .public)")
        }

        let missing = identifiers.filter { map[$0] == nil }
        guard !missing.isEmpty else { return map }

        logger.warning("RC offerings incomplete — StoreKit fallback for \(missing.joined(separator: ", "), privacy: .public)")
        for product in await Purchases.shared.products(missing) {
            map[product.productIdentifier] = product
        }

        let stillMissing = identifiers.filter { map[$0] == nil }
        if !stillMissing.isEmpty {
            logger.error("Products unavailable: \(stillMissing.joined(separator: ", "), privacy: .public)")
        }
        return map
    }
}
