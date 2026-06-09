# First-Run Experience & Conversion Funnel Redesign

**Date:** 2026-05-23  
**Statut:** Approuvé  
**Objectif:** Maximiser les abonnements pour toutes les audiences (investisseurs, marques, utilisatrices, presse)

---

## Contexte & Problème

L'app L'Écrin Virtuel dispose de toutes les features pour convertir, mais le funnel entre "première ouverture" et "premier paiement" n'est pas assez maîtrisé pour garantir le moment WOW. Les 3 crédits gratuits sont en or uniquement si le premier résultat est bluffant — sans wizard guidé, l'utilisatrice peut gaspiller un crédit sur une mauvaise photo ou un mauvais bijou et ne jamais revenir.

---

## Solution — 4 Sections Enchaînées

### Section 1 — Onboarding Cinématique

**Remplace :** 3 slides statiques texte/icône  
**Durée :** < 30 secondes · entièrement skippable

**4 écrans :**

1. **Splash gold** (1,5s auto)
   - Animation WeddingParticlesCanvas existante réutilisée
   - Progress bar animée
   - Texte "L'ÉCRIN VIRTUEL" en letterspacing doré
   - Auto-skip vers écran 2

2. **Before/After interactif**
   - Slider drag pour comparer photo brute / résultat IA
   - Texte : "Essayez avant d'acheter · IA en 8 secondes"
   - Auto-avance à 2,5s si pas d'interaction

3. **Grid 4 catégories**
   - Bagues · Colliers · Bracelets · Montres en 2×2
   - Animations d'entrée décalées (stagger 0,1s)
   - Texte : "Tous les bijoux, sur vous"

4. **CTA plein écran**
   - Bouton principal : "ESSAYER MAINTENANT →" → wizard guidé
   - Bouton secondaire discret : "Se connecter"
   - Sous-texte : "3 essais offerts · Aucune carte requise"
   - Bouton Skip en haut à droite sur tous les écrans

**Comportements :**
- `hasCompletedOnboarding` dans UserDefaults — jamais affiché deux fois
- Skip à tout moment → écran CTA directement
- "Essayer maintenant" → ne crée pas de compte, lance wizard directement

---

### Section 2 — Wizard Premier Essayage Guidé

**Objectif :** Garantir un résultat bluffant au premier essayage  
**Déclenché par :** CTA onboarding OU première ouverture sans onboarding

**Étape 1 — Photo guidée**
- Guide photo affiché avant la sélection :
  - ✓ Fond neutre ou clair
  - ✓ Lumière naturelle de face
  - ✓ Buste visible, pas de chapeau
- Score qualité photo en temps réel après sélection :
  - 🟢 Excellent — luminosité OK, visage détecté, fond clair
  - 🟡 Correct — génération possible mais résultat moyen possible
  - 🔴 Améliorer — message d'aide contextuel avant de continuer
- L'utilisatrice ne peut pas continuer sur 🔴 sans confirmation explicite

**Étape 2 — Bijou Star pré-sélectionné**
- Affiche les 4 bijoux catalogue avec le meilleur track record de résultats
- Le bijou STAR est pré-sélectionné (badge "STAR ✦")
- Sélection changeable librement
- Le bijou star est celui avec le meilleur prompt + le plus de générations réussies historiquement (défini statiquement dans `WizardConfig.swift` au lancement, mis à jour via remote config)

**Étape 3 — Loading luxe**
- Animation gold concentrique (3 cercles pulsés)
- Micro-texte décrivant l'étape en cours :
  - "Analyse de votre photo…"
  - "Application du bijou…"
  - "Rendu final…"
- Citation luxe : *"Chaque bijou est placé avec précision pour respecter votre morphologie et votre teinte de peau"*
- Durée cible : < 12 secondes

**Données techniques :**
- Réutilise `QuickTryOnViewModel` + `ImageGenerationService`
- `isFirstRun: Bool` dans `AppState` pour conditionner l'affichage du wizard
- Le wizard s'affiche une seule fois — stocké dans UserDefaults `hasCompletedFirstRun`

---

### Section 3 — Post-Résultat + Share Loop

**4 états enchaînés selon les crédits restants**

**① Révélation**
- Animation d'apparition de l'image (scale + fade, 0,6s)
- Gold particles burst au reveal (WeddingParticlesCanvas réutilisé)
- Boutons visibles immédiatement :
  - Primaire : "PARTAGER →" (gold, pleine largeur)
  - Secondaires : ♡ Sauvegarder · ⬇ Télécharger
  - Tertiaires : "Réessayer" · "Bijou suivant →"

**② Share Sheet branded**
- Export image avec watermark "L'ÉCRIN VIRTUEL · ecrin.app"
- Cadre doré autour du résultat
- Destinations directes : Instagram Stories · WhatsApp · Twitter/X · Télécharger
- Le watermark est non-supprimable sur le plan gratuit, optionnel à partir du plan Starter

**③ Nudge "Encore un ?"** (si crédits > 0)
- Affiche le nombre de crédits restants
- Propose 2 bijoux tendance du catalogue (séléction algorithmique ou manuelle)
- Lien vers catalogue complet en tertiaire
- Objectif : garder l'utilisatrice dans le flow, pas retour accueil

**④ Paywall émotionnel** (si crédits = 0)
→ voir Section 4

**Mécanique virale :**
Chaque partage Story/WhatsApp inclut le watermark + lien. Une spectatrice clique → App Store → télécharge → vit le même wizard → partage à son tour. Acquisition organique sans budget.

---

### Section 4 — Paywall Émotionnel Redesign

**Remplace :** paywall générique avec icône 🔒 et prix en premier

**Structure du nouvel écran :**

1. **Titre émotionnel** (pas "Passez Premium")  
   → *"Vous avez trouvé votre style. Continuez l'histoire."*

2. **Leurs propres créations** (3 vignettes)  
   - 2 images générées + 1 case vide avec "∞ illimité"
   - Continuité émotionnelle directe avec ce qu'elles viennent de vivre

3. **Social proof**  
   → "+12 400 utilisatrices ont découvert leurs bijoux parfaits"  
   → Avatars empilés

4. **Plans visibles (2 affichés, tous accessibles)**  
   Tarifs tels que définis dans `PaywallView.swift` — inchangés :
   - **Starter** · 7,99€/mois · 30 essayages
   - **Premium** · 14,99€/mois · 70 essayages ← badge "POPULAIRE"
   - **Elite** · 24,99€/mois · 100 essayages (accessible via scroll ou "Voir plus")
   - **Annuel** : plans annuels accessibles via toggle mensuel/annuel
   - **Fondateur** : accessible depuis profil uniquement

5. **CTA principal**  
   → "COMMENCER — 7 JOURS OFFERTS"  
   → Sous-texte : "Résiliable à tout moment · Apple Pay accepté"

6. **Secondaires**  
   → "Voir tous les forfaits" · "Restaurer mes achats"

**Ce qui change :**
- Prix jamais le premier élément visible
- 2 plans côte à côte = ancrage (Starter rend Premium raisonnable)
- 7 jours offerts réduit la friction d'entrée
- Leurs propres images = lien émotionnel direct

---

### App Store Screenshots — 5 Visuels

Format principal : **1320×2868px** (iPhone 6.9" Pro Max)  
Format secondaire : iPad Pro 13" requis pour soumission

| # | Titre | Contenu | Message |
|---|-------|---------|---------|
| 1 | Before/After | Slider interactif | "Essayez avant d'acheter" |
| 2 | Résultat IA | Bijou porté photoréaliste | "Résultats photoréalistes · 8 secondes" |
| 3 | Dressing Virtuel | Grid de looks sauvegardés | "Votre dressing virtuel" |
| 4 | Catalogue Artisans | Boutique partenaire | "Bijoux artisanaux français" |
| 5 | Partage Social | Export branded Story | "Partagez vos looks" |

**Règles de production :**
- Fond : `Color(hex: "#0d0d0a")` — identique à l'app
- Texte : SF Pro Display Bold, couleur `#f5c842` pour les titres
- Jamais de prix hardcodé sur les screenshots (guideline Apple)
- Produits avec de vraies photos IA (pas d'emoji placeholder)

---

## Architecture Technique

### Nouveaux fichiers

| Fichier | Rôle |
|---------|------|
| `Sources/Features/Onboarding/CinematicOnboardingView.swift` | Onboarding 4 écrans avec slider before/after |
| `Sources/Features/Onboarding/BeforeAfterSliderView.swift` | Composant slider interactif réutilisable |
| `Sources/Features/QuickTryOn/FirstRunWizardView.swift` | Wizard 3 étapes guidé |
| `Sources/Features/QuickTryOn/PhotoQualityAnalyzer.swift` | Analyse qualité photo (luminosité, détection visage) |
| `Sources/Features/QuickTryOn/WizardConfig.swift` | Config bijou star + sélection catalogue |
| `Sources/Features/SocialExport/BrandedShareSheet.swift` | Share sheet avec watermark L'Écrin Virtuel |
| `Sources/Features/Paywall/EmotionalPaywallView.swift` | Nouveau paywall avec images utilisatrice |

### Fichiers modifiés

| Fichier | Changement |
|---------|-----------|
| `OnboardingView.swift` | Remplacé par `CinematicOnboardingView` |
| `PaywallView.swift` | Ajout de `EmotionalPaywallView` comme vue principale |
| `AppState.swift` | Ajout `isFirstRun: Bool`, `hasCompletedFirstRun: Bool` |
| `RootView.swift` / `ContentView.swift` | Conditionne affichage wizard au premier lancement |
| `TryOnViewModel.swift` | Hook post-résultat → déclenche `BrandedShareSheet` |
| `QuickTryOnViewModel.swift` | Idem |

### Réutilisation

- `WeddingParticlesCanvas` → réutilisé dans splash onboarding et reveal résultat
- `CreditsManager` → conditionne affichage nudge vs paywall
- `SocialExportView` existant → étendu avec le template branded

---

## Critères de succès

| Métrique | Cible |
|----------|-------|
| Taux de complétion onboarding | > 70% |
| Taux de complétion wizard first-run | > 85% |
| Taux de partage post-résultat | > 25% |
| Conversion free → payant (J7) | > 8% |
| Note App Store | > 4,6 ⭐ |

---

## Ce qui est hors scope

- Refonte de la navigation principale
- Nouveau système de crédits (déjà implémenté)
- Backend Analytics (PostHog déjà intégré)
- Contenu des screenshots (nécessite vraies photos IA — livré séparément)
