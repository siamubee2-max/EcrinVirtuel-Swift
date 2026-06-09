# HANDOFF — L'Écrin Virtuel

État du projet (`/Volumes/EVO/EcrinVirtuel-Swift/`).

---

## ✅ Checklist session (1 juin 2026 — « fais tout »)

| # | Tâche | Statut |
|---|--------|--------|
| 1 | Projet Supabase canonique `itjtshfzpknlzownpwte` | ✅ `Secrets.xcconfig`, deploy script, lien CLI |
| 2 | `tryon-generate` v16 (9:16, GPT Image 2 i2i + cascade) | ✅ Live — `curl` → **401** sans JWT |
| 3 | Migration `004_preferred_gender` | ✅ Appliquée via MCP |
| 4 | Migrations 005/006 | ✅ Déjà en prod (`atomic_consume_credits`, `006_remove_community_post_email`) |
| 5 | Build Debug iOS | ✅ **BUILD SUCCEEDED** |
| 6 | Install + launch iPhone Tof | ✅ `00008110-0002442C019A801E` → `com.ecrin.jewelry` |
| 7 | Tests unitaires météo | ✅ **14/14** |
| 8 | Secrets Edge (Dashboard) | ⚠️ Page ouverte — confirmer `KIE_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY` à la main |
| 9 | Nettoyage mannequin duplicate | ⏭️ Optionnel (SQL Dashboard) |

---

## Backend Supabase (`itjtshfzpknlzownpwte` — Dashboard **lecrin-replit**)

> **Correction 1 juin 2026** : l’app pointait par erreur vers `amafgweelzayrjzemdtq` (« les crocs malins », autre produit). Projet canonique Écrin Virtuel = **`itjtshfzpknlzownpwte`**. `Secrets.xcconfig`, `scripts/deploy-tryon.sh` et lien CLI alignés. `tryon-generate` **v16** déployée (GPT Image 2 i2i, ratio **9:16**, cascade Kie/Gemini/OpenAI).

| Item | Statut |
|------|--------|
| `tryon-generate` (JWT, Kie GPT Image 2 9:16 + fallbacks) | ✅ Live **v16** — `curl` → 401 sans Bearer |
| `credit-generations` (RevenueCat → quotas) | ✅ Live v2 (code non versionné ici) |
| `delete-user-account` | ✅ Live v1 |
| Vue `clothing_catalog` / RLS wardrobe | ✅ |
| Migration `004_preferred_gender.sql` | ✅ Colonne `users.preferred_gender` en prod |

### Déploiement Edge Function (quand CLI OK)

```bash
supabase login   # interactif, une fois
# ou: export SUPABASE_ACCESS_TOKEN=...
./scripts/deploy-tryon.sh
```

Secrets Dashboard (bloquant génération si absents) :  
https://supabase.com/dashboard/project/itjtshfzpknlzownpwte/functions/secrets  
→ `GOOGLE_API_KEY`, `OPENAI_API_KEY`

---

## iOS App

| Item | Statut |
|------|--------|
| Build Debug iPhone physique | ✅ **BUILD SUCCEEDED** |
| Install + launch iPhone de Tof | ✅ 25 mai ~15:53 |
| Look du Jour (Open-Meteo, scoring, carte dans `TryOnView`) | ✅ |
| Genre : UserDefaults + upsert Supabase `users.preferred_gender` | ✅ code Swift |
| Tests `WeatherConditionTests` + `WeatherLookRecommenderTests` | ✅ 14/14 |

### Commandes utiles

```bash
# Build device
cd /Volumes/EVO/EcrinVirtuel-Swift
xcodebuild -scheme EcrinVirtuel \
  -destination 'platform=iOS,id=00008110-0002442C019A801E' \
  -configuration Debug build

# Install + launch
APP=~/Library/Developer/Xcode/DerivedData/EcrinVirtuel-*/Build/Products/Debug-iphoneos/EcrinVirtuel.app
xcrun devicectl device install app --device 00008110-0002442C019A801E "$APP"
xcrun devicectl device process launch --device 00008110-0002442C019A801E com.ecrin.jewelry

# Tests simulateur
xcodebuild -scheme EcrinVirtuel \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' \
  -only-testing:EcrinVirtuelTests test
```

---

## Weather Look — implémentation

Fichiers principaux :

- Services : `LocationService`, `WeatherService`, `WeatherLookRecommender`
- UI : `LookDuJourCard`, `LookDuJourViewModel`, `WeatherBadge`, `GenderPickerSheet`, `CitySearchSheet`
- Spec : `docs/specs/2026-05-24-weather-look-localization.md`

**Phase 6 (Widget iOS)** : non implémenté (hors scope session).

---

## Mannequins / catalogue

- Catalogue mode : ~95 articles (`wardrobe_models` / vue `clothing_catalog`)
- Mannequins : inventaire historique 13 `body_parts` dans HANDOFF mai 22 ; objectif mentionné **33 `corps_entier`** — à reconfirmer via Dashboard si besoin
- Doublon « Buste 2 » / « Modèle Rousse » : nettoyage SQL optionnel non exécuté

---

## ⚠️ Actions manuelles restantes

1. **Secrets Edge** : [Functions → Secrets](https://supabase.com/dashboard/project/itjtshfzpknlzownpwte/functions/secrets) — confirmer `KIE_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`
2. **Tester essayage** sur l’iPhone (app relancée) : multi-vues / essayage rapide → image **9:16** (pas carré)
3. **RevenueCat webhook** → `https://itjtshfzpknlzownpwte.supabase.co/functions/v1/revenuecat-webhook` (si pas déjà fait)
4. **TestFlight / App Store** : incrémenter `CURRENT_PROJECT_VERSION` avant upload
5. Republier `tryon-generate` : `./scripts/deploy-tryon.sh` (après `supabase login`) ou MCP `deploy_edge_function`

---

## Sécurité

- Pas de secrets dans le dépôt (`Secrets.xcconfig` gitignored)
- `tryon-generate` refuse les requêtes sans JWT utilisateur valide
- Localisation : Open-Meteo / ipapi.co uniquement (pas de lat/lon vers Supabase)

---

*Dernière mise à jour : 1 juin 2026 — projet `itjtshfzpknlzownpwte`, tryon v16, migration 004, build + install iPhone + 14 tests OK.*

---

## Mise à jour agent Cursor (25 mai 2026, ~16:24)

| Action tentée | Résultat |
|---------------|----------|
| `supabase projects list` / `deploy-tryon.sh` | ❌ Pas de `SUPABASE_ACCESS_TOKEN` ni `~/.supabase/access-token` |
| Terminal Claude (12.txt) | Aucune activité `supabase login` |
| `tryon-generate` POST sans JWT | ✅ **401** (fonction live, JWT requis) |
| `revenuecat-webhook` POST vide | ✅ Endpoint répond (**500** sans payload valide — pas 404) |
| Migration `004_preferred_gender.sql` | ❌ Non appliquée (CLI non auth) — SQL ci-dessous |
| Build Debug iPhone | ✅ **BUILD SUCCEEDED** |
| Install + launch `com.ecrin.jewelry` | ✅ UDID `00008110-0002442C019A801E` et CoreDevice `D597B755-…` |
| Tests météo simulateur | ✅ 14/14 passés |

### SQL à coller dans [SQL Editor](https://supabase.com/dashboard/project/itjtshfzpknlzownpwte/sql/new) si pas de CLI

```sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS preferred_gender TEXT
  CHECK (preferred_gender IN ('femme', 'homme', 'unisexe'));

COMMENT ON COLUMN users.preferred_gender IS 'Genre pour recommandations Look du Jour (femme/homme/unisexe)';
```

### Secrets Edge (vérification manuelle Dashboard uniquement)

[Functions → Secrets](https://supabase.com/dashboard/project/itjtshfzpknlzownpwte/functions/secrets) : confirmer `GOOGLE_API_KEY` et `OPENAI_API_KEY` présents (pas vérifiable sans accès Dashboard/API management authentifié).

