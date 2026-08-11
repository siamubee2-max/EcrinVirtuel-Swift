import SwiftUI

// MARK: - CreditsManager
// Source de vérité unique pour les générations restantes.
// Remplace les compteurs locaux (trialsRemaining) dans chaque ViewModel.
//
// Fonctionnement :
//  - La valeur locale (remaining) est une estimation côté client.
//  - Le vrai quota est géré par l'Edge Function tryon-generate (user_quotas).
//  - sync() récupère la valeur exacte depuis Supabase après une génération ou un achat.

@Observable
@MainActor
final class CreditsManager {

    static let shared = CreditsManager()
    private init() {}

    /// Générations restantes.
    /// Initialisé à 0 — sync() le met à jour :
    ///   • 3 pour les nouveaux utilisateurs non connectés (essais gratuits)
    ///   • valeur serveur pour les utilisateurs connectés
    /// Évite l'affichage optimiste erroné pour les utilisateurs ayant épuisé leurs crédits.
    var remaining: Int = 0

    /// Vrai après le premier appel à sync() — avant ça, `remaining` = 0 par sécurité.
    private(set) var hasLoaded: Bool = false

    var isSyncing: Bool = false

    /// Compte fondateur (ex. siamubee2@gmail.com) — pas de paywall ni décompte serveur.
    private(set) var isUnlimited: Bool = false

    // MARK: - Consume

    /// Tente de consommer 1 crédit.
    /// Retourne `false` et appelle `showPaywall` si le solde est à zéro.
    /// Le vrai décompte est fait par l'Edge Function — ceci est local uniquement.
    @discardableResult
    func consume(count: Int = 1, showPaywall: () -> Void) -> Bool {
        guard count > 0 else { return true }
        if isUnlimited { return true }
        guard remaining >= count else {
            showPaywall()
            return false
        }
        remaining = max(0, remaining - count)
        return true
    }

    func refund(count: Int = 1) {
        guard count > 0 else { return }
        remaining += count
    }

    // MARK: - Sync with Supabase

    /// Synchronise le solde depuis Supabase user_quotas.
    /// À appeler au démarrage de l'app, après chaque génération réussie et après un achat.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let session = try? await SupabaseService.shared.client.auth.session else {
            // Pas de session : utilisateur non connecté.
            // Accordons 3 essais gratuits seulement si jamais chargé (évite de réinitialiser
            // après que l'utilisateur a déjà consommé des essais dans la session courante).
            isUnlimited = false
            if !hasLoaded { remaining = 3 }
            hasLoaded = true
            return
        }

        if UnlimitedAccess.isUnlimited(email: session.user.email) {
            isUnlimited = true
            remaining = UnlimitedAccess.quotaDisplayValue
            hasLoaded = true
            return
        }

        isUnlimited = false
        if let count = try? await SupabaseService.shared.fetchRemainingCredits() {
            remaining = max(0, count)
        }
        hasLoaded = true
    }

    /// Déclenche un sync en arrière-plan (fire-and-forget).
    func syncDetached() {
        Task.detached { [weak self] in
            await self?.sync()
        }
    }

    /// Réinitialise l'état après une déconnexion : le solde — y compris le
    /// statut fondateur illimité — du compte précédent ne doit pas rester
    /// affiché pour l'utilisateur suivant sur le même appareil.
    func resetForSignOut() {
        isUnlimited = false
        remaining = 0
        hasLoaded = false
        syncDetached() // ré-évalue l'état anonyme (essais gratuits)
    }

    // MARK: - Subscription update

    /// Appelé après un achat RevenueCat : met à jour l'affichage local
    /// en attendant que l'Edge Function credit-generations confirme le nouveau total.
    func handleSubscriptionUpgrade(to status: SubscriptionStatus) {
        remaining = status.monthlyGenerations == .max ? 999 : status.monthlyGenerations
    }
}
