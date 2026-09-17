import Foundation

// MARK: - Packs de recharge d'essais (consommables IAP)

// Le `count` de chaque pack DOIT rester égal au nombre annoncé par le produit
// App Store Connect : c'est ce libellé que l'acheteur lit sur la feuille de
// confirmation Apple, et le serveur (`credit-generations`, VALID_PACKS) qui
// fait foi crédite EXACTEMENT ce nombre — jamais un bonus implicite (motif
// de rejet : les anciens « +5 / +20 offerts » affichaient 75 et 170 dans
// l'app pour des fiches ASC qui en annonçaient 70 et 150).
//
// ⚠️ Grille du 31/08/2026 (Spark 10 / Éclat 40 / Diamant 140, Glow retiré) —
// alignée avec `supabase/functions/credit-generations/index.ts` ET avec
// `EcrinVirtuel.storekit` (sandbox local). PAS ENCORE répercutée sur les
// fiches produit App Store Connect elles-mêmes : au 17/09/2026, ASC annonce
// toujours Éclat à 70 crédits/9,99 $ et Diamant à 150 crédits/24,99 $ (Glow
// encore en vente à 6,99 $/30 crédits). Tant que ASC n'est pas corrigée, un
// acheteur y lit un nombre que le serveur ne créditera pas — à corriger côté
// dashboard ASC (prix + texte des fiches) avant toute nouvelle soumission.
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

    /// Trois packs, rangés sur la MÊME échelle que les abonnements : le prix
    /// au crédit décroît strictement quand le montant débité augmente.
    ///
    ///   2,99 €  Spark    10 cr  -> 0,299 €/cr
    ///   6,99 €  Essentiel mensuel 25 cr -> 0,280 €/cr
    ///  10,99 €  Éclat    40 cr  -> 0,275 €/cr
    ///  14,99 €  Signature mensuel 60 cr -> 0,250 €/cr
    ///  29,99 €  Diamant 140 cr  -> 0,214 €/cr
    ///
    /// Glow (30 crédits, 7,99 €, 0,266 €/cr) a été RETIRÉ : placé juste après
    /// Essentiel mensuel, il faisait remonter le prix au crédit d'Éclat et
    /// cassait la monotonie que le client vérifie en dix secondes.
    ///
    /// Aucun badge. L'ancien « MEILLEURE VALEUR » était sur Glow alors
    /// qu'Éclat et Diamant offraient un meilleur prix unitaire — affirmation
    /// fausse affichée à côté du prix au crédit qui la contredisait.
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
            id: "ecrin_credits_eclat",
            label: "Éclat",
            count: 40,
            price: "10,99€",
            referencePrice: 10.99,
            badge: nil,
            icon: "star.fill"
        ),
        CreditsPack(
            id: "ecrin_credits_diamant",
            label: "Diamant",
            count: 140,
            price: "29,99€",
            referencePrice: 29.99,
            badge: nil,
            icon: "crown.fill"
        ),
    ]
}
