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
    /// Numéro d'époque : incrémenté à chaque déconnexion. Un sync suspendu sur
    /// le réseau avec le JWT du compte PRÉCÉDENT reprend après resetForSignOut
    /// et réappliquait son solde — y compris le statut fondateur illimité — au
    /// poste déconnecté. Comparer l'époque au retour de l'await jette ce
    /// résultat périmé.
    private var epoch = 0

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let startEpoch = epoch

        guard let session = try? await SupabaseService.shared.client.auth.session else {
            // Pas de session : utilisateur non connecté.
            // Accordons 3 essais gratuits seulement si jamais chargé (évite de réinitialiser
            // après que l'utilisateur a déjà consommé des essais dans la session courante).
            guard epoch == startEpoch else { return }
            isUnlimited = false
            if !hasLoaded { remaining = 3 }
            hasLoaded = true
            return
        }

        let fetched = try? await SupabaseService.shared.fetchRemainingCredits()
        // Déconnexion pendant l'await : la réponse est partie avec le JWT de
        // l'ANCIEN compte. On la jette et on relance un sync propre une fois
        // isSyncing retombé (le Task de syncDetached passe après le defer).
        guard epoch == startEpoch else {
            syncDetached()
            return
        }
        if let count = fetched {
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

    /// Réinitialise l'état après une déconnexion : le solde — y compris le
    /// statut fondateur illimité — du compte précédent ne doit pas rester
    /// affiché pour l'utilisateur suivant sur le même appareil.
    func resetForSignOut() {
        epoch += 1
        isUnlimited = false
        remaining = 0
        hasLoaded = false
        syncDetached() // ré-évalue l'état anonyme (essais gratuits)
    }

    // MARK: - Après achat

    /// Resynchronise jusqu'à ce que le solde serveur dépasse `baseline`.
    ///
    /// L'octroi est asynchrone et hors de l'app (webhook `revenuecat-webhook`,
    /// ou `credit-generations` appelée juste avant) : un unique `sync()` juste
    /// après le paiement lit souvent l'ancien solde. Renvoie `true` dès que
    /// l'augmentation est constatée, `false` si elle ne l'est pas dans le
    /// budget imparti — l'appelant affiche alors « attribution en cours »,
    /// jamais un nombre inventé ni une erreur.
    ///
    /// Remplace l'ancien `handleSubscriptionUpgrade`, qui AFFECTAIT
    /// `remaining = status.monthlyGenerations` en concurrence avec `sync()` :
    /// l'utilisateur voyait « 15 » puis « 3 », ou l'inverse, après paiement.
    @discardableResult
    func syncUntilIncrease(above baseline: Int, attempts: Int = 5) async -> Bool {
        for attempt in 0..<max(1, attempts) {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(2))
            }
            await sync()
            if remaining > baseline { return true }
        }
        return false
    }
}
