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
