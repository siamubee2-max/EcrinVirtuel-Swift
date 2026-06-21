# M1 — Sécurité Phase 1 — Design (spec)

**Date :** 2026-06-21
**Programme :** « Audit total + Tests E2E + Sécurité 95/100 » (voir `2026-06-21-security-audit-e2e-program-design.md`)
**Backend :** `itjtshfzpknlzownpwte` · **Baseline schéma :** `supabase/migrations/009_prod_baseline.sql`
**Statut :** Design approuvé — en attente de relecture avant `writing-plans`.

## 1. Objectif

Fermer les items de sécurité **déployables sans rebuild iOS**, en redéployant l'Edge
Function de génération payante `tryon-generate` et l'Edge `delete-user-account`,
sans interruption du service. Cible ≈ **92/100** (le reste — App Attest, Universal
Links — est en M4).

## 2. Décisions actées (brainstorming)

- **Modération en panne → hybride fail-open logé** : timeout 3s ; si l'appel modération
  échoue/timeout, on **génère quand même** mais on insère un `monitoring_events` et on
  incrémente un compteur d'alerte. (Revenu préservé, traçabilité conservée.)
- **Cutover live = capture → deploy → smoke-test → bucket privé** : on archive d'abord la
  version Edge live (rollback), on déploie v22, on valide par une **génération réelle via
  un compte fondateur** (illimité, 0 quota, 0 coût), puis seulement on passe le bucket en
  privé. Rollback = redeploy de l'archive + bucket public.
- **TTL URL signée = 120s** (poll génération max 50s + marge).
- **Liste fondateurs** : la source de vérité reste **serveur** (l'Edge a déjà
  `UNLIMITED_EMAILS`). Le **client** cesse d'embarquer la liste en dur ; il dérive
  `isUnlimited` d'un signal serveur.

## 3. Composants (unités isolées)

### C1 — `tryon-generate` v22 (Edge, TypeScript)
Trois changements au pipeline existant (étapes pures, isolées) :
1. **`moderate(prompt)`** avant `consumeQuota` : `POST https://api.openai.com/v1/moderations`
   modèle `omni-moderation-latest`, `AbortController` timeout 3s. Bloque si l'une des
   catégories `sexual/minors`, `sexual`, `violence/graphic`, `illicit` est `true` →
   réponse **400 `{error:"content_rejected"}`** + `monitoring_events` type
   `moderation_blocked`. Échec/timeout → **fail-open** + `monitoring_events` type
   `moderation_unavailable`.
2. **`createSignedUrl(tempPath, 120)`** remplace `getPublicUrl` ; l'URL signée est passée à
   Kie.ai. Échec de signature → ne pas tomber sur une URL publique : retourner 503.
3. **Imports Deno épinglés** : `std@0.224.0` (au lieu de `0.168.0`), `@supabase/supabase-js`
   à une version exacte.

### C2 — Migration `010_tryon_temp_private.sql`
`update storage.buckets set public = false where id = 'tryon-temp';`
**Appliquée seulement après** le smoke-test Edge réussi (étape 4 du cutover).

### C3 — `delete-user-account` v2 (Edge, TypeScript)
Cascade `service_role`, chaque table en `try/catch` indépendant, sur les tables prod
user-owned (clé entre crochets, d'après 009) :
`try_on_results[user_id]`, `wardrobe_items[user_id]`, `jewelry_items[user_id]`,
`outfit_presets[user_id]`, `community_posts[user_id]`, `post_comments[user_id]`,
`post_likes[user_id]`, `post_reports[reporter_id]`, `conversations[user_id]` (+
`messages[conversation_id]` via les conversations de l'utilisateur), `credit_transactions[user_id]`,
`user_quotas[user_id]`, `users[id]`. **Puis** `auth.admin.deleteUser(userId)` **uniquement
si** aucune suppression de données n'a échoué ; sinon retourner les échecs partiels sans
supprimer le compte auth.

### C4 — Monitoring sécurité
Types `monitoring_events` normalisés émis par l'Edge : `moderation_blocked`,
`moderation_unavailable`, `generation_spike`. Contrôle de fin de jalon : `get_advisors`
(security) propre + une requête de comptage des events.

### C5 — Hygiène secrets (iOS)
`Sources/Core/Services/UnlimitedAccess.swift` : retirer le `Set` d'emails en dur. Le client
dérive `isUnlimited` du quota serveur (l'Edge renvoie déjà un quota illimité pour les
fondateurs ; `CreditsManager` traite `remaining >= UnlimitedAccess.quotaDisplayValue` comme
illimité). Aucune liste d'emails dans l'IPA.

## 4. Séquence d'exécution (cutover)

1. `get_edge_function tryon-generate` → archiver dans `supabase/functions/tryon-generate/index.live-YYYYMMDD.ts`.
2. Écrire v22, `deploy_edge_function tryon-generate` (bucket encore public).
3. **Smoke-test** : génération réelle via JWT d'un compte fondateur → vérifier image renvoyée + provider.
4. Si OK → `apply_migration 010` (bucket privé) → re-smoke-test (signed URL).
5. Écrire + `deploy_edge_function delete-user-account` v2 ; smoke-test sur un **compte OTP jetable réel** créé sur itjtshfzp : seed de quelques lignes (try_on_results, wardrobe_items…), appel delete v2, puis **vérification MCP** que toutes les tables user-owned + le compte auth sont supprimés.
6. C5 (iOS) : éditer `UnlimitedAccess`/`CreditsManager`, build + tests iOS verts.
7. `get_advisors` security + comptage events.

## 5. Gestion d'erreurs

- Modération : 3s timeout, fail-open logé (acté).
- Signature URL échouée → 503, **jamais** d'exposition publique de la photo.
- delete v2 : échecs partiels remontés ; pas de `deleteUser` auth tant que des données restent.
- Cutover : rollback = redeploy archive + bucket public.

## 6. Vérification & limites

Le code Edge (Deno/TS) n'a pas de harnais de test unitaire dans ce repo. M1 se vérifie par :
**smoke-tests réels via MCP** (génération fondateur ; suppression d'un compte jetable),
**`get_advisors`**, et les **tests iOS existants** pour C5. Pas de couverture unitaire Edge
(sur-investissement ici ; les E2E viennent en M3). C'est une limite assumée.

## 7. Non-objectifs (YAGNI)

- Pas de modération d'image (seulement le prompt) en M1 — l'analyse d'image/deepfake est
  hors scope (relève du consentement, pas de la modération).
- Pas d'App Attest / Universal Links (M4).
- Pas de refactor du pipeline cascade existant.

## 8. Dépendances & risques

- **Redéploiement live d'une fonction payante** : mitigé par le cutover capture→smoke-test→rollback.
- **Compte jetable pour delete-v2** : ACTÉ — compte OTP jetable réel sur itjtshfzp (seed → delete v2 → vérification MCP de suppression complète). Le compte est créé et détruit dans le test.
- **`createSignedUrl` + Kie.ai** : l'URL signée doit être fetchable par Kie.ai (HTTP public temporaire) — c'est le cas d'un signed URL Supabase. Vérifié au smoke-test étape 4.
