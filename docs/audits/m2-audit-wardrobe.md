# Wardrobe/Catalog/Outfit Cluster — Code Audit
Generated: 2026-06-21

---

## [CRITICAL] SupabaseService.swift:501 — wardrobe upsert targets wrong RLS policy (UUID vs varchar key mismatch)

**What:** `saveWardrobeItem(_:)` builds a `SupabaseWardrobeRow` whose `id` field is declared `String`, set to `item.id.uuidString`. The production `wardrobe_items` table (schema documented in 009_prod_baseline.sql:93-95) has `id varchar`, `user_id varchar`. These match varchar. However, the RLS policy evaluates `(auth.uid())::text = user_id::text`. The upsert row encodes `user_id = auth.session.user.id.uuidString` (a String). This should work for the write. The critical issue is the **schema mismatch on the `wardrobe_items` table itself**: production has only `id, user_id, name, type, category, brand, color, image_url, is_favorite, created_at` — it is **missing the columns** `subcategory, material, tags, try_on_prompt, source, price, purchase_url` that `SupabaseWardrobeRow` (SupabaseService.swift:424-440) encodes and inserts. The upsert will **fail with a Postgres 42703 "column does not exist"** error — silently swallowed by `try?` at WardrobeViewModel.swift:76.

**Why:** The schema was declared in migration 001 (`swift_native_tables.sql`), but the prod baseline (009) reveals the real table has far fewer columns. Every add/update silently fails on cloud; user data is never persisted to Supabase.

**Fix:** Either apply a migration that adds the missing columns, or trim `SupabaseWardrobeRow` to only what the prod table has, and propagate errors (remove `try?`).

---

## [CRITICAL] SupabaseService.swift:149-173 — `users` table auth_id usage inverted vs prod schema

**What:** `fetchPreferredGender(authId:)` and `updatePreferredGender(_:)` query/upsert the `users` table filtering on `auth_id` (a separate column). But production schema (009_prod_baseline.sql:82-88) documents: **"id IS auth.uid() — NOT a separate auth_id"**, `id varchar NN=gen_random_uuid() (== auth.uid() text)`. The `auth_id` column does not exist in production. All calls to `fetchPreferredGender` and `updatePreferredGender` silently fail (`try?` at line 171); the preferred gender is never read or saved.

**Fix:** Change `eq("auth_id", value: authId)` → `eq("id", value: authId)` and the upsert's `onConflict: "auth_id"` → `onConflict: "id"`.

---

## [CRITICAL] WardrobeViewModel.swift:68 — cloud sync overwrites sample items with empty list on first launch

**What:** `init()` unconditionally fires `Task { await syncFromCloud() }`. `syncFromCloud()` (line 118) calls `supabase.fetchWardrobeItems()`, which calls `auth.session` (line 467 of SupabaseService.swift). When the user is not signed in, `try?` makes it return `[]`. The guard `guard let cloudItems = try? …, !cloudItems.isEmpty else { return }` guards against the empty-array case, so on an unauthenticated launch the sync is correctly skipped. **However**, if the user IS signed in but the wardrobe_items table is empty (first login), `cloudItems` is empty — again the guard fires `return` — but `items` is already populated from `FashionItem.samples` and then `save()`. This is benign. The real bug: after a successful cloud fetch returns items, `items = cloudItems + localOnly` (line 125) then calls `save()`. If the cloud now returns the pre-migration broken rows (wrong columns decoded back), `asFashionItem` uses fallbacks (`?? .top`, `?? .now`, etc.) that produce corrupted local items that permanently replace the user's local data.

**Fix:** Validate decoded items (non-empty name, valid category) before replacing `items`.

---

## [HIGH] WardrobeViewModel.swift:76,83,89,98 — all Supabase write errors swallowed with `try?`

**What:** Every CRUD operation — `add`, `update`, `delete`, `toggleFavorite` — launches a fire-and-forget `Task { try? await supabase.XXX }`. Errors from network failures, schema mismatches, auth expiry, and RLS denials are silently discarded. The UI shows no error state. Combined with the column mismatch in CRITICAL #1, this means users believe their wardrobe is cloud-backed when it is not.

**Fix:** Capture errors in a `@Published var syncError: Error?` and surface them (at minimum a brief toast); or use structured error logging beyond the current `lastError` which is only on `ClothingCatalogService`, not `WardrobeViewModel`.

---

## [HIGH] ClothingCatalogService.swift:29-42 — parallel fetch race: `totalCount` checked before writes complete

**What:** `fetchAll()` runs three sequential awaits (lines 35-37): `womenItems`, `menItems`, `unisexItems`. Between each await the MainActor yields. If a second caller enters `fetchAll(force: false)` during this window (e.g. two views appearing simultaneously), `totalCount > 0` may already be true (womenItems populated) and the second call returns immediately, leaving `menItems`/`unisexItems` empty. `CatalogBrowserView.swift:43` calls `fetchAll(force: true)` on `.task`, so `force` mitigates this for the primary view, but `fetchBySeasonAndCategory` (line 125) reads the cached arrays directly and will return incomplete data during a concurrent load.

**Fix:** Add a `private var isFetching: Bool` flag guard at the start of `fetchAll` (in addition to the data-presence check), or use `async let` to parallelize all three gender fetches atomically.

---

## [HIGH] AddWardrobeItemSheet.swift:7 — `@StateObject` for `AddItemForm` in `@Observable`-world ViewModel

**What:** `AddWardrobeItemSheet` uses `@StateObject private var form = AddItemForm()` where `AddItemForm` is an `ObservableObject` (line 330). The enclosing `WardrobeViewModel` is `@Observable`. In iOS 17+ `@Observable` world, mixing `@StateObject`/`ObservableObject` in child views of `@Observable` parents compiles but can produce double-observation cycles and stale renders because `@StateObject` retains through view identity but `@Observable` uses per-access tracking. More concretely: `DetailsSection` takes `@ObservedObject var form: AddItemForm` (line 249) — this is a re-observation of the same object, which is redundant and may cause spurious re-renders on every published-property change.

**Fix:** Convert `AddItemForm` to `@Observable` and use `@State` in the sheet; remove `@ObservedObject` from `DetailsSection`.

---

## [HIGH] WardrobeAnalyticsViewModel.swift:109 — force-unwrap on `totalValue`

**What:** Line 109: `avgPrice = totalValue! / Double(prices.count)`. `totalValue` is set to `prices.reduce(0, +)` on line 108 and `avgPrice` is computed immediately after inside the `else` branch where `prices` is non-empty. The force-unwrap is unnecessary but also **safe only because** `totalValue` is set two lines above. If the order of these lines ever changes (refactor), the force-unwrap becomes a crash. `prices.count` is guaranteed > 0 by the `if prices.isEmpty { return }` guard on line 104.

**Fix:** Replace `totalValue!` with `(totalValue ?? 0)` or rewrite as a local `let total = prices.reduce(0, +)`.

---

## [MEDIUM] OutfitViewModel.swift:12 — OutfitViewModel is `ObservableObject` while parent uses `@Observable`

**What:** `OutfitBuilderView` creates `@StateObject private var vm = OutfitViewModel()` (line 8). `OutfitViewModel` is `final class … ObservableObject` (line 7), while the rest of the codebase has migrated to `@Observable` (`WardrobeViewModel`, `ClothingCatalogService`, `WardrobeAnalyticsViewModel`). Using `@StateObject` with `ObservableObject` in a view that may be embedded inside `@Observable` parents causes the view to receive updates via `objectWillChange` rather than per-property fine-grained invalidation, potentially causing unnecessary full-view re-renders when any `@Published` var changes.

**Fix:** Migrate `OutfitViewModel` to `@Observable` and change `@StateObject` → `@State`.

---

## [MEDIUM] CatalogBrowserView.swift:43 — `fetchAll(force: true)` called on every `.task` invocation

**What:** `.task { await catalogService.fetchAll(force: true) }` (line 43) bypasses the cache guard and triggers a full 3-gender network fetch every time `CatalogBrowserView` appears (e.g., tab switching). Each appearance issues up to 6 HTTP requests (3× SDK + 3× REST fallback). With the REST fallback always active (SDK may be failing per logs), that's 3 JSONDecoder + 3 URLSession calls per tab switch.

**Fix:** Use `force: false` for normal appearances; only `force: true` from the explicit "Réessayer" button or pull-to-refresh (already done at line 196).

---

## [MEDIUM] CatalogClothingItem.swift:229 — `resolvedFashionCategory` default for unknown `accessory` subcategory returns `.scarf`

**What:** `resolvedFashionCategory` (line 220) for `category == "accessory"` with no matching subcategory keyword falls through to `return .scarf` — the last case. Any accessory item with an unrecognized subcategory (e.g. "montre", "ceinture" spelled differently, or nil) will be mapped to `.scarf`. The `bodyZone` for `.scarf` is `.neck`, affecting try-on routing. Similarly, the default for any unrecognized top-level category returns `.top` (line 229) — silently coercing e.g. a "jewelry" catalog item to a top.

**Fix:** Return an explicit nil or throw; at minimum log the unrecognized case.

---

## [MEDIUM] WardrobeViewModel.swift:124 — cloud-to-local merge strategy is lossy for local-only sample items

**What:** `syncFromCloud()` replaces `items` with `cloudItems + localOnly`. `localOnly` is computed as `items.filter { !cloudIDs.contains($0.id) }`. The 27 `FashionItem.samples` all have fixed UUIDs generated at struct literal time (each `UUID()` call in the static `let samples` array). Because `UUID()` is called once when the type is loaded, the same UUID is generated every session. If the cloud ever contains an item whose UUID happens to collide with a sample UUID (unlikely but possible if samples were ever synced up), the local sample is silently dropped from the merge.

**Fix:** Mark sample items with a special `source: .generated` sentinel or prefix their IDs with a known namespace UUID.

---

## [LOW] BackgroundViewModel.swift:116 — `isApplying = false` set inside a nested `Task { @MainActor in … }` instead of `defer`

**What:** Line 116: `defer { Task { @MainActor in isApplying = false } }`. Since `applyBackground` is already `@MainActor`, the `defer` + nested `Task` is unnecessary indirection. The `defer` runs synchronously, schedules a new Task, and the `isApplying` flag is reset only when that Task runs — after all awaits complete. This is functionally correct but fragile: if the function is ever made `nonisolated` or moved off MainActor, the nested Task will still hop back to MainActor while the outer function could be on another executor, causing a brief window where `isApplying` stays `true` after the function returns.

**Fix:** Use `defer { isApplying = false }` directly since `@MainActor` is already inherited.

---

## [LOW] OutfitBuilderView.swift:61-64 — `.task` initializes `availableItems` from `appState.wardrobe` but OutfitViewModel starts with `FashionItem.samples`

**What:** `OutfitViewModel.availableItems` (line 12) is initialized to `FashionItem.samples`. The `.task` block (line 61) sets `vm.availableItems = appState.wardrobe.items.isEmpty ? FashionItem.samples : appState.wardrobe.items`. If `appState.wardrobe` is mid-sync (isSyncing = true, items = samples), the builder will use samples instead of the user's real items. The `.onChange(of: appState.wardrobe.items)` (line 65) will correct this later, but there's a visible window where the wrong items appear in the picker.

**Fix:** Observe `appState.wardrobe.isSyncing` and defer the initial assignment, or always use samples as fallback only when both the sync is complete AND items is empty.

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH     | 4 |
| MEDIUM   | 4 |
| LOW      | 2 |
| **Total**| **13** |
