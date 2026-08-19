# Écrin Virtuel — Fiche de distribution App Store Connect (à coller dans ASC)

App : **L'Écrin** (bundle `com.ecrin.jewelry`) · Team `GG9U76Z4X7` · iOS 18+ · FR-first
Version 1.0.0 · Partenaire MONI'ATTITUDE (bijoux artisanaux, Belgique)

> Compliance : vérifier chaque champ contre le skill `app-store-review` (limites de caractères,
> écrans requis, déclencheurs de rejet) AVANT soumission. Cette fiche est la **stratégie + le contenu** ;
> les garde-fous de conformité sont dans `app-store-review`.

---

## 1. Identité de l'app (App Information)

| Champ | Valeur | Notes |
|---|---|---|
| **Nom** (≤30) | `L'Écrin Virtuel : Bijoux IA` | 27 car. Marque + mot-clé indexé « Bijoux IA ». |
| **Sous-titre** (≤30) | `Essayage virtuel & garde-robe` | 29 car. Proposition de valeur. Aucun mot dupliqué du nom. |
| **Catégorie principale** | **Lifestyle** | Cœur = essayage/style perso ; moins saturé que Shopping. |
| **Catégorie secondaire** | **Shopping** | Boutique partenaire / try-before-buy. |
| **Classification d'âge** | **12+** | UGC communauté (modération + signalement requis, déjà en place : `post_reports`, modération IA M1). Photos perso = pas de contenu sensible par design. |
| **Droits/Copyright** | `© 2026 L'Écrin` | |
| **Bundle ID** | `com.ecrin.jewelry` | |
| **SKU** | `ECRIN-IOS-001` | |

## 2. Localisations
Principale **Français (France)**. Ajouter **Français (Canada)**, **Anglais (R.-U./É.-U.)** en v1.1.
Les métadonnées EN doivent être **réécrites** (pas traduites) avec recherche de mots-clés par marché.

## 3. URLs & contact
| Champ | Valeur |
|---|---|
| Support URL | `https://ecrin.app/support` *(à créer — obligatoire)* |
| Marketing URL | `https://ecrin.app` |
| Privacy Policy URL | `https://ecrin.app/privacy` *(déjà référencée dans Info.plist ; héberger la page `web/public/ecrin/privacy.html`)* |
| Conditions (EULA) | EULA standard Apple, ou `https://ecrin.app/terms` (`web/public/ecrin/terms.html`) |

## 4. Texte promotionnel (≤170, modifiable sans soumission)
> `Nouveau : essayez n'importe quel bijou ou tenue sur VOTRE photo en quelques secondes grâce à l'IA. Look du Jour selon la météo + garde-robe intelligente. ✨`
(157 car.) — à faire tourner par saison/feature (cf. §10).

## 5. Mots-clés (champ 100 car., virgules sans espaces, singulier, pas de doublon nom/sous-titre/catégorie)
Exclus car déjà indexés : *bijou, ia, essayage, virtuel, garde-robe, lifestyle, shopping*.
```
essai,collier,bague,bracelet,boucle,mode,tenue,look,miroir,vetement,style,relooking,joaillerie,cadeau,coffret,parure,montre,accessoire,dressing,outfit
```
(99 car.) — prioriser **intention** (essai/collier/bague/tenue/dressing) sur volume. Itérer chaque release via Apple Search Ads + App Analytics.

## 6. Description (FR — structure accroche / features / preuve / CTA ; pas de markdown, puces Unicode)

```
Essayez chaque bijou et chaque tenue sur VOTRE propre photo — sans rien acheter à l'aveugle. L'Écrin transforme votre téléphone en miroir d'essayage par IA, photoréaliste, en quelques secondes.

Comment ça marche
• Prenez ou importez une photo, choisissez un bijou ou un vêtement, et l'IA vous l'enfile au format portrait 9:16.
• Boucles, colliers, bagues, bracelets, tenues complètes : essayez avant d'offrir ou d'acheter.

Vos fonctions préférées
• Look du Jour — une tenue suggérée chaque matin selon la météo de votre ville.
• Garde-robe intelligente — numérisez vos vêtements et composez des tenues.
• Studio multi-poses & multi-vues pour voir le rendu sous tous les angles.
• Conseil teint & sous-ton de peau pour trouver les métaux qui vous subliment.
• Communauté & défis style, badges et niveaux pour progresser en élégance.
• Mode Cadeau & Mariage : créez et partagez des coffrets virtuels.

Bijoux d'artisans
• Découvrez les créations MONI'ATTITUDE — bijoux artisanaux en pierres semi-précieuses — et essayez-les avant de craquer.

Respect de votre vie privée
• Vos photos servent uniquement à générer votre essayage. Pas de revente de données.

Téléchargez L'Écrin et offrez-vous le plus beau des miroirs. ✨
```

> **Cross-check conversion** : chaque promesse ci-dessus DOIT correspondre à un écran réel (cf. plan captures). Ne pas promettre une feature absente de la build soumise.

## 7. Nouveautés de cette version (What's New, v1.0.0)
```
Bienvenue dans L'Écrin ✨ Essayage de bijoux et de tenues par IA sur votre photo, Look du Jour météo, garde-robe intelligente, communauté style et boutique d'artisans. C'est notre toute première version — dites-nous tout !
```

## 8. Confidentialité (App Privacy "nutrition label") — réponses à déclarer
D'après le code (`PrivacyInfo.xcprivacy`, Info.plist) :
| Donnée | Collectée ? | Usage | Liée à l'identité | Tracking |
|---|---|---|---|---|
| Photos/Vidéos (perso) | Oui | Fonctionnalité de l'app (génération essayage) | Non (idéalement) | Non |
| Email / compte (Apple, OTP) | Oui | Authentification | Oui | Non |
| Localisation approximative | Oui | Look du Jour (météo) — via ipapi/Open-Meteo, **pas** stockée | Non | Non |
| Achats (RevenueCat) | Oui | Gestion abonnement | Oui | Non |
| Identifiants (user id) | Oui | App fonctionnement | Oui | Non |
- **ATT** : aucun tracking cross-app déclaré → pas de prompt ATT requis (confirmer : pas de SDK pub/attrib tiers actif). Si RevenueCat/analytics font de l'attribution, revoir.
- Permissions Info.plist déjà rédigées (caméra, photothèque, localisation) — bon.

## 9. Informations de App Review (notes au reviewer)
```
Compte de démo : créez un compte via "Connexion par e-mail" (code OTP à 6 chiffres) OU Sign in with Apple. 
Compte de test fourni : review@ecrin.app / OTP envoyé à la demande (ou compte de test dédié à créer dans ASC > App Review).
Parcours à tester : onglet Essayage → importer une photo (une photo de test est fournie) → choisir un bijou → générer (≈20–60 s, génération IA via backend). 
La génération d'image passe par un proxy serveur sécurisé (clés IA jamais dans l'app). 
UGC communauté : modération automatique (catégories interdites bloquées) + signalement (post_reports) + masquage — conforme Guideline 1.2.
Achats : abonnements auto-renouvelables + crédits consommables (RevenueCat/StoreKit2). Sandbox testable.
Suppression de compte : Profil → Supprimer mon compte (Guideline 5.1.1(v), supprime toutes les données + le compte auth).
```
- **Pré-requis review** : Support URL live, Privacy page live, paywall fonctionnel en sandbox, et — si App Attest activé (M4) — laisser `APP_ATTEST_MODE=off` pour la review (sinon risque de blocage si non validé device).

## 10. Plan de rotation (promotional text / In-App Events)
- Lancement → texte promo §4.
- Saisonnier : « Bijoux de fête », « Look de mariage » (printemps/été), « Cadeaux de Noël » (déc.).
- **In-App Events** (cartes Search/Today) : « Défi Style de la semaine » (Challenge), « Nouvelle collection MONI'ATTITUDE » (Premiere). Nom ≤30 / desc courte ≤50 / longue ≤120 / image 16:9.

## 11. Custom Product Pages (jusqu'à 70 ; mots-clés assignés = visibilité search)
| Page | Audience / canal | 1re capture | Promo | Mesure |
|---|---|---|---|---|
| `Search-EssayageBijoux` | Search Ads « essayage bijou » | écran essayage collier | « Essayez le bijou sur votre photo » | tap-through, CR |
| `Social-LookDuJour` | Insta/TikTok | Look du Jour météo | « Votre tenue du jour, par IA » | CR par campagne |
| `Cadeau-Coffret` | saison cadeaux | Mode Cadeau | « Le cadeau qui se voit avant de s'offrir » | installs attribués |

## 12. Product Page Optimization (1re expé)
- **Hypothèse** : un 1er écran « essayage collier sur photo réelle » convertit mieux qu'un écran « Look du Jour ».
- **Traitements** (≤3) : T1 ordre actuel · T2 essayage collier en slot 1 · T3 idem + légende bénéfice.
- **Locales** : FR (FR). **Métrique** : taux de conversion impression→téléchargement. **Règle** : adopter à ≥90 % de confiance, min. 7 jours.
