# M2 — Audit complet du code — Synthèse (2026-06-21)

Audit adversarial parallèle (5 clusters) des 28 features + Core. Correctness / archi / perf / DB.
Sécurité couverte en M0/M1 (hors scope ici). Détail par cluster : `docs/audits/m2-audit-*.md`.

**~85 findings** · ~10 Critical · ~27 High · ~30 Medium · ~21 Low.

## 🔴 Thème récurrent (cause racine de la plupart des Critical)

**Dérive repo↔prod + `try?` qui avale les erreurs.** Le code iOS écrit/lit des colonnes
ou tables qui **n'existent pas en prod** (voir `009_prod_baseline.sql`), et chaque échec
Postgres (42703 « column does not exist », 404 table) est silencieusement avalé par `try?`.
Résultat : des features **paraissent marcher** mais ne persistent jamais rien en prod.

## Critical vérifiés

| # | Fichier | Bug | Impact | Vérifié |
|---|---------|-----|--------|---------|
| C1 | `SupabaseService.swift:~480-503` `SupabaseWardrobeRow` | encode 16 champs ; prod `wardrobe_items` en a **10** (pas de subcategory/material/tags/try_on_prompt/source/price/purchase_url) | **toute** sauvegarde garde-robe cloud échoue (avalée par `try?`) | ✅ vs baseline 009 |
| C2 | `SupabaseService.swift:133-175` preferred_gender | requête `.eq("auth_id", …)` ; prod `users` n'a **pas** de colonne `auth_id` (id == auth.uid()) | genre Look du Jour jamais lu/sauvé | ✅ vs baseline 009 |
| C3 | `GiftViewModel.swift:88-179` | insert/select sur `gift_cards` + colonnes inexistantes ; **table absente** en prod | cadeaux jamais réels → carte locale + **sample factice** affiché au destinataire | ✅ table absente confirmée |
| C4 | `PaywallView.swift:211,241` | `entitlements["premium"]` en dur ; les plans Elite/Starter/Lifetime ont d'**autres** entitlement IDs (cf. boot app) | achat Elite/Starter : **débité mais** `creditGenerations` jamais appelé, paywall ne se ferme pas | ✅ (à confirmer config RC) |
| C5 | `BodyContextAnalyzer.swift:196,317,543` | `try? handler.perform()` avale l'erreur Vision ; `continuation.resume()` seulement dans le completion → **continuation jamais reprise** si Vision échoue | **hang permanent** du pipeline de génération (TryOn/QuickTryOn/MultiPose) | ✅ |
| C6 | `ARTryOnView.swift:218` | `snapshot` nil → completion jamais appelée → `isCapturing` reste true → boucle de snapshots à chaque re-render | freeze UI / crash session AR | ✅ (signalé) |
| C7 | `EcrinVirtuelApp.swift:36` | `try?` sur `customerInfo()` au cold launch | abonné payant bloqué en `.free` toute la session sur un hoquet réseau | ✅ |
| C8 | `CreditsManager` vs `CreditsPackViewModel.swift:92` | deux sources de vérité du solde ; après achat de crédits seul `CreditsPackViewModel` est synchro | crédits achetés **inutilisables** jusqu'au prochain cold launch (paywall affiché à tort) | ✅ |

## High notables (extraits)

- `WardrobeViewModel.swift:76-98` — toutes les erreurs CRUD avalées par `try?` (aggrave C1).
- `WeatherLookRecommender.swift:334` — scoring saison (poids 20) **toujours 0** : `"ete"` vs catalogue `"été"` (diacritiques).
- `WeatherSeason` — saison fausse pour automne doux (22 °C en octobre → `.hiver`).
- `SnapshotRenderer.swift:33` + `BrandedShareSheet.swift:175` — « Sauvegardé ✓ » affiché alors que l'écriture photo n'est **pas confirmée** (completion ignorée).
- `CommunityViewModel.swift:121` — `Task.detached` casse l'isolation @MainActor + retient le VM.
- `MoodBoardGalleryView`/`MoodBoardResultView:289` — « Save » et « Essayer ces bijoux » = **stubs no-op**.
- `ARTryOnWrapperView.swift:239` — picker bijoux AR câblé sur `JewelryItem.samples` (catalogue réel jamais branché).
- `GoldParticles.swift:31` — Timer 60 Hz sur main thread (TimelineView déjà présent) ; perf.
- `FramePickerView.swift:258` — frames premium `isUnlockableByXP=false` → **verrouillées sans voie de déblocage**.
- Export VMs sans `deinit { renderTask?.cancel() }`.

## Forks de correction (décisions nécessaires)

- **C1/C2/C3 (dérive schéma)** : soit **aligner le Swift sur les colonnes prod réelles** (retirer les champs en trop — plus rapide, mais perd des features potentielles), soit **ajouter les colonnes/tables manquantes en prod** (migrations — si ces features sont voulues : matière/tags/prix garde-robe, table cadeaux). Décision produit.
- **C4** : confirmer la config RevenueCat (un seul entitlement « premium » pour tous les plans, ou un par tier) avant de corriger la clé.
- **C5/C6/C7/C8 + High** : corrections claires, à appliquer (chacune = petit cycle TDD).

## Recommandation

Traiter par vagues : (1) les Critical de **logique** sans fork (C5 hang, C6 boucle AR, C7 abonné, C8 crédits) ; (2) **décider** le fork schéma (C1/C2/C3) puis corriger ; (3) confirmer RC pour C4 ; (4) les High. Chaque correctif vérifié (tests / smoke-test).
