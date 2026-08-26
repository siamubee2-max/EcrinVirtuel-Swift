import Foundation

/// Statut "illimité" (comptes fondateur / QA), appliqué à DEUX niveaux :
/// - serveur : l'Edge Function `tryon-generate` ne décompte jamais ces comptes
///   et `user_quotas` porte un solde sentinel (999 999) ;
/// - client : le tier Elite est forcé pour ces emails (fonds premium, modèle
///   premium, aucun paywall), quel que soit l'état RevenueCat de l'appareil.
enum UnlimitedAccess {
    static let quotaDisplayValue = 999_999

    /// Seuil au-delà duquel on considère le solde comme "illimité".
    private static let unlimitedThreshold = 100_000

    private static let emails: Set<String> = [
        "siamubee2@gmail.com",
        "monia.valenza@gmail.com",
        "chrweber@skynet.be",
    ]

    static func isUnlimited(email: String?) -> Bool {
        guard let email else { return false }
        return emails.contains(email.lowercased())
    }

    /// Dérive le statut illimité du solde de crédits renvoyé par le serveur.
    static func isUnlimited(remainingCredits: Int) -> Bool {
        remainingCredits >= unlimitedThreshold
    }

    /// Statut d'abonnement effectif : les comptes fondateur obtiennent le tier
    /// le plus élevé quel que soit l'état RevenueCat de l'appareil.
    static func effectiveStatus(resolved: SubscriptionStatus, email: String?) -> SubscriptionStatus {
        isUnlimited(email: email) ? .elite : resolved
    }
}
