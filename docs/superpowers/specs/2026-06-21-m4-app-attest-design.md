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

## Deployment status (2026-06-21) — IMPORTANT
- ✅ Migration `011_device_attest` APPLIED to prod (additive, safe).
- ✅ All code COMMITTED in the repo: iOS (`AttestationService`, header wiring, AASA, entitlement,
  `onContinueUserActivity`); Edge `verify-attestation/index.ts` (665 lines, UNTESTED crypto);
  `tryon-generate` v23 hook (`APP_ATTEST_MODE`, default off, no new top-level imports, body read once).
- ⛔ **NOT deployed to the live Edge by the agent — on purpose.** The live `tryon-generate` stays at
  the verified-working **v22**. Deploying 600+ line functions via lossy inline reproduction (the only
  channel the agent has) risks a transcription error on the paid revenue path; and the App Attest
  crypto is untested. Deploy from the repo files instead (exact):
  ```bash
  supabase functions deploy verify-attestation --project-ref itjtshfzpknlzownpwte
  supabase functions deploy tryon-generate    --project-ref itjtshfzpknlzownpwte   # v23 (hook OFF by default)
  ```
  Then validate on a real device and flip the mode (see Activation runbook).

### Activation runbook (your steps — agent cannot do these)
1. Host `web/public/.well-known/apple-app-site-association` at `https://ecrin.app/.well-known/apple-app-site-association` (content-type `application/json`, no redirect).
2. Confirm the embedded Apple App Attest Root CA PEM in `verify-attestation/index.ts` against https://www.apple.com/certificateauthority/.
3. `supabase functions deploy verify-attestation` and `tryon-generate` (v23, hook stays OFF).
4. Build a TestFlight/device build (App Attest is simulator-unsupported; `appattest-environment=development` for TestFlight, `production` for App Store).
5. Set `APP_ATTEST_MODE=log` (Edge secret). Generate from a real device → confirm `monitoring_events` shows `attestation_ok`. Tune the DER-nesting caveat if `attestation_fail` shows parser issues.
6. Only once green from real devices: set `APP_ATTEST_MODE=enforce`.

## Verification limits
Agent verifies: builds compile (xcodebuild), migration applies, Edge deploys with
`APP_ATTEST_MODE=off` (no behaviour change — re-smoke-test a real generation stays 200).
Agent CANNOT verify: the App Attest crypto correctness (needs a real device), Universal Link
resolution (needs ecrin.app hosting + a build). Those are YOUR validation steps before `enforce`.
