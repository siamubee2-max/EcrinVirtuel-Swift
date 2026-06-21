# Try-On Core Cluster — Code Audit
*Files audited: TryOn/, QuickTryOn/, MultiPose/, ARTryOn/, JewelryDetection/, SkinTone/ + 4 Core Services*
*Read-only audit — no files modified.*

---

## CRITICAL

### [SEV: Critical] `BodyContextAnalyzer.swift:197` — `try? handler.perform([request])` silently swallows Vision failures in `detectFaceRect`
**What's wrong:** `try? handler.perform([request])` discards any Vision error (permission denied, unsupported hardware, invalid image format, out-of-memory). When it fails, the `withCheckedContinuation` continuation is never resumed. This causes a **Swift concurrency hang**: the caller `await detectFaceRect(...)` suspends forever, which in turn hangs every call to `BodyContextAnalyzer.analyze()`, blocking `tryOnEnriched`, `tryOnQuick`, and the multi-pose generation pipeline — the whole image generation feature is dead with no error shown to the user.
**Why it matters:** The same pattern is repeated in `analyzePose` (line 317) and `detectClothing` (line 543). Three potential hangs in the same code path.
**Suggested fix:** Replace `try? handler.perform([request])` with a `do/catch` that resumes the continuation with a fallback value on error:
```swift
do { try handler.perform([request]) }
catch { continuation.resume(returning: nil) } // or default value per method
```

---

### [SEV: Critical] `ARTryOnView.swift:30` — `isCapturing` is never reset to `false` after snapshot if `ARView.snapshot` returns `nil`
**What's wrong:** In `updateUIView`, when `isCapturing` is `true`, `captureSnapshot(completion:)` is called. Inside `captureSnapshot` (line 218), `arView.snapshot(saveToHDR:)` may return `nil` (e.g., Metal not available, session not running). In that case `completion` is never called, so `DispatchQueue.main.async { isCapturing = false }` on line 33 is never reached. `isCapturing` stays `true` permanently, causing `updateUIView` to call `captureSnapshot` on every subsequent SwiftUI re-render — potentially dozens or hundreds of times per second, creating a runaway snapshot loop.
**Why it matters:** Infinite render loop → battery drain, UI freeze, possible session corruption.
**Suggested fix:** Always reset `isCapturing` in the completion regardless of whether `image` is nil:
```swift
arView.snapshot(saveToHDR: false) { image in
    defer { DispatchQueue.main.async { isCapturing = false } }
    if let image { completion(image) }
}
```

---

## HIGH

### [SEV: High] `QuickTryOnViewModel.swift:311` — `CreditsManager.shared.remaining` mutated directly from non-owner code
**What's wrong:** Line 311: `CreditsManager.shared.remaining = 0`. This is a direct external mutation of a shared singleton's state property, bypassing whatever locking or actor isolation `CreditsManager` uses. If `CreditsManager` is `@Observable` or `@MainActor`, this mutation on the MainActor's task could race with a background `syncDetached()` call that also writes `remaining`. More critically, this over-writes the canonical credit count with `0` unconditionally — if there was a race and `remaining` was already refunded (e.g., network call returned in the meantime), this stomps the correct value.
**Why it matters:** Credit count is a billing-critical value. Incorrect zeroing could lock the user out of features they paid for, or allow extra generations that bypass the paywall.
**Suggested fix:** Expose a dedicated `markExhausted()` method on `CreditsManager` that sets remaining to 0 only if the server truly reports quota exhaustion (not a local side-effect). Remove the direct property assignment from the ViewModel.

---

### [SEV: High] `BodyContextAnalyzer.swift:508–520` — Dead branch in `classifyLightingType`: both `warm` and non-warm map to `.indoor` at brightness 0.30–0.55
**What's wrong:** Lines 513–514:
```swift
case 0.30..<0.55:
    return colorTemp == .warm ? .indoor : .indoor
```
Both arms of the ternary return `.indoor`. This is a copy-paste error — the intent was clearly to return different values (e.g., `.warm` vs `.natural`), but neither branch was filled in. The `colorTemp` check here is completely dead code. The `LightingType` enum almost certainly has a warm-indoor variant that will never be produced by this function.
**Why it matters:** The `promptContext` body context injected into every generation prompt will always report `.indoor` lighting for mid-brightness photos, even if the actual ambient is warm/golden, degrading generation quality for the majority of indoor photos. The wasted analysis CPU is minor; the broken prompt signal is the real cost.
**Suggested fix:** Determine the intended return values and fill them in. For example: `.indoor` for warm and `.natural` for cool/neutral at that brightness range.

---

### [SEV: High] `ImageGenerationService.swift:44–45` — 30-second connection timeout is too short for the full round-trip; 90-second resource timeout may be inadequate
**What's wrong:** `timeoutIntervalForRequest = 30` means if the Supabase Edge Function takes more than 30 seconds to *respond with the first byte*, URLSession throws a timeout. The comment says "génération IA peut prendre 20-40s", meaning the edge function itself is already at 40s of processing — add network overhead and the 30s connection timeout fires before the response begins. The 90s resource timeout then becomes irrelevant because the request already failed.
**Why it matters:** Every generation attempt on a slow backend response (which the code explicitly anticipates) will time out with `GenerationError.apiError` — no generation, credit consumed, then `refund()` is called, but the Edge Function may still be running server-side billing the provider.
**Suggested fix:** Set `timeoutIntervalForRequest` to at least 60 seconds (or better, align it to the full expected latency + margin: 70–90 seconds). `timeoutIntervalForResource` should be 120 seconds.

---

### [SEV: High] `ARTryOnWrapperView.swift:239` — AR jewelry picker uses hardcoded `JewelryItem.samples` instead of the live catalog
**What's wrong:** Line 239: `ForEach(JewelryItem.samples)`. The in-AR jewelry switcher overlay always shows only the static sample items, regardless of what was loaded from Supabase or what the user selected originally. The real jewelry catalog from Supabase is not passed into `ARTryOnWrapperView`.
**Why it matters:** Any jewelry item from the real catalog (loaded via `SupabaseService`) is invisible in the AR picker. Users can only switch between hardcoded demo items. This is a broken feature — the AR switcher will never reflect the production catalog.
**Suggested fix:** Add a `catalog: [JewelryItem]` parameter to `ARTryOnWrapperView.init` and pass the real catalog from the parent, then use it in `ForEach`.

---

### [SEV: High] `MultiPoseViewModel.swift:167–183` — Retry loop uses `try? Task.sleep(...)` which silently discards cancellation
**What's wrong:** Lines 181–182:
```swift
try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
```
Using `try?` here suppresses task cancellation. If the user dismisses `MultiPoseFlowView` (which calls `dismiss()`), the parent task is cancelled, but `Task.sleep` is interrupted silently, the retry loop *continues* for remaining attempts, and the generation keeps running after the view is gone. Since `MultiPoseViewModel` is `@MainActor` and mutates `@Observable` state (`results`, `progress`, `generatingPoseId`), mutations continue on a dismissed view, potentially accessing deallocated view state.
**Why it matters:** Ghost network requests, credit consumption after dismissal, possible writes to deallocated `@Observable` storage.
**Suggested fix:** Use `try await Task.sleep(...)` without `try?`, then let cancellation propagate. Wrap the generation loop in a `withTaskCancellationHandler` or check `Task.isCancelled` at the loop boundary.

---

### [SEV: High] `SkinToneAdvisorView.swift:44–50` — `photosPicker` bound to a constant `false` Binding; top-level Photos picker is broken
**What's wrong:** Lines 44–50:
```swift
.photosPicker(
    isPresented: Binding(
        get: { false },
        set: { _ in }
    ),
    selection: $selectedPhoto,
    matching: .images
)
```
The `isPresented` binding always returns `false` and the setter is a no-op. This modifier can never open the photo picker. The actual `PhotosPicker` used in the view body (lines 129–157 and 202) works correctly because they use `$selectedPhoto` directly as a label-based picker — but the additional programmatic `.photosPicker()` modifier at the bottom of the `body` is completely dead code that can never trigger. If any code path tries to open it programmatically (e.g., a future button calling a `showPicker = true` style), it will silently fail.
**Why it matters:** This is broken dead code that could mislead future maintainers into thinking programmatic photo picking is wired up when it isn't. If any usage were added, it would silently fail.
**Suggested fix:** Remove the entire `.photosPicker(isPresented: Binding(get: { false }, set: { _ in }), ...)` modifier — it serves no purpose.

---

## MEDIUM

### [SEV: Medium] `BodyContextAnalyzer.swift:350–356` — Height classification uses `neck.location.y - ankleY` without checking Vision coordinate direction
**What's wrong:** The comment at line 355 says "en coordonnées Vision (y croissant vers le haut)", meaning `neck.location.y > ankleY` for a standing person → `bodyHeight > 0` is expected. However, if the image is rotated (landscape capture, EXIF orientation), Vision's coordinate system may be inverted, giving a negative `bodyHeight`. The thresholds (`> 0.65` tall, `< 0.45` petite) don't guard against negative values, so any rotation would make everyone classify as `petite` (< 0.45 includes negatives) or cause incorrect height estimation.
**Why it matters:** Vision uses `VNImageRequestHandler(cgImage:)` which respects the image orientation from CGImage metadata. If the user takes a landscape photo, the coordinate system is rotated and the height estimate is wrong, affecting the prompt injected into every generation.
**Suggested fix:** Clamp `bodyHeight = abs(neck.location.y - ankleY)` to handle both coordinate orientations robustly.

---

### [SEV: Medium] `QuickTryOnViewModel.swift:285–296` — Multi-item generation uses `generated` (first-item result) as input for second-pass without credit refund atomicity
**What's wrong:** Lines 276–295: first pass generates with `primaryItem` (1 credit deducted). If it succeeds, a second pass re-generates the full look from the first-pass image. If the second pass throws (`catch` on line 305), `CreditsManager.shared.refund(count: creditCost)` refunds `creditCost` credits (which was 2 for `>1 items`). But 2 credits were consumed and 2 are refunded — seemingly correct. However, `syncDetached()` was NOT called before the second pass, so if the app is killed between pass 1 and pass 2, the server-side credit was consumed once but the local count shows 0 consumed (because no sync happened). On next launch, server and client will be out of sync.
**Why it matters:** Credit accounting inconsistency — users may see different credit counts after crash recovery.
**Suggested fix:** Call `CreditsManager.shared.syncDetached()` after the first pass succeeds (regardless of whether a second pass is needed), so the server credit state is persisted.

---

### [SEV: Medium] `ImageGenerationService.swift:88` — `tryOnEnriched` is marked `@MainActor` unnecessarily while calling blocking `sendRequest`
**What's wrong:** Line 88: `@MainActor func tryOnEnriched(...)`. This function is called from `QuickTryOnViewModel.generate()` which is already `@MainActor`. The `@MainActor` annotation here forces `sendRequest` (a URLSession call) to start on the MainActor. While `URLSession.data(for:)` is async and suspends, any synchronous work before that await (JSON serialization at line 213 `try JSONSerialization.data(...)`) runs on MainActor, blocking the UI thread briefly per request. In the multi-pose path, this is called per-pose sequentially.
**Why it matters:** Brief main-thread blocks per generation. Low impact with small JSON, but the pattern is architecturally incorrect.
**Suggested fix:** Remove the `@MainActor` annotation from `tryOnEnriched` — the `BodyContextAnalyzer` call inside already handles its own actor isolation correctly.

---

### [SEV: Medium] `MultiPoseFlowView.swift:552` — `DispatchQueue.main.asyncAfter` used inside a `@MainActor` SwiftUI view for dismiss delay
**What's wrong:** Line 552:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    dismiss()
}
```
This is called from `saveResultsToDressing()` which is inside a `@MainActor` SwiftUI view. Using `DispatchQueue.main.asyncAfter` in Swift 6 / Strict Concurrency mode creates an unstructured `DispatchWorkItem` that captures `dismiss` (an `@Environment(\.dismiss)` value, which is `Sendable`). While it compiles, it bypasses Swift structured concurrency — the work item is not cancellable, not tied to the view lifecycle, and fires even if the view is already dismissed (e.g., user swipes down the sheet before 1.2s elapses), calling `dismiss()` on an already-dismissed environment.
**Why it matters:** Double-dismiss of a sheet can cause a navigation state crash in SwiftUI (especially in NavigationStack contexts).
**Suggested fix:** Replace with a structured `Task { try? await Task.sleep(for: .seconds(1.2)); dismiss() }`.

---

### [SEV: Medium] `BodyContextAnalyzer.swift:466–471` — Integer division `w/3` and `w * 2/3` for CGRect cropping uses integer arithmetic on `Int` dimensions
**What's wrong:** Lines 469–470:
```swift
let leftRegion  = cgImage.cropping(to: CGRect(x: 0,         y: 0, width: w/3, height: h)) ?? cgImage
let rightRegion = cgImage.cropping(to: CGRect(x: w * 2/3,   y: 0, width: w/3, height: h)) ?? cgImage
```
`w` and `h` are typed as `Int` (`let w = cgImage.width`). `w/3` performs integer division, so for a 100px wide image, `w/3 = 33`, `w*2/3 = 66`, and the right region width is also `33` but starts at x=66, leaving 1px uncovered (`66+33=99`, not 100). The left and right strips are slightly narrower than 1/3 of the image, leaving a central gap unanalyzed. For the `topRegion`, `h/3` is fine (it's only a y-crop).
**Why it matters:** Minor: the lighting direction detection misses a 1px vertical slice on each crop boundary. The real issue is that `CGRect` expects `CGFloat`, so `w/3` converts `Int` → `CGFloat` but still loses precision from integer truncation. Could mislead the direction analysis for very narrow images.
**Suggested fix:** Cast to `CGFloat` before division: `let wF = CGFloat(cgImage.width); let leftWidth = wF / 3`.

---

### [SEV: Medium] `EarringsPoseView.swift:489–491` — `startGeneration()` falls back to `QuickTryOnMode.allCases[0]` which may not be compatible with earrings
**What's wrong:** Lines 489–491:
```swift
let defaultMode = QuickTryOnMode.allCases.first(where: {
    $0.compatibleCategories.contains(item.fashionCategory)
}) ?? QuickTryOnMode.allCases[0]
```
`QuickTryOnMode.allCases[0]` is `.topOnly` (the first case in declaration order). An earring item has `fashionCategory == .earring`, which is NOT in `.topOnly.compatibleCategories`. So if the `first(where:)` somehow fails (impossible with current data, but fragile), the fallback produces a mode incompatible with earrings, causing the prompt to be built with `.topOnly.promptSuffix` — "full body editorial shot… focus on the top garment" — which is semantically wrong for an earring try-on.
**Why it matters:** Broken generation prompt if the fallback is ever triggered. The fallback is `allCases[0]` which is an unchecked index access (crashes if `allCases` is empty — not the case today, but brittle).
**Suggested fix:** Use a safe default: `?? .jewelsOnly` which is the correct mode for jewelry.

---

### [SEV: Medium] `JewelryDetectionView.swift:152` — `ForEach(detectionResults, id: \.category)` uses non-unique ID
**What's wrong:** Line 152: `ForEach(detectionResults, id: \.category)`. The deduplication in `JewelryDetectionService.mapToJewelry` (line 71–77) ensures at most one result per `FashionCategory`, so in practice this is currently unique. However, `detectionResults` is typed as `[JewelryDetectionResult]` and nothing in the type system enforces uniqueness. If the deduplication logic is ever changed or bypassed, two results with the same `category` would have the same SwiftUI ID → incorrect diffing → potentially wrong rows being shown or crashes.
**Why it matters:** Latent SwiftUI identity bug. Low risk today given current deduplication, but fragile.
**Suggested fix:** Either conform `JewelryDetectionResult` to `Identifiable` with a stable unique ID (e.g., `UUID`), or use `id: \.label` which is the raw Vision identifier and is unique per observation.

---

## LOW

### [SEV: Low] `ARTryOnView.swift:108–109` — Unused `material` variable
**What's wrong:** Lines 108–109:
```swift
let material = ARJewelryEntity.goldMaterial()
_ = material // already captured in factory
```
`goldMaterial()` is called here but the returned `SimpleMaterial` is immediately discarded. The factory methods (`makeEarrings`, `makeNecklace`, etc.) all call `goldMaterial()` internally. This is dead code that creates an extra `SimpleMaterial` allocation per `setupJewelryEntities()` call (which is called every time jewelry changes).
**Suggested fix:** Remove both lines.

---

### [SEV: Low] `BodyContextAnalyzer.swift:513` — `classifyLightingType` has an unreachable `default` branch in a `switch` on `Double`
**What's wrong:** Line 518: `default: return .natural`. The `switch` covers `..<0.30`, `0.30..<0.55`, `0.55..<0.70`, and `0.70...`. These ranges partition all `Double` values (−∞ to +∞ and 0.70 to +∞). Swift's pattern-matching on `Double` requires a `default` branch because the compiler cannot prove coverage, but in this function `brightness` is constrained by `clamped(to: 0...1)` before reaching here, making `default` unreachable. The `default` silently returns `.natural`, hiding any future gaps if ranges are changed.
**Suggested fix:** Add an `assertionFailure` in the `default` branch to catch future range errors in debug builds.

---

### [SEV: Low] `SkinToneAdvisorView.swift:338–352` — `isAnalyzing = false` not in a `defer`, can be forgotten if early `return`
**What's wrong:** Lines 333–353: `isAnalyzing` is set to `true` at the start, and `false` at line 352 at the end. However, if the `guard let item else { return }` returns early (line 334), `isAnalyzing` was never set to `true` — fine. But if a future developer adds a `throw` or `return` between `isAnalyzing = true` and the final `isAnalyzing = false`, the spinner will be stuck. The pattern is not protected by `defer`.
**Suggested fix:** Add `defer { isAnalyzing = false }` immediately after `isAnalyzing = true`.

---

### [SEV: Low] `MultiPoseViewModel.swift:63–64` — `totalCostUSD` and `costEstimate` diverge: `totalCostUSD` uses `modelInUse` (which is default `.standard` until `generateAll` is called), `costEstimate` computes from `items.count`
**What's wrong:** `totalCostUSD` (line 64) computes cost using `costPerGeneration` which reads `modelInUse`. Before `generateAll` is called, `modelInUse == .standard`. `costEstimate(itemsCount:)` (line 50) always recomputes via `Self.model(for:)`. If the UI displays `totalCostUSD` before generation, it shows the wrong cost for multi-item looks (shows standard price, not premium). The posesSummaryCard in `MultiPoseFlowView.swift:299` correctly uses `costEstimate(itemsCount:)`, but if someone binds to `totalCostUSD` anywhere in the UI, it shows stale cost.
**Suggested fix:** Remove `totalCostUSD` or make it call `costEstimate(itemsCount:)` with the known items count, to avoid the stale-state trap.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High     | 5 |
| Medium   | 6 |
| Low      | 4 |
| **Total**| **17** |

---

## Top 3 Findings

1. **[Critical] `BodyContextAnalyzer.swift:197,317,543`** — Three `try? handler.perform([request])` calls that silently never-resume `withCheckedContinuation`, causing permanent async hangs that freeze the entire generation pipeline with no error surfaced.

2. **[Critical] `ARTryOnView.swift:218`** — `ARView.snapshot` nil case never resets `isCapturing`, triggering an infinite snapshot capture loop on every SwiftUI re-render once AR snapshot fails.

3. **[High] `ARTryOnWrapperView.swift:239`** — In-AR jewelry picker hardcodes `JewelryItem.samples` instead of the real catalog, making the AR jewelry switcher a broken feature that can never show production items.

---

*Report written to: /tmp/m2-audit-tryon.md*
