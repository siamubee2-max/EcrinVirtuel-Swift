# Écrin Virtuel — Métadonnées ASO localisées v1.1 (en-US, en-GB, fr-CA)

Complément de `2026-06-21-ecrin-virtuel-asc-fiche-distribution.md` (§2 : les métadonnées EN
sont **réécrites** pour chaque marché, pas traduites). Toutes les longueurs ci-dessous sont
vérifiées par script : nom ≤30, sous-titre ≤30, promo ≤170, mots-clés ≤100, sans doublon
entre nom / sous-titre / champ mots-clés d'une même locale.

À ajouter dans ASC → App Information → Localizations au moment de la v1.1 (ou dès la v1.0
si on veut couvrir les stores anglophones immédiatement — les champs sont prêts).

---

## 1. English (U.S.) — `en-US`

| Champ | Valeur | Long. |
|---|---|---|
| **Name** | `L'Écrin: AI Jewelry Try-On` | 26/30 |
| **Subtitle** | `Virtual wardrobe & outfits` | 26/30 |

**Promotional text** (136/170)
```
New: try any jewel or outfit on YOUR photo in seconds with AI. Daily weather-based Look of the Day + a smart wardrobe that styles you. ✨
```

**Keywords** (99/100 — no overlap with name/subtitle terms)
```
necklace,earrings,ring,bracelet,fashion,style,dress,mirror,gift,wedding,clothes,look,stylist,bridal
```

**Description**
```
Try every piece of jewelry and every outfit on YOUR own photo — no more buying blind. L'Écrin turns your phone into a photorealistic AI fitting mirror, in seconds.

How it works
• Take or import a photo, pick a jewel or a garment, and the AI puts it on you in 9:16 portrait format.
• Earrings, necklaces, rings, bracelets, full outfits: see it on you before you buy or gift it.

Your favorite features
• Look of the Day — an outfit suggested every morning based on your city's weather.
• Smart wardrobe — digitize your clothes and compose outfits.
• Multi-pose & multi-angle studio to see the result from every side.
• Skin-tone & undertone advice to find the metals that flatter you most.
• Style community & challenges, badges and levels to grow your elegance.
• Gift & Wedding mode: create and share virtual gift boxes.

Artisan jewelry
• Discover MONI'ATTITUDE creations — handcrafted jewelry with semi-precious stones — and try them on before falling for them.

Your privacy, respected
• Your photos are used only to generate your try-on. No data resale.

Download L'Écrin and treat yourself to the most beautiful mirror. ✨
```

**What's New (v1.1)**
```
Welcome to L'Écrin ✨ AI try-on for jewelry and outfits on your own photo, weather-based Look of the Day, smart wardrobe, style community and an artisan boutique. Tell us what you think!
```

---

## 2. English (U.K.) — `en-GB`

Identique à `en-US` **sauf l'orthographe britannique** (« jewellery ») :

| Champ | Valeur | Long. |
|---|---|---|
| **Name** | `L'Écrin: AI Jewellery Try-On` | 28/30 |
| **Subtitle** | `Virtual wardrobe & outfits` | 26/30 |

- **Keywords** : mêmes 99 car. que `en-US` (les termes génériques necklace/earrings/etc. sont
  identiques dans les deux marchés ; « jewellery » est déjà indexé par le nom en-GB, « jewelry »
  par le nom en-US — les deux graphies sont donc couvertes sans gaspiller le champ).
- **Promotional text / Description / What's New** : reprendre `en-US` en remplaçant
  `jewelry` → `jewellery` (3 occurrences dans la description).

---

## 3. Français (Canada) — `fr-CA`

Reprendre la fiche fr-FR à l'identique (nom, sous-titre, promo, description, nouveautés,
mots-clés) — le vocabulaire de la fiche est neutre (aucun terme franco-français marqué).
Deux nuances facultatives si on veut optimiser plus tard :
- « magasiner » est un terme de recherche fort au Québec → candidat pour une itération du
  champ mots-clés (remplacer `essai`).
- Les prix/exemples restent gérés par Apple (devise CAD automatique).

---

## 4. Rappels d'exécution

- Chaque localisation ASC a ses **propres** nom/sous-titre/mots-clés → coller par locale.
- Screenshots : les 6 captures 6.9" actuelles (UI française) sont acceptables pour lancer
  en-US/en-GB, mais prévoir des captures avec UI anglaise dès que l'app est localisée EN
  (à ce jour l'app est FR-first — vérifier l'état de la localisation EN in-app avant
  d'activer ces fiches, pour ne pas promettre une langue absente : Guideline 2.3).
- Apple Search Ads : dupliquer les campagnes par storefront (US/UK/CA-fr) avec les
  mots-clés ci-dessus comme base exact-match.
