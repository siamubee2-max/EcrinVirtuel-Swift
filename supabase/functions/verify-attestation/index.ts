// ============================================================
// ⚠️  UNTESTED — Apple App Attest server-side verification
// ============================================================
// This Edge Function implements Apple's App Attest server protocol per:
//   https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server
//
// It CANNOT be validated without:
//   • A real iOS device (App Attest requires hardware Secure Enclave)
//   • An App Store or TestFlight build signed with the correct App ID
//   • An actual DCAppAttestService.attestKey / generateAssertion call from the device
//
// DO NOT set APP_ATTEST_MODE=enforce until you have confirmed
// "attestation_ok" events from real devices in monitoring_events.
//
// App:   GG9U76Z4X7.com.ecrin.jewelry
// Team:  GG9U76Z4X7
// Bundle: com.ecrin.jewelry
//
// Libs pinned:
//   cbor-x    1.5.9   (CBOR decode)  — https://esm.sh/cbor-x@1.5.9
//   @peculiar/x509 1.9.7 (X.509/cert parse) — https://esm.sh/@peculiar/x509@1.9.7
//   WebCrypto (crypto.subtle) for SHA-256 + ECDSA (built-in Deno)
//
// Auth model:
//   Called server-to-server by tryon-generate (same Supabase project).
//   verify_jwt is false (set in supabase/config.toml or deploy flags).
//   If INTERNAL_FN_KEY env var is set, the caller must send header
//   x-internal-key matching it. If INTERNAL_FN_KEY is not set, the
//   function is accessible to any caller that can reach it (acceptable
//   for an internal-only function with no PII in the response).
//
// See M4 spec: docs/superpowers/specs/2026-06-21-m4-app-attest-design.md
// ============================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
import { decode as cborDecode } from "https://esm.sh/cbor-x@1.5.9"
import { X509Certificate, X509ChainBuilder } from "https://esm.sh/@peculiar/x509@1.9.7"

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const APP_ID     = "GG9U76Z4X7.com.ecrin.jewelry"  // rpId for App Attest = teamId.bundleId
const TEAM_ID    = "GG9U76Z4X7"
const BUNDLE_ID  = "com.ecrin.jewelry"

// Apple App Attest Root CA — embedded as PEM constant.
// Source: https://www.apple.com/certificateauthority/Apple_App_Attest_Root_CA.pem
// This is the only trust anchor for App Attest cert chains.
// SHA-256 fingerprint: d5:f5:d9:39:3a:84:61:e7:71:90:1b:c5:97:b4:d1:9b:58:38:d4:e8:6b:e3:f3:0b:4b:ae:5b:9b:35:66:21:e3
const APPLE_APP_ATTEST_ROOT_CA_PEM = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYLK2pkCRxCMEMaIzggpA8GA1UEChMTQXBwbGUgSW5jLjETMBEGA1UECxMKQXBw
bGUgQ2VydDETMBEGA1UEAxMKQXBwbGUgUm9vdCBDQTAeFw0yMDA0MDgxODM3MTBa
Fw00NTA0MDgxODM3MTBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3QgUm9v
dCBDQSAtIEcxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIxAI1vpp+h4OTsW05zipJ/PXhTmI/02h9YHsN1Sv44
qEwqgxoaqg2mZG3huZPo0VVM7QIwHQLuJpveRex1gy5PF4uenBXap9l2nqxFyrjT
oBAwpLHiDUz30bGQROnqLFqSFp36
-----END CERTIFICATE-----`

// AAGUID bytes for App Attest (authData bytes 37–52, 16 bytes total).
// Production: "appattest" + 7 zero bytes (UTF-8: 61 70 70 61 74 74 65 73 74 00 00 00 00 00 00 00)
// Development: "appattestdevelop"  (UTF-8: 61 70 70 61 74 74 65 73 74 64 65 76 65 6c 6f 70)
const AAGUID_PROD = new Uint8Array([0x61,0x70,0x70,0x61,0x74,0x74,0x65,0x73,0x74,0x00,0x00,0x00,0x00,0x00,0x00,0x00])
const AAGUID_DEV  = new Uint8Array([0x61,0x70,0x70,0x61,0x74,0x74,0x65,0x73,0x74,0x64,0x65,0x76,0x65,0x6c,0x6f,0x70])

// Extension OID that Apple places the credCert nonce in (DER-wrapped SHA-256).
const APPLE_ATTEST_NONCE_OID = "1.2.840.113635.100.8.2"

// ---------------------------------------------------------------------------
// Env
// ---------------------------------------------------------------------------

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
// Optional: if set, callers must send `x-internal-key: <value>` to prevent
// accidental public access.  tryon-generate passes this header.
const INTERNAL_FN_KEY           = Deno.env.get("INTERNAL_FN_KEY")

// ---------------------------------------------------------------------------
// HTTP entry point
// ---------------------------------------------------------------------------

serve(async (req: Request): Promise<Response> => {
  // Only POST.
  if (req.method === "OPTIONS") return new Response(null, { status: 204 })
  if (req.method !== "POST")    return jsonErr("method_not_allowed", 405)

  // Optional shared-secret header guard (server-to-server only).
  if (INTERNAL_FN_KEY) {
    const hdr = req.headers.get("x-internal-key")
    if (hdr !== INTERNAL_FN_KEY) return jsonErr("unauthorized", 401)
  }

  let body: {
    keyId:              string
    attestation?:       string  // base64 CBOR attestation object (first call)
    assertion?:         string  // base64 CBOR assertion object (subsequent calls)
    clientDataHashB64?: string  // base64-encoded SHA-256 of the request body
  }

  try {
    body = await req.json()
  } catch {
    return jsonErr("invalid_json", 400)
  }

  const { keyId, attestation, assertion, clientDataHashB64 } = body

  if (!keyId)               return jsonErr("keyId required", 400)
  if (!clientDataHashB64)   return jsonErr("clientDataHashB64 required", 400)
  if (!attestation && !assertion) return jsonErr("attestation or assertion required", 400)

  const clientDataHash = base64Decode(clientDataHashB64)
  const adminClient    = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    if (attestation) {
      // ── ATTESTATION PATH (first registration of a device key) ────────────
      return await handleAttestation(attestation, keyId, clientDataHash, adminClient)
    } else {
      // ── ASSERTION PATH (subsequent calls, verifying a signature) ─────────
      return await handleAssertion(assertion!, keyId, clientDataHash, adminClient)
    }
  } catch (err) {
    console.error("[verify-attestation] Unhandled error:", err)
    return jsonErr(`internal: ${String(err)}`, 500)
  }
})

// ---------------------------------------------------------------------------
// Attestation (first-time device registration)
// ---------------------------------------------------------------------------
//
// Apple's attestation object is a CBOR map with format:
//   { fmt: "apple-appattest",
//     attStmt: { x5c: [credCert DER bytes, ...], receipt: bytes },
//     authData: bytes }
//
// Verification steps follow:
//   https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server#3576644
//
// ⚠️ UNTESTED — see file header.
// ---------------------------------------------------------------------------

async function handleAttestation(
  attestationB64: string,
  keyId:          string,
  clientDataHash: Uint8Array,
  admin:          ReturnType<typeof createClient>,
): Promise<Response> {

  // Step 0 — decode base64 CBOR.
  const attestBytes  = base64Decode(attestationB64)
  // cbor-x decode returns a plain JS object.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const attestObj    = cborDecode(attestBytes) as any

  if (attestObj?.fmt !== "apple-appattest") {
    return jsonErr("invalid_fmt: expected apple-appattest", 400)
  }

  const attStmt: { x5c: Uint8Array[]; receipt: Uint8Array } = attestObj.attStmt
  const authData: Uint8Array = attestObj.authData

  if (!attStmt?.x5c || attStmt.x5c.length < 2) {
    return jsonErr("x5c chain too short", 400)
  }
  if (!authData || authData.length < 37 + 16 + 2) {
    return jsonErr("authData too short", 400)
  }

  // ── Step 1 — Parse x5c and validate chain to Apple App Attest Root CA ──
  //
  // attStmt.x5c[0] = credCert (leaf, contains device public key)
  // attStmt.x5c[1..] = intermediate(s)
  // Trust anchor = APPLE_APP_ATTEST_ROOT_CA_PEM (embedded above).
  //
  // @peculiar/x509 X509ChainBuilder does path building but its trust-store
  // API differs across versions. We: build the chain manually, verify each
  // issuer matches the next cert, and verify the root matches our embedded PEM.
  //
  // TODO: In production, also verify that attStmt.receipt can be validated
  // against Apple's receipt validation service. For v1 we skip this — receipt
  // validation is an additional defence-in-depth step and requires calling
  // Apple's /attestationData endpoint with your private key.

  const credCertDer   = attStmt.x5c[0]
  const intermCertDer = attStmt.x5c[1]

  let credCert:   X509Certificate
  let intermCert: X509Certificate
  let rootCert:   X509Certificate
  try {
    credCert   = new X509Certificate(credCertDer)
    intermCert = new X509Certificate(intermCertDer)
    rootCert   = new X509Certificate(APPLE_APP_ATTEST_ROOT_CA_PEM)
  } catch (e) {
    return jsonErr(`cert_parse_error: ${String(e)}`, 400)
  }

  // Verify: credCert is issued by intermCert, intermCert is issued by rootCert.
  // @peculiar/x509 X509Certificate.verify(issuer) verifies the signature.
  // This is the cryptographic chain validation.
  try {
    const credOk  = await credCert.verify({ issuerCertificate: intermCert })
    const intermOk = await intermCert.verify({ issuerCertificate: rootCert })
    if (!credOk)   return jsonErr("credCert signature invalid against intermediate", 400)
    if (!intermOk) return jsonErr("intermediate signature invalid against Apple root CA", 400)
  } catch (e) {
    return jsonErr(`chain_verify_error: ${String(e)}`, 400)
  }

  // ── Step 2 — Verify nonce in credCert extension ──────────────────────────
  //
  // Apple embeds SHA256(authData || clientDataHash) inside the credCert
  // extension OID 1.2.840.113635.100.8.2.  The extension value is a DER
  // SEQUENCE containing an OCTET STRING of the 32-byte hash.
  //
  // DER layout: SEQUENCE { SEQUENCE { [1] EXPLICIT OCTET STRING { hash } } }
  // We locate it by looking for the known OID in the cert extensions.

  const expectedNonce = new Uint8Array(
    await crypto.subtle.digest("SHA-256", concat(authData, clientDataHash))
  )

  const nonceExt = credCert.extensions?.find(
    (ext: { oid: string }) => ext.oid === APPLE_ATTEST_NONCE_OID
  )
  if (!nonceExt) {
    return jsonErr("credCert missing nonce extension (1.2.840.113635.100.8.2)", 400)
  }

  // nonceExt.value is the raw DER bytes of the extension value.
  // We parse the ASN.1 manually (minimal DER parser for this known layout).
  const extValueDer: Uint8Array = (nonceExt as { value: Uint8Array }).value
  const extractedNonce = extractOctetStringFromDer(extValueDer)
  if (!extractedNonce) {
    return jsonErr("failed to extract nonce from credCert extension DER", 400)
  }
  if (!bytesEqual(extractedNonce, expectedNonce)) {
    return jsonErr("nonce mismatch: clientDataHash or authData corrupted", 400)
  }

  // ── Step 3 — Verify rpIdHash ─────────────────────────────────────────────
  //
  // authData[0..31] = SHA-256(rpId) where rpId = APP_ID = teamId.bundleId.

  const rpIdHash         = authData.slice(0, 32)
  const expectedRpIdHash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(APP_ID))
  )
  if (!bytesEqual(rpIdHash, expectedRpIdHash)) {
    return jsonErr(`rpIdHash mismatch — wrong APP_ID? expected SHA256("${APP_ID}")`, 400)
  }

  // ── Step 4 — Verify AAGUID ───────────────────────────────────────────────
  //
  // authData layout:
  //   [0..31]   = rpIdHash (32 bytes)
  //   [32]      = flags (1 byte)
  //   [33..36]  = sign count (4 bytes, big-endian)
  //   [37..52]  = aaguid (16 bytes)   ← checked here
  //   [53..54]  = credentialIdLength (2 bytes, big-endian)
  //   [55..]    = credentialId || credentialPublicKey (CBOR)
  //
  // Valid AAGUIDs: "appattest" + 7×0x00 (prod) or "appattestdevelop" (dev).
  // We accept both to avoid breaking developer builds.

  const aaguid = authData.slice(37, 53)
  if (!bytesEqual(aaguid, AAGUID_PROD) && !bytesEqual(aaguid, AAGUID_DEV)) {
    const aaguidHex = Array.from(aaguid).map(b => b.toString(16).padStart(2, "0")).join("")
    return jsonErr(`invalid AAGUID: ${aaguidHex}`, 400)
  }
  const isDevMode = bytesEqual(aaguid, AAGUID_DEV)
  if (isDevMode) {
    console.warn("[verify-attestation] Development AAGUID — accept for now, but deny in enforce+prod")
  }

  // ── Step 5 — Verify credentialId == keyId ────────────────────────────────
  //
  // credentialIdLength is authData[53..54] as big-endian uint16.
  // credentialId follows at authData[55..55+len].
  // The iOS client sends keyId as the base64url of the DCAppAttestService key.
  // Per Apple spec, credentialId == SHA-256 of the public key.
  // We compare by re-encoding credentialId as base64url.

  const credIdLen = (authData[53] << 8) | authData[54]
  const credId    = authData.slice(55, 55 + credIdLen)
  const credIdB64 = bytesToBase64url(credId)

  // Apple returns the keyId as base64 (standard or url-safe). Normalise both.
  const keyIdNorm = normaliseBase64url(keyId)
  if (credIdB64 !== keyIdNorm) {
    return jsonErr(
      `credentialId mismatch: attested=${credIdB64} claimed=${keyIdNorm}`,
      400
    )
  }

  // ── Step 6 — Extract device public key from credCert ─────────────────────
  //
  // The device EC P-256 public key is the Subject Public Key Info of credCert.
  // We export it as base64-encoded SPKI for storage.
  //
  // @peculiar/x509 exposes cert.publicKey.export() which returns a CryptoKey.
  // We import it into WebCrypto to export as SPKI bytes.

  let publicKeyBase64: string
  try {
    const cryptoKey = await credCert.publicKey.export({ algorithm: { name: "ECDSA", namedCurve: "P-256" } })
    const spkiBytes = new Uint8Array(await crypto.subtle.exportKey("spki", cryptoKey))
    publicKeyBase64 = bytesToBase64(spkiBytes)
  } catch (e) {
    return jsonErr(`public_key_export_error: ${String(e)}`, 400)
  }

  // ── Step 7 — Store in device_attest (upsert) ─────────────────────────────

  const { error: dbError } = await admin.from("device_attest").upsert({
    key_id:     keyId,
    public_key: publicKeyBase64,
    sign_count: 0,
    updated_at: new Date().toISOString(),
  }, { onConflict: "key_id" })

  if (dbError) {
    console.error("[verify-attestation] DB upsert error:", dbError)
    return jsonErr(`db_error: ${dbError.message}`, 500)
  }

  console.log(`[verify-attestation] Attestation OK — keyId=${keyId} dev=${isDevMode}`)
  return jsonOk()
}

// ---------------------------------------------------------------------------
// Assertion (subsequent calls — verifies a signed assertion from the device)
// ---------------------------------------------------------------------------
//
// Apple's assertion object is a CBOR map with:
//   { signature: bytes, authenticatorData: bytes }
//
// Verification steps:
//   https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server#3576644
//   (the "Verify the Assertion" section)
//
// ⚠️ UNTESTED — see file header.
// ---------------------------------------------------------------------------

async function handleAssertion(
  assertionB64:   string,
  keyId:          string,
  clientDataHash: Uint8Array,
  admin:          ReturnType<typeof createClient>,
): Promise<Response> {

  // Load stored device record.
  const { data: row, error: fetchErr } = await admin
    .from("device_attest")
    .select("public_key, sign_count")
    .eq("key_id", keyId)
    .maybeSingle()

  if (fetchErr) {
    console.error("[verify-attestation] DB fetch error:", fetchErr)
    return jsonErr(`db_error: ${fetchErr.message}`, 500)
  }
  if (!row) {
    return jsonErr("unknown_key: device not attested yet", 401)
  }

  const storedPublicKeyB64: string = row.public_key
  const storedSignCount:    bigint = BigInt(row.sign_count)

  // Decode assertion.
  const assertionBytes = base64Decode(assertionB64)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const assertionObj   = cborDecode(assertionBytes) as any

  const signature:         Uint8Array = assertionObj?.signature
  const authenticatorData: Uint8Array = assertionObj?.authenticatorData

  if (!signature || !authenticatorData) {
    return jsonErr("assertion missing signature or authenticatorData", 400)
  }

  // ── Assert Step 1 — Verify rpIdHash ──────────────────────────────────────

  const rpIdHash         = authenticatorData.slice(0, 32)
  const expectedRpIdHash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(APP_ID))
  )
  if (!bytesEqual(rpIdHash, expectedRpIdHash)) {
    return jsonErr("assertion rpIdHash mismatch", 400)
  }

  // ── Assert Step 2 — Verify counter > stored ───────────────────────────────
  //
  // authenticatorData[33..36] = sign count (4 bytes, big-endian).
  // The counter MUST be strictly greater than the stored value to prevent replay.

  const newSignCount = BigInt(
    (authenticatorData[33] << 24) |
    (authenticatorData[34] << 16) |
    (authenticatorData[35] << 8)  |
     authenticatorData[36]
  )
  if (newSignCount <= storedSignCount) {
    return jsonErr(
      `replay_detected: counter ${newSignCount} <= stored ${storedSignCount}`,
      401
    )
  }

  // ── Assert Step 3 — Verify ECDSA signature ───────────────────────────────
  //
  // nonce = SHA-256(authenticatorData || clientDataHash)
  // The device signs `nonce` with its EC P-256 private key.
  // We verify with the stored SPKI public key.

  const nonce = new Uint8Array(
    await crypto.subtle.digest("SHA-256", concat(authenticatorData, clientDataHash))
  )

  // Import the SPKI public key from storage.
  const spkiBytes = base64Decode(storedPublicKeyB64)
  let cryptoPubKey: CryptoKey
  try {
    cryptoPubKey = await crypto.subtle.importKey(
      "spki",
      spkiBytes,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"]
    )
  } catch (e) {
    return jsonErr(`public_key_import_error: ${String(e)}`, 500)
  }

  // Apple's ECDSA signature is DER-encoded; WebCrypto ECDSA needs raw (r||s).
  // Convert DER to raw 64-byte signature.
  const rawSig = derToRawEcdsaSig(signature)
  if (!rawSig) {
    return jsonErr("assertion signature DER decode failed", 400)
  }

  let sigValid: boolean
  try {
    sigValid = await crypto.subtle.verify(
      { name: "ECDSA", hash: { name: "SHA-256" } },
      cryptoPubKey,
      rawSig,
      nonce,
    )
  } catch (e) {
    return jsonErr(`ecdsa_verify_error: ${String(e)}`, 500)
  }

  if (!sigValid) {
    return jsonErr("assertion signature invalid", 401)
  }

  // ── Assert Step 4 — Update sign_count in DB ──────────────────────────────

  const { error: updateErr } = await admin
    .from("device_attest")
    .update({ sign_count: Number(newSignCount), updated_at: new Date().toISOString() })
    .eq("key_id", keyId)

  if (updateErr) {
    // Log but don't fail — the signature was valid; the counter update is best-effort.
    console.error("[verify-attestation] sign_count update failed:", updateErr)
  }

  console.log(`[verify-attestation] Assertion OK — keyId=${keyId} counter=${newSignCount}`)
  return jsonOk()
}

// ---------------------------------------------------------------------------
// Utility: ASN.1 / DER parsing
// ---------------------------------------------------------------------------

/**
 * Extracts the 32-byte octet string from the Apple credCert nonce extension.
 *
 * The extension value DER layout is:
 *   SEQUENCE {
 *     SEQUENCE {
 *       [1] EXPLICIT {
 *         OCTET STRING { <32 bytes of SHA-256> }
 *       }
 *     }
 *   }
 *
 * We skip outer tags and lengths to reach the OCTET STRING content.
 * This is a minimal hand-rolled parser — it handles exactly this shape.
 *
 * ⚠️ UNTESTED: The exact nesting depth depends on what @peculiar/x509
 * exposes via nonceExt.value. If the library already strips the outer
 * SEQUENCE wrapper (returning starting from the inner SEQUENCE), adjust
 * the offset here. Add logging in development to inspect raw bytes.
 */
function extractOctetStringFromDer(der: Uint8Array): Uint8Array | null {
  try {
    let pos = 0

    // Helper: read tag+length, return content slice start and advance pos.
    function readTL(): { tag: number; start: number; len: number } | null {
      if (pos >= der.length) return null
      const tag = der[pos++]
      let len = der[pos++]
      if (len & 0x80) {
        const nBytes = len & 0x7f
        len = 0
        for (let i = 0; i < nBytes; i++) len = (len << 8) | der[pos++]
      }
      const start = pos
      return { tag, start, len }
    }

    // Skip outer SEQUENCE (0x30) — the extension value wrapper.
    const outer = readTL()
    if (!outer || outer.tag !== 0x30) return null
    // Skip inner SEQUENCE.
    const inner = readTL()
    if (!inner || inner.tag !== 0x30) return null
    // Skip [1] EXPLICIT context tag (0xa1).
    const ctx = readTL()
    if (!ctx || ctx.tag !== 0xa1) return null
    // OCTET STRING (0x04).
    const oct = readTL()
    if (!oct || oct.tag !== 0x04 || oct.len !== 32) return null

    return der.slice(oct.start, oct.start + oct.len)
  } catch {
    return null
  }
}

/**
 * Converts a DER-encoded ECDSA signature to the raw 64-byte (r||s) format
 * required by WebCrypto.
 *
 * DER layout: SEQUENCE { INTEGER r, INTEGER s }
 * Each integer may have a leading 0x00 padding byte to signal positive sign.
 *
 * ⚠️ UNTESTED.
 */
function derToRawEcdsaSig(der: Uint8Array): Uint8Array | null {
  try {
    let pos = 0
    if (der[pos++] !== 0x30) return null  // SEQUENCE tag
    // Length (skip, may be short or long form).
    let seqLen = der[pos++]
    if (seqLen & 0x80) {
      const nb = seqLen & 0x7f
      seqLen = 0
      for (let i = 0; i < nb; i++) seqLen = (seqLen << 8) | der[pos++]
    }

    function readInt(): Uint8Array | null {
      if (der[pos++] !== 0x02) return null  // INTEGER tag
      let len = der[pos++]
      if (len & 0x80) {
        const nb = len & 0x7f
        len = 0
        for (let i = 0; i < nb; i++) len = (len << 8) | der[pos++]
      }
      const bytes = der.slice(pos, pos + len)
      pos += len
      // Strip leading 0x00 padding byte (positive sign indicator).
      const stripped = bytes[0] === 0x00 ? bytes.slice(1) : bytes
      // Pad or trim to 32 bytes.
      const result = new Uint8Array(32)
      const offset = 32 - stripped.length
      if (offset >= 0) {
        result.set(stripped, offset)
      } else {
        result.set(stripped.slice(-offset))
      }
      return result
    }

    const r = readInt()
    const s = readInt()
    if (!r || !s) return null

    const raw = new Uint8Array(64)
    raw.set(r, 0)
    raw.set(s, 32)
    return raw
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Utility: base64 / bytes
// ---------------------------------------------------------------------------

function base64Decode(b64: string): Uint8Array {
  // Handle both standard base64 and base64url (replace - with + and _ with /).
  const normalised = b64.replace(/-/g, "+").replace(/_/g, "/")
  const padded     = normalised + "=".repeat((4 - (normalised.length % 4)) % 4)
  const binary     = atob(padded)
  const bytes      = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = ""
  const chunk = 8192
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk))
  }
  return btoa(bin)
}

function bytesToBase64url(bytes: Uint8Array): string {
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
}

/** Normalise any base64/base64url string to base64url without padding. */
function normaliseBase64url(b64: string): string {
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}

function concat(...arrays: Uint8Array[]): Uint8Array {
  const total = arrays.reduce((s, a) => s + a.length, 0)
  const out   = new Uint8Array(total)
  let offset  = 0
  for (const a of arrays) { out.set(a, offset); offset += a.length }
  return out
}

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

function jsonOk(): Response {
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
}

function jsonErr(reason: string, status: number): Response {
  return new Response(JSON.stringify({ ok: false, reason }), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
