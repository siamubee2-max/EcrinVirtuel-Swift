# Écrin Virtuel — Monétisation & étude de marché

App d'essayage virtuel bijoux/mode par IA (FR-first). RevenueCat + StoreKit 2.
⚠️ Décisions de pricing **non encore figées** dans l'app (MARKETING_VERSION 1.0.0). Ce doc propose la grille.

---

## 1. Étude de marché

### 1.1 Le marché
- **Try-on virtuel (AR/IA)** en forte croissance, tiré par le e-commerce mode/beauté ; l'essayage **photoréaliste par IA générative** (sur la vraie photo de l'utilisateur) est une vague récente (2024-2026) qui dépasse l'AR « overlay ».
- **Bijou** = niche à **panier moyen élevé** et fort besoin de réassurance avant achat → l'essayage a une vraie valeur perçue.
- **France/Belgique** d'abord (ancrage MONI'ATTITUDE, Belgique) puis international.

### 1.2 Concurrents & positionnement
| Catégorie | Acteurs | Modèle | Limite vs Écrin |
|---|---|---|---|
| AR bijou/montre | Wanna (Wannaby), Perfect Corp/YouCam, Tangiblee | B2B widget e-commerce | AR overlay, pas photoréaliste sur photo perso ; pas d'app grand public FR |
| Try-on mode IA | Google « Try-on », Doji, Veesual, Pickle | freemium / B2B | mode surtout, **pas le bijou** ; pas de styling météo/garde-robe |
| Garde-robe / styling | Whering, Acloset, Indyx, Combyne | freemium €5-10/mo | gèrent la garde-robe mais **pas d'essayage IA photoréaliste** |
| Beauté AR | YouCam Makeup (Perfect Corp) | freemium massif | maquillage, pas bijou/tenue |

**Le trou que comble Écrin (USP)** : *seule app grand public FR à combiner* (a) **essayage IA photoréaliste bijoux ET tenues sur votre photo**, (b) **styling** (Look du Jour météo + garde-robe + teint), (c) **social/gaming**, (d) **bijoux d'artisans** (MONI'ATTITUDE). Personne ne fait les 4 ensemble.

### 1.3 Cible
Femmes 25-55, intérêt mode/bijou/cadeau ; acheteuses de bijoux hésitantes ; offreuses de cadeaux. FR/BE/CA-fr en cœur.

---

## 2. Économie unitaire (le chiffre qui décide tout)

**Coût réel par génération IA** (cascade Edge `tryon-generate`, mesuré dans le code) :
- standard `gpt-image-2-image-to-image` ≈ **$0.030** ; premium `nano-banana-pro` ≈ **$0.060** ; fallbacks $0.02-0.08.
- → **COGS ≈ $0.03–0.06 par essayage** (hors infra Supabase, négligeable).

**Commission Apple** : **15 %** (Small Business Program, <$1M/an) — sinon 30 %. Hypothèse 15 %.

> Conséquence : tout tier doit être pricé pour couvrir `nb_générations × ~$0.045` **+** marge **après** les 15 % d'Apple. Les quotas généreux (elite 500/mo, « lifetime illimité ») sont **dangereux**.

---

## 3. Grille d'abonnements proposée (RevenueCat)

| Tier | Quota IA/mois | Prix FR/BE (€) | COGS/mois (@$0.045) | Net après Apple 15 % | Marge approx. | Verdict |
|---|---|---|---|---|---|---|
| **Free** | 3 (essai) | 0 | ~$0.14 | 0 | acquisition | garder bas (anti-abus serveur déjà en place) |
| **Starter** | 20 | **4,99** | ~$0.90 | ~€4.24 (~$4.6) | ~$3.7 ✅ | sain |
| **Premium** ⭐ | 60 | **9,99** | ~$2.70 | ~€8.49 (~$9.2) | ~$6.5 ✅ | tier vedette |
| **Elite** | 300 *(↓ de 500)* | **29,99** | ~$13.5 | ~€25.5 (~$27.5) | ~$14 ✅ | **réduire 500→300** sinon marge fine |
| Crédits (conso.) | packs | 10→2,99 · 50→9,99 · 150→24,99 | $0.45 / $2.25 / $6.75 | — | ✅ | pour non-abonnés / dépassement |

**Annuel** : proposer Premium **79,99 €/an** (≈ -33 % vs mensuel) pour booster la LTV et lisser le churn.

### ⚠️ Risque critique — « Lifetime illimité »
Un **lifetime à prix fixe avec génération illimitée** = **COGS non borné à vie** → chaque utilisateur lourd vous coûte de l'argent pour toujours. **Ne pas l'offrir tel quel.** Options sûres :
- Lifetime = **gros pack de crédits** one-time (ex. 79,99 € → 250 crédits), **pas** d'illimité, OU
- Lifetime « Premium » avec **cap mensuel** (60/mo à vie), explicitement plafonné.
- Le statut **fondateur illimité** (déjà codé) doit rester réservé à ~2 comptes internes (c'est déjà le cas, et la liste est désormais côté serveur — M1).

---

## 4. Tarification par territoire
- **Base** : zone Euro (FR/BE) = grille §3.
- **US** : ~ parité numérique ($4.99 / $9.99 / $29.99) — psychologie de prix US.
- **UK** : £4.49 / £8.99 / £27.99.
- **Autres régions** : activer la **tarification automatique Apple par territoire** (ou PPP) pour ne pas surfacturer les marchés à faible pouvoir d'achat (cf. skill `asc-ppp-pricing` : `asc` price import / price schedule par pays). Garder les ratios.
- Configurer dans ASC : créer les **produits StoreKit** (abos auto-renouvelables `ecrin.starter.monthly`, `ecrin.premium.monthly`, `ecrin.premium.yearly`, `ecrin.elite.monthly` + consommables `ecrin.credits.10/50/150`), un **groupe d'abonnement** avec niveaux pour up/downgrade, et mapper les **entitlements RevenueCat** (`starter`/`premium`/`elite`).

## 5. Modèle de projection (illustratif — à calibrer)
Leviers : installs, taux free→payant, mix de tiers, ARPPU, churn, COGS.
- **Hyp. An 1 (FR-first, marketing modéré)** : 50 000 installs · **conversion 3 %** → 1 500 payants.
- Mix : 50 % Starter / 40 % Premium / 10 % Elite → **ARPPU ≈ 8,5 €/mo**.
- **MRR ≈ 12 750 € · ARR ≈ 153 k€** (brut). Moins COGS (~5-8 %) et Apple 15 % → **net ≈ 120-130 k€**.
- + revenus **crédits consommables** (non-abonnés) et future **commission boutique partenaire** (MONI'ATTITUDE, 15 % déjà dans le schéma `partner_brands`).
- **Sensibilité** : passer la conversion de 3 % → 5 % ≈ **+85 k€ ARR**. Le 1er écran/paywall (cf. PPO) et le Look du Jour (rétention) sont les leviers #1.

## 6. Mécanique paywall & rétention (renvoi)
- Implémentation StoreKit/paywall : skill `storekit` (le code paywall existe ; **bug C4 corrigé cette session** — reconnaît désormais n'importe quel entitlement actif).
- **Paywall émotionnel** déjà codé (montre les essayages de la session) → bon pour la conversion ; A/B-tester via PPO.
- Déclencheur d'upsell : après épuisement des 3 essais gratuits, et après un « beau » résultat partagé.
- **Crédits = source de vérité serveur** (M0/M1) → pas de bypass ; conso atomique.

## 7. À décider (toi)
- [ ] Valider la grille (et **réduire Elite 500→300**, **abandonner le lifetime illimité**).
- [ ] Prix annuel Premium ?
- [ ] Activer Apple Small Business Program (15 %) — **à faire**, gros impact marge.
- [ ] Créer les produits StoreKit + groupe d'abonnement dans ASC, mapper RevenueCat.
- [ ] Tarification auto par territoire (ou PPP via `asc`).
