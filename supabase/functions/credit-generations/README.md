# credit-generations

Crédite les packs d'essais après un achat consommable RevenueCat. Appelée par l'app iOS
via `SupabaseService.shared.creditGenerations(productId:transactionId:)`.

> **Le code source est désormais versionné ici** (`index.ts`). La v9 déployée en prod
> ne l'était pas — c'est ce qui avait laissé passer la faille C1 ci-dessous.

## État

| | |
|---|---|
| Prod actuelle | **v9 — VULNÉRABLE**, aucune vérification d'achat |
| Ce dépôt | **v10 — correctif d'audit, NON DÉPLOYÉ** |
| Dépendance | migration `012_credit_generations_atomic.sql` (non appliquée) |
| Secrets | ✅ `REVENUECAT_SECRET_KEY` + `REVENUECAT_PROJECT_ID` **posés le 9 août** |

## ⚠️ API v2, pas v1

Les clés secrètes émises aujourd'hui par RevenueCat sont **v2**, et la doc est explicite :
« v1 API keys are not compatible with v2 […] generate new v2 secret keys ». Une première
version de ce correctif visait `/v1/subscribers` — elle aurait renvoyé 401 en permanence,
donc (la fonction étant fail-closed) **n'aurait crédité aucun achat légitime**.

La v10 cible donc `https://api.revenuecat.com/v2` avec :

| Secret | Valeur |
|---|---|
| `REVENUECAT_SECRET_KEY` | clé `supabase-credit-generations` (créée le 9 août) |
| `REVENUECAT_PROJECT_ID` | `projc8c287c3` — **format v2**, pas le slug d'URL `c8c287c3` |

La clé est en **moindre privilège** : `Purchases → Read only` et `Products → Read only`,
les 20 autres permissions sur « No access ». Révocable seule.

**Deux appels** sont nécessaires, d'où les deux permissions :
1. `/v2/projects/{id}/customers/{user_id}/purchases` → retrouver l'achat par
   `store_purchase_identifier`, vérifier `status === "owned"` et l'environnement ;
2. `/v2/projects/{id}/products/{product_id}` → résoudre le `store_identifier` et vérifier
   qu'il correspond au pack réclamé. **Sans ce second appel, la transaction d'un pack à
   2,99 € permettrait de réclamer les 120 crédits du pack à 29,99 €.**

## Ce que corrige la v10

**C1 — CRITIQUE.** La v9 ne vérifiait aucun achat : `transaction_id` venait du client et
n'était jamais confronté à Apple ni à RevenueCat. Un compte gratuit pouvait poster un
identifiant arbitraire et se créditer sans fin — le paywall était décoratif.
→ La v10 interroge l'API RevenueCat, qui a elle-même validé le reçu Apple.
**L'`app_user_id` interrogé est toujours `user.id` issu du JWT**, jamais une valeur du
corps de requête : sinon un attaquant ferait valider l'achat d'un tiers à son profit.

**C2 — CRITIQUE.** Idempotence applicative racée (SELECT-puis-INSERT sans contrainte
`UNIQUE`), solde en read-modify-write, registre écrit *après* l'octroi et sans contrôle
d'erreur. → Tout est délégué à `credit_generations_atomic` : registre d'abord, la
contrainte `UNIQUE` **porte** l'idempotence, une seule transaction Postgres.

Corrigés au passage : `CORS: *` → `https://ecrin.app` ; `String(e)` n'est plus renvoyé
au client ; fail-closed si `REVENUECAT_SECRET_KEY` est absente.

## Déploiement (dans cet ordre)

```sql
-- 1) Vérifier l'absence de doublons — la migration ABORT sinon, c'est voulu.
--    Des doublons = trace d'un double-crédit (bug ou exploitation de C1/C2) : à auditer,
--    surtout PAS à supprimer sans regarder.
SELECT transaction_id, COUNT(*), SUM(credits_added), array_agg(user_id)
FROM public.credit_transactions GROUP BY transaction_id HAVING COUNT(*) > 1;
```

```bash
# 2) Appliquer la migration (contrainte UNIQUE + fonction atomique)
supabase db push --project-ref itjtshfzpknlzownpwte
#    ou coller 012_credit_generations_atomic.sql dans le SQL Editor

# 3) Poser le secret RevenueCat (Dashboard → API keys → Secret key)
supabase secrets set --project-ref itjtshfzpknlzownpwte \
  REVENUECAT_SECRET_KEY="sk_..."

# 4) Déployer la fonction
supabase functions deploy credit-generations --project-ref itjtshfzpknlzownpwte
```

**Ordre impératif** : la fonction v10 appelle `credit_generations_atomic`. La déployer
avant la migration casse tout achat légitime.

## Validation effectuée

La migration a été exécutée sur une instance PostgreSQL 16 jetable avec le schéma prod
minimal. Résultats :

| Test | Attendu | Obtenu |
|---|---|---|
| Premier crédit (nouvel utilisateur) | 120 | ✅ 120 |
| Rejeu du même `transaction_id` | `ALREADY_CREDITED` | ✅ |
| Nouvelle transaction | 120 → 130 | ✅ 130 |
| `p_credits` négatif | `INVALID_CREDITS` | ✅ |
| `transaction_id` vide | `INVALID_TRANSACTION_ID` | ✅ |
| **10 appels concurrents, même txn** | 1 succès, solde 120 | ✅ 1 succès / 9 rejets, solde **120** (et non 1200), 1 ligne de registre |
| `authenticated` appelle la fonction | droit refusé | ✅ (piège du `REVOKE` de la migration 005 évité) |
| `service_role` appelle la fonction | succès | ✅ |
| Doublons préexistants | `ABORT` explicite | ✅ |

`deno check index.ts` : ✅

**Non testé** : la vérification RevenueCat elle-même (nécessite une vraie clé et un achat
réel). À valider en sandbox avec `ALLOW_SANDBOX_PURCHASES=true` avant la bascule prod.

## Point de vigilance — délai de propagation

L'app appelle cette fonction immédiatement après l'achat ; RevenueCat n'a parfois pas
encore ingéré la transaction. La v10 retente **3 fois à 2 s d'intervalle**, uniquement
sur les motifs de propagation (`subscriber_unknown`, `no_purchase_for_product`,
`transaction_not_found`) — jamais sur un refus ferme.

Si des `purchase_not_verified` apparaissent sur des achats légitimes, augmenter
`RC_PROPAGATION_RETRIES` **avant** d'envisager d'affaiblir la vérification.

⚠️ Côté client, `PaywallView.swift:218` appelle `try?` : un échec de crédit est
**silencieusement ignoré**. L'utilisateur paie Apple et ne voit aucune erreur. À traiter
séparément (remonter l'erreur et proposer une reprise).
