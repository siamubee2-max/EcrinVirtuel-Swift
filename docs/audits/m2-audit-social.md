# M2 Code Audit — Social/Export/SnapshotFrames/MoodBoard/Styliste
Date: 2026-06-21

---

## HIGH Severity

### [HIGH] SnapshotRenderer.swift:29–37 — saveToPhotos resumes continuation before write completes (data loss)
`UIImageWriteToSavedPhotosAlbum` is asynchronous: the write happens on a background thread and calls back via a selector/completion. The code passes `nil` for the completion callback, so `continuation.resume()` is called immediately—before the write finishes or errors. If the write fails (disk full, permission denied after the first check), the caller gets no error and `savedSuccess = true` is shown to the user. The image may silently not be saved.
```swift
// SnapshotRenderer.swift:33–36
UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)  // completion = nil
continuation.resume()                                  // immediate, not on write completion
```
**Fix:** Use `PHPhotoLibrary.shared().performChanges` (as `FullExportViewModel.saveToPhotos` correctly does) instead of `UIImageWriteToSavedPhotosAlbum`.

---

### [HIGH] BrandedShareSheet.swift:170–184 — `downloadToPhotos` never reports save failure (silent failure)
`PHPhotoLibrary.shared().performChanges` `completionHandler` receives `(Bool, Error?)`. The code ignores both parameters, so any write failure (disk full, permission revoked) is swallowed. `savedToPhotos = true` is set unconditionally.
```swift
// BrandedShareSheet.swift:175–183
PHPhotoLibrary.shared().performChanges {
    PHAssetChangeRequest.creationRequestForAsset(from: branded)
} completionHandler: { _, _ in        // ← success and error both ignored
    DispatchQueue.main.async {
        withAnimation(EcrinAnimation.springSnap) { savedToPhotos = true }
    }
}
```
**Fix:** Check `success`; if `false`, surface the `Error` to the user.

---

### [HIGH] CommunityViewModel.swift:121 — `Task.detached` captures `SupabaseService` without [weak self]; retain cycle risk + actor isolation violation
`Task.detached` runs outside the `@MainActor` isolation of `CommunityViewModel`. The closure captures no actor context. `SupabaseService.shared.setPostLike` may itself be `@MainActor` or require specific threading—calling it from a detached task skips all actor checks. Additionally, if the ViewModel is torn down before the task completes, the detached task holds a strong reference keeping it alive.
```swift
// CommunityViewModel.swift:121
Task.detached { await SupabaseService.shared.setPostLike(postId: postId, liked: newLiked) }
```
**Fix:** Use `Task { ... }` (inherits actor context) or `Task { [weak self] in ... }`.

---

### [HIGH] FrameRenderer.swift:30–58 — Heavy UIGraphicsImageRenderer compositing on background thread but modifies UIKit objects (thread safety)
`compose()` dispatches work via `Task.detached(priority: .userInitiated)`. Inside, `UIGraphicsImageRenderer` and all `UIBezierPath`, `UIColor`, `CGContext` calls are UIKit/CoreGraphics. UIKit drawing contexts (`UIGraphicsImageRenderer`) are not thread-safe when the host app also renders on main. While CGContext can typically be used off-main when you own the context, `UIColor(Color(hex:))` ultimately calls UIKit color conversion which may hit main-thread-only APIs.
```swift
// FrameRenderer.swift:30–31
return await Task.detached(priority: .userInitiated) {
    let renderer = UIGraphicsImageRenderer(size: outputSize)
```
`SnapshotRenderer.render()` similarly calls `ImageRenderer` (a SwiftUI type) on `@MainActor` but `renderer.scale = 1` — the scale of 1x for a render target of 1080×1920 will produce a 1x UIImage, meaning actual device pixel data is NOT at 1x relative to screen. On a 3x device the rendered image will be rendered at 1/3 the expected resolution (360×640 effective pixels, not 1080×1920). See next finding.

---

### [HIGH] SnapshotRenderer.swift:13 — render scale hardcoded to 1 produces low-resolution output at full pixel dimensions
`renderer.scale = 1` means ImageRenderer will use 1pt = 1px. But `targetSize` is already in pixels (1080×1920 for Stories). On a 3x device, SwiftUI lays out views in points, so the compositor will render at 1080×1920 **points** × 1 scale = a very large logical canvas, but the resulting UIImage only has 1080×1920 pixels (which is what is wanted). However `proposedSize` is set to 1080×1920 **points** — SwiftUI will lay out subviews as if the canvas is 1080pt wide (on a screen that is ~390pt wide). Text and elements will appear at 2.77× their screen size in points but the image will only be 1080px wide. The net result: **text and watermark are rendered at correct pixel size, but the photo fills the layout at 1080×1920pt which can cause extreme memory usage** (UIImage from SwiftUI ImageRenderer at that point size × 1 scale still allocates a large backing buffer). For a 1080×1920 composition this is 1080×1920×4 bytes = ~8 MB, acceptable; however this is a design risk if sizes change.

More critically: `renderer.scale = 1` when the source `UIImage` (`tryOnImage`) is a 3x screen-captured image means the image.draw call inside `SnapshotCompositeView` will appear at 1/3 size within the 1080pt frame, not filling it. The `.scaledToFill` modifier on the SwiftUI Image should correct this for the SwiftUI layer, but this is not guaranteed when rendered via `ImageRenderer` off the screen layout system.

**Fix:** Use `renderer.scale = UIScreen.main.scale` and set `targetSize` in points (e.g. 360×640 for stories), letting the renderer produce a pixel-correct output.

---

### [HIGH] GoldParticles.swift:31 — Timer on main run loop fires at 60 Hz, blocks main thread with particle math
`Timer.publish(every: 0.016, on: .main, in: .common)` runs `updateParticles()` on the main thread 60 times per second. `updateParticles()` allocates a new array via `compactMap` each frame (up to 120 particles). While lightweight individually, this is a guaranteed 60 Hz main-thread allocation loop for as long as the view is visible, competing with UI rendering.
```swift
// GoldParticles.swift:31–33
.onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
    updateParticles()
    if particles.count < 60 { spawnParticle(in: geo.size) }
}
```
**Fix:** Use `TimelineView(.animation)` (already wrapping the Canvas) to drive updates — it fires at display refresh rate and is optimized by SwiftUI. Remove the Timer entirely and compute particle positions as a pure function of time elapsed since start.

---

## MED Severity

### [MED] CommunityView.swift:180 — `StoryAvatar.isActive` recomputes on every body call with `Bool.random()` causing continuous random flicker
`let isActive: Bool = Bool.random()` is a stored property initialized at `let` declaration time. In a struct, this is re-evaluated every time the view is re-created (which SwiftUI can do very frequently). Each rerender will randomly flip whether the story ring is "active", causing visual flickering.
```swift
// CommunityView.swift:180
let isActive: Bool = Bool.random()
```
The property `isActive` is also never actually used in the body (the body uses `entry.rank <= 5` instead). It is dead code that still re-evaluates on every render.
**Fix:** Remove `isActive` entirely (it is unused) or make it deterministic.

---

### [MED] CommunityViewModel.swift:148–151 — `Task { @MainActor in try? await ... }` inside toggleParticipation silently swallows Task.sleep cancellation
`try?` suppresses the `CancellationError` from `Task.sleep`. If the ViewModel is deallocated or the task is cancelled, the `toastMessage = nil` line is still attempted on a potentially deallocated `self`. While `@MainActor` isolation prevents a data race, the `try?` means the 2.5s timer cannot be cancelled from outside.
```swift
// CommunityViewModel.swift:148–151
Task { @MainActor in
    try? await Task.sleep(nanoseconds: 2_500_000_000)
    if self.toastMessage != nil { self.toastMessage = nil }
}
```
**Fix:** Store the `Task` in a property so it can be cancelled when a new toast arrives or the VM is torn down.

---

### [MED] BrandedShareSheet.swift:189–191 — `renderBranded` creates a new `BrandedShareSheet` instance just to call `makeBrandedImage()`, leaking SwiftUI state
```swift
// BrandedShareSheet.swift:189–191
static func renderBranded(image: UIImage, jewelryName: String) -> UIImage {
    BrandedShareSheet(image: image, jewelryName: jewelryName).makeBrandedImage()
}
```
Creating a SwiftUI `View` struct outside the SwiftUI hierarchy to call a non-view method on it is architecturally broken. The `@State` properties (`savedToPhotos`, `appeared`, etc.) will be default-initialized (not the `@State`-managed values), which happens to be fine here since `makeBrandedImage()` only uses `image` and `jewelryName`. However this is a ticking time bomb: any future `makeBrandedImage()` refactor that reads `@State` will silently return wrong data.
**Fix:** Extract `makeBrandedImage()` to a standalone free function or `struct BrandedImageRenderer`.

---

### [MED] SocialExportView.swift:96–105 — `scheduleRender` task is cancelled but `renderTask` is never cancelled on ViewModel deinit (potential background work after dealloc)
`renderTask` is a `Task<Void, Never>` stored as an instance var but `SocialExportViewModel` has no `deinit` that cancels it. If the user dismisses the export sheet while a render is in progress, the task continues running (it is a MainActor task so it will try to write to `renderedImage` and `isRendering` on a deallocated — but retained by the task — ViewModel).
```swift
// SocialExportView.swift:96–105
private var renderTask: Task<Void, Never>?
func scheduleRender() {
    renderTask?.cancel()
    renderTask = Task { ... }
}
// No deinit
```
Same issue exists in `FullExportViewModel` (FullExportView.swift:369–384).
**Fix:** Add `deinit { renderTask?.cancel() }` to both ViewModels.

---

### [MED] MoodBoardResultView.swift:69–71 — `DispatchQueue.main.asyncAfter` for staggered animations instead of SwiftUI `.task` / `.onAppear` with `try await Task.sleep`
Three `DispatchQueue.main.asyncAfter` calls in `onAppear` introduce non-cancellable timers tied to the view lifecycle. If the view is dismissed before the timers fire, they still execute and write to `@State` variables on a dismissed view (harmless but wasteful). This is a SwiftUI anti-pattern.
```swift
// MoodBoardResultView.swift:69–71
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)  { paletteVisible = true }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { descriptionVisible = true }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.4)  { jewelryVisible = true }
```
**Fix:** Use a single `.task` with `try await Task.sleep` blocks that respect task cancellation.

---

### [MED] FrameRenderer.swift:98–118 — `drawImage` leaks CGContext clip state when `cornerRadius == 0`
When `cornerRadius > 0`, `context.saveGState()` is called before clipping. When `cornerRadius == 0`, neither `saveGState` nor `restoreGState` is called, which is correct. However the function uses early-return-style logic where `restoreGState` is called **only if cornerRadius > 0**, making the code fragile. If a future caller adds any drawing after the clip path is added (cornerRadius > 0 path) and before restore, they will draw within an invisible clip.
```swift
// FrameRenderer.swift:99–117
if cornerRadius > 0 {
    let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    context.saveGState()
    path.addClip()
}
...
image.draw(in: drawRect)
if cornerRadius > 0 {
    context.restoreGState()
}
```
This is fine today but is a latent bug. Minor severity bump since it does affect rendering if ever extended.

---

### [MED] CommunityPost.swift — `tryOnImage: Data()` hardcoded empty Data in all generated sample posts
Both `buildDynamicSamples` (line 178) and the static `samples` (line 326) set `tryOnImage: Data()`. The `CommunityPost` model requires this field for `Codable` (non-optional). Any code path that tries to convert `tryOnImage` back to `UIImage` (e.g., for the `PostCard` QuickTryOn sheet via `preselectedItem: .wardrobe(post.jewelry.asFashionItem)`) will work because it uses `post.jewelry`, not `post.tryOnImage`. However the field is misleading and wastes Codable space (though Data() is empty).
**Bigger issue:** the comment says "tryOnImage" is the image the user shared, but it's always empty Data for sample posts. If any downstream code ever calls `UIImage(data: post.tryOnImage)` it will silently get `nil`.

---

### [MED] FramePickerView.swift:258–260 — `isUnlocked` logic for Premium frames is wrong; Premium+XP frames are permanently locked
```swift
// FramePickerView.swift:258–260
func isUnlocked(_ frame: SnapshotFrame) -> Bool {
    if !frame.isPremium && !frame.isUnlockableByXP { return true }
    if frame.isUnlockableByXP { return unlockedByUser.contains(frame.id) }
    return false  // ← Premium-only frames: always false, no way to unlock
}
```
For `isPremium = true, isUnlockableByXP = false` (e.g., `magazine_ecrin`, `luxury_diamants`, `luxury_baroque`, `luxury_art_deco`, `magazine_vogue`, `magazine_harper`): the function returns `false` unconditionally. There is no in-app purchase flow that sets `unlockedByUser`, and Premium frames cannot be unlocked via XP. These frames are permanently locked for all users with no path to unlock.
**Fix:** Wire a subscription/purchase gate that adds premium frame IDs to `unlockedByUser`, or add a `subscriptionActive` property to `FrameViewModel` and check it here.

---

### [MED] StylisteViewModel.swift:45–48 — `history` is built from `messages.dropLast()` then `+ [newMsg]`, but `messages` already contains the user message (appended at line 39)
```swift
// StylisteViewModel.swift:38–49
messages.append(userMessage)      // messages now has the new user msg
isThinking = true
let history = messages
    .dropLast()                   // removes the user msg we just appended
    .map(\.asAPIMessage)
let newMsg = userMessage.asAPIMessage
// sends history (without new msg) + [newMsg] — effectively correct but confusing
```
The logic works by accident (dropLast removes the just-appended message, then it's re-added as `newMsg`). But it is fragile: if any future code path appends another message between line 39 and line 45, `dropLast` removes the wrong message and the API call gets stale history.
**Fix:** Capture `userMessage` before appending and build `history` from `messages` (before append) + `[userMessage]`.

---

## LOW Severity

### [LOW] CommunityViewModel.swift:14 — `currentUserRank: Int = 7` is a hardcoded constant with no data source
The user's rank is always 7 regardless of actual leaderboard data. The leaderboard `LeaderboardEntry.samples` is generated with ranks 1–20. `currentUserRank = 7` happens to match rank 7 in the sample data. If real data arrives and the user is not rank 7, the sticky banner will show wrong data or find `nil` (defaulting to "Vous" and "0 pts").

---

### [LOW] MoodBoardGalleryView.swift:6 — Gallery boards are in-memory only; newly generated boards are never persisted
`@State private var boards: [MoodBoard] = MoodBoard.previews` is reset every app launch. The `MoodSaveLookSheet.onSave` callback sets `savedSuccessfully = true` and dismisses the sheet but never inserts the board into `MoodBoardGalleryView.boards`. The save operation is a no-op: the gallery never grows.
```swift
// MoodBoardResultView.swift:74–77
MoodSaveLookSheet(board: board, onSave: {
    savedSuccessfully = true
    showSaveSheet = false
    // boards is not modified — no persistence or callback to parent
})
```
**Fix:** Pass a closure from `MoodBoardGalleryView` down through the navigation stack to append to `boards`, and persist to UserDefaults or Supabase.

---

### [LOW] MoodBoardResultView.swift:289–291 — "Essayer ces bijoux" CTA calls `dismiss()` instead of navigating to TryOn
```swift
// MoodBoardResultView.swift:289–291
GoldButton(title: "Essayer ces bijoux") {
    dismiss()   // just closes the result sheet, does not open TryOn
}
```
The button label promises try-on navigation but only closes the fullScreenCover. `MoodJewelCard.onTap` closure is also empty (line 249). The entire try-on CTA is dead code that silently dismisses.

---

### [LOW] FramePreviewTile.swift:72 — `scaleDown` computed property can return values < 1 for frames with borderWidth < 3
```swift
// FramePreviewTile.swift:72
private var scaleDown: CGFloat { frame.style.borderWidth > 0 ? max(frame.style.borderWidth / 3, 1) : 1 }
```
For `borderWidth = 2` (e.g., `classic_double_or`): `max(2/3, 1) = 1`. For `borderWidth = 3`: `max(1, 1) = 1`. For `borderWidth = 4`: `max(4/3, 1) = 4/3 ≈ 1.33`. The intent is to scale down the preview border, but for borderWidths 1–3 the scale is 1 (no scale-down). This makes thin-border frames look the same in the thumbnail regardless of actual width. Low impact.

---

### [LOW] FlowLayout.swift — `sizeThatFits` and `placeSubviews` use different row-break conditions (potential height mismatch)
`sizeThatFits` checks `rowWidth + w > containerWidth` (strictly greater), while `placeSubviews` checks the same condition with `!rows[rows.count - 1].isEmpty` guard. The two passes should produce matching row structures, but `sizeThatFits` accumulates `rowWidth += w + spacing` including trailing spacing for last item on row, while `placeSubviews` does the same. This matches, so no visual bug today, but the two passes duplicating logic is fragile.

---

### [LOW] GoldParticles.swift — `spawnBurst` adds 60 particles on `onAppear`, then the timer immediately calls `spawnParticle` since `particles.count < 60` is already false until age expires
Once 60 burst particles are active, the cap `particles.count < 60` prevents new ambient particles. As burst particles expire, ambient particles slowly fill up. The intent comment says "spawn burst + ambient" but the cap treats them identically. Burst and ambient phases are not cleanly separated. Minor visual design issue, not a crash.

---

### [LOW] Community/PostCard.swift:473 — `DispatchQueue.main.asyncAfter` for heart animation cleanup is not cancellable
```swift
// PostCard.swift:473–475
DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
    showHeartBurst = false
}
```
If the PostCard view is removed from hierarchy before 0.8 s elapses, the dispatch fires and tries to set `showHeartBurst` on a view no longer in the tree. SwiftUI handles this gracefully by discarding the update, but it is an unnecessary allocation.

---

## Summary

| Severity | Count |
|----------|-------|
| HIGH     | 5     |
| MED      | 8     |
| LOW      | 7     |

**Top 3 findings:**

1. **HIGH — SnapshotRenderer.swift:33** `UIImageWriteToSavedPhotosAlbum` with nil completion means "Save to Photos" always reports success even when the write fails. Data loss to the user.

2. **HIGH — SnapshotRenderer.swift:13** `renderer.scale = 1` with `proposedSize = 1080×1920 points` causes SwiftUI ImageRenderer to lay out a 1080pt-wide composition on a device where the screen is ~390pt. While the output image size is technically correct in pixels, the source `tryOnImage` (a screen-captured image at 3x) will not fill the composition frame correctly via the SwiftUI `.scaledToFill` layout pass inside ImageRenderer — the rendered export image will likely have incorrect scaling relative to screen preview.

3. **HIGH — GoldParticles.swift:31** A 60 Hz `Timer` on the main thread fires allocation-heavy `compactMap` particle updates every 16ms for the entire lifetime of the view. This degrades main-thread responsiveness and directly competes with SwiftUI's own render loop.

Report: `/tmp/m2-audit-social.md`
