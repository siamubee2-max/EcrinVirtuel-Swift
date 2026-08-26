# Audit essayage — coût réel, qualité, UX (23 juin 2026)

App **L'Écrin Virtuel** — Supabase prod `itjtshfzpknlzownpwte`, Edge Function `tryon-generate` **v24** (code live capturé via MCP).
1 crédit = 1 génération (`consume_credits` p_cost:1).

---

## 1. Étude de coût réel par essayage

### Coût fournisseur par modèle (depuis le code live, USD → EUR @ 0,92)

| Modèle (Kie.ai sauf indiqué) | Rôle | Coût USD | ≈ EUR |
|---|---|---|---|
| `gpt-image-2-image-to-image` | preview/standard (défaut) | 0,030 | 0,028 |
| `nano-banana-pro` | premium | 0,060 | 0,055 |
| `nano-banana-2` | fallback 1 | 0,030 | 0,028 |
| `flux-kontext` | fallback 2 | 0,020 | 0,018 |
| `gpt4o-image` | fallback 3 | 0,080 | 0,074 |
| Gemini 2.0 flash image | fallback 4 | ~0,00–0,04 | ~0,01 |
| OpenAI gpt-image-1 (edit 1024×1536) | fallback 5 | ~0,04 | 0,037 |

### Revenu par crédit (brut, puis net après Apple −15 % Small Business)

| Offre | Prix | Crédits/mois | Brut/crédit | **Net/crédit** |
|---|---|---|---|---|
| Starter | 4,99 €/mo | 15 | 0,333 € | **0,283 €** |
| Premium | 9,99 €/mo | 40 | 0,250 € | **0,213 €** |
| Elite | 29,99 €/mo | 100 | 0,300 € | **0,255 €** |
| Pack 10 | 2,99 € | 10 | 0,299 € | **0,254 €** |
| Pack 30 | 7,99 € | 30 | 0,266 € | **0,226 €** |
| Pack 70 | 16,99 € | 70 | 0,243 € | **0,206 €** |
| Pack 150 | 29,99 € | 150 | 0,200 € | **0,170 €** ← plancher |

### Coût réel selon le scénario de cascade

La cascade actuelle pour une requête `standard` essaie **jusqu'à 7 modèles** dans l'ordre :
`standard → premium → nano-banana-2 → flux-kontext → gpt4o-image → Gemini → OpenAI`.
Chaque modèle Kie poll jusqu'à **50 s** (20 × 2,5 s).

| Scénario | Modèles consommés | Coût | Marge vs plancher (0,170 €) |
|---|---|---|---|
| **Idéal** (1er essai OK) | standard | 0,028 € | **84 %** ✅ |
| **Typique** (1 retry) | standard✗ → premium✓ | 0,055 € | **68 %** ✅ |
| **Dégradé** (jobs timeout *facturés*) | standard+premium+nano2 | 0,111 € | **35 %** ⚠️ |
| **Catastrophe** (cascade complète) | jusqu'à gpt4o-image | 0,203 € | **−19 %** ❌ |

> **Risque clé** : un job Kie qui *timeout côté client* (50 s) continue souvent de tourner et **se facture quand même** côté Kie. La cascade à 5 modèles transforme une génération difficile en coût ×4 à ×7, parfois **supérieur au revenu** sur le pack 150.

### Conclusions coût
1. **Best-case sain** (marge >80 %), mais **la cascade est une bombe à retardement** : latence (jusqu'à 143 s observés en prod) ET double-facturation des jobs timeout.
2. **Aucun routing par catégorie** → une bague simple paie la même cascade qu'une tenue complète.
3. Le **pack 150 (plancher 0,170 €)** devient déficitaire dès qu'on dépasse ~3 modèles facturés.

---

## 2. Le « bon générateur » par catégorie (recommandation)

Actuellement : **un seul pipeline** pour bijoux / vêtements / chaussures (seul le *texte* du prompt diffère). D'où « vêtements pas fidèlement mis » + « proportions bijoux mauvaises ».

| Catégorie | Modèle primaire reco | Pourquoi | Coût | Fallback |
|---|---|---|---|---|
| **Bijoux** (bague, collier, BO, bracelet) | `flux-kontext` | édition locale précise, rapide, le moins cher | 0,018 € | nano-banana-2 |
| **Vêtements** (tenue complète) | `nano-banana-pro` | meilleure fidélité tissu/coupe | 0,055 € | gpt-image-2 |
| **Chaussures** | `gpt-image-2` | bon compromis pieds/sol | 0,028 € | flux-kontext |

Gain double : **+fidélité** (modèle adapté) et **−coût** sur les bijoux (volume probablement majoritaire).
Nécessite : champ `category` envoyé par iOS + sélection du primaire côté Edge Function (**redéploiement de la fonction payante = risque à valider**).

---

## 3. Causes racines confirmées (code à l'appui)

| # | Symptôme user | Cause racine | Fichier:ligne |
|---|---|---|---|
| 1 | « boutique vedette ne fonctionne pas » | bijou sélectionné jamais injecté dans `TryOnView()` → CTA grisé | `PartnerDetailView.swift:44` vs `:189` — **CORRIGÉ** |
| 2 | proportions bijoux mauvaises | `aspectRatio` figé `9:16` + prompt « FULL-BODY head-to-toe » forcé même pour bague/BO | `ImageGenerationService.swift:204`, `PosePromptBuilder.swift:55`, Edge `withTryOnFramingPrompt` |
| 3 | couleurs trop chaudes | accent `gold #CA8A04` (ocre, canal bleu ≈ 0) + `.tint(gold)` global + glass `.tint(gold 0.2)` | `DesignSystem.swift:7`, `MainTabView.swift:67`, `GlassCard.swift:58` |
| 4 | beaucoup de générations échouent | cascade 5 modèles × poll 50 s = jusqu'à 143 s → timeouts perçus | Edge `tryon-generate` cascade |
| 5 | manque de fluidité | résultat surgit sans animation (transition déclarée, pas de `withAnimation`) | `TryOnViewModel.swift:57,79` — **CORRIGÉ** |
| 6 | fluidité (suite) | compression JPEG synchrone sur main actor + `AsyncImage` sans cache/downsample | `ImageGenerationService.swift:146`, thumbs |
| 7 | UX attente 143 s | spinner nu, aucun temps estimé ni progression | `TryOnView.swift:288`, `QuickTryOnView.swift:733` |
| 8 | vêtements pas fidèles | modèle non adapté (pas de routing catégorie) + framing full-body imposé | voir §2 |

---

## 4. Statut des correctifs — TOUS LIVRÉS (build ✅ iPhone 17, 44 tests ✅)

| Correctif | Fichiers | Statut |
|---|---|---|
| Bug boutique vedette | `TryOnView(preselectedJewelry:)` + `.sheet(item:)` `PartnerDetailView` | ✅ |
| Reveal résultat animé | `withAnimation(springBounce)` `TryOnViewModel` | ✅ |
| Palette champagne | `gold #CA8A04→#C8A85A`, `goldLight→#EADFB8`, AccentColor, tint glass 0.2→0.12, FashionGroup.jewelry | ✅ |
| UX attente (143 s) | `GenerationProgressView` (anneau + compteur + étapes + estimation) → TryOnView & QuickTryOnView | ✅ |
| Routing générateur par catégorie | iOS `GenerationCategory` envoyé ; Edge **v25** `CATEGORY_PRIMARY` (bijou→flux-kontext, vêtement→nano-banana-pro, chaussure→gpt-image-2) | ✅ déployé |
| Framing bijoux | Edge `withTryOnFramingPrompt(category)` : bijou → gros plan zone (pas full-body) | ✅ déployé |
| Cascade dédupliquée | Edge : dédup par nom de modèle (−coût/latence) | ✅ déployé |
| Compression hors main actor | `tryOnEnriched` n'est plus `@MainActor` | ✅ |
| Community : commentaires reliés à l'image | `PostComment`, `CommentsSheet` (image présentée en tête), store VM, bouton actif | ✅ |

**Edge `tryon-generate` v24 → v25** déployée via MCP, `verify_jwt: true`, smoke-test OPTIONS 200 + POST 401 OK. Rétro-compatible : catégorie absente = comportement v24.

**Reste (hors scope de cette passe) :** downsample des `AsyncImage` thumbnails (gain mineur), test sur device réel des nouveaux modèles par catégorie (qualité visuelle réelle bijou/vêtement/chaussure).
