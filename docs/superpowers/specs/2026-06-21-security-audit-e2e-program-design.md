# Programme « Audit total + Tests E2E + Sécurité 95/100 » — Design

**Date :** 2026-06-21
**Projet :** L'Écrin Virtuel (iOS SwiftUI + Supabase + Edge IA `tryon-generate`)
**Backend canonique :** `itjtshfzpknlzownpwte`
**Statut :** Design approuvé — en attente de relecture du spec avant `writing-plans` (jalon M0)

---

## 1. Objectif

Un programme unique fusionnant trois piliers :

- **P1 — Sécurité → 95/100** sur le scoring 007 (8 domaines pondérés).
- **P2 — Audit complet du code** (correction/bugs, architecture, perf, DB) sur les 28 features (~43K LOC, 167 fichiers Swift).
- **P3 — Suite de tests** E2E (`xcuitest`) couvrant **chaque écran/action** + unitaires (`swift-testing`) pour services & view-models.

**Définition de « terminé » :** score 007 ≥ 95/100 **ET** suite de tests verte couvrant chaque action **ET** backlog d'audit traité — le tout vérifié en prod (MCP) / simulateur (`xcodebuild test`), hors dépendances client explicitées (M4).

## 2. État de départ (réconcilié avec la prod, 2026-06-19/21)

L'audit 007 initial a révélé que **les migrations du repo divergent fortement de la prod** (10+ tables prod absentes du repo ; `gift_cards` et `gaming_profiles` n'existent pas en prod → features dégradées). La vérification sur prod a invalidé 2 « critiques » source-only et révélé 2 vrais critiques invisibles depuis le code.

**Déjà corrigé en prod (migrations 007/008, vérifiées via advisors — 11 → 4 lints) :**
- `consume_credits` : verrouillé `service_role`, garde `p_cost > 0` (bypass paywall fermé), `search_path` figé.
- `handle_new_user` : retiré des RPC publics ; `update_quota_timestamp` `search_path` figé.
- `device_tryons` : policy ouverte `USING(true)` supprimée → service-role only.
- `tryon-temp` : énumération des photos de visage supprimée.

**Restant à traiter (couvert par ce programme) :** abus sessions anonymes (coût IA), absence de modération, bucket `tryon-temp` public, auth callback `ecrin://` usurpable, suppression de compte incomplète (RGPD), dérive IaC, couverture de tests quasi nulle (2 fichiers).

## 3. Modèle de score cible (95/100)

| Domaine | Poids | Actuel | Cible | Levier |
|---|---|---|---|---|
| Secrets & credentials | 20% | 85 | 95 | E-mails fondateurs → serveur ; docs nettoyés (UDID/Team) |
| Input validation | 15% | 60 | 95 | Modération prompt+image (Edge) |
| AuthN & AuthZ | 15% | 70 | 95 | App Attest + Universal Links |
| Protection PII | 15% | 40 | 93 | Bucket privé + URL signées ; suppression compte v2 |
| Résilience | 10% | 65 | 95 | Conso bornée (attest) + rate-limit + timeouts/idempotence |
| Monitoring | 10% | 55 | 93 | Évènements sécurité + alertes |
| Supply chain | 10% | 70 | 93 | Épinglage deps Deno |
| Compliance | 5% | 45 | 93 | Suppression RGPD complète + modération + consentement |

**Pondéré cible ≈ 95.**

## 4. Décomposition en jalons

Chaque jalon suit son propre cycle spec→plan→exécution→vérification. Le présent document est le **spec programme** ; M0 sera détaillé en premier dans `writing-plans`.

### M0 — Fondations (harnais de test + vérité IaC)
- Cibles `EcrinVirtuelUITests` (XCUITest) + `EcrinVirtuelTests` (Swift Testing) structurées.
- *Seams* déterministes : launch-arguments (`-uitest`, mock auth/session, seed d'état, désactivation réseau réel) pour des tests reproductibles sans backend live.
- Passe d'`accessibilityIdentifier` sur les éléments interactifs clés (préalable aux page-objects).
- Réconciliation IaC : dump du schéma prod réel (via MCP) → migration baseline `009_prod_baseline.sql` ; documenter la dérive.
- **Acceptation :** un test E2E « smoke » lance l'app en mode mock et navigue les 5 onglets, vert sur simulateur.

### M1 — Sécurité Phase 1 (déployable + vérifiable)
- Modération : `omni-moderation-latest` (OpenAI, gratuit) sur le prompt dans l'Edge, fail-closed sur catégories interdites.
- PII : bucket `tryon-temp` `public=false` + `createSignedUrl(120s)` au lieu de `getPublicUrl` (migration + Edge v22a).
- `delete-user-account` v2 : cascade `service_role` sur **toutes** les tables user-owned réelles (corrige la suppression RGPD incomplète).
- Hygiène : e-mails fondateurs → config serveur (plus dans l'IPA) ; épinglage des imports Deno (`std@x`, `esm.sh` figés).
- Monitoring : évènements sécurité (échecs modération, pics de génération) + alerte.
- **Acceptation :** advisors Supabase sans WARN sécurité résiduel non justifié ; chaque fix couvert par un test de non-régression ; Edge déployée et probée.

### M2 — Audit complet du code (adversarial, 28 features)
- Balayage par lentilles : correctness/bugs (`code-review`), architecture (`swift-architecture`), perf, DB (`supabase-postgres-best-practices`), critique adversariale (`bmad`).
- Vérification adversariale de chaque finding avant correction (pas de faux positifs).
- Confirmer/corriger les défauts déjà repérés : incohérence modèle d'ID `auth_id` vs `users.id` (inserts/deletes silencieusement rejetés), échecs `try?` fire-and-forget masqués, features gift/gaming non fonctionnelles en prod.
- **Acceptation :** backlog priorisé vérifié ; corrections haute-confiance appliquées avec tests.

### M3 — Suite de tests E2E (chaque action)
- Page-objects `xcuitest` par feature ; couverture : onboarding, auth (Apple/OTP), 5 onglets, wizard QuickTryOn, essayage bijoux/mode, paywall + achat (StoreKit testing), garde-robe (CRUD), communauté (post/like), gift, gaming, Look du Jour.
- Unitaires `swift-testing` : `CreditsManager`, décodeurs `SupabaseService`, `WeatherLookRecommender` (existant), prompt builders, view-models clés.
- **Acceptation :** `xcodebuild test` vert ; chaque action utilisateur a au moins un test E2E ou unitaire la couvrant.

### M4 — Sécurité Phase 2 (App Attest + Universal Links)
- App Attest : `AttestationService.swift` (`DCAppAttestService`) côté iOS + validation côté Edge (attestation : chaîne cert → Apple App Attest Root CA, nonce, rpId, compteur ; assertion par requête). Table `device_attest`. Remplace la dépendance aux sessions anonymes.
- Universal Links : `apple-app-site-association` sur `ecrin.app` + entitlement `applinks:` ; `ecrin://` en fallback.
- **Acceptation :** Edge déployée + probée par moi ; code client complet. *Vérif bout-en-bout dépend du build App Store/TestFlight + hébergement AASA côté utilisateur.*

### M5 — Scoring final & vérification
- Re-run advisors + suite de tests + recalcul du score par domaine + verdict.
- **Acceptation :** score ≥ 95/100 documenté ; suite verte.

## 5. Architecture — unités isolées

- **iOS test seams** : un seul point d'entrée de configuration test (`AppLaunchEnvironment`) lisant les launch-args ; aucune logique de test dans le code prod hors de ce seam.
- **Edge `tryon-generate` v22** : pipeline en étapes pures et testables — `verifyAttestation()` → `moderate()` → `consumeQuota()` → `signTempUrl()` → `cascadeGenerate()`. Chaque étape isolée.
- **`device_attest`** (DB) : keyId → clé publique, compteur, free_used. Service-role only.
- **`delete-user-account` v2** : liste centralisée des tables user-owned, cascade idempotente.
- **Page-objects XCUITest** : une classe par écran, exposant les actions ; les tests ne touchent jamais les sélecteurs bruts.

## 6. Non-objectifs (YAGNI)

- Pas de refactor d'archi non lié à la sécurité/aux bugs trouvés.
- Pas de migration de stockage cross-projet des assets catalogue (dette long-terme, hors scope).
- Pas de couverture 100 % lignes — cible = **chaque action** couverte, pas chaque branche.
- Pas de widget iOS / fonctionnalités produit nouvelles.

## 7. Limites de vérification

Build/tests sur **simulateur** (`xcodebuild test`) ; déploiement Edge/DB via **MCP**. Non réalisables par l'agent : ship App Store/TestFlight, hébergement sur `ecrin.app`. → App Attest *client* (M4) et Universal Links restent code-complets mais non vérifiables bout-en-bout par l'agent ; l'utilisateur doit builder/héberger.

## 8. Dépendances & risques

- **App Attest en Deno** : validation crypto (CBOR + chaîne X.509) non triviale → risque de fragilité ; mitigation : fail-closed + tests de vecteurs.
- **Dérive IaC** : corrigée en M0 (baseline) ; sans elle, tout travail DB est aveugle.
- **StoreKit testing** : nécessite une config `.storekit` pour tester le paywall en E2E.
- **Stratégie de test des flux authentifiés (décidé 2026-06-21) : MOCK TOTAL.** Mode `-uitest` → auth/session mockées via launch-args, état seedé en mémoire, **zéro backend live**. Plus robuste et reproductible. Aucun utilisateur de test réel ni credentials requis.
