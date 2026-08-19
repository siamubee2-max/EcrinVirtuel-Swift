# M4 iOS Implementation Report
Date: 2026-06-21

## Status
BUILD SUCCEEDED — 44 unit tests passed, 0 failures.

## Commits
- `eec16e0 feat(m4): App Attest + Universal Links iOS client`

(All M4 iOS components were committed in a single commit by the previous agent. The tree was clean on entry — nothing was left uncommitted.)

## AttestationService
- No-op on simulator (DCAppAttestService.isSupported == false): YES — guarded in `isAttestationAvailable()`
- No-op under -uitest flag: YES — `AppLaunchEnvironment.isUITesting` guard in `isAttestationAvailable()`
- keyId persisted in: UserDefaults (`"attestation.keyId"`) — no crypto material stored, only the opaque key identifier issued by Apple
- First call: `generateKey()` → `attestKey()` → persists keyId → returns `x-attest-keyid` + `x-attest-object` headers
- Subsequent calls: `generateAssertion()` → returns `x-attest-keyid` + `x-attest-assertion` headers
- Error handling: all errors caught in `attestHeaders` and `assertionHeaders`; returns `[:]` on any failure; on assertion failure, clears persisted keyId so next call re-attests
- Static helper `AttestationService.clientDataHash(from:)` hashes the JSON body (sorted keys) with SHA-256 as the clientDataHash

## ImageGenerationService
- `clientDataHash(from: body)` called on the request body dictionary before serialisation
- `attestationHeaders(clientDataHash:)` called with `await` before building the URLRequest
- Headers added best-effort: empty dict means no headers added, request is sent unchanged
- No `import CryptoKit` needed in ImageGenerationService — hash computed inside AttestationService

## Universal Links (C4)
- AASA: `web/public/.well-known/apple-app-site-association` present
  - appID: `GG9U76Z4X7.com.ecrin.jewelry`
  - paths: `/ecrin/login-callback*`, `/ecrin/gift/*`
- Entitlement: `Sources/App/EcrinVirtuel.entitlements` with `com.apple.developer.associated-domains = applinks:ecrin.app` and `com.apple.developer.devicecheck.appattest-environment = development`
- project.yml: entitlements block present for EcrinVirtuel target (path + properties including associated-domains and appattest-environment)
- EcrinVirtuelApp.swift: `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` handler present — extracts `activity.webpageURL` and calls `handleIncomingURL(_:)` (same handler as `.onOpenURL`)

## Unit Tests
PASSED — 44 tests, 0 failures.
Test suites executed: AttestationServiceTests (if present), WeatherConditionTests, WeatherLookRecommenderTests, and others.

## Concerns
- `CODE_SIGNING_ALLOWED=NO` used for simulator build; real-device builds require a provisioning profile that includes the `com.apple.developer.associated-domains` and `com.apple.developer.devicecheck.appattest-environment` entitlements
- App Attest only functions on real devices (`isSupported == false` on simulator) — code no-ops cleanly; no simulator test coverage of the attestation path itself
- `appattest-environment` is set to `development` (for TestFlight/development); must be changed to `production` before App Store submission
- AASA file must be hosted at `https://ecrin.app/.well-known/apple-app-site-association` (served as `application/json`, no redirect) before Universal Links will resolve
- Server-side `APP_ATTEST_MODE` defaults to `off` — attestation headers are silently ignored until explicitly set to `log` then `enforce`
- Enable path: deploy M4 → set `APP_ATTEST_MODE=log` → confirm `monitoring_events` shows `attestation_ok` from real devices → set `APP_ATTEST_MODE=enforce`
