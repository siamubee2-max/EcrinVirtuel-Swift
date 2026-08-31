// Supabase Edge Function — génération d'image avec cascade 3 niveaux
//
// Fournisseurs dans l'ordre de tentative :
//   1. fal.ai  (Nano Banana 2 / Nano Banana Pro / Flux Kontext) — primaire
//   2. Google Gemini 3.1 Flash Image (Nano Banana 2 direct)     — sauvetage
//   3. OpenAI GPT Image 1                                        — dernier recours
//
// La clé API n'est JAMAIS exposée côté client iOS.
//
// Nommage fal (piégeux, vérifié fal.ai/models) :
//   fal-ai/nano-banana-2/edit             = Nano Banana 2  (identité, 9:16 natif)
//   fal-ai/gemini-3-pro-image-preview/edit = Nano Banana Pro (Gemini 3 Pro Image)
//   fal-ai/flux-pro/kontext               = FLUX Kontext (secours)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const FAL_API_KEY               = Deno.env.get("FAL_API_KEY")!
const FAL_QUEUE_URL             = "https://queue.fal.run"
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!
const GOOGLE_API_KEY            = Deno.env.get("GOOGLE_API_KEY")   // optionnel — sauvetage
const OPENAI_API_KEY            = Deno.env.get("OPENAI_API_KEY")   // optionnel — dernier recours

// ── M4 App Attest (porté depuis la branche audit-007) ────────────────────────
// APP_ATTEST_MODE: "off" | "log" | "enforce"  (default "off" — aucun overhead)
// INTERNAL_FN_KEY: secret partagé transmis à verify-attestation (optionnel)
const APP_ATTEST_MODE  = Deno.env.get("APP_ATTEST_MODE") ?? "off"
const INTERNAL_FN_KEY  = Deno.env.get("INTERNAL_FN_KEY") ?? ""
const VERIFY_ATTEST_URL = Deno.env.get("VERIFY_ATTEST_URL") ??
  `${SUPABASE_URL}/functions/v1/verify-attestation`

// CORS : restreint au domaine de l'app web et au Studio Supabase.
// Les clients iOS natifs n'appliquent pas CORS — ce header protège les appels browser.
const CORS = {
  "Access-Control-Allow-Origin": "https://ecrin.app",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

const STORAGE_BUCKET         = "tryon-temp"
const MAX_PROMPT_CHARS       = 4_000
const MAX_IMAGE_BASE64_CHARS = 6 * 1024 * 1024   // ~4.5 MB binaire
const POLL_INTERVAL_MS       = 3_000
const POLL_MAX_ATTEMPTS      = 30                  // 30 × 3s = 90s max
// Bucket `tryon-temp` privé (migration 010) → URL signée courte pour fal.ai.
// Couvre la file d'attente fal (POLL_MAX_ATTEMPTS × POLL_INTERVAL_MS = 90 s).
const SIGNED_URL_TTL_SECONDS = 300

// ── En-têtes plateforme fal.ai (fal.ai/docs/documentation/model-apis/common-parameters)
//   X-Fal-Store-IO: "0"                    → fal ne stocke pas les payloads JSON
//                                            (défaut : conservation 30 jours).
//   X-Fal-Object-Lifecycle-Preference      → expiration des fichiers CDN produits
//                                            + ACL initiale ("forbid" = 403 pour
//                                            les tiers ; le propriétaire de la clé
//                                            garde l'accès).
const FAL_PRIVACY_HEADERS: Record<string, string> = {
  "X-Fal-Store-IO": "0",
  "X-Fal-Object-Lifecycle-Preference": JSON.stringify({
    expiration_duration_seconds: SIGNED_URL_TTL_SECONDS,
    initial_acl: { default: "forbid" },
  }),
}

// Comptes fondateur — pas de décompte quota (aligné iOS UnlimitedAccess.swift)
const UNLIMITED_EMAILS = new Set([
  "siamubee2@gmail.com",
  "monia.valenza@gmail.com",
  "chrweber@skynet.be",
])

function isUnlimitedEmail(email: string | undefined): boolean {
  return !!email && UNLIMITED_EMAILS.has(email.toLowerCase())
}

// ─── Mapping tiers iOS → modèles fal.ai ──────────────────────────────────────

interface FalModel {
  id:      string    // endpoint fal (ex: fal-ai/nano-banana-2/edit)
  input:   "image_urls" | "image_url"
  costUSD: number
}

const NANO_BANANA_2: FalModel = { id: "fal-ai/nano-banana-2/edit",              input: "image_urls", costUSD: 0.030 }
const NANO_BANANA_PRO: FalModel = { id: "fal-ai/gemini-3-pro-image-preview/edit", input: "image_urls", costUSD: 0.100 }
const FLUX_KONTEXT: FalModel = { id: "fal-ai/flux-pro/kontext",                 input: "image_url",  costUSD: 0.040 }

const FAL_MODELS: Record<string, FalModel> = {
  preview:  NANO_BANANA_2,
  standard: NANO_BANANA_2,
  premium:  NANO_BANANA_PRO,
}

// Cascade de secours (essayée dans l'ordre après le modèle demandé)
const FAL_FALLBACK_MODELS: FalModel[] = [FLUX_KONTEXT]

// Coûts des fournisseurs de secours hors fal.ai, en dollars par image.
// ⚠️ ESTIMATIONS, à confirmer sur les factures Google et OpenAI. La colonne
// `provider` de generation_costs permet de recalculer a posteriori si ces
// valeurs se révèlent fausses — c'est précisément pourquoi on la stocke.
const GEMINI_COST_USD = 0.039
const OPENAI_COST_USD = 0.040

// ─── Main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS })
  }

  // ── JWT Supabase obligatoire ──────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonError("unauthorized", 401)
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return jsonError("unauthorized", 401)

  const userId      = user.id
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  // Signe un objet du bucket privé `tryon-temp` pour que fal.ai puisse le lire.
  // `null` si la signature échoue → la cascade bascule sur les APIs directes.
  const signTempUrl = async (path: string): Promise<string | null> => {
    const { data, error } = await adminClient.storage
      .from(STORAGE_BUCKET)
      .createSignedUrl(path, SIGNED_URL_TTL_SECONDS)
    if (error || !data?.signedUrl) {
      console.warn(`Signed URL failed for ${path}:`, error)
      return null
    }
    return data.signedUrl
  }

  try {
    let rawBodyText: string | undefined
    let parsedBody: Record<string, unknown> | undefined

    if (APP_ATTEST_MODE !== "off") {
      // Read body as text so we can hash it AND parse it.
      rawBodyText = await req.text()
      try { parsedBody = JSON.parse(rawBodyText) } catch { /* invalid JSON caught below */ }

      // Compute clientDataHash = SHA-256(raw request body bytes).
      const bodyBytes       = new TextEncoder().encode(rawBodyText)
      const hashBuffer      = await crypto.subtle.digest("SHA-256", bodyBytes)
      const clientDataHashB64 = btoa(String.fromCharCode(...new Uint8Array(hashBuffer)))

      const keyId      = req.headers.get("x-attest-keyid")
      const attestObj  = req.headers.get("x-attest-object")    // base64 CBOR, first call
      const assertionH = req.headers.get("x-attest-assertion") // base64 CBOR, subsequent

      if (keyId && (attestObj || assertionH)) {
        // Attempt attestation verification — wrapped in total try/catch so
        // any bug here can NEVER crash the main generation flow.
        try {
          const verifyBody = JSON.stringify({
            keyId,
            ...(attestObj  ? { attestation: attestObj   } : {}),
            ...(assertionH ? { assertion:   assertionH  } : {}),
            clientDataHashB64,
          })

          const verifyHeaders: Record<string, string> = {
            "Content-Type":  "application/json",
            // Forward service role key so verify-attestation can write to device_attest.
            "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          }
          if (INTERNAL_FN_KEY) verifyHeaders["x-internal-key"] = INTERNAL_FN_KEY

          const verifyRes = await fetch(VERIFY_ATTEST_URL, {
            method:  "POST",
            headers: verifyHeaders,
            body:    verifyBody,
            // Short timeout — never let attestation stall generation beyond 3 s.
            signal:  AbortSignal.timeout(3_000),
          })

          const verifyJson = await verifyRes.json().catch(() => ({ ok: false, reason: "json_parse" }))
          const attestOk   = verifyJson?.ok === true

          if (attestOk) {
            // Fire-and-forget log (same pattern as moderation logging).
            adminClient.from("monitoring_events").insert({
              event_type:    "attestation_ok",
              user_id:       userId,
              error_domain:  "app_attest",
              error_message: `keyId=${keyId} mode=${APP_ATTEST_MODE}`,
              platform:      "edge",
            }).catch(() => {})
          } else {
            const reason = verifyJson?.reason ?? `http_${verifyRes.status}`
            adminClient.from("monitoring_events").insert({
              event_type:    "attestation_fail",
              user_id:       userId,
              error_domain:  "app_attest",
              error_message: `keyId=${keyId} reason=${reason} mode=${APP_ATTEST_MODE}`.slice(0, 500),
              platform:      "edge",
            }).catch(() => {})

            if (APP_ATTEST_MODE === "enforce") {
              return jsonError("attestation_required", 401)
            }
            // In "log" mode: fall through, allow generation.
          }
        } catch (attestErr) {
          // Network error, timeout, or any other failure — never block generation.
          console.warn("[tryon-generate] App Attest check error (non-blocking):", attestErr)
          if (APP_ATTEST_MODE === "enforce") {
            // In enforce mode even a network error blocks (fail-closed).
            return jsonError("attestation_required", 401)
          }
        }
      } else if (APP_ATTEST_MODE === "enforce") {
        // enforce requires attest headers; missing → reject.
        return jsonError("attestation_required", 401)
      }
    }
    // ── end App Attest hook ─────────────────────────────────────────────────

    // Si le hook App Attest est actif, le corps a déjà été lu et parsé.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const bodyJson: any = parsedBody ?? await req.json()
    const {
      imageBase64,
      prompt,
      model = "standard",
      aspectRatio: aspectRatioRaw,
      referenceImageBase64,
    } = bodyJson

    // Validation AVANT tout traitement
    if (!imageBase64 || !prompt)  return jsonError("imageBase64 and prompt required", 400)
    if (typeof prompt !== "string" || prompt.length > MAX_PROMPT_CHARS)
      return jsonError("prompt too long", 400)
    if (typeof imageBase64 !== "string" || imageBase64.length > MAX_IMAGE_BASE64_CHARS)
      return jsonError("image too large", 400)

    const aspectRatio = normalizeAspectRatio(aspectRatioRaw)
    const generationPrompt = withTryOnFramingPrompt(prompt, aspectRatio)

    // ── Quota — opération atomique (sauf comptes fondateur illimités) ─────────
    if (!isUnlimitedEmail(user.email)) {
      const { error: consumeError } = await adminClient.rpc("consume_credits", {
        p_user_id: userId,
        p_cost:    1,
      })

      if (consumeError) {
        if (consumeError.message?.includes("QUOTA_EXCEEDED")) {
          return jsonError("quota_exceeded", 429)
        }
        console.error("consume_credits DB error:", consumeError)
        return jsonError("service_unavailable", 503)
      }
    }

    // ── Upload Storage pour fal.ai (besoin d'une URL fetchable) ─────────────
    // Le bucket est PRIVÉ depuis la migration 010 : getPublicUrl y renvoie une
    // URL qui répond 400/404, donc fal.ai échouait à chaque appel et la cascade
    // retombait systématiquement sur Gemini. On signe l'URL (TTL court).
    const falConfig  = FAL_MODELS[model] ?? FAL_MODELS.standard
    const imageBytes = base64ToBytes(imageBase64)
    const stamp      = Date.now()
    const tempPath   = `${userId}/${stamp}.jpg`

    const { error: uploadError } = await adminClient.storage
      .from(STORAGE_BUCKET)
      .upload(tempPath, imageBytes, { contentType: "image/jpeg", upsert: true })

    if (uploadError) {
      console.warn("Storage upload failed — fal.ai unavailable, using direct APIs:", uploadError)
    }

    const signedUrl = uploadError ? null : await signTempUrl(tempPath)

    // Photo produit du bijou/vêtement sélectionné — SANS elle le modèle invente
    // un bijou différent à chaque génération. Transmise comme 2e image de
    // référence aux modèles multi-images (Nano Banana 2 / Pro, Gemini).
    let refUrl: string | null = null
    let refPath: string | null = null
    const hasValidRef = typeof referenceImageBase64 === "string"
      && referenceImageBase64.length > 0
      && referenceImageBase64.length <= MAX_IMAGE_BASE64_CHARS
    if (hasValidRef && !uploadError) {
      refPath = `${userId}/${stamp}-ref.jpg`
      const { error: refUploadError } = await adminClient.storage
        .from(STORAGE_BUCKET)
        .upload(refPath, base64ToBytes(referenceImageBase64), { contentType: "image/jpeg", upsert: true })
      if (refUploadError) {
        console.warn("Reference upload failed — generating without product reference:", refUploadError)
        refPath = null
      } else {
        refUrl = await signTempUrl(refPath)
        if (!refUrl) refPath = null
      }
    }

    const promptWithRef = refUrl
      ? `${generationPrompt}\n\nPRODUCT REFERENCE - IDENTITY IS THE HARD CONSTRAINT: the item to add is EXACTLY the product shown in the SECOND image. Reproduce its design, silhouette, length, proportions, materials, finish, stones and colors, including any asymmetry between the two pieces of a pair. Never substitute, simplify, shorten, split or invent a different piece. If any other instruction cannot be satisfied at the same time as this one, break that other instruction - never this one. A faithful product rendered imperfectly is a success; a well-composed image showing different jewelry is a total failure.\n\nIGNORE THE REFERENCE FRAMING: the second image is a macro shot taken a few centimeters from the lens, so the object fills the frame. It may also show a display card, an easel, a stand, packaging or a QR code - reproduce ONLY the jewelry itself, never its support. Its apparent size there carries NO information about its real size. Never scale the piece to match how big it looks in that image.\n\nSCALE BRIDGE - MEASURE, DO NOT GUESS: real jewelry is built from thin metal. In the reference, the post, ear wire, hoop wire, clasp or chain link is about 1 mm thick in reality; take that as your unit, read every other dimension of the product as a multiple of it, and keep those multiples exactly. Then place the piece on the person using the body as the ruler: an adult ear is about 6 cm tall, an earlobe about 1.5 cm, an eye about 3 cm wide, a finger about 1.8 cm wide, a wrist about 16 cm around. If the piece shows no thin metal, use the earlobe as the ruler instead.\n\nTHE RESULT OF THAT MEASUREMENT IS ALWAYS CORRECT: a stud stays a tiny point of light on the lobe, smaller than the iris. A wide hoop stays wide. A long drop earring stays long and hangs below the jawline onto the neck - expected, not an error. No outside rule caps or floors the size; the only wrong size is one that disagrees with the reference's own proportions. Scale the object as one rigid unit - never stretch, thin, crop or truncate one part relative to another.\n\nREMOVE WHAT IS ALREADY WORN: if the person in the first photo already wears jewelry on the same spot (earrings, studs, hoops, a necklace, a ring), remove it completely and leave bare skin before placing the product. The final image must show the product and nothing else.\n\nPLACE IT LIKE A REAL OBJECT: attached where the real piece attaches (through the earlobe, on its chain in the hollow of the neck, around the finger), hanging straight down under gravity with the weight and drape of its actual material, lit by the scene's own light, with a soft contact shadow on the skin and correct occlusion by hair and ear. If the piece at its true size does not fit the crop, widen the framing. Change the framing, never the jewel.`
      : generationPrompt

    // ── Cascade de fournisseurs ───────────────────────────────────────────────
    let resultBase64: string | null = null
    let provider = ""
    const errors: string[] = []

    // Comptabilité du coût RÉEL de cette génération. Un appel exécuté est
    // compté comme facturé même s'il échoue : hypothèse pessimiste, assumée —
    // mieux vaut surestimer le coût que fonder un prix sur une sous-estimation.
    const costT0 = Date.now()
    let costAttempts = 0
    let costUSD = 0

    // ── Fournisseur 1 : fal.ai (NB2 → NB Pro → Flux Kontext) ─────────────────
    if (signedUrl) {
      const cascade: FalModel[] = [falConfig]
      // Escalade vers l'autre Nano Banana si le modèle demandé n'est pas lui
      const alternate = falConfig.id === NANO_BANANA_PRO.id ? NANO_BANANA_2 : NANO_BANANA_PRO
      cascade.push(alternate, ...FAL_FALLBACK_MODELS)

      for (const cfg of cascade) {
        costAttempts += 1
        costUSD += cfg.costUSD
        try {
          resultBase64 = await generateWithFal(cfg, signedUrl, refUrl, promptWithRef, aspectRatio)
          provider = cfg.id
          break // succès → on sort de la cascade
        } catch (err) {
          errors.push(`fal ${cfg.id}: ${String(err)}`)
          console.warn(`fal ${cfg.id} failed:`, err)
        }
      }

      // Nettoyage Storage — loggé en cas d'échec pour détecter les fuites
      const toClean = refPath ? [tempPath, refPath] : [tempPath]
      adminClient.storage.from(STORAGE_BUCKET).remove(toClean).catch((cleanupErr) => {
        console.error(`[tryon-generate] Storage cleanup failed (orphaned: ${toClean.join(",")}):`, cleanupErr)
      })
    }

    // ── Fournisseur 2 : Google Gemini ─────────────────────────────────────────
    if (!resultBase64 && GOOGLE_API_KEY) {
      costAttempts += 1
      costUSD += GEMINI_COST_USD
      try {
        resultBase64 = await generateWithGemini(imageBase64, promptWithRef, aspectRatio, hasValidRef ? referenceImageBase64 : null)
        provider = "gemini-3.1-flash-image"
        console.warn(`Fell back to Gemini. fal errors: ${errors.join(" | ")}`)
      } catch (e3) {
        errors.push(`Gemini: ${String(e3)}`)
        console.warn("Gemini fallback failed:", e3)
      }
    }

    // ── Fournisseur 3 : OpenAI GPT Image ──────────────────────────────────────
    if (!resultBase64 && OPENAI_API_KEY) {
      costAttempts += 1
      costUSD += OPENAI_COST_USD
      try {
        resultBase64 = await generateWithOpenAI(imageBase64, generationPrompt)
        provider = "openai-gpt-image-1"
        console.warn(`Fell back to OpenAI. Previous errors: ${errors.join(" | ")}`)
      } catch (e4) {
        errors.push(`OpenAI: ${String(e4)}`)
        console.error("All providers failed:", errors)
      }
    }

    // Télémétrie du coût réel — une ligne par génération, succès OU échec.
    // Fire-and-forget : elle ne doit JAMAIS faire échouer une génération que
    // l'utilisatrice a déjà payée en crédit.
    adminClient.from("generation_costs").insert({
      user_id:     userId,
      tier:        model ?? "standard",
      provider:    provider || "none",
      attempts:    costAttempts,
      cost_usd:    Number(costUSD.toFixed(5)),
      duration_ms: Date.now() - costT0,
      success:     Boolean(resultBase64),
    }).then((res: { error?: unknown }) => {
      if (res?.error) console.error("[tryon-generate] cost telemetry failed:", res.error)
    })

    if (!resultBase64) {
      // Logger les détails côté serveur uniquement — jamais exposer au client
      console.error("[tryon-generate] All providers failed:", errors)
      throw new Error("generation_failed")
    }

    return new Response(JSON.stringify({ result: resultBase64, provider }), {
      status: 200,
      headers: { "Content-Type": "application/json", ...CORS }
    })

  } catch (e) {
    const msg = String(e)
    if (msg.includes("quota_exceeded") || msg.includes("QUOTA_EXCEEDED")) return jsonError("quota_exceeded", 429)
    if (msg.includes("unauthorized") || msg.includes("401"))               return jsonError("unauthorized", 401)
    // Logger le détail interne côté serveur — retourner un message opaque au client
    console.error("[tryon-generate] Unhandled error:", e)
    return jsonError("Image generation temporarily unavailable. Please try again.", 500)
  }
})

// ─── fal.ai : file d'attente + polling ───────────────────────────────────────

// Format 9:16 (story vertical mobile) — match le ratio des cellules d'affichage
// dans l'app et fournit une image full-body native (head-to-toe).
const TRYON_ASPECT_RATIO = "9:16"

function normalizeAspectRatio(raw: unknown): string {
  if (typeof raw === "string") {
    const trimmed = raw.trim()
    if (/^\d+:\d+$/.test(trimmed)) return trimmed
  }
  return TRYON_ASPECT_RATIO
}

function withTryOnFramingPrompt(prompt: string, aspectRatio: string): string {
  // NE JAMAIS forcer le corps entier : sur un essayage bijou en gros plan,
  // "full-body head-to-toe" faisait dézoomer le modèle (silhouette en robe
  // au lieu du portrait 3/4 demandé). Le cadrage suit la photo d'entrée et
  // les instructions de pose du prompt client.
  return `${prompt}\n\nOUTPUT FRAMING: Vertical ${aspectRatio} portrait (mobile story). Keep the same framing and camera distance as the input photo: a close-up stays a close-up, a full-body shot stays full-body. Never zoom out wider than the input photo. Follow the pose instructions above exactly. Do not output a square 1:1 crop.`
}

async function generateWithFal(
  cfg: FalModel,
  imageUrl: string,
  refUrl: string | null,
  prompt: string,
  aspectRatio: string
): Promise<string> {
  // Schéma d'entrée par famille (vérifié fal.ai/models/*/api) :
  //   nano-banana-2/edit & gemini-3-pro-image-preview/edit → image_urls: [..]
  //   flux-pro/kontext                                     → image_url: ".."
  // Multi-images : [photo personne, photo produit] — le prompt désigne la 2e
  // image comme référence produit. flux-kontext ne prend qu'une seule image.
  const input: Record<string, unknown> = {
    prompt,
    aspect_ratio:  aspectRatio,
    output_format: "jpeg",
    num_images:    1,
  }
  if (cfg.input === "image_urls") input.image_urls = refUrl ? [imageUrl, refUrl] : [imageUrl]
  else                            input.image_url  = imageUrl

  // Soumission en file (queue.fal.run) — les URLs de suivi sont renvoyées
  const submitRes = await fetch(`${FAL_QUEUE_URL}/${cfg.id}`, {
    method: "POST",
    headers: {
      "Authorization": `Key ${FAL_API_KEY}`,
      "Content-Type":  "application/json",
      ...FAL_PRIVACY_HEADERS,
    },
    body: JSON.stringify(input),
  })
  if (!submitRes.ok) {
    const err = await submitRes.text().catch(() => "")
    throw new Error(`fal submit HTTP ${submitRes.status}: ${err.slice(0, 300)}`)
  }
  const submitted = await submitRes.json()
  const statusUrl:   string | undefined = submitted.status_url
  const responseUrl: string | undefined = submitted.response_url
  if (!statusUrl || !responseUrl) throw new Error("fal: no status/response URL in submit response")

  // Polling du statut
  for (let attempt = 0; attempt < POLL_MAX_ATTEMPTS; attempt++) {
    await sleep(POLL_INTERVAL_MS)

    const statusRes = await fetch(statusUrl, {
      headers: { "Authorization": `Key ${FAL_API_KEY}` },
    })
    const status = (await statusRes.json()).status as string | undefined

    if (status === "COMPLETED") {
      const res = await fetch(responseUrl, {
        headers: { "Authorization": `Key ${FAL_API_KEY}` },
      })
      if (!res.ok) throw new Error(`fal result HTTP ${res.status}`)
      const json = await res.json()
      const outputUrl: string | undefined =
        json.images?.[0]?.url ?? json.image?.url ?? json.output?.[0]?.url
      if (!outputUrl) throw new Error("fal: job done but no image URL in response")

      // L'ACL initiale "forbid" ferme le fichier CDN aux tiers ; le propriétaire
      // de la clé garde l'accès, d'où le repli authentifié si l'appel anonyme
      // est refusé (403/404).
      let imgRes = await fetch(outputUrl)
      if (imgRes.status === 403 || imgRes.status === 404) {
        imgRes = await fetch(outputUrl, { headers: { "Authorization": `Key ${FAL_API_KEY}` } })
      }
      if (!imgRes.ok) throw new Error(`fal: image download failed ${imgRes.status}`)
      return bytesToBase64(new Uint8Array(await imgRes.arrayBuffer()))
    }

    if (status === "FAILED" || status === "ERROR" || status === "CANCELLED") {
      throw new Error(`fal job failed with status: ${status}`)
    }
    // IN_QUEUE / IN_PROGRESS → on continue
  }

  throw new Error(`fal job timed out after ${POLL_MAX_ATTEMPTS * POLL_INTERVAL_MS / 1000}s`)
}

// ─── Google Gemini 3.1 Flash Image : sauvetage ───────────────────────────────

async function generateWithGemini(
  imageBase64: string,
  prompt: string,
  aspectRatio: string,
  referenceImageBase64: string | null = null
): Promise<string> {
  if (!GOOGLE_API_KEY) throw new Error("GOOGLE_API_KEY not configured")

  // Modèle image dédié + imageConfig.aspectRatio (sinon sortie souvent 1:1).
  // gemini-3.1-flash-image-preview (Nano Banana 2) = lignée courante ;
  // gemini-2.0-flash-preview-image-generation et 2.5-flash-image sont dépréciés
  // (arrêt 2.5-flash-image le 2 oct 2026).
  const res = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent",
    {
      method: "POST",
      headers: {
        "Content-Type":   "application/json",
        "x-goog-api-key": GOOGLE_API_KEY,
      },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
            ...(referenceImageBase64
              ? [{ inlineData: { mimeType: "image/jpeg", data: referenceImageBase64 } }]
              : []),
          ]
        }],
        generationConfig: {
          responseModalities: ["IMAGE", "TEXT"],
          imageConfig: { aspectRatio },
        },
      }),
    }
  )

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(`Gemini HTTP ${res.status}: ${JSON.stringify(err)}`)
  }

  const json = await res.json()
  const parts: Record<string, unknown>[] = json.candidates?.[0]?.content?.parts ?? []
  const imgPart = parts.find(p =>
    (p.inlineData as Record<string, string> | undefined)?.mimeType?.startsWith("image/")
  )

  if (!imgPart) throw new Error("Gemini: no image part in response")
  return (imgPart.inlineData as Record<string, string>).data
}

// ─── OpenAI GPT Image 1 : dernier recours ────────────────────────────────────

async function generateWithOpenAI(imageBase64: string, prompt: string): Promise<string> {
  if (!OPENAI_API_KEY) throw new Error("OPENAI_API_KEY not configured")

  const imageBytes = base64ToBytes(imageBase64)
  const formData   = new FormData()
  formData.append("model", "gpt-image-1")
  formData.append("prompt", prompt)
  formData.append("n", "1")
  // OpenAI gpt-image-1 supporte 1024x1024, 1024x1536 (portrait), 1536x1024.
  // 1024x1536 = ratio 2:3 — le plus proche de 9:16 que l'API accepte.
  formData.append("size", "1024x1536")
  formData.append(
    "image",
    new Blob([imageBytes], { type: "image/png" }),
    "image.png"
  )

  const res = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_API_KEY}` },
    body: formData,
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(`OpenAI HTTP ${res.status}: ${JSON.stringify(err)}`)
  }

  const json = await res.json()

  // gpt-image-1 retourne b64_json par défaut
  const b64 = json.data?.[0]?.b64_json as string | undefined
  if (b64) return b64

  // Fallback URL (dall-e-3 / autres modèles)
  const imgUrl = json.data?.[0]?.url as string | undefined
  if (imgUrl) {
    const imgRes = await fetch(imgUrl)
    if (!imgRes.ok) throw new Error(`OpenAI: image download failed ${imgRes.status}`)
    return bytesToBase64(new Uint8Array(await imgRes.arrayBuffer()))
  }

  throw new Error("OpenAI: no image in response")
}

// ─── Utilitaires ─────────────────────────────────────────────────────────────

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = ""
  const chunk = 8192
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk))
  }
  return btoa(bin)
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

function jsonError(msg: string, status: number): Response {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { "Content-Type": "application/json", ...CORS }
  })
}
