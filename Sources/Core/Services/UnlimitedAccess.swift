import Foundation

/// Statut "illimité" (comptes fondateur / QA). La source de vérité est le SERVEUR :
/// l'Edge Function renvoie un quota au sentinel pour ces comptes. Le client ne stocke
/// AUCUNE liste d'emails (évite d'embarquer des PII / la liste de bypass dans l'IPA).
enum UnlimitedAccess {
    static let quotaDisplayValue = 999_999

    /// Seuil au-delà duquel on considère le solde comme "illimité".
    private static let unlimitedThreshold = 100_000

    /// Dérive le statut illimité du solde de crédits renvoyé par le serveur.
    static func isUnlimited(remainingCredits: Int) -> Bool {
        remainingCredits >= unlimitedThreshold
    }
}
