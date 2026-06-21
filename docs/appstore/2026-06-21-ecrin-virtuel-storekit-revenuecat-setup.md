# EcrinVirtuel — StoreKit Configuration & RevenueCat Setup

**Date:** 2026-06-21  
**App:** L'Écrin Virtuel (`com.ecrin.jewelry`)  
**Bundle ID:** `com.ecrin.jewelry`  
**StoreKit config file:** `EcrinVirtuel.storekit` (project root)

---

## 1. Product IDs & RevenueCat Entitlement Mapping

### Auto-Renewable Subscriptions — Group "Écrin"

| Product ID | Display Name (FR) | Price | Period | Group Level | RevenueCat Entitlement |
|---|---|---|---|---|---|
| `ecrin.starter.monthly` | Starter | 4,99 € | 1 month | 3 (lowest) | `starter` |
| `ecrin.premium.monthly` | Premium | 9,99 € | 1 month | 2 | `premium` |
| `ecrin.premium.yearly` | Premium annuel | 79,99 € | 1 year | 2 | `premium` |
| `ecrin.elite.monthly` | Elite | 29,99 € | 1 month | 1 (highest) | `elite` |

Group level convention: **lower number = higher tier** (Elite=1 > Premium=2 > Starter=3). Apple uses this for upgrade/downgrade direction — upgrading to a lower group level charges immediately, downgrading takes effect at next renewal.

`ecrin.premium.monthly` includes a **7-day free introductory trial** (free trial, no charge).

### Consumable In-App Purchases (not in subscription group)

| Product ID | Display Name (FR) | Price |
|---|---|---|
| `ecrin.credits.10` | 10 Crédits | 2,99 € |
| `ecrin.credits.50` | 50 Crédits | 9,99 € |
| `ecrin.credits.150` | 150 Crédits | 24,99 € |

---

## 2. How the App Reads Entitlements (EcrinVirtuelApp.swift)

The boot task in `EcrinVirtuelApp.swift` fetches `Purchases.shared.customerInfo()` and resolves the subscription tier like this:

```swift
let entitlements = info.entitlements.all
let activeIds = entitlements.filter { $0.value.isActive }.keys
let resolved: SubscriptionStatus
if activeIds.contains(where: { $0.contains("elite") }) {
    resolved = .elite
} else if activeIds.contains(where: { $0.contains("premium") }) {
    resolved = .premium
} else if activeIds.contains(where: { $0.contains("starter") || $0 == "premium" }) {
    resolved = .starter
} else {
    resolved = .free
}
```

**Implication:** RevenueCat entitlement IDs **must** contain the strings `elite`, `premium`, or `starter` (case-sensitive substring match). Use exactly `elite`, `premium`, `starter` as entitlement identifiers in the RevenueCat dashboard.

---

## 3. App Store Connect Setup Steps

### 3.1 Subscription Group

1. In App Store Connect → **My Apps → L'Écrin Virtuel → Subscriptions**
2. Create subscription group named **"Écrin"**
3. Add all four subscriptions with the product IDs above, prices, and FR localizations
4. Set group levels: Elite=1, Premium monthly=2, Premium yearly=2, Starter=3
5. Enable the 7-day free trial on `ecrin.premium.monthly`

### 3.2 Consumables

1. In App Store Connect → **In-App Purchases** (non-subscription section)
2. Add three consumable IAPs: `ecrin.credits.10`, `ecrin.credits.50`, `ecrin.credits.150`
3. Set prices and FR localizations as per table above

### 3.3 Apple Small Business Program

- Enroll at https://developer.apple.com/app-store/small-business-program/
- Reduces Apple's commission from 30% to **15%** for developers with <$1M annual proceeds
- Takes effect on qualifying transactions after enrollment; applies retroactively to calendar year once approved
- This materially improves margin especially on the Starter (4,99€) plan

---

## 4. RevenueCat Dashboard Setup

### 4.1 Entitlements

Create three entitlements in RevenueCat → **Entitlements**:

| Identifier | Display Name | Products |
|---|---|---|
| `starter` | Starter Access | `ecrin.starter.monthly` |
| `premium` | Premium Access | `ecrin.premium.monthly`, `ecrin.premium.yearly` |
| `elite` | Elite Access | `ecrin.elite.monthly` |

### 4.2 Offerings & Packages

Create one **Default Offering** with the following packages:

| Package Identifier | Type | Product |
|---|---|---|
| `$rc_monthly` (or `starter_monthly`) | Monthly | `ecrin.starter.monthly` |
| `$rc_monthly` (or `premium_monthly`) | Monthly | `ecrin.premium.monthly` |
| `$rc_annual` (or `premium_yearly`) | Annual | `ecrin.premium.yearly` |
| `$rc_monthly` (or `elite_monthly`) | Monthly | `ecrin.elite.monthly` |

> Tip: Create separate offerings per tier ("Starter Offering", "Premium Offering", "Elite Offering") so the paywall can be targeted by entitlement level via the RevenueCat dashboard without an app update.

### 4.3 Credits Consumables

Add consumable products to RevenueCat (no entitlement mapping needed — handled via `CreditsManager.shared`):

- `ecrin.credits.10`
- `ecrin.credits.50`
- `ecrin.credits.150`

---

## 5. Local StoreKit Testing

The `EcrinVirtuel.storekit` file is wired into the `EcrinVirtuel` scheme via `project.yml`:

```yaml
schemes:
  EcrinVirtuel:
    run:
      storeKitConfiguration: EcrinVirtuel.storekit
    test:
      storeKitConfiguration: EcrinVirtuel.storekit
```

After running `xcodegen generate` in the project root, Xcode will use this config for both Run and Test. This allows testing purchases locally in the simulator without hitting StoreKit servers.

**Storefront is set to FRA** (France) in the .storekit file so EUR prices display correctly.

---

## 6. Currency & Pricing Notes

- All prices are **EUR** (€), storefront FRA
- Apple rounds prices to the nearest valid price tier; verify in ASC that each price maps to an actual tier (4.99, 9.99, 24.99, 29.99, 79.99 are all standard EUR tiers as of 2026)
- RevenueCat `customerInfo.entitlements.active` is checked at app boot (step 2 in the task block) — no separate refresh needed at tab-switch
- Offline / network-failure fallback: last known tier is persisted in `UserDefaults` under key `lastKnownSubscriptionTier` (Bug C7 fix already in prod)
