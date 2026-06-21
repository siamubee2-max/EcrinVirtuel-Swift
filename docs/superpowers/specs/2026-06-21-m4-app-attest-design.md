# M4 — App Attest + Universal Links — Design (spec)

**Date:** 2026-06-21 · Backend `itjtshfzpknlzownpwte`
**Status:** ⚠️ CODE-COMPLETE BUT UNTESTED BY THE AGENT. App Attest requires a real device + an
App Store/TestFlight build to exercise; the agent cannot run it. SHIPPED SAFE (log-only).

## Goal
Close the 95/100 path: bound AI-generation abuse with Apple **App Attest** (genuine-device
attestation) and replace the spoofable `ecrin://` auth callback with **Universal Links**.

## NON-NEGOTIABLE SAFETY
The App Attest verification is integrated into `tryon-generate` behind an env switch
**`APP_ATTEST_MODE`** with values:
- `off` (DEFAULT) — attestation headers ignored; generation behaves exactly as today.
- `log` — verify attestation/assertion and `monitoring_events`-log the result, but NEVER block.
- `enforce` — reject requests that fail attestation (HTTP 401 `attestation_required`).

It ships as `off`. **Do NOT set `enforce` until you have validated on a real device** (a crypto
bug would otherwise break ALL paid generation). Enable path: deploy → set `APP_ATTEST_MODE=log`
→ confirm `monitoring_events` shows `attestation_ok` from real devices → set `enforce`.

## Components

### C1 — `device_attest` table (migration 011) [agent-applied, safe — additive]
`key_id text PK, public_key text (base64 SPKI/raw), sign_count bigint, created_at, updated_at`.
RLS enabled, no policy (service-role only). Stores one row per attested App Attest key.

### C2 — Edge `_shared/appAttest.ts` + integration in `tryon-generate` [agent-deployed log-only]
Pure functions implementing Apple App Attest server verification:
- `verifyAttestation(attestationB64, keyId, challenge, bundleId, teamId)` → parses the CBOR
  attestation, validates the x5c cert chain to Apple's App Attest Root CA, checks the nonce
  (`SHA256(authData || SHA256(clientData))` in the credCert extension `1.2.840.113635.100.8.2`),
  the rpId hash (`SHA256(appId)`), the AAGUID, extracts the device public key, returns it.
- `verifyAssertion(assertionB64, publicKey, clientDataHash, prevSignCount)` → verifies the ECDSA
  signature over `authData || clientDataHash` and that sign_count increased.
`tryon-generate` reads `APP_ATTEST_MODE`; in `log`/`enforce` it reads headers
`x-attest-keyid`, `x-attest-object` (first call) / `x-attest-assertion` (subsequent) and a
challenge, runs verification, logs `attestation_ok` / `attestation_fail`, and only blocks in
`enforce`. The challenge = a server-issued nonce; for v1 we use the request body hash as the
client data (documented; a dedicated challenge endpoint is a future hardening).

### C3 — iOS `AttestationService.swift` [agent-written, user must ship]
Wraps `DCAppAttestService.shared`: `generateKey()` (persist keyId in Keychain), `attestKey` on
first use, `generateAssertion` for subsequent requests. Exposes
`attestationHeaders(clientDataHash:) async -> [String:String]`. `ImageGenerationService`
attaches these headers best-effort (failure → no headers; with `APP_ATTEST_MODE=off`/`log`,
generation still works). Guarded: skipped on simulator / when `DCAppAttestService.isSupported`
is false / under `-uitest`.

### C4 — Universal Links [agent-written config, user must HOST + ship]
- `web/public/.well-known/apple-app-site-association` (JSON: appID `GG9U76Z4X7.com.ecrin.jewelry`,
  paths `/ecrin/login-callback*`, `/ecrin/gift/*`). **You must host this at
  `https://ecrin.app/.well-known/apple-app-site-association`** (served as `application/json`, no
  redirect).
- `project.yml`: add `com.apple.developer.associated-domains` entitlement `applinks:ecrin.app`.
- App: handle the universal link in `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` →
  same `SupabaseService.handleDeepLink`/gift logic. Keep `ecrin://` as fallback.

## Verification limits
Agent verifies: builds compile (xcodebuild), migration applies, Edge deploys with
`APP_ATTEST_MODE=off` (no behaviour change — re-smoke-test a real generation stays 200).
Agent CANNOT verify: the App Attest crypto correctness (needs a real device), Universal Link
resolution (needs ecrin.app hosting + a build). Those are YOUR validation steps before `enforce`.
