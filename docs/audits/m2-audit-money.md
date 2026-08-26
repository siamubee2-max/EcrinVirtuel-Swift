# EcrinVirtuel-Swift — Money/Auth/Core Audit
Date: 2026-06-21
Audited by: read-only code audit

---

## CRIT

### [CRIT] PaywallView.swift:211 — Wrong entitlement key gates ALL subscription upgrades
**What:** `purchase()` checks `result.customerInfo.entitlements["premium"]?.isActive == true` as the single condition before crediting the user. Plans "elite", "starter", and the lifetime "fondateur" plan are identified by their own entitlement keys (e.g. "ecrin_elite_monthly", not "premium"). If RevenueCat is configured with separate entitlement IDs per tier (which the app startup code at EcrinVirtuelApp.swift:39-44 and PaywallView.swift:57-63 imply — it uses `activeIds.contains(where: { $0.contains("elite") })`), the entitlement key `"premium"` will be `nil` or `false` for elite and starter purchases. The `creditGenerations` server call is never made, `purchasedPlan` is not set, `dismiss()` is not called, and the UI is stuck in a success-less limbo while the user's Apple payment has already been charged.
**Why:** The check uses a hardcoded literal `"premium"` instead of deriving the entitlement from the purchased plan's identifier. The `restore()` function at line 241 has the same bug.
**Fix:** Use `plan.resolvedSubscriptionStatus` to determine the correct entitlement key, or check any active entitlement: `!result.customerInfo.entitlements.all.filter({ $0.value.isActive }).isEmpty`.

---

### [CRIT] EcrinVirtuelApp.swift:36-45 — Subscription status silently stays `.free` on any RC error; `try?` drops the error
**What:** `if let info = try? await Purchases.shared.customerInfo()` silently returns `nil` on network errors, session expiry, or RevenueCat SDK misconfiguration. The subscription status remains `.free` for the entire session. Paid subscribers are treated as free-tier users — paywall is shown, credits are restricted. This is a money bug because it blocks paying users.
**Why:** `try?` swallows `ErrorCode` from RevenueCat with no fallback, no retry, no error state. On cold launch with a network hiccup the subscriber sees the paywall.
**Fix:** Use `try`/`catch`, persist the last-known subscription status to UserDefaults as a fallback, and expose a loading/error state to the UI.

---

### [CRIT] CreditsManager.swift:61 — `isSyncing` guard races on concurrent `sync()` calls; CreditsPackViewModel.swift:23 triggers a parallel fetch
**What:** `sync()` has `guard !isSyncing else { return }` as a reentrancy guard, but this only works because `CreditsManager` is `@MainActor`. However, `CreditsPackViewModel.fetchCurrentCredits()` (line 30) independently calls `SupabaseService.shared.fetchRemainingCredits()` and writes to its own `currentCredits` — entirely bypassing `CreditsManager`. After a credit-pack purchase, `CreditsPackViewModel.purchase()` at line 92 updates `currentCredits` from the server response but never updates `CreditsManager.shared.remaining`. The next generation attempt will therefore use a stale (too-low) local count and falsely trigger the paywall. This is a double-block: the user bought credits, can see the updated count in CreditsPackView, but is still blocked in TryOnView.
**Why:** Two separate sources of truth for remaining credits: `CreditsManager.shared.remaining` and `CreditsPackViewModel.currentCredits`. After a consumable IAP purchase, only `CreditsPackViewModel.currentCredits` is updated (line 92); `CreditsManager` is not synced.
**Fix:** After a successful purchase in `CreditsPackViewModel.purchase()`, call `await CreditsManager.shared.sync()` to resync the single source of truth. Remove `currentCredits` from the ViewModel and read from `CreditsManager.shared.remaining` instead.

---

## HIGH

### [HIGH] EcrinVirtuelApp.swift:31 — Auth session restored but credits sync may precede it; credits set to 3 (unauthenticated) then overwritten
**What:** Boot sequence: (1) restore Supabase session → sets `appState.signIn`, (2) restore RC subscription, (3) `CreditsManager.shared.sync()`. If step 1 succeeds, step 3 correctly fetches server credits. But if `SupabaseService.shared.currentUser()` is slow or fails, step 3 runs `sync()` with no session → sets `remaining = 3` (free trial). If the session is later restored (e.g. via deep link), `sync()` is not called again automatically. The user sees 3 credits until the next explicit sync trigger. More critically: if step 1 succeeds but `sync()` at step 3 fails (network error, `try?` at line 75 suppresses it), `remaining` stays 0 (`hasLoaded` is false, so the guard at line 70 doesn't give the 3 free trials either). The user sees 0 credits even though they have a valid subscription.
**Why:** `CreditsManager.sync()` at line 75 uses `try?` to silently discard server errors. If the Supabase `fetchRemainingCredits()` RPC fails, `remaining` is left at 0 with `hasLoaded = true` — paying users see 0 credits with no retry.
**Fix:** Retry on transient errors, or use a last-known-good cache. Do not silently leave `remaining = 0` when a session exists.

---

### [HIGH] PaywallView.swift:43 — `selectedPlan` initialised to "premium_monthly" but `currentPlans` filters by `selectedPeriod` (monthly); switching to Yearly resets selection correctly but `selectedPlan` is never cleared on period switch if no best-value plan exists
**What:** When the user switches from Monthly to Lifetime (`PlanPeriod.lifetime`), the `onChange` handler at line 346 correctly selects the best-value plan or `.first`. There is only one lifetime plan ("fondateur") and it has `isBestValue: false`, so `plans.first` is selected. This is fine. However, if `currentPlans` is empty (e.g. no yearly products loaded from RC), `selectedPlan` remains the stale monthly selection. The purchase call then proceeds with `plan.rcIdentifier = "ecrin_premium_monthly"` while the user sees a yearly UI. This is a latent data-race between stale `selectedPlan` and visible plan list.
**Why:** `selectedPlan` is not validated against `currentPlans` before initiating purchase.
**Fix:** In `purchase()`, assert `currentPlans.contains(where: { $0.id == selectedPlan?.id })` before proceeding.

---

### [HIGH] GamingService.swift:28-30 — `init()` calls `refreshQuestsIfNeeded()` AND `loadProfile()` which calls `refreshQuestsIfNeeded()` again
**What:** `private init()` at line 27 calls `loadProfile()` (line 28) and then `refreshQuestsIfNeeded()` (line 29) directly. `loadProfile()` itself calls `refreshQuestsIfNeeded()` at line 251. This means `refreshQuestsIfNeeded()` is always called twice on startup. The second call at line 29 of `init()` immediately follows and `questsLastRefresh` was already set to today by the first call inside `loadProfile()`, so the guard `Calendar.current.isDate(today, inSameDayAs: questsLastRefresh)` returns `true` → the second call exits early. This is benign today but fragile: the duplicate call is an architecture smell that will cause a real double-reset bug if `refreshQuestsIfNeeded()` is ever made async or if the guard condition changes.
**Why:** Logic duplication in init flow; `loadProfile` already fully initialises quests, the second explicit call is dead code that will confuse future maintainers.
**Fix:** Remove the `refreshQuestsIfNeeded()` call at line 29 of `init()` since `loadProfile()` already calls it.

---

### [HIGH] GamingService.swift:92-93 — Double XP for streak milestones on same day
**What:** `recordLogin()` calls `record(.dailyLogin)` unconditionally, then checks `if profile.streak == 7 { record(.streakMilestone7) }`. Each `record()` call saves the profile. But `recordLogin()` already mutated `profile.streak` before calling `record(.dailyLogin)`. After `record(.dailyLogin)` runs, `profile.currentLevel` might change (level-up), `pendingRewards` is appended, `saveProfile()` is called. Then the milestone check runs. This is fine. The bug is subtler: `recordLogin()` does NOT guard against being called multiple times in the same calendar day from different call sites. Looking at init: `loadProfile()` calls `Task { await syncFromSupabase() }` which is fire-and-forget. If `syncFromSupabase()` merges a cloud profile with more XP, `profile.streak` is overwritten but `profile.lastLoginDate` is also overwritten from the cloud profile, potentially making `recordLogin()` callable again if the app re-checks. The daily guard `guard !calendar.isDate(today, inSameDayAs: profile.lastLoginDate) else { return }` at line 77 is correct, but the cloud merge at `syncFromSupabase()` (line 263) replaces `profile` in its entirety with the cloud profile — including `lastLoginDate`. If the cloud profile has `lastLoginDate` = yesterday (e.g. user was offline on another device), the daily guard will pass after the merge, allowing `recordLogin()` to be called again if triggered by any event. This gives the user a second batch of +5 XP and potentially a false streak increment.
**Why:** `syncFromSupabase()` unconditionally overwrites `profile` (line 263) without re-triggering the daily login guard awareness.
**Fix:** After cloud merge, update `lastLoginDate` to `.now` locally to prevent the re-trigger, or re-call `recordLogin()` intentionally (not silently via external code paths).

---

### [HIGH] GamingService.swift:125-139 — `claimQuestReward()` does not check if quest is in `activeQuests`; can be called with a stale Quest from any caller
**What:** `claimQuestReward(_ quest: Quest)` checks `quest.isCompleted` and `!profile.completedQuestIDs.contains(quest.id)`. These guards are correct. But `quest.progress` is taken from the caller's copy of the Quest struct (value type). If a caller holds a stale Quest (e.g. captured before `updateQuestProgress` ran), `quest.isCompleted` could be `true` even if the live `activeQuests[i].progress` has since been reset. In the current app code this is not exploitable because `QuestCard` always calls with a quest from `gaming.activeQuests` (which is @Published and up to date). However, the API is unsafe by design.
**Why:** Value-type Quest passed to the claim function means the guard `quest.isCompleted` uses the caller's snapshot, not the live state.
**Fix:** Look up the quest in `activeQuests` by ID inside `claimQuestReward` before checking completion status.

---

### [HIGH] ProfileView.swift:237 — Credits re-fetched on sheet dismiss via separate Supabase call, not via CreditsManager; ProfileView maintains its own `remainingCredits: Int?` state
**What:** `ProfileView` has a local `@State private var remainingCredits: Int?` and fetches it independently on appear (line 242) and on CreditsPackView dismiss (line 237). This is a third source of truth alongside `CreditsManager.shared.remaining` and `CreditsPackViewModel.currentCredits`. After a purchase, if `CreditsManager.sync()` fires and updates the singleton, `ProfileView.remainingCredits` will be stale until the sheet is dismissed. The credit display in ProfileView therefore shows an incorrect value during the window between purchase and sheet dismiss.
**Why:** ProfileView doesn't observe `CreditsManager.shared` and maintains its own stale copy.
**Fix:** Replace `remainingCredits` state with a direct observation of `CreditsManager.shared.remaining` using `@Environment` or direct `GamingService.shared` pattern (`CreditsManager` is `@Observable`).

---

### [HIGH] EmotionalPaywallView.swift:203-224 — Prices shown in EmotionalPaywall are hardcoded and differ from PaywallView
**What:** `EmotionalPaywallView.planCards` shows "Starter: 7,99€ / 30 essayages/mois" and "Premium: 14,99€ / 70 essayages/mois". `PaywallView` shows "Starter: 6,99€ / 15 crédits/mois" and "Premium: 12,99€ / 40 crédits/mois". Both the prices and the credit counts are different. This is a HIGH because it shows users incorrect pricing before they enter the full paywall — potential App Store rejection (guideline 3.1.1: must show accurate prices) and user trust issue.
**Why:** `EmotionalPaywallView` uses static `PlanRow` with hardcoded strings, not connected to `PaywallViewModel.liveProducts` or even the static `allPlans` array in `PaywallViewModel`.
**Fix:** Share pricing data from `PaywallViewModel` (or the static `allPlans` array) with `EmotionalPaywallView`, or remove the price display from the emotional paywall and let the full `PaywallView` show prices.

---

## MED

### [MED] CreditsManager.swift:85-89 — `syncDetached()` uses `Task.detached` with `[weak self]` but `CreditsManager` is a `@MainActor` singleton — weak capture is unnecessary and the task runs off the main actor
**What:** `Task.detached { [weak self] in await self?.sync() }` creates a detached task (no actor inheritance). `sync()` is `@MainActor` so the `await self?.sync()` hop is correct. But since `CreditsManager` is a singleton with `static let shared`, `self` will never be nil — the `weak` capture is pointless and misleading. More importantly, `Task.detached` runs with no actor context, then hops to the main actor for `sync()`. This is correct but unnecessarily complex; `Task { await CreditsManager.shared.sync() }` would be cleaner and avoid the potential confusion.
**Why:** Misleading use of `weak self` on a singleton; `Task.detached` adds unnecessary complexity.
**Fix:** Replace with `Task { await CreditsManager.shared.sync() }`.

---

### [MED] GamingService.swift:242 — `saveProfile()` fires a `Task.detached` cloud sync on every single action, including rapid consecutive calls
**What:** Every call to `record(_:)` calls `saveProfile()` which fires `Task.detached { await SupabaseService.shared.saveGamingProfile(snapshot) }`. During a rapid try-on session, `record(.tryOnGenerated)` could be called many times in succession, spawning many concurrent Supabase writes. Each writes the full profile. There is no debounce, coalescing, or rate limiting.
**Why:** N detached tasks = N concurrent Supabase writes, N database round-trips. Under load this can cause write conflicts on the server and wastes bandwidth.
**Fix:** Debounce the cloud sync with a `Task` that cancels the previous one if fired within a short window (e.g. 2 seconds).

---

### [MED] GamingService.swift:260-268 — `syncFromSupabase()` merge strategy can erase local-only progress
**What:** The merge is: if `cloud.totalXP > profile.totalXP`, replace `profile` entirely with the cloud copy. This means if the user earned badges or completed quests locally (offline) but the cloud has more XP from a different action, the local badge progress is silently discarded. Conversely, if local XP is higher, all cloud progress is discarded.
**Why:** A max-XP merge doesn't preserve all independent progress. Local badges earned offline are lost if cloud XP is higher.
**Fix:** Merge fields individually: `totalXP = max(local, cloud)`, `earnedBadgeIDs = union(local, cloud)`, `completedQuestIDs = union(local, cloud)`, `streak` = take whichever is higher (or the most recent login date).

---

### [MED] LoginView.swift:199-202 — Apple Sign In error path silently discards the sign-in failure — no UI feedback
**What:** `handleAppleSignIn()` at line 198: if `guard case .success` fails (i.e. the result is `.failure`), the function returns silently with no error shown to the user. If Apple returns an error (e.g. network error, user-cancelled error with code != 1001), the user sees nothing and the login button remains active.
**Why:** The `guard case .success(let auth) = result` early-return discards `.failure(let error)` without setting `loginError`.
**Fix:** Add `guard case .success(let auth) = result else { if case .failure(let err) = result { loginError = err.localizedDescription } return }`.

---

### [MED] EcrinVirtuelApp.swift:43 — Entitlement key `"premium"` used as identifier for Starter tier, creating ambiguous matching
**What:** In the boot sequence subscription restore (line 43): `activeIds.contains(where: { $0.contains("starter") || $0 == "premium" })`. The `|| $0 == "premium"` clause means any entitlement literally named "premium" (not containing "premium") maps to `.starter`. But at PaywallView.swift:211, the purchase success check also uses `entitlements["premium"]` to gate all purchases. If the actual RevenueCat entitlement for the "Premium" plan is named "premium" (exact match), then the boot code maps it to `.starter`, not `.premium`. This is a classification bug: Premium subscribers might be initialised as `.starter`.
**Why:** `|| $0 == "premium"` in the starter clause would match an entitlement literally named "premium", which should map to `.premium`, not `.starter`. The clause ordering (elite first, then premium, then starter) does protect against the elite case, but the `$0 == "premium"` arm in the starter branch is suspicious.
**Fix:** Remove `|| $0 == "premium"` from the starter branch and ensure the RevenueCat entitlement naming is consistent with `activeIds.contains(where: { $0.contains("premium") })` for the premium tier check.

---

### [MED] PartnerDetailView.swift:44-47 — TryOnView sheet opened without pre-selecting the jewelry item
**What:** `selectedJewelryForTryOn` is set at line 189 before `showTryOn = true` at line 191, but `TryOnView()` at line 45 is constructed with no parameters and no `@Environment` item that carries the pre-selected jewelry. The jewelry selection is stored in local state `selectedJewelryForTryOn` but never passed to `TryOnView`. The user taps "Essayer" on a specific ring, and TryOnView opens to its default (unselected) state.
**Why:** `selectedJewelryForTryOn` is set but never consumed by the destination view.
**Fix:** Pass the selected item to TryOnView (via initialiser, environment, or a shared ViewModel/service).

---

### [MED] MainTabView.swift:94 — `ClothingCatalogService.shared.fetchAll(force: true)` called in MainTabView's `.task` AND in EcrinVirtuelApp boot `.task` (step 4)
**What:** The boot sequence (EcrinVirtuelApp.swift:55) already calls `await ClothingCatalogService.shared.fetchAll(force: true)`. MainTabView's `.task` (line 94) calls it again unconditionally every time `MainTabView` appears. With `force: true` there is no cache bypass prevention — this triggers two sequential network fetches of the entire 95-item catalog on every app launch (once during boot, once when the main tab view appears).
**Why:** Duplicate forced fetch of the catalog wastes bandwidth and Supabase read quota on every launch.
**Fix:** Remove the `fetchAll(force: true)` from MainTabView's `.task`, or at minimum change it to `fetchAll(force: false)` so the already-loaded cache is respected.

---

## LOW

### [LOW] GamingService.swift:218 — `"first_challenge"` badge condition is `challengeWinCount >= 0` — always true once `checkBadges()` runs
**What:** `case "first_challenge": return profile.challengeWinCount >= 0` — since `challengeWinCount` is initialised to 0 and the condition is `>= 0`, this badge is always awarded on the first call to `checkBadges()` after the `first_challenge` badge hasn't been earned yet. Every new user gets the "Première Candidate" badge without ever participating in a challenge.
**Why:** Condition should be `>= 1` but is `>= 0`.
**Fix:** Change to `return profile.challengeWinCount >= 1` or wire a `challengeParticipatedCount` counter.

---

### [LOW] GamingService.swift:221-222 — Duplicate badge conditions: "challenge_3" and "challenge_won_3" both use `challengeWinCount >= 3`
**What:** `case "challenge_3": return profile.challengeWinCount >= 3` and `case "challenge_won_3": return profile.challengeWinCount >= 3` are identical conditions. Both badges are earned at the same moment. "challenge_3" is documented as "Participated in 3 different challenges" (a participation metric) but uses the win counter.
**Why:** Missing a `challengeParticipatedCount` field; participation and wins are collapsed into one counter.
**Fix:** Add `var challengeParticipatedCount: Int = 0` to `GamingProfile`, update it in `updateCounters(for: .challengeParticipated)`, and use it for `"challenge_3"`.

---

### [LOW] CreditsManager.swift:96 — `handleSubscriptionUpgrade(to:)` sets `remaining = 999` for `.elite`
**What:** `remaining = status.monthlyGenerations == .max ? 999 : status.monthlyGenerations`. `Int.max` is `9223372036854775807` on 64-bit; the comparison `.max` refers to `Int.max`. For `elite` tier, `trialLimit` returns `.max` → `remaining` is set to 999. This is a display-only approximation (fine), but if the user tries to consume 1000 credits before the next sync, they'll hit the paywall. Since `isUnlimited` is also set by the server (via `UnlimitedAccess.isUnlimited`) and `consume()` checks `if isUnlimited { return true }` first, this is not a real block. But `handleSubscriptionUpgrade()` does NOT set `isUnlimited = true`, only `remaining = 999`. After an elite purchase, until the next `sync()`, `isUnlimited` is `false` and `remaining = 999`. The user would be blocked after 999 optimistic decrements.
**Why:** `handleSubscriptionUpgrade()` updates `remaining` but not `isUnlimited`.
**Fix:** Add `if status == .elite { isUnlimited = true }` inside `handleSubscriptionUpgrade()`.

---

### [LOW] BoutiqueView.swift — Entire BoutiqueView is a stub (dead feature in production build)
**What:** `BoutiqueView` contains only a `Text("Boutique")` label. It is not in the tab bar (`MainTabView` uses `PartnerStoreView` for the Boutique tab). `BoutiqueView` appears to be dead code.
**Why:** Unused file; `MainTabView` at line 39 uses `PartnerStoreView()`, not `BoutiqueView()`.
**Fix:** Delete `BoutiqueView.swift` or document its intended use.

---

### [LOW] PartnerService.swift:94-95 — `PartnerBrand.id` (UUID) is re-generated at every app launch via `UUID()` in the static `sampleBrands` array
**What:** `static let sampleBrands: [PartnerBrand]` initialises `id: UUID()` for each brand. Static `let` in Swift is lazily initialised once per process lifetime, so this is stable within a session. However, across launches the UUID changes. If any code persists a `PartnerBrand.id` (e.g. in `PartnerDetailView.selectedBrand` navigation state, or analytics `clickLog`), those IDs will not match across launches.
**Why:** `PartnerService.fetchPartnerCatalog(id:)` identifies Moni'attitude by checking `moni.name.contains("Moni")` — this works around the unstable UUID but only for that specific brand. Any future partner lookup by ID will fail across launches.
**Fix:** Use a stable hardcoded UUID literal instead of `UUID()` for static partner data.

---

### [LOW] GamingDashboardView.swift:396 — `var displayBadge = badge` is mutated inside a closure side-effect block that evaluates to `()`; the mutation has no effect
**What:** Lines 395-396:
```swift
var displayBadge = badge
let _ = { if gaming.profile.earnedBadgeIDs.contains(badge.id) { displayBadge.earnedAt = displayBadge.earnedAt ?? .now } }()
```
`displayBadge` is modified inside the closure but `displayBadge` is a copy captured by the closure. The outer `displayBadge` is never used after this block — the `Button` label immediately creates another copy of `badge` via `BadgeCard(badge: { var b = badge ... }())`. The entire `displayBadge` mutation is dead code.
**Why:** Closure captures `displayBadge` by value; the mutation inside the closure doesn't affect the outer variable. The outer `displayBadge` is never read.
**Fix:** Remove the dead `displayBadge` mutation block. The `BadgeCard` below it already handles the earned state correctly.

---

End of report.
