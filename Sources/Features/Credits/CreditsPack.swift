import Foundation

// MARK: - Packs de recharge d'essais (consommables IAP)

// Le `count` de chaque pack DOIT rester égal au nombre annoncé par le produit
// App Store Connect (10 / 30 / 70 / 150) : c'est ce libellé que l'acheteur lit
// sur la feuille de confirmation Apple. Les anciens « +5 / +20 offerts » —
// affichés 75 et 170 dans l'app — contredisaient ASC (motif de rejet).
struct CreditsPack: Identifiable {
    let id: String          // = rcProductIdentifier
    let label: String
    let count: Int
    let price: String       // affiché en UI (mis à jour depuis StoreKit)
    let referencePrice: Double  // en EUR — repli quand StoreKit est muet
    let badge: String?      // ex: "MEILLEURE VALEUR"
    let icon: String        // SF Symbol

    // Coût par crédit — REPLI uniquement, quand StoreKit n'a pas répondu.
    // Le symbole était codé en dur : sur un store non européen l'utilisateur
    // lisait un prix en dollars et un ratio en euros sur la même ligne.
    // Le chemin normal passe par `CreditsPackViewModel.perCredit(for:)`, qui
    // dérive le ratio du prix réel et de sa devise.
    var perTrialFallback: String {
        let raw = referencePrice / Double(count)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"          // devise des prix de référence ci-dessous
        f.maximumFractionDigits = 2
        let amount = f.string(from: NSNumber(value: raw)) ?? String(format: "%.2f", raw)
        return "\(amount)/crédit"
    }

    static let all: [CreditsPack] = [
        CreditsPack(
            id: "ecrin_credits_spark",
            label: "Spark",
            count: 10,
            price: "2,99€",
            referencePrice: 2.99,
            badge: nil,
            icon: "sparkle"
        ),
        CreditsPack(
            id: "ecrin_credits_glow",
            label: "Glow",
            count: 30,
            price: "7,99€",
            referencePrice: 7.99,
            badge: "MEILLEURE VALEUR",
            icon: "sparkles"
        ),
        CreditsPack(
            id: "ecrin_credits_eclat",
            label: "Éclat",
            count: 70,
            price: "16,99€",
            referencePrice: 16.99,
            badge: nil,
            icon: "star.fill"
        ),
        CreditsPack(
            id: "ecrin_credits_diamant",
            label: "Diamant",
            count: 150,
            price: "29,99€",
            referencePrice: 29.99,
            badge: nil,
            icon: "crown.fill"
        ),
    ]
}
