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

    /// Compte illimité (solde serveur ≥ seuil) — pas de paywall ni décompte local.
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

        if let count = try? await SupabaseService.shared.fetchRemainingCredits() {
            remaining = max(0, count)
            isUnlimited = UnlimitedAccess.isUnlimited(remainingCredits: count)
        } else {
            isUnlimited = false
        }
        hasLoaded = true
    }

    /// Déclenche un sync en arrière-plan (fire-and-forget).
    func syncDetached() {
        // CreditsManager is a singleton — [weak self] is unnecessary and misleading.
        // Task (not Task.detached) inherits the caller's actor context where needed.
        Task { await CreditsManager.shared.sync() }
    }

    // MARK: - Subscription update

    /// Appelé après un achat RevenueCat : met à jour l'affichage local
    /// en attendant que l'Edge Function credit-generations confirme le nouveau total.
    func handleSubscriptionUpgrade(to status: SubscriptionStatus) {
        remaining = status.monthlyGenerations == .max ? 999 : status.monthlyGenerations
    }
}
