import Foundation

// MARK: - Packs de recharge d'essais (consommables IAP)

struct CreditsPack: Identifiable {
    let id: String          // = rcProductIdentifier
    let label: String
    let count: Int
    let price: String       // affiché en UI (mis à jour depuis StoreKit)
    let priceUSD: Double    // valeur de référence interne
    let bonus: String?      // ex: "+5 offerts" — label d'affichage uniquement
    let bonusCount: Int     // crédits bonus réels crédités (0 si pas de bonus)
    let badge: String?      // ex: "MEILLEURE VALEUR"
    let icon: String        // SF Symbol

    // Coût par crédit affiché
    var perTrial: String {
        let raw = priceUSD / Double(count)
        return String(format: "%.2f€/crédit", raw)
    }

    static let all: [CreditsPack] = [
        CreditsPack(
            id: "ecrin_credits_spark",
            label: "Spark",
            count: 10,
            price: "2,99€",
            priceUSD: 2.99,
            bonus: nil,
            bonusCount: 0,
            badge: nil,
            icon: "sparkle"
        ),
        CreditsPack(
            id: "ecrin_credits_glow",
            label: "Glow",
            count: 30,
            price: "7,99€",
            priceUSD: 7.99,
            bonus: nil,
            bonusCount: 0,
            badge: "MEILLEURE VALEUR",
            icon: "sparkles"
        ),
        CreditsPack(
            id: "ecrin_credits_eclat",
            label: "Éclat",
            count: 70,
            price: "16,99€",
            priceUSD: 16.99,
            bonus: "+5 offerts",
            bonusCount: 5,
            badge: nil,
            icon: "star.fill"
        ),
        CreditsPack(
            id: "ecrin_credits_diamant",
            label: "Diamant",
            count: 150,
            price: "29,99€",
            priceUSD: 29.99,
            bonus: "+20 offerts",
            bonusCount: 20,
            badge: nil,
            icon: "crown.fill"
        ),
    ]
}
