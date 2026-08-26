# M0 — Fondations (Harnais de test + Vérité IaC) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a deterministic XCUITest + unit-test harness for L'Écrin Virtuel and reconcile the repo's infrastructure-as-code with the real production schema, so later milestones can "test every action" and audit the DB against truth.

**Architecture:** A single production seam (`AppLaunchEnvironment`) reads UI-test launch arguments; in `-uitest` mode the app starts signed-in with a deterministic mock user and skips all live-backend boot calls. `project.yml` (XcodeGen) becomes the authoritative source for the app + unit-test + UI-test targets. The prod schema is dumped via Supabase MCP into a reference baseline migration.

**Tech Stack:** Swift 6 / SwiftUI, XcodeGen, XCTest + XCUITest, `xcodebuild`, Supabase MCP.

## Global Constraints

- **Build/test ONLY via `xcodebuild`** — never `swift build`. (CLAUDE.md)
- Check build result with `grep -E "BUILD SUCCEEDED|BUILD FAILED|TEST SUCCEEDED|TEST FAILED|error:"` — `| tail` masks the real exit code.
- Project: `EcrinVirtuel.xcodeproj` · App target & scheme: `EcrinVirtuel` · Bundle id prefix: `com.ecrin`.
- Swift version `6.0`, iOS deployment target `18.0`, `DEVELOPMENT_TEAM: GG9U76Z4X7`.
- Logging via `os.Logger` (no `print()` in production code).
- French UI copy; English code/comments.
- **Work on branch `security-audit-e2e-program`, NOT `main`.** Commit per task.
- Production code must behave identically when `-uitest` is absent (the seam is inert in normal runs).
- Simulator destination used throughout: `DEST="platform=iOS Simulator,name=iPhone 16"` — confirm an equivalent exists first (Task 1, Step 2).

---

### Task 0: Create the working branch

**Files:** none (git only)

- [ ] **Step 1: Create and switch to the program branch**

Run:
```bash
cd /Volumes/EVO/EcrinVirtuel-Swift && git checkout -b security-audit-e2e-program
```
Expected: `Switched to a new branch 'security-audit-e2e-program'`

- [ ] **Step 2: Stage the already-written artifacts from prior milestones**

Run:
```bash
git add supabase/migrations/007_harden_consume_credits_and_definer_functions.sql \
        supabase/migrations/008_lock_down_device_tryons_and_tryon_temp_listing.sql \
        docs/superpowers/specs/2026-06-21-security-audit-e2e-program-design.md \
        docs/superpowers/plans/2026-06-21-m0-foundations.md
git commit -m "chore: add security hardening migrations (007/008), program spec and M0 plan"
```
Expected: a commit containing the 4 files.

---

### Task 1: Make `project.yml` authoritative for app + unit + UI-test targets

The `.xcodeproj` already has an `EcrinVirtuelTests` target but `project.yml` does not declare it — regenerating would drop it. This task adds both test targets to `project.yml` and regenerates, then proves the existing 15 tests still pass.

**Files:**
- Modify: `project.yml` (append `EcrinVirtuelTests`, `EcrinVirtuelUITests` targets + `schemes`)
- Create: `Tests/UITests/.gitkeep` (so the UITest sources path exists)

**Interfaces:**
- Produces: scheme `EcrinVirtuel` with test targets `EcrinVirtuelTests` (unit) and `EcrinVirtuelUITests` (UI); unit sources = `Tests/` excluding `Tests/UITests/**`; UI sources = `Tests/UITests/**`.

- [ ] **Step 1: Ensure XcodeGen is installed**

Run:
```bash
which xcodegen || brew install xcodegen
```
Expected: a path like `/opt/homebrew/bin/xcodegen` (or successful install).

- [ ] **Step 2: Confirm a usable simulator exists**

Run:
```bash
xcrun simctl list devices available | grep -E "iPhone 16|iPhone 17"
```
Expected: at least one available iPhone simulator line. If "iPhone 16" is absent, set `DEST` to a name that appears here for all later `xcodebuild` commands.

- [ ] **Step 3: Create the UITests source directory**

Run:
```bash
mkdir -p Tests/UITests && touch Tests/UITests/.gitkeep
```

- [ ] **Step 4: Append test targets + schemes to `project.yml`**

Append to the end of `project.yml`:
```yaml
  EcrinVirtuelTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: Tests
        excludes:
          - "UITests/**"
    dependencies:
      - target: EcrinVirtuel
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.ecrin.jewelry.tests
        GENERATE_INFOPLIST_FILE: YES

  EcrinVirtuelUITests:
    type: bundle.ui-testing
    platform: iOS
    sources:
      - path: Tests/UITests
    dependencies:
      - target: EcrinVirtuel
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.ecrin.jewelry.uitests
        GENERATE_INFOPLIST_FILE: YES

schemes:
  EcrinVirtuel:
    build:
      targets:
        EcrinVirtuel: all
        EcrinVirtuelTests: [test]
        EcrinVirtuelUITests: [test]
    test:
      targets:
        - EcrinVirtuelTests
        - EcrinVirtuelUITests
      gatherCoverageData: true
```

- [ ] **Step 5: Regenerate the Xcode project**

Run:
```bash
xcodegen generate
```
Expected: `Created project at .../EcrinVirtuel.xcodeproj`

- [ ] **Step 6: Verify the existing unit tests still pass (regression gate)**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelTests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST SUCCEEDED|TEST FAILED|error:|Executed"
```
Expected: `** TEST SUCCEEDED **` and the existing ~15 Weather tests executed.

- [ ] **Step 7: Commit**

```bash
git add project.yml Tests/UITests/.gitkeep EcrinVirtuel.xcodeproj/project.pbxproj
git commit -m "build: declare unit + UI test targets in project.yml (XcodeGen authoritative)"
```

---

### Task 2: `AppLaunchEnvironment` seam (pure, testable)

**Files:**
- Create: `Sources/Core/Testing/AppLaunchEnvironment.swift`
- Test: `Tests/AppLaunchEnvironmentTests.swift`

**Interfaces:**
- Produces:
  - `AppLaunchEnvironment.isUITesting(_ args: [String]) -> Bool`
  - `AppLaunchEnvironment.mockAuthenticated(_ args: [String]) -> Bool`
  - `AppLaunchEnvironment.mockCredits(_ args: [String]) -> Int`
  - Live convenience accessors: `AppLaunchEnvironment.isUITesting: Bool`, `.mockAuthenticated: Bool`, `.mockCredits: Int`, `.mockUser: User`
  - Launch-arg vocabulary: `-uitest` (enable test mode), `-uitest-auth` (start signed-in), `-uitest-credits <Int>` (seed balance).

- [ ] **Step 1: Write the failing test**

Create `Tests/AppLaunchEnvironmentTests.swift`:
```swift
import XCTest
@testable import EcrinVirtuel

final class AppLaunchEnvironmentTests: XCTestCase {

    func testIsUITestingTrueWhenFlagPresent() {
        XCTAssertTrue(AppLaunchEnvironment.isUITesting(["app", "-uitest"]))
    }

    func testIsUITestingFalseWhenAbsent() {
        XCTAssertFalse(AppLaunchEnvironment.isUITesting(["app"]))
    }

    func testMockAuthenticatedRequiresFlag() {
        XCTAssertTrue(AppLaunchEnvironment.mockAuthenticated(["-uitest", "-uitest-auth"]))
        XCTAssertFalse(AppLaunchEnvironment.mockAuthenticated(["-uitest"]))
    }

    func testMockCreditsParsesValue() {
        XCTAssertEqual(AppLaunchEnvironment.mockCredits(["-uitest-credits", "7"]), 7)
    }

    func testMockCreditsDefaultsToThree() {
        XCTAssertEqual(AppLaunchEnvironment.mockCredits([]), 3)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelTests/AppLaunchEnvironmentTests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST FAILED|error:|cannot find 'AppLaunchEnvironment'"
```
Expected: FAIL — `cannot find 'AppLaunchEnvironment' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/Core/Testing/AppLaunchEnvironment.swift`:
```swift
import Foundation

/// The single seam between production code and UI tests. This is the ONLY place
/// that reads UI-test launch arguments. Production behaviour is unchanged unless
/// `-uitest` is passed — which only XCUITest does. Parsing is exposed as pure
/// functions over `[String]` so it is unit-testable without spawning a process.
enum AppLaunchEnvironment {

    // MARK: Pure parsing (testable)

    static func isUITesting(_ args: [String]) -> Bool { args.contains("-uitest") }

    static func mockAuthenticated(_ args: [String]) -> Bool { args.contains("-uitest-auth") }

    static func mockCredits(_ args: [String]) -> Int {
        guard let i = args.firstIndex(of: "-uitest-credits"),
              i + 1 < args.count, let n = Int(args[i + 1]) else { return 3 }
        return n
    }

    // MARK: Live accessors (use the real process arguments)

    private static var live: [String] { ProcessInfo.processInfo.arguments }

    static var isUITesting: Bool { isUITesting(live) }
    static var mockAuthenticated: Bool { mockAuthenticated(live) }
    static var mockCredits: Int { mockCredits(live) }

    /// Deterministic mock user for UI tests (never touches the backend).
    static var mockUser: User {
        User(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA") ?? UUID(),
             email: "uitest@ecrin.local",
             displayName: "UITest")
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelTests/AppLaunchEnvironmentTests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST SUCCEEDED|TEST FAILED|Executed"
```
Expected: `** TEST SUCCEEDED **`, 5 tests executed.

- [ ] **Step 5: Commit**

```bash
git add Sources/Core/Testing/AppLaunchEnvironment.swift Tests/AppLaunchEnvironmentTests.swift
git commit -m "feat: add AppLaunchEnvironment UI-test seam (pure, unit-tested)"
```

---

### Task 3: Wire the seam into `AppState` (deterministic auth)

**Files:**
- Modify: `Sources/Core/Models/AppState.swift:68-74` (the `init()`)
- Test: `Tests/AppStateLaunchModeTests.swift`

**Interfaces:**
- Consumes: `AppLaunchEnvironment.isUITesting`, `.mockAuthenticated`, `.mockUser`
- Produces: when `-uitest -uitest-auth` is set, `AppState().phase == .authenticated` and `currentUser == AppLaunchEnvironment.mockUser`; when `-uitest` alone, `phase == .onboarding`. Normal launches are unchanged.

- [ ] **Step 1: Write the failing test**

Create `Tests/AppStateLaunchModeTests.swift`:
```swift
import XCTest
@testable import EcrinVirtuel

@MainActor
final class AppStateLaunchModeTests: XCTestCase {

    func testAuthenticatedMockStartsAuthenticated() {
        let state = AppState(launchArguments: ["-uitest", "-uitest-auth"])
        XCTAssertEqual(state.phase, .authenticated)
        XCTAssertEqual(state.currentUser?.email, "uitest@ecrin.local")
    }

    func testUITestWithoutAuthStartsOnboarding() {
        let state = AppState(launchArguments: ["-uitest"])
        XCTAssertEqual(state.phase, .onboarding)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelTests/AppStateLaunchModeTests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST FAILED|error:|extra argument 'launchArguments'"
```
Expected: FAIL — `AppState` has no `init(launchArguments:)`.

- [ ] **Step 3: Make `AppPhase` equatable and add the testable init**

In `Sources/Core/Models/AppState.swift`, change the enum declaration:
```swift
enum AppPhase: Equatable {
    case onboarding
    case unauthenticated
    case authenticated
}
```

Replace the existing `init()` (currently at lines 68–74) with:
```swift
    /// Default production initializer.
    convenience init() {
        self.init(launchArguments: ProcessInfo.processInfo.arguments)
    }

    /// Testable initializer. `launchArguments` is injected so UI-test mode is
    /// deterministic and unit-testable without spawning a process.
    init(launchArguments: [String]) {
        if AppLaunchEnvironment.isUITesting(launchArguments) {
            if AppLaunchEnvironment.mockAuthenticated(launchArguments) {
                currentUser = AppLaunchEnvironment.mockUser
                phase = .authenticated
            } else {
                phase = .onboarding
            }
            return
        }
        if UserDefaults.standard.bool(forKey: AppStorageKey.hasCompletedOnboarding) {
            phase = .unauthenticated
        } else {
            phase = .onboarding
        }
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelTests/AppStateLaunchModeTests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST SUCCEEDED|TEST FAILED|Executed"
```
Expected: `** TEST SUCCEEDED **`, 2 tests executed.

- [ ] **Step 5: Commit**

```bash
git add Sources/Core/Models/AppState.swift Tests/AppStateLaunchModeTests.swift
git commit -m "feat: AppState starts in deterministic mock-auth state under -uitest"
```

---

### Task 4: Skip live-backend boot under `-uitest`

The app's `.task` boot calls Supabase, RevenueCat, Open-Meteo, etc. UI tests must run with zero live backend.

**Files:**
- Modify: `Sources/App/EcrinVirtuelApp.swift:23-63` (the `.task { ... }` block) and `:10-13` (the `init()`)

**Interfaces:**
- Consumes: `AppLaunchEnvironment.isUITesting`, `.mockCredits`
- Produces: under `-uitest`, the boot task seeds `CreditsManager.shared.remaining` and returns before any network call; `Purchases.configure` is skipped.

- [ ] **Step 1: Guard RevenueCat configuration in `init()`**

In `Sources/App/EcrinVirtuelApp.swift`, replace the `init()` body:
```swift
    init() {
        if AppLaunchEnvironment.isUITesting { return }
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
        Purchases.logLevel = .warn
    }
```

- [ ] **Step 2: Short-circuit the boot task**

In the same file, insert at the very top of the `.task { ... }` closure (before "// 1. Restaurer une session..."):
```swift
                    // UI-test mode: no live backend. Seed deterministic state and stop.
                    if AppLaunchEnvironment.isUITesting {
                        CreditsManager.shared.remaining = AppLaunchEnvironment.mockCredits
                        return
                    }
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild build -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/EcrinVirtuelApp.swift
git commit -m "feat: skip live-backend boot and seed credits under -uitest"
```

---

### Task 5: Accessibility identifiers on the 5 tab roots + FAB

**Files:**
- Modify: `Sources/App/MainTabView.swift`

**Interfaces:**
- Produces: tab roots carry `.accessibilityIdentifier("screen.essayage" | "screen.garderobe" | "screen.boutique" | "screen.communaute" | "screen.profil")`; the FAB carries `.accessibilityIdentifier("fab.quicktryon")`. Tab-bar buttons remain reachable by their visible labels.

- [ ] **Step 1: Add identifiers to each tab's root content**

In `Sources/App/MainTabView.swift`, add an `.accessibilityIdentifier(...)` to each tab's root view. Concretely:

- On `TryOnView()` (tab 0): add `.accessibilityIdentifier("screen.essayage")` immediately after `TryOnView()`.
- On the `NavigationStack { WardrobeView()... }` (tab 1): add `.accessibilityIdentifier("screen.garderobe")` to the `NavigationStack`.
- On `PartnerStoreView()` (tab 2): add `.accessibilityIdentifier("screen.boutique")`.
- On the `NavigationStack { CommunityView()... }` (tab 3): add `.accessibilityIdentifier("screen.communaute")` to the `NavigationStack`.
- On `ProfileView()` (tab 4): add `.accessibilityIdentifier("screen.profil")`.

Example for tab 0:
```swift
                TryOnView()
                    .accessibilityIdentifier("screen.essayage")
                    .tabItem { Label("Essayage", systemImage: "sparkles") }
                    .tag(0)
```

- [ ] **Step 2: Add an identifier to the FAB**

On the floating "Essayage rapide" `Button`, add after its existing `.accessibilityHint(...)`:
```swift
            .accessibilityIdentifier("fab.quicktryon")
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild build -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Sources/App/MainTabView.swift
git commit -m "feat: add accessibility identifiers to tab roots and quick-try-on FAB"
```

---

### Task 6: Smoke navigation UI test (the M0 acceptance gate)

**Files:**
- Create: `Tests/UITests/SmokeNavigationUITests.swift`

**Interfaces:**
- Consumes: launch args `-uitest -uitest-auth`; tab-bar buttons labelled `Essayage`, `Garde-robe`, `Boutique`, `Communauté`, `Profil`; identifier `fab.quicktryon`.

- [ ] **Step 1: Write the UI test**

Create `Tests/UITests/SmokeNavigationUITests.swift`:
```swift
import XCTest

final class SmokeNavigationUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testNavigatesAllFiveTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-auth"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar never appeared")

        for label in ["Essayage", "Garde-robe", "Boutique", "Communauté", "Profil"] {
            let button = tabBar.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Tab '\(label)' missing")
            button.tap()
        }

        // The quick-try-on FAB is present on the main tab surface.
        XCTAssertTrue(app.buttons["fab.quicktryon"].waitForExistence(timeout: 5),
                      "Quick-try-on FAB missing")
    }
}
```

- [ ] **Step 2: Run it — verify it passes (this is the M0 acceptance gate)**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -only-testing:EcrinVirtuelUITests/SmokeNavigationUITests \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST SUCCEEDED|TEST FAILED|error:|Executed"
```
Expected: `** TEST SUCCEEDED **`, 1 test executed. If the tab-bar query fails, confirm the tab labels in `MainTabView.swift` match exactly (accents included).

- [ ] **Step 3: Commit**

```bash
git add Tests/UITests/SmokeNavigationUITests.swift
git commit -m "test: add E2E smoke test navigating all five tabs in mock mode"
```

---

### Task 7: IaC reconciliation — prod schema baseline + drift doc

Capture the real production schema (security-relevant surface) so future DB work audits against truth, and document the repo↔prod drift.

**Files:**
- Create: `supabase/migrations/009_prod_baseline.sql` (reference snapshot — header marks it NOT for re-apply)
- Create: `docs/IAC-DRIFT.md`

**Interfaces:**
- Produces: a committed baseline of prod tables/columns, RLS policies, and functions for project `itjtshfzpknlzownpwte`; a drift register.

- [ ] **Step 1: Dump the table+column inventory via MCP**

Using the Supabase MCP tool `execute_sql` on project `itjtshfzpknlzownpwte`, run and capture each result:
```sql
-- tables + columns
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public'
order by table_name, ordinal_position;
```
```sql
-- RLS policies
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname='public' order by tablename, policyname;
```
```sql
-- functions (security-relevant)
select proname, prosecdef as security_definer, pg_get_function_identity_arguments(oid) as args
from pg_proc where pronamespace='public'::regnamespace order by proname;
```

- [ ] **Step 2: Write the baseline file**

Create `supabase/migrations/009_prod_baseline.sql` with this header, followed by the captured DDL/inventory rendered as SQL comments + `CREATE`-style statements where practical:
```sql
-- Migration 009 — PROD BASELINE (reference snapshot, 2026-06-21)
-- ============================================================================
-- DO NOT RE-APPLY. This file documents the REAL production schema of
-- itjtshfzpknlzownpwte as captured via Supabase MCP, to reconcile the heavy
-- drift between repo migrations 001–006 and production.
--
-- Migrations 007 and 008 (security hardening) ARE real, applied changes.
-- Everything below is an inventory snapshot for audit reference only.
-- ============================================================================

-- <paste the table+column inventory here, grouped by table>
-- <paste the RLS policy inventory here>
-- <paste the function inventory here>
```

- [ ] **Step 3: Write the drift register**

Create `docs/IAC-DRIFT.md`:
```markdown
# IaC Drift Register — repo migrations vs production (itjtshfzpknlzownpwte)

Captured 2026-06-21 via Supabase MCP during M0.

## Summary
Repo migrations `001`–`006` do NOT reflect production. Treat
`supabase/migrations/009_prod_baseline.sql` as the source of truth for the
current schema. `007`/`008` are real applied hardening changes.

## Confirmed discrepancies
- `gift_cards` — defined in `001` but **absent in prod** → the Gift feature
  degrades to local-only.
- `gaming_profiles` — written by the app but **absent in prod** → gaming
  cloud-sync silently fails.
- Prod tables NOT in any repo migration: `conversations`, `credit_transactions`,
  `device_tryons`, `jewelry_items`, `messages`, `outfit_presets`,
  `post_comments`, `post_reports`, `try_on_results`, `partnership_requests`.
- `users` prod columns differ from `001` (e.g. `try_on_credits_jewelry`,
  `try_on_credits_clothing`, `subscription_tier`, `username`).

## Consequence for later milestones
- M2 (audit) must verify the app's id model (`auth_id` vs `users.id`) against
  the prod baseline, not the repo migrations.
- Any new migration must be diffed against `009_prod_baseline.sql`.
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/009_prod_baseline.sql docs/IAC-DRIFT.md
git commit -m "docs: capture prod schema baseline (009) and IaC drift register"
```

---

### Task 8: M0 acceptance — full test target green

**Files:** none (verification only)

- [ ] **Step 1: Run the complete test target (unit + UI)**

Run:
```bash
DEST="platform=iOS Simulator,name=iPhone 16"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel \
  -destination "$DEST" -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "TEST SUCCEEDED|TEST FAILED|error:|Executed"
```
Expected: `** TEST SUCCEEDED **`. The existing Weather tests, the new `AppLaunchEnvironmentTests`, `AppStateLaunchModeTests`, and `SmokeNavigationUITests` all execute and pass.

- [ ] **Step 2: Tag the milestone**

```bash
git tag m0-foundations
```

---

## Self-Review

**1. Spec coverage (M0 items):**
- (1) XCUITest + Swift Testing targets via project.yml → Task 1. *Note: existing tests are XCTest; M0 uses XCTest/XCUITest. Swift Testing migration is deferred to M3 per spec §4.*
- (2) Deterministic `-uitest` seams (mock auth/session, in-memory seed, zero live backend) → Tasks 2, 3, 4.
- (3) `accessibilityIdentifier` pass on the 5 tabs' interactive elements → Task 5.
- (4) IaC reconciliation → baseline `009_prod_baseline.sql` + drift doc → Task 7.
- Acceptance (smoke E2E navigates 5 tabs, green on simulator) → Task 6 + Task 8.

**2. Placeholder scan:** Task 7 Step 2 intentionally pastes MCP-captured inventory into the baseline (data is environment-derived, captured at execution time) — this is a data-capture step, not a code placeholder. All code steps contain full code.

**3. Type consistency:** `AppLaunchEnvironment` parsing signatures `(_ args: [String])` are used identically in Tasks 2/3. `AppState.init(launchArguments:)` defined in Task 3 and consumed by its own tests. `AppPhase` made `Equatable` in Task 3 (required by `XCTAssertEqual`). Identifiers `screen.*` / `fab.quicktryon` defined in Task 5 and consumed in Task 6.
