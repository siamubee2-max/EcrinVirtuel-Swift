# Écrin Virtuel — Plan de captures d'écran App Store (à produire + uploader dans ASC)

App iPhone-only (`TARGETED_DEVICE_FAMILY = "1"`) → **pas de captures iPad requises**.

## Jeux de tailles requis (iOS actuel)
| Display | Appareil de référence | Pixels (portrait) | Statut |
|---|---|---|---|
| **6.9"** | iPhone 16 Pro Max | **1320 × 2868** | **REQUIS** (jeu primaire) |
| 6.5" | iPhone 15 Plus / 14 Pro Max | 1242 × 2688 | Optionnel (Apple peut dériver du 6.9") |
| 6.1" / autres | — | — | Optionnel |
- Jusqu'à **10 captures** par jeu/localisation. **Les 3 premières font 80 % de la décision.**
- Pas d'écran d'onboarding/splash/chargement dans les 3 premières.
- Direction artistique : marque « Écrin » = **or sur fond sombre**, élégant/joaillerie. Légende **2-5 mots** en haut, 1 ligne bénéfice en bas. Verbes d'action.

## Le jeu ordonné (8 captures, légendes orientées bénéfice — FR)

| # | Écran | Légende haut | Sous-ligne | Pourquoi ce slot |
|---|---|---|---|---|
| **1** | Essayage : un **collier** rendu sur une vraie photo (avant/après ou résultat 9:16) | **Essayez sur votre photo** | Le bijou sur vous, en quelques secondes — par IA | Proposition de valeur #1 |
| **2** | **Look du Jour** (carte météo + tenue suggérée) | **Votre tenue du jour** | Suggérée chaque matin selon la météo | Différenciateur cœur |
| **3** | **Garde-robe** intelligente (grille de vêtements numérisés) | **Toute votre garde-robe** | Numérisez, composez, essayez | 3e feature la plus forte |
| 4 | Studio **multi-poses / multi-vues** | **Sous tous les angles** | Voyez le rendu de face, de profil | Démontre la qualité |
| 5 | **Conseil teint** / sous-ton de peau (carte score métal) | **Le métal qui vous va** | Or, argent, doré : trouvez le vôtre | Personnalisation |
| 6 | **Communauté & défis** (feed + badges/niveaux) | **Progressez en style** | Défis, badges, niveaux d'élégance | Engagement/rétention |
| 7 | **Boutique MONI'ATTITUDE** (bijoux artisanaux) | **Bijoux d'artisans** | Essayez avant de craquer | Preuve + monétisation |
| 8 | **Mode Cadeau / Mariage** (coffret virtuel partageable) | **Le cadeau qui se voit** | Créez et offrez un coffret virtuel | Cas d'usage saisonnier |

## App Preview (vidéo, optionnel mais fortement recommandé)
- Occupe le slot 1 → choisir une **1re frame** qui tient comme capture autonome (écran essayage collier).
- 15-30 s : photo importée → choix bijou → génération → résultat 9:16 → Look du Jour → garde-robe.
- Montrer la feature cœur dans les **5 premières secondes**.

## Comment PRODUIRE les captures (2 voies)

### Voie A — capture déterministe via le harnais `-uitest` (recommandé pour la base)
Le mode `-uitest -uitest-auth` (M0/M3) lance l'app **authentifiée, avec données mock, sans backend** ;
les écrans cœur ont des `accessibilityIdentifier` (M3). Un test XCUITest peut naviguer + `app.screenshot()`
chaque écran de façon reproductible (utile pour itérer vite + localiser).
- ⚠️ Limite : en mode mock, le résultat d'essayage est une image **placeholder** (pas une vraie génération IA),
  et le simulateur ne fournit pas le rendu marketing. → Pour les slots 1/4 (résultats IA), capturer depuis
  un **vrai device** avec de vraies générations, puis habiller.
- Génère le bon ratio en lançant le simulateur **iPhone 16 Pro Max** (6.9", 1320×2868).

### Voie B — capture device réelle + habillage (pour le rendu final)
1. Vraies générations sur device (essayages réels, photos de modèles avec consentement / photos libres de droit).
2. Habillage : fond or-sur-sombre, légendes, cadre device léger (Figma/Sketch/Fastlane frameit).
3. Export aux tailles requises ci-dessus.

## À faire
- [ ] Capturer les 8 écrans en 1320×2868 (6.9").
- [ ] Habiller avec légendes FR (cf. tableau) + direction artistique or/sombre.
- [ ] (Optionnel) vidéo App Preview, 1re frame = essayage collier.
- [ ] Localiser les légendes par marché avant d'ajouter EN.
- [ ] Cross-check : chaque capture correspond à un écran RÉEL de la build soumise (sinon rejet).
