# M2 Audit — Occasions Cluster
Generated: 2026-06-21

Severity scale: CRIT > HIGH > MED > LOW

---

## CRIT

### [CRIT] GiftViewModel.swift:77,88-119 — Gift insert sends columns that don't exist in prod schema — data loss + 400 error every time
**What:** `createGiftLink` inserts `from_display_name`, `from_email`, `jewelry_json`, `jewelry_image_url` into `gift_cards`. The prod schema (migration 001, confirmed against prod baseline in 009) has none of those columns; the table only has `id, from_user_id, jewelry_id, jewelry_name, message, occasion, share_token, is_revealed, expires_at, created_at`.
**Why it breaks:** Every insert will throw a Postgres column-not-found error. The `catch` at line 135 silently degrades to a local-only card with a `ecrin://gift/…` deeplink. The recipient can never fetch the gift from Supabase because the row was never written. The error is logged but no user-facing toast is shown to the sender.
**Fix:** Either align the insert columns to the real schema (drop the extra columns, add `share_token`), or run a migration to add the missing columns.

### [CRIT] GiftViewModel.swift:173-179 — `receive(giftID:)` selects `from_email`, `jewelry_json` — columns that don't exist — always throws, always falls back to GiftCard.sample
**What:** The SELECT query lists `from_email`, `from_display_name`, `jewelry_json`, `jewelry_image_url`, `created_at`. None of these exist in prod `gift_cards`. The query will throw a Postgres error at `.execute().value`.
**Why it breaks:** Every gift-reveal deeplink will land in the `catch` block (line 236) and render `GiftCard.sample` — a hard-coded dummy "Bague Solitaire from marie@example.com". Recipients always see the demo card, never the real gift.
**Fix:** Align SELECT columns to the real schema.

---

## HIGH

### [HIGH] GiftCard.swift:64 — Force-unwrap on URL construction crashes when `id` contains reserved chars
**What:** `var generatedShareURL: URL { URL(string: "ecrin://gift/\(id.uuidString)")! }`
**Why it crashes:** UUID strings are safe but the force-unwrap propagates to all callers (`createGiftLink`, `GiftRevealView` `.task`). Any future change to the URL template that introduces invalid characters silently turns into a crash instead of a compile-time issue. Also, the sender's share sheet shows `ecrin://gift/<uuid>` (a custom scheme), while the DB row would store `https://inferencevision.store/ecrin/gift/<uuid>` — the receiver gets an unusable URL.
**Fix:** Use `URL(string:)!` only in tests; build the URL with `URLComponents` and guard or throw.

### [HIGH] WeatherSnapshot.swift:33 — `weatherSeason` uses `Calendar.current` (device locale calendar), not a UTC/fixed calendar — wrong month at midnight near DST boundaries
**What:** `Calendar.current.component(.month, from: fetchedAt)` inherits the device's locale, calendar type, and timezone. `fetchedAt` is stored in UTC (ISO8601 decoder on the service). At midnight UTC in a UTC+N timezone the device may decode the date as the previous month.
**Why it matters:** Season computation is wrong for ~1–2 hours around midnight near month boundaries. Spring vs. Winter flip at month 3 boundary is the most visible case.
**Fix:** Use `Calendar(identifier: .gregorian)` with `timeZone = TimeZone.current` (not UTC) to extract the month, which matches user expectation.

### [HIGH] WeatherLookRecommender.swift:334 — `seasonMatch` compares `weatherSeason.rawValue` ("ete", "hiver" …) against catalog `item.season` strings, but catalog stores "été", "automne" etc. — season scoring is always zero
**What:** `weather.weatherSeason.rawValue` returns `"ete"` (no accent), `"printemps"`, `"automne"`, `"hiver"`. Catalog rows store `["printemps","été","automne","hiver"]` (with accent on été). The `.lowercased()` comparison `"ete" == "été"` is false; diacritic folding is not applied here.
**Why it breaks:** Season scoring (20-point weight) always returns 0 for summer items. The fallback `ignoreSeason` path gives everything a flat 0.1. Catalog `"all"` season items (which are NOT in the catalog data) also produce 0. This means season-specific picks are never boosted and the recommender effectively ignores season.
**Fix:** Either store rawValues without accents in the catalog, or apply `.folding(options: .diacriticInsensitive, locale: .current)` before comparing in `seasonMatch`.

### [HIGH] LookNotificationService.swift:11 — `@MainActor final class LookNotificationService: Sendable` — `@MainActor` type cannot conform to `Sendable` correctly; stored mutable state (`center`) is not Sendable-safe
**What:** `@MainActor` classes are not `Sendable` because they can only be accessed from the main actor; the `Sendable` conformance is semantically wrong and will trigger a warning/error in strict concurrency. `UNUserNotificationCenter` is not `Sendable`.
**Fix:** Remove `Sendable`, let the `@MainActor` isolation guarantee thread-safety.

### [HIGH] LookDuJourViewModel.swift:210+143 — Double location request on every `activate` call
**What:** `activate` → `performLocateAndFetch` which calls `locationService.requestPermissionAndLocate()` (line 210), then immediately calls `refresh` (line 211) which also calls `requestPermissionAndLocate()` when `force == true` (line 143). Every first-activation triggers two full locate sequences (GPS request + reverse-geocode) in sequence.
**Fix:** Remove the redundant call in `refresh` when called immediately after `performLocateAndFetch`, or pass a flag.

---

## MED

### [MED] WeddingViewModel.swift:97 — `try?` swallows auth session error; silently falls back to `loadOrCreate()` — user loses remote data with no feedback
**What:** `guard let userId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString` — network/auth errors silently turn into "no user", triggering local-only mode with no toast or error.
**Fix:** Distinguish "not logged in" (expected) from "auth error" (unexpected) and surface the latter.

### [MED] WeddingViewModel.swift:176 — `_ = try? await` on upsert — all Supabase write failures are silent; wedding data is lost remotely with no retry
**What:** Upsert errors in the background `Task.detached` block are swallowed. If the network fails or the schema is wrong, the local cache has the data but Supabase never syncs, with no feedback.
**Fix:** Log or surface the error; consider a retry queue.

### [MED] LocationService.swift:53-54 — Two `CheckedContinuation` properties without protection against double-resume if `CLLocationManager` fires delegate callbacks twice
**What:** If `locationManagerDidChangeAuthorization` is called twice (possible on iOS < 17 with `requestWhenInUseAuthorization`), `permissionContinuation?.resume()` is called once, then `permissionContinuation` is still non-nil until the next line clears it — there is a race if the second delegate call arrives before the Task context switches back. Double-resume crashes the app.
**Fix:** Nil the continuation before calling `.resume()`.

### [MED] LookNotificationService.swift:93 — `try? await center.add(request)` — notification scheduling failure is silently swallowed; `requestAndSchedule` returns `true` even though the notification was not added
**What:** If `UNUserNotificationCenter.add` fails (e.g. notification limit reached, category misconfigured), the function still returns `true` and sets `userWantsNotifKey = true`. The user will believe notifications are enabled but never receive them.
**Fix:** Propagate the error or at minimum return `false`.

### [MED] WeatherService.swift:113-120 — Retry logic in `fetchWithRetry` retries even on non-transient errors (HTTP 400/429); 3-second sleep on main actor (class is `@MainActor`)
**What:** The `catch` around `session.data(for:)` retries unconditionally including on HTTP errors that are handled after the call returns. But `Task.sleep` at line 118 suspends the task — since `WeatherService` is `@MainActor`, this suspends on the main actor for 3 seconds during any network error.
**Why:** While a suspension is not a UI block, it delays all subsequent `@MainActor` work, and a cancelled `Task` will throw before the sleep, causing the retry to re-run on a stale task context.
**Fix:** Only retry on `URLError` with transient codes; move to `nonisolated` or a background actor.

### [MED] WeatherSeason.swift:13-20 — Southern hemisphere and edge-month temperature override can loop to `.hiver` for months 3–5 below 5°C (cold spring snap) but months 9–11 above 20°C fall through to `hiver` too — not a bug per se but a correctness gap
**What:** `case 9...11 where temperatureC < 20` — a warm autumn (e.g. 22°C in October) falls through to `default: return .hiver`. This returns `.hiver` for hot October weather, causing winter items to be recommended during a warm autumn.
**Fix:** Remove temperature guard from autumn, or add a `case 9...11: return .automne` fallback.

---

## LOW

### [LOW] OccasionVaultViewModel.swift:32-35 — Sample data written to UserDefaults on first launch then never updated if `SavedLook.samples` changes
**What:** `if savedLooks.isEmpty { savedLooks = SavedLook.samples; save() }` — once saved, samples are never refreshed when the array is updated in new versions. Stale sample data from old installs persists indefinitely.
**Fix:** Version the storage key (already done with `_v2`) and clear samples on version bump.

### [LOW] StoneDetector.swift:63 — `item.material` used directly without nil-check coercion (it's a non-optional in `JewelryItem` but the concatenation includes a potentially empty string) — not a crash risk, minor logic gap
**What:** `"\(item.name) \(item.prompt) \(item.material)"` — if `item.material` is empty the haystack is still valid; no crash. Low severity.

### [LOW] WeatherLookRecommender.swift:169 — Dress-detection heuristic uses `catalogResult.first?.category.lowercased() == "dress"` which only checks the FIRST catalog item. If a wardrobe item fills slot 1 and a dress is slot 2 in catalog, `hasCatalogDress` is false and a bottom is added alongside the dress.
**What:** Logic: `let hasCatalogDress = catalogResult.first?.category.lowercased() == "dress"`. But `catalogResult` is empty at this point if a wardrobe top was picked (wardrobeResult is populated instead). The dress detection across both lists is inconsistent.
**Fix:** Check `catalogResult.contains(where: { $0.category.lowercased() == "dress" })`.

### [LOW] LookDuJourViewModel.swift:239 — `.stale` threshold is `< -2 * 3600` (negative = past), but the check `snapshot.fetchedAt.timeIntervalSinceNow < -2 * 3600` correctly detects data older than 2 hours. This is fine but the cache is valid for 30 minutes (`WeatherPersistence.cacheDuration`), so data that passes the 30-min cache check can still trigger `.stale` after 2 hours — intentional but undocumented.

---

## Summary

| Severity | Count |
|----------|-------|
| CRIT     | 2     |
| HIGH     | 5     |
| MED      | 6     |
| LOW      | 4     |
| **Total**| **17**|
