# Spec : Mode Localisation & Analyse Météo → Look Adapté
**Fichier :** `docs/specs/2026-05-24-weather-look-localization.md`  
**Statut :** Draft — Phase 1 (design uniquement, pas d'implémentation)  
**Auteur :** Code Architect  
**Date :** 2026-05-24

---

## 1. Vue d'ensemble & Motivation produit

L'Écrin Virtuel cible des prospects qui ne savent pas quoi s'habiller le matin. En superposant la météo réelle à l'inventaire de mode du catalogue Supabase, l'application devient une **stylist IA contextuelle** : elle recommande le bon look, pour la bonne météo, selon le genre de l'utilisateur.

**Valeur prospect (angle conversion)** : à l'ouverture, avant même le premier essayage, afficher "Il fait 8 °C et pluvieux à Paris — voici votre look imperméable du jour" transforme l'app en outil quotidien, pas juste en gadget photo.

**Valeur utilisateur récurrente** : le "Look du Jour" devient le hook de rétention matinal.

---

## 2. Mode Localisation

### 2.1 Philosophie de permission

**Principe iOS** : ne demander la permission que lorsque l'utilisateur comprend clairement pourquoi.

| Contexte | Timing recommandé |
|----------|------------------|
| First-run `FirstRunWizardView` (step final) | **Non** — trop tôt, pas de valeur démontrée |
| `MainTabView` au 2e lancement | **Oui** — après que l'utilisateur a vu la valeur de l'app |
| Entrée dans "Look du Jour" (card en accueil) | **Préféré** — permission contextuelle, claire, motivée |
| Bouton manuel "Localiser" dans `ProfileView` | Fallback utilisateur explicite |

**Recommandation finale** : demander la permission **la première fois que l'utilisateur appuie sur la carte "Look du Jour"**, avec une dialog Apple-native précédée d'une dialog personnalisée "pré-alerte" expliquant pourquoi.

### 2.2 Clés Info.plist à ajouter

```xml
<!-- Localisation en avant-plan uniquement (pas de background) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>L'Écrin Virtuel utilise votre position pour vous proposer un look adapté à la météo de votre ville.</string>

<!-- Optionnel — si on veut proposer la météo dès le matin sans ouvrir l'app (notification push future) -->
<!-- NE PAS AJOUTER pour la Phase 2 — hors périmètre -->
<!-- <key>NSLocationAlwaysAndWhenInUseUsageDescription</key> -->
```

**Mode demandé :** `whenInUse` uniquement. Jamais `always` — pas de justification, risque de rejet App Store.

### 2.3 Précision requise

`kCLLocationAccuracyThreeKilometers` suffit largement pour la météo (ville). Ne pas demander `Best` — agressif en batterie, inutile.

### 2.4 Fallbacks par ordre de priorité

```
1. CLLocation résolue (autorisation accordée)
2. Ville saisie manuellement (champ texte libre → geocoder → coordonnées)
3. IP géolocalisation via https://ipapi.co/json/ (gratuit, aucune clé)
4. Défaut codé en dur : Paris (48.8566, 2.3522)
```

Le fallback IP doit être **silencieux** (pas de dialog). Le fallback Paris doit afficher un petit badge "📍 Paris par défaut — modifiez dans Profil".

### 2.5 Persistance

```
UserDefaults.standard:
  - "weather.userCity"         : String?   → ville saisie manuellement
  - "weather.lastLatitude"     : Double    → dernière lat connue
  - "weather.lastLongitude"    : Double    → dernière lon connue
  - "weather.locationSource"   : String    → "gps" | "manual" | "ip" | "default"
  - "weather.locationDenied"   : Bool      → true si l'utilisateur a refusé
```

La localisation GPS n'est **jamais stockée au-delà de la session** (vie privée RGPD). Seule la dernière ville résolue est persistée.

### 2.6 Texte RGPD / App Store Privacy Nutrition Label

**Données collectées :** Position approximative (ville), usage unique dans l'app  
**Finalité :** Recommandation météorologique de style  
**Durée de rétention :** Session uniquement (coordonnées GPS) / locale sur l'appareil (nom de ville)  
**Partage tiers :** Aucun — l'API météo reçoit uniquement des coordonnées (lat/lon), sans identifiant utilisateur  

**App Store Data Type checklist :**
- `Location > Coarse Location` → **Linked to App** : Non, **Tracking** : Non

---

## 3. Analyse Météo Temps Réel

### 3.1 Choix d'API : Open-Meteo ✅

| Critère | WeatherKit (Apple) | Open-Meteo | OpenWeatherMap |
|---------|-------------------|------------|----------------|
| Coût | Gratuit ≤ 500k/an | **Gratuit, sans clé** | Gratuit tier limité |
| Clé API | Entitlement Xcode requis | **Aucune** | Clé requise |
| Qualité données | Excellente | Excellente (ERA5 + NWP) | Bonne |
| Confidentialité | Apple gère les données | **Stateless, pas de tracking** | Enregistrement requis |
| Intégration Swift | Framework natif lourd | **URLSession pur** | URLSession |
| Latence | Faible | Faible | Variable |
| Offline | Non | Non | Non |

**Décision : Open-Meteo.** Zéro clé, zéro entitlement Xcode, aucun risque de rejet App Store, données de niveau professionnel.

**URL pattern :**
```
https://api.open-meteo.com/v1/forecast
  ?latitude={lat}
  &longitude={lon}
  &current=temperature_2m,apparent_temperature,precipitation,windspeed_10m,weathercode,uv_index
  &hourly=temperature_2m,weathercode
  &forecast_days=1
  &timezone=auto
```

### 3.2 Modèle de données météo requis

```swift
struct WeatherSnapshot: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let cityName: String?          // Résolu par CLGeocoder côté client
    let fetchedAt: Date

    // Données actuelles
    let temperatureC: Double       // temperature_2m
    let feelsLikeC: Double         // apparent_temperature
    let precipitationMM: Double    // precipitation (mm/h)
    let windspeedKmh: Double       // windspeed_10m
    let uvIndex: Double            // uv_index
    let weatherCode: Int           // WMO weather code (voir §3.3)

    // Dérivés calculés (non stockés)
    var condition: WeatherCondition { WeatherCondition(wmoCode: weatherCode) }
    var formattedTemp: String { "\(Int(temperatureC.rounded()))°C" }
    var isRainy: Bool { precipitationMM > 0.2 }
    var isHot: Bool { temperatureC >= 25 }
    var isCold: Bool { temperatureC < 10 }
    var isMild: Bool { !isHot && !isCold }
    var isWindy: Bool { windspeedKmh > 30 }
    var isSunny: Bool { [0, 1].contains(weatherCode) && uvIndex > 3 }
}

enum WeatherCondition: String, CaseIterable {
    case clearSky      // WMO 0
    case partlyCloudy  // WMO 1-3
    case foggy         // WMO 45, 48
    case drizzle       // WMO 51-57
    case rain          // WMO 61-67
    case snow          // WMO 71-77
    case thunderstorm  // WMO 95-99

    init(wmoCode: Int) {
        switch wmoCode {
        case 0:        self = .clearSky
        case 1...3:    self = .partlyCloudy
        case 45, 48:   self = .foggy
        case 51...57:  self = .drizzle
        case 61...67:  self = .rain
        case 71...77:  self = .snow
        case 95...99:  self = .thunderstorm
        default:       self = .partlyCloudy
        }
    }

    var emoji: String {
        switch self {
        case .clearSky:     return "☀️"
        case .partlyCloudy: return "⛅"
        case .foggy:        return "🌫"
        case .drizzle:      return "🌦"
        case .rain:         return "🌧"
        case .snow:         return "❄️"
        case .thunderstorm: return "⛈"
        }
    }

    var label: String {
        switch self {
        case .clearSky:     return "Ciel dégagé"
        case .partlyCloudy: return "Partiellement nuageux"
        case .foggy:        return "Brouillard"
        case .drizzle:      return "Bruine"
        case .rain:         return "Pluie"
        case .snow:         return "Neige"
        case .thunderstorm: return "Orage"
        }
    }
}
```

### 3.3 Stratégie de cache

```
Durée de validité : 30 minutes (météo = données lentes)
Clé de cache : "weather.snapshot" dans UserDefaults (JSON encodé)

Règle de refresh :
  - Si fetchedAt > 30 min → refetch
  - Si nouvelle position > 20 km de l'ancienne → refetch
  - Si l'app revient au foreground > 30 min après suspend → refetch
  - Pull-to-refresh manuel par l'utilisateur → refetch forcé
```

Le snapshot est stocké dans `UserDefaults` (léger, < 1 KB). Pas besoin de CoreData.

### 3.4 Gestion offline / erreurs

| Scénario | Comportement |
|----------|-------------|
| Pas de réseau | Utiliser le dernier snapshot en cache avec badge "⚠️ Données de X h" |
| Cache vide + pas de réseau | Afficher skeleton + "Connexion requise pour la météo" |
| Géocodage échoué | Afficher coordonnées brutes : "48.86°N 2.35°E" |
| Quota dépassé (improbable, Open-Meteo est illimité) | Retenter après 5 min |
| Timeout réseau | Retenter 1x après 3 sec, puis cache |

---

## 4. Moteur de Recommandation Look (Weather → Style Rules)

### 4.1 Règles météo → catégories vêtements

Le moteur mappe un `WeatherSnapshot` vers des **scores** appliqués aux `CatalogClothingItem`.

#### Tableau des règles de scoring

| Condition météo | Catégories boostées | Catégories pénalisées | style_tags boostés | saisons boostées |
|----------------|--------------------|-----------------------|---------------------|-----------------|
| `isRainy` (pluie/bruine) | `coat`, `jacket` | `dress` (jupe exposée), `shoes` sandals | `imperméable`, `trench`, `ciré` | - |
| `isCold` (< 10 °C) | `coat`, `jacket`, `top` (pull/sweat) | `dress` légère, `shoes` sandales | `laine`, `cachemire`, `manteau`, `oversize` | `hiver`, `automne` |
| `isHot` (≥ 25 °C) | `dress`, `top` léger, `bottom` short | `coat`, `jacket` | `lin`, `coton`, `été`, `légère` | `été`, `printemps` |
| `isMild` (10-24 °C) | `jacket`, `top`, `bottom` | - | `casual`, `bureau`, `élégant` | `printemps`, `automne` |
| `isWindy` (> 30 km/h) | `jacket`, `coat` | `dress` (longue) | - | - |
| `isSunny` + UV > 5 | `top` (léger), `accessory` (chapeau, lunettes) | - | `été`, `casual` | `été` |
| `snow` | `coat`, `boots` | sandales, robes | `hiver`, `neige` | `hiver` |
| `thunderstorm` | `coat`, `jacket` | dress, sandales | `imperméable` | - |

#### Algorithme de scoring

```
Score(item, weather) =
    base(isFeatured)           * 10
  + categoryBoost(item, weather)  * 30  // règles ci-dessus
  + seasonMatch(item, weather)    * 20  // saison courante du snapshot
  + genderMatch(item, userGender) * 40  // filtre dur (hors unisexe)
  + materialBoost(item, weather)  * 15  // lin si chaud, laine si froid
  + styleTagBoost(item, weather)  * 15  // matching tags

Score > 0 → éligible
Ranking → top 6 items affichés dans "Look du Jour"
```

**Filtre dur sur le genre** : seuls les items `gender == userGender || gender == .unisexe` sont éligibles. Pas de mélange H/F.

### 4.2 Saison dérivée de la météo

```swift
enum WeatherSeason: String {
    case printemps, ete, automne, hiver

    static func from(month: Int, temperatureC: Double) -> WeatherSeason {
        // Hemisphère nord
        switch month {
        case 3...5  where temperatureC > 5:  return .printemps
        case 6...8:                          return .ete
        case 9...11 where temperatureC < 20: return .automne
        default:                             return .hiver
        }
    }
}
```

### 4.3 Pré-sélection du mannequin selon le genre

L'essayage virtuel `fullOutfit` sur QuickTryOn utilise un corps entier. Le genre de l'utilisateur détermine le mannequin :

| `userGender` | Mannequin `QuickTryOnMode` par défaut | `BodyContext` préféré |
|-------------|--------------------------------------|----------------------|
| `.femme` | `fullOutfit` | `bodyShape: .hourglass / .rectangle` |
| `.homme` | `fullOutfit` | `bodyShape: .rectangle / .invTriangle` |
| Non défini | `fullOutfit` | Neutre |

Le genre est stocké dans `AppState.currentUser.gender` (à créer si absent — voir §4.6).

### 4.4 Modèle `LookRecommendation`

```swift
struct LookRecommendation: Identifiable, Sendable {
    let id: UUID
    let weather: WeatherSnapshot
    let gender: ClothingGender
    let items: [CatalogClothingItem]      // 3 à 6 items scorés
    let headline: String                   // "Look Pluie Parisienne"
    let subline: String                    // "Imperméable + Bottines + Sac seau"
    let styleTag: String                   // "Urban Chic", "Cocooning", etc.
    let generatedAt: Date
    let weatherEmoji: String               // "🌧 12 °C · Pluie"
}
```

### 4.5 Fallback si catalogue trop petit

Si moins de 3 items correspondent aux règles météo + genre → relâcher le filtre `season` (garder seulement catégorie + genre) → si toujours < 3, prendre les `isFeatured = true` du genre.

### 4.6 Genre utilisateur

**Source de vérité :** `AppState.currentUser` → à enrichir avec `preferredGender: ClothingGender`.

Si l'utilisateur n'a pas renseigné son genre → afficher un sélecteur H/F au premier affichage de "Look du Jour" (modal légère, 1 tap).

Le genre est persisté dans `Supabase` (colonne `preferred_gender` dans la table `users`) ET en `UserDefaults` pour accès hors ligne.

---

## 5. Flux UX & Emplacement dans l'Application

### 5.1 Décision d'emplacement

**Option retenue : Carte "Look du Jour" en haut de `MainTabView` / Tab 0 (Essayage)**

Raisonnement :
- La Tab 0 est la tab d'entrée principale
- Le Look du Jour guide naturellement vers l'essayage virtuel (conversion)
- La météo est une information éphémère → doit être visible dès l'ouverture
- Ne crée pas de nouvelle tab (évite de surcharger la nav)

### 5.2 Wireframe textuel — Carte "Look du Jour"

```
┌─────────────────────────────────────────────┐
│  LOOK DU JOUR                     [Actualiser ↺] │
│  ☁️  Paris · 12 °C · Bruine                      │
├─────────────────────────────────────────────┤
│  "Journée Parisienne"                            │
│  Trench + Pull Col Roulé + Bottines             │
│                                                   │
│  [img]  [img]  [img]  +3                         │
│                                                   │
│  [→ Essayer ce look]   [Voir tout le catalogue]  │
└─────────────────────────────────────────────┘
```

La carte est un `GlassCard` (design system existant) avec un gradient météo subtil en background.

### 5.3 Flux utilisateur complet (Mermaid)

```mermaid
flowchart TD
    A[Ouverture app] --> B{hasLocation?}
    B -->|Non, première fois| C[Carte Look du Jour<br/>avec état vide + CTA]
    B -->|Oui, cache valide| D[Afficher WeatherSnapshot]
    C --> E[Tap "Voir mon look météo"]
    E --> F{Permission accordée?}
    F -->|Non| G[Dialog pré-alerte<br/>personnalisée EV]
    G --> H[Dialog système iOS]
    H -->|Refusé| I[Fallback: saisie ville manuelle]
    H -->|Accordé| J[Résoudre position GPS]
    I --> J
    J --> K[Appel Open-Meteo API]
    K --> L[Créer WeatherSnapshot]
    L --> M[WeatherLookRecommender<br/>score items × règles météo]
    M --> N{Gender défini?}
    N -->|Non| O[Modal choix H/F rapide]
    O --> P[Filtrer par genre]
    N -->|Oui| P
    P --> Q[LookRecommendation<br/>top 6 items]
    Q --> R[Afficher carte Look du Jour]
    R --> S{Tap "Essayer ce look"}
    S --> T[QuickTryOnView<br/>mode=fullOutfit<br/>items pré-sélectionnés]
    D --> M
```

### 5.4 Intégration dans `TryOnView` (Tab 0)

`TryOnView` (actuellement vue bijoux) recevra une **section header** "Look du Jour" insérée au-dessus du contenu bijoux. La carte est lazy-loadée via `.task`.

### 5.5 Expérience prospect (first-run conversion)

Au first-run `FirstRunFlowView` : **ne pas** intégrer la météo (flow déjà dense). Après le premier run, l'app mémorise le genre choisi et la météo est disponible immédiatement.

Message de conversion affiché lors du premier Look du Jour :
> *"Votre stylist personnelle connaît votre météo. Essayez une tenue avant même de sortir."*

---

## 6. Architecture Swift

### 6.1 Nouveaux fichiers à créer

| Fichier | Dossier | Type | Priorité |
|---------|---------|------|----------|
| `LocationService.swift` | `Sources/Core/Services/` | `@Observable final class` | P1 |
| `WeatherService.swift` | `Sources/Core/Services/` | `@Observable final class` | P1 |
| `WeatherLookRecommender.swift` | `Sources/Core/Services/` | `struct` pur (sans état) | P1 |
| `WeatherSnapshot.swift` | `Sources/Core/Models/` | `struct Codable` | P1 |
| `WeatherCondition.swift` | `Sources/Core/Models/` | `enum` | P1 |
| `LookRecommendation.swift` | `Sources/Core/Models/` | `struct` | P1 |
| `LookDuJourCard.swift` | `Sources/Features/Weather/` | `View` | P2 |
| `WeatherBadge.swift` | `Sources/Features/Weather/` | `View` | P2 |
| `LookDuJourViewModel.swift` | `Sources/Features/Weather/` | `@Observable final class` | P2 |
| `CitySearchSheet.swift` | `Sources/Features/Weather/` | `View` (fallback manuel) | P2 |
| `GenderPickerSheet.swift` | `Sources/Features/Weather/` | `View` (modal genre) | P2 |

### 6.2 Fichiers à modifier

| Fichier | Modifications |
|---------|--------------|
| `Sources/App/Info.plist` | Ajouter `NSLocationWhenInUseUsageDescription` |
| `Sources/Core/Models/AppState.swift` | Ajouter `preferredGender: ClothingGender?` |
| `Sources/Core/Models/User.swift` | Ajouter `preferredGender: ClothingGender?` |
| `Sources/App/EcrinVirtuelApp.swift` | `.environment(LocationService.shared)` + `.environment(WeatherService.shared)` |
| `Sources/Features/TryOn/TryOnView.swift` | Insérer `LookDuJourCard` en header |
| `Sources/Features/QuickTryOn/QuickTryOnViewModel.swift` | Ajouter init avec items pré-sélectionnés depuis LookRecommendation |
| `Sources/Core/Services/ClothingCatalogService.swift` | Ajouter `fetchBySeasonAndCategory(_:season:gender:)` |

### 6.3 Interface `LocationService`

```swift
@Observable
@MainActor
final class LocationService: NSObject {
    static let shared = LocationService()

    enum LocationSource { case gps, manual(String), ip, `default` }
    enum AuthStatus { case notDetermined, denied, restricted, authorized }

    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var cityName: String?
    private(set) var source: LocationSource = .default
    private(set) var authStatus: AuthStatus = .notDetermined

    func requestPermissionAndLocate() async
    func locateManually(city: String) async
    func locateViaIP() async         // ipapi.co fallback
    func applyDefault()              // Paris fallback
}
```

### 6.4 Interface `WeatherService`

```swift
@Observable
@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private(set) var snapshot: WeatherSnapshot?
    private(set) var isLoading = false
    private(set) var lastError: WeatherError?

    private let cacheKey = "weather.snapshot"
    private let cacheDuration: TimeInterval = 30 * 60  // 30 min

    func fetchCurrent(coordinate: CLLocationCoordinate2D, cityName: String?) async
    func refresh() async             // force fetch
    func loadFromCache() -> WeatherSnapshot?
}
```

### 6.5 Interface `WeatherLookRecommender`

```swift
struct WeatherLookRecommender {
    /// Pur, sans état, testable unitairement
    func recommend(
        weather: WeatherSnapshot,
        gender: ClothingGender,
        catalog: [CatalogClothingItem],
        limit: Int = 6
    ) -> LookRecommendation

    /// Retourne le score d'un item (exposé pour les tests)
    func score(
        item: CatalogClothingItem,
        weather: WeatherSnapshot,
        gender: ClothingGender
    ) -> Double
}
```

### 6.6 Flux de données

```
User opens app
    │
    ▼
EcrinVirtuelApp.task
    ├── LocationService.shared.loadPersisted()
    └── WeatherService.shared.loadFromCache()
            │
            ▼ (si cache valide → affichage immédiat)
    LookDuJourViewModel
            │
            ├── snapshot = WeatherService.shared.snapshot
            ├── catalog  = ClothingCatalogService.shared.items(for: gender)
            └── recommendation = WeatherLookRecommender().recommend(...)
                        │
                        ▼
                LookDuJourCard (SwiftUI)
                        │
                        ▼ (tap "Essayer")
                QuickTryOnView(preselectedItems: recommendation.items,
                               mode: .fullOutfit)
```

### 6.7 Patterns à respecter

- **`@Observable` + `@MainActor`** : pattern uniforme de tout le projet (AppState, ClothingCatalogService)
- **`static let shared`** : singleton pattern déjà établi
- **Supabase** : pas de nouveau appel Supabase pour la météo (donnée externe)
- **Pas de nouveaux packages** : CoreLocation est natif, URLSession pour Open-Meteo, CLGeocoder pour la résolution de nom de ville
- **Pas de WeatherKit** : évite un entitlement Xcode supplémentaire
- **JSON Codable** : même pattern que `CatalogClothingItem`
- **`EcrinFont` / `EcrinColor` / `GlassCard`** : design system existant pour toutes les nouvelles vues

---

## 7. Confidentialité & RGPD

### 7.1 Ce qui sort de l'appareil

| Donnée | Destination | Identifiant ? | Rétention |
|--------|------------|---------------|-----------|
| lat/lon (≈3km) | api.open-meteo.com | ❌ Non | 0 (stateless) |
| lat/lon | ipapi.co (fallback IP uniquement) | ❌ Non | 0 |

**Aucune donnée de localisation ne transite par Supabase.**  
**Aucune donnée de localisation n'est partagée avec des tiers publicitaires.**

### 7.2 App Store Privacy Nutrition Label

```
Location > Coarse Location
  Linked to User: No
  Used for Tracking: No
  Purpose: App Functionality (météo contextuelle)
```

### 7.3 Texte politique de confidentialité à ajouter

> **Données de localisation**  
> L'Écrin Virtuel peut utiliser votre position géographique approximative (ville, non votre adresse précise) pour vous proposer des recommandations vestimentaires adaptées à la météo locale. Cette information est transmise de façon anonyme au service Open-Meteo (open-meteo.com) pour obtenir les données météorologiques. Vos coordonnées GPS ne sont jamais stockées sur nos serveurs ni partagées avec des tiers à des fins publicitaires. Vous pouvez désactiver l'accès à la localisation à tout moment dans les Réglages iOS.

---

## 8. Phases d'implémentation

### Phase 2 — Services de base (MVP technique)
**Durée estimée :** 1-2 jours

1. Créer `WeatherSnapshot.swift` + `WeatherCondition.swift` + `LookRecommendation.swift`
2. Créer `LocationService.swift` (GPS + IP fallback + défaut Paris)
3. Créer `WeatherService.swift` (Open-Meteo + cache 30 min)
4. Ajouter clé `Info.plist`
5. Tests unitaires : `WeatherCondition(wmoCode:)` + `WeatherLookRecommender.score()`

### Phase 3 — Moteur de recommandation
**Durée estimée :** 1 jour

1. Créer `WeatherLookRecommender.swift` avec table de scoring complète
2. Ajouter `fetchBySeasonAndCategory` dans `ClothingCatalogService`
3. Tests unitaires complets du moteur (cas extrêmes : catalogue vide, mono-genre)

### Phase 4 — UI "Look du Jour"
**Durée estimée :** 1-2 jours

1. Créer `LookDuJourViewModel.swift`
2. Créer `LookDuJourCard.swift` (GlassCard météo + grille 3 items)
3. Créer `WeatherBadge.swift` (capsule temp + emoji météo)
4. Créer `CitySearchSheet.swift` (fallback saisie manuelle)
5. Créer `GenderPickerSheet.swift` (modal H/F si genre non défini)
6. Intégrer dans `TryOnView` en header
7. Pré-sélection dans `QuickTryOnViewModel` depuis `LookRecommendation`

### Phase 5 — Polissage & Conversion
**Durée estimée :** 0.5 jour

1. Animations de transition météo (shimmer → card réelle)
2. Copy de conversion prospect (voir §5.5)
3. Badge "Données non fraîches" si cache > 2h
4. Pull-to-refresh sur la carte
5. Intégration `AppState.preferredGender` persisté Supabase

### Phase 6 — Extensions futures (backlog)
- Widget iOS "Look du Jour" (WidgetKit) — météo + 1 item vedette
- Notifications push matinales "Votre look de 8h est prêt" (nécessite `always` location)
- Look "occasion" croisé météo × agenda calendrier
- Historique des looks portés selon la météo (table `look_history` Supabase)

---

## 9. Questions ouvertes / Décisions à prendre

| # | Question | Recommandation |
|---|----------|----------------|
| Q1 | Ajouter `preferredGender` dans `User` Supabase dès maintenant ? | **Oui** — migration simple, colonne nullable |
| Q2 | Afficher la météo même si le catalogue est vide ? | **Non** — attendre que `ClothingCatalogService.totalCount > 0` |
| Q3 | Proposer un "Look d'urgence" si réseau absent ? | **Oui** — 1 look statique codé en dur par genre (hiver/été) |
| Q4 | La carte Look du Jour est-elle payante (Premium only) ? | **Non** — c'est un hook de rétention/conversion, doit être free tier |
| Q5 | Faut-il un onglet dédié "Météo" dans la tab bar ? | **Non** — surcharge visuelle, préférer l'intégration dans Tab 0 |
| Q6 | L'angle "prospect" justifie-t-il de le montrer avant la auth ? | **Oui** — afficher la carte en lecture seule, gate sur l'essayage |

---

## 10. Annexes

### A. Codes WMO (Open-Meteo) clés

| Code | Description | `WeatherCondition` |
|------|------------|-------------------|
| 0 | Clear sky | `.clearSky` |
| 1-3 | Mainly clear / partly cloudy / overcast | `.partlyCloudy` |
| 45, 48 | Fog | `.foggy` |
| 51-57 | Drizzle | `.drizzle` |
| 61-67 | Rain | `.rain` |
| 71-77 | Snow | `.snow` |
| 80-82 | Rain showers | `.rain` |
| 95-99 | Thunderstorm | `.thunderstorm` |

### B. Exemple de réponse Open-Meteo

```json
{
  "latitude": 48.8566,
  "longitude": 2.3522,
  "current": {
    "temperature_2m": 11.8,
    "apparent_temperature": 9.2,
    "precipitation": 0.4,
    "windspeed_10m": 22.1,
    "weathercode": 61,
    "uv_index": 1.0
  }
}
```

### C. Style tags existants dans le catalogue (référence)

D'après les données prévisualisées dans `CatalogClothingItem.preview` :
- Femme : `soirée`, `élégant`, `casual`
- Homme : `bureau`, `élégant`
- Boosters météo à ajouter progressivement : `imperméable`, `laine`, `lin`, `été`, `hiver`, `casual`, `cocooning`

---

*Spec générée le 2026-05-24. Prochaine action : Phase 2 — implémentation des services.*
