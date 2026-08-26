# App Store Connect — IAP créés (résultat réel, 22 juin 2026)

App **« Ecrin Virtuel »** — `com.ecrin.jewelry` — ASC app id **6760768389** (l'app qui shippe : build 10017 du 25 avr., = `project.yml`).

> ⚠️ Le compte contient **3 app records L'Écrin**. Les product IDs `ecrin.premium.monthly`, `ecrin.premium.yearly`, `ecrin.credits.50` sont **verrouillés à vie** par une vieille app (`com.inferencevision.lecrinvirtuel` / 6758549821) et **impossibles à recréer** sur l'app qui shippe. D'où les IDs alternatifs ci-dessous.

## Produits créés (tous READY_TO_SUBMIT)

Groupe d'abonnement **« Écrin »** (id `22175486`), loc fr-FR + en-US.

### Abonnements (6)

| Produit (ASC) | ID code `PaywallProductID` | Type | Prix FRA | Essai |
|---|---|---|---|---|
| `ecrin.starter.monthly` | `starterMonthly` | Abo P1M lvl3 | 4,99 € | — |
| **`ecrin.premium.month`** | `premiumMonthly` | Abo P1M lvl2 | 9,99 € | **3 j gratuits** |
| `ecrin.elite.monthly` | `eliteMonthly` | Abo P1M lvl1 | 29,99 € | — |
| `ecrin.starter.yearly` | `starterYearly` | Abo P1Y lvl3 | 54,99 € | — |
| **`ecrin.premium.year`** | `premiumYearly` | Abo P1Y lvl2 | 79,99 € | — |
| `ecrin.elite.yearly` | `eliteYearly` | Abo P1Y lvl1 | 194,99 € | — |

### À vie (1)

| Produit (ASC) | ID code `PaywallProductID` | Type | Prix FRA |
|---|---|---|---|
| `ecrin.founder.lifetime` | `founderLifetime` | Non-consommable | 349,99 € |

### Consommables (4)

| Produit (ASC) | CreditsPack id | Crédits | Prix FRA |
|---|---|---|---|
| `ecrin_credits_spark` | `ecrin_credits_spark` | 10 crédits | 2,99 € |
| `ecrin_credits_glow` | `ecrin_credits_glow` | 30 crédits | 7,99 € |
| `ecrin_credits_eclat` | `ecrin_credits_eclat` | 70 crédits | 16,99 € |
| `ecrin_credits_diamant` | `ecrin_credits_diamant` | 150 crédits | 29,99 € |

Chaque produit a : nom + description fr-FR & en-US, prix **équilibré sur 175 territoires**, disponibilité mondiale (+ nouveaux territoires auto), capture de review (1242×2208). Essai 3 j posé sur les 175 territoires de `ecrin.premium.month`.

## Code modifié — PaywallProductID

`Sources/Features/Paywall/PaywallView.swift` (lignes 28–41) : les IDs underscore verrouillés ont été remplacés par les IDs pointés créés sur `com.ecrin.jewelry` :

- `ecrin_starter_monthly` → `ecrin.starter.monthly`
- `ecrin_premium_monthly` → `ecrin.premium.month`
- `ecrin_elite_monthly`   → `ecrin.elite.monthly`
- `ecrin_starter_yearly`  → `ecrin.starter.yearly`
- `ecrin_premium_yearly`  → `ecrin.premium.year`
- `ecrin_elite_yearly`    → `ecrin.elite.yearly`
- `ecrin_founder_lifetime`→ `ecrin.founder.lifetime`

Le catalogue `PaywallPlan` (prix 6,99/12,99/24,99/54,99/99,99/194,99/349,99 €) et le routing `resolvedSubscriptionStatus` sont inchangés — ils utilisent `.contains("elite/premium/starter")` qui fonctionne avec les IDs pointés.

## Configuration RevenueCat requise

Voici les étapes dashboard click-par-click.

### 1 — Products (onglet « Products »)

Créer les 11 produits (App Store → `com.ecrin.jewelry`). Pour chaque produit, « + New » → renseigner l'Identifier :

**Abonnements :**
```
ecrin.starter.monthly
ecrin.premium.month
ecrin.elite.monthly
ecrin.starter.yearly
ecrin.premium.year
ecrin.elite.yearly
```
**Non-consommable :**
```
ecrin.founder.lifetime
```
**Consommables :**
```
ecrin_credits_spark
ecrin_credits_glow
ecrin_credits_eclat
ecrin_credits_diamant
```

### 2 — Entitlements (onglet « Entitlements »)

Créer 3 entitlements et leur attacher les produits :

| Identifier | Produits à attacher |
|---|---|
| `starter` | `ecrin.starter.monthly`, `ecrin.starter.yearly` |
| `premium` | `ecrin.premium.month`, `ecrin.premium.year` |
| `elite` | `ecrin.elite.monthly`, `ecrin.elite.yearly`, `ecrin.founder.lifetime` |

> Note : `EcrinVirtuelApp.swift` lit `info.entitlements.all` et cherche les clés `starter`, `premium`, `elite`.

### 3 — Offerings → Packages (onglet « Offerings »)

Créer l'offering **`default`** (ou vérifier qu'il existe), puis ajouter 7 packages :

| Identifier RC | Product identifier |
|---|---|
| `$rc_monthly` ou `starter_monthly` | `ecrin.starter.monthly` |
| `$rc_monthly` ou `premium_monthly` | `ecrin.premium.month` |
| `elite_monthly` | `ecrin.elite.monthly` |
| `starter_yearly` | `ecrin.starter.yearly` |
| `$rc_annual` ou `premium_yearly` | `ecrin.premium.year` |
| `elite_yearly` | `ecrin.elite.yearly` |
| `lifetime` | `ecrin.founder.lifetime` |

> Les consommables **ne passent pas** par les offerings — `CreditsPackViewModel` les fetch directement via `Purchases.shared.products(ids)`.

### 4 — App Store Connect → version 1.0 : attacher les IAP

Dans ASC > app 6760768389 > soumission version 1.0 :
- Section « In-App Purchases and Subscriptions » → ajouter les 11 produits → ils partiront en review avec le build.

## État RevenueCat (configuré programmatiquement, 22 juin 2026)

Projet `c8c287c3` — App `app533f570e3b` (`com.ecrin.jewelry`) :

| Composant | État |
|---|---|
| **11 Products** créés | ✓ actifs |
| **Entitlement `starter`** | ✓ ecrin.starter.monthly + ecrin.starter.yearly |
| **Entitlement `premium`** | ✓ ecrin.premium.month + ecrin.premium.year |
| **Entitlement `elite`** | ✓ ecrin.elite.monthly + ecrin.elite.yearly + ecrin.founder.lifetime |
| **Offering `default`** (`ofrnga01c25df3f`) | ✓ current |
| **7 packages** (starter/premium/elite × monthly/annual + lifetime) | ✓ |
| **Produits → packages** | ✓ tous attachés (`eligibility_criteria: "all"`) |

Endpoints RC V2 utilisés :
- Entitlements : `POST /v2/projects/{pid}/entitlements/{eid}/actions/attach_products` body `{product_ids:[...]}`
- Packages : `POST /v2/projects/{pid}/packages/{pkgid}/actions/attach_products` body `{products:[{product_id,eligibility_criteria}]}`

## Reste à faire (côté user)

- [x] ~~Configurer RevenueCat~~ (fait par API)
- [ ] Rebuild et tester le paywall sur simulateur (`xcodebuild`, iPhone 17)
- [ ] Attacher les 11 IAP à la soumission version 1.0 dans ASC (étape 4)
- [ ] App Attest M4 : secret `APPLE_APP_ATTEST_ROOT_CA_PEM` à poser dans Supabase (cf. `docs/M4-ACTIVATION-RUNBOOK.md`)
