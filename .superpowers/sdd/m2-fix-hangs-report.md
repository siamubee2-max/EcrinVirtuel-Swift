# m2 Fix-Hangs Report — C5 & C6

## Bug C5 — BodyContextAnalyzer continuation leak

### Root cause
Three sites used `try? handler.perform([request])`. When `perform` throws (e.g. unsupported config, nil CGImage source, Vision internal error), the VNRequest completion closure is **never invoked** — but the `withCheckedContinuation` awaiter waits indefinitely for `continuation.resume(...)`. This permanently hangs the entire `analyze(image:)` pipeline, which all callers `await`.

### Site 1 — `detectFaceRect` (original ~line 196)

**Before:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try? handler.perform([request])
```

**After:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
} catch {
    // perform threw — the request completion will NOT fire; resume with fallback (nil faceRect)
    continuation.resume(returning: nil)
}
```

**Single-resume argument:**
- If `perform` succeeds → completion closure fires → resumes with `converted` CGRect or `nil` (guard path). The `catch` block does NOT run. ✓ exactly one resume.
- If `perform` throws → completion closure does NOT fire → `catch` resumes with `nil`. ✓ exactly one resume.

### Site 2 — `analyzePose` (original ~line 317)

**Before:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try? handler.perform([request])
```

**After:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
} catch {
    // perform threw — the request completion will NOT fire; resume with default pose values
    continuation.resume(returning: PoseAnalysisResult(
        shape: .hourglass,
        height: .medium,
        shoulders: .medium
    ))
}
```

**Single-resume argument:**
- `perform` succeeds → completion fires → resumes with either default `PoseAnalysisResult` (guard path) or `classifyPose(from:)` result. `catch` skipped. ✓ one resume.
- `perform` throws → completion skipped → `catch` resumes with same default value the completion guard would return. ✓ one resume.

### Site 3 — `detectClothing` (original ~line 543)

**Before:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try? handler.perform([request])
```

**After:**
```swift
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
} catch {
    // perform threw — the request completion will NOT fire; resume with empty garment list
    continuation.resume(returning: [])
}
```

**Single-resume argument:**
- `perform` succeeds → completion fires → resumes with `[]` (guard path) or mapped garments. `catch` skipped. ✓ one resume.
- `perform` throws → completion skipped → `catch` resumes with `[]` (same fallback as guard path). ✓ one resume.

---

## Bug C6 — ARTryOnView infinite snapshot loop

### Root cause
`captureSnapshot` called `arView.snapshot(saveToHDR:completion:)`. When `snapshot` returns a `nil` image (e.g. renderer not ready, session not running), the completion closure silently returned without calling `completion(image)`. Because `updateUIView` only resets `isCapturing = false` inside the `completion` callback, a nil snapshot left `isCapturing = true`. SwiftUI re-renders the view → `updateUIView` triggers again → another `captureSnapshot` → nil again → infinite loop / freeze.

### Before
```swift
func captureSnapshot(completion: @escaping @Sendable (UIImage) -> Void) {
    guard let arView else { return }
    arView.snapshot(saveToHDR: false) { image in
        if let image {
            completion(image)
        }
        // nil case: no call → isCapturing stays true → infinite loop
    }
}
```

Call site in `updateUIView`:
```swift
if isCapturing {
    context.coordinator.captureSnapshot { image in
        onCapture(image)
        DispatchQueue.main.async { isCapturing = false }
    }
}
```

### After
```swift
func captureSnapshot(
    completion: @escaping @Sendable (UIImage) -> Void,
    onCaptureFailure: @escaping @Sendable () -> Void = {}
) {
    guard let arView else {
        DispatchQueue.main.async { onCaptureFailure() }
        return
    }
    arView.snapshot(saveToHDR: false) { image in
        if let image {
            completion(image)
        } else {
            // snapshot returned nil — completion must NOT be called (no valid image),
            // but we MUST notify the caller so it can reset isCapturing and stop the loop.
            DispatchQueue.main.async { onCaptureFailure() }
        }
    }
}
```

Call site:
```swift
if isCapturing {
    context.coordinator.captureSnapshot(
        completion: { image in
            onCapture(image)
            DispatchQueue.main.async { isCapturing = false }
        },
        onCaptureFailure: {
            // snapshot returned nil — reset flag to break the infinite re-render loop
            isCapturing = false
        }
    )
}
```

**Loop-break argument:** On every exit path — success (`completion`) or failure (`onCaptureFailure`) or missing arView (`onCaptureFailure`) — `isCapturing` is reset to `false` on the main thread, so SwiftUI stops re-triggering the capture.

---

## Build & Test Results

- **Build:** `BUILD SUCCEEDED` (xcodebuild, iPhone 17 simulator, `CODE_SIGNING_ALLOWED=NO`)
- **Suite:** `TEST SUCCEEDED` — 25 tests executed, 0 failures
