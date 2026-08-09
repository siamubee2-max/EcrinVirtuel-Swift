// Supabase Edge Function — génération d'image avec cascade Nano Banana + GPT Image 2
//
// Tiers (iOS model → Kie.ai) :
//   preview/standard → gpt-image-2-image-to-image (9:16 natif)
//   premium          → nano-banana-pro
// Fallbacks : nano-banana-2 → flux-kontext → gpt4o-image → Gemini → OpenAI
//
// M4 — App Attest hook (default OFF, zero overhead when off)
//   APP_ATTEST_MODE=off    (default) — attestation headers silently ignored.
//   APP_ATTEST_MODE=log    — verify + log to monitoring_events; never block generation.
//   APP_ATTEST_MODE=enforce — reject requests that fail attestation (HTTP 401).
//   INTERNAL_FN_KEY        — if set, forwarded to verify-attestation as x-internal-key.
//
// ⚠️ DO NOT set enforce until you see "attestation_ok" from real devices in monitoring_events.
//    A crypto bug in enforce mode would break ALL paid generation.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"

const KIE_API_KEY               = Deno.env.get("KIE_API_KEY")!
const KIE_BASE_URL              = "https://api.kie.ai"
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!
const GOOGLE_API_KEY            = Deno.env.get("GOOGLE_API_KEY")
const OPENAI_API_KEY            = Deno.env.get("OPENAI_API_KEY")

// M4 App Attest — env vars (no new imports; these are just string reads).
// APP_ATTEST_MODE: "off" | "log" | "enforce"  (default "off")
// INTERNAL_FN_KEY: shared secret forwarded to verify-attestation (optional)
const APP_ATTEST_MODE  = Deno.env.get("APP_ATTEST_MODE") ?? "off"
const INTERNAL_FN_KEY  = Deno.env.get("INTERNAL_FN_KEY") ?? ""
// URL of the verify-attestation Edge Function (same project, internal routing).
// Falls back to a pattern derived from SUPABASE_URL if not explicitly set.
const VERIFY_ATTEST_URL = Deno.env.get("VERIFY_ATTEST_URL") ??
  `${SUPABASE_URL}/functions/v1/verify-attestation`

const CORS = {
  "Access-Control-Allow-Origin": "https://ecrin.app",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

const STORAGE_BUCKET         = "tryon-temp"
const MAX_PROMPT_CHARS       = 4_000
const MAX_IMAGE_BASE64_CHARS = 6 * 1024 * 1024
const POLL_INTERVAL_MS       = 2_500
const POLL_MAX_ATTEMPTS      = 20

// Comptes fondateur — pas de décompte quota (aligné iOS UnlimitedAccess.swift)
const UNLIMITED_EMAILS = new Set([
  "siamubee2@gmail.com",
  "monia.valenza@gmail.com",
])

function isUnlimitedEmail(email: string | undefined): boolean {
  return !!email && UNLIMITED_EMAILS.has(email.toLowerCase())
}

interface KieModel {
  api:     "flux_kontext" | "gpt4o_image" | "market_task"
  model:   string
  costUSD: number
}

// Essayage virtuel → format vertical 9:16.
const KIE_MODELS: Record<string, KieModel> = {
  preview:  { api: "market_task",  model: "gpt-image-2-image-to-image", costUSD: 0.030 },
  standard: { api: "market_task",  model: "gpt-image-2-image-to-image", costUSD: 0.030 },
  premium:  { api: "market_task",  model: "nano-banana-pro",            costUSD: 0.060 },
}

// Primaire par CATÉGORIE d'essayage — le « bon générateur » selon le type d'article.
//   bijoux     → flux-kontext   (édition locale précise, gros plan zone, rapide, peu cher)
//   vêtements  → nano-banana-pro (meilleure fidélité tissu/coupe)
//   chaussures → gpt-image-2     (bon compromis pieds/sol)
// Catégorie absente/inconnue → fallback sur KIE_MODELS[model] (comportement v24 inchangé).
const CATEGORY_PRIMARY: Record<string, KieModel> = {
  jewelry:  { api: "flux_kontext", model: "flux-kontext",                costUSD: 0.020 },
  clothing: { api: "market_task",  model: "nano-banana-pro",            costUSD: 0.060 },
  shoes:    { api: "market_task",  model: "gpt-image-2-image-to-image", costUSD: 0.030 },
}

// Fallback Kie.ai réduit à UN seul modèle rapide et fiable : gpt4o-image (lent, 0.08$)
// et le doublon flux-kontext ont été retirés pour que la cascade tienne dans le budget
// wall-clock de l'Edge Function (~150 s) — sinon la fonction était tuée et renvoyait
// « échec » alors qu'un fallback aurait pu réussir. Gemini + OpenAI restent en secours final.
const KIE_FALLBACK_MODELS: KieModel[] = [
  { api: "market_task",  model: "nano-banana-2", costUSD: 0.030 },
]

const TRYON_ASPECT_RATIO = "9:16"

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS })
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return jsonError("unauthorized", 401)

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return jsonError("unauthorized", 401)

  const userId      = user.id
  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    // ── M4 App Attest hook ───────────────────────────────────────────────────
    // When APP_ATTEST_MODE is "off" (the default), this block is entirely skipped.
    // It adds zero overhead and zero imports when inactive.
    //
    // When "log" or "enforce":
    //   • Read the raw body bytes (needed to compute clientDataHash = SHA-256(body)).
    //   • Parse JSON from those bytes (same result as req.json() would give).
    //   • Call verify-attestation server-to-server with the attest headers.
    //   • On failure: log to monitoring_events; in enforce mode also return 401.
    //
    // The try/catch around the entire block CANNOT propagate into the main flow —
    // any error inside is caught and, unless enforce mode wants to block, ignored.
    //
    // ⚠️ UNTESTED — see verify-attestation/index.ts header. Do not enforce in prod
    //    until "attestation_ok" is confirmed from a real device.

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

    // If APP_ATTEST_MODE is active we already parsed the body above; otherwise parse now.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const bodyJson: any = parsedBody ?? await req.json()
    const {
      imageBase64,
      prompt,
      model = "standard",
      quality = "medium",
      category: categoryRaw,
      aspectRatio: aspectRatioRaw,
    } = bodyJson as {
      imageBase64?:  string
      prompt?:       string
      model?:        string
      quality?:      string
      category?:     unknown
      aspectRatio?:  unknown
    }

    // Validation AVANT tout traitement
    if (!imageBase64 || !prompt)  return jsonError("imageBase64 and prompt required", 400)
    if (typeof prompt !== "string" || prompt.length > MAX_PROMPT_CHARS)
      return jsonError("prompt too long", 400)
    if (typeof imageBase64 !== "string" || imageBase64.length > MAX_IMAGE_BASE64_CHARS)
      return jsonError("image too large", 400)

    const category    = typeof categoryRaw === "string" ? categoryRaw.toLowerCase() : ""
    const aspectRatio = normalizeAspectRatio(aspectRatioRaw)
    const generationPrompt = withTryOnFramingPrompt(prompt, aspectRatio, category)

    // Modération du PROMPT seul (fail-open, loggée). La photo est modérée plus bas,
    // une fois l'URL signée disponible — voir le bloc « modération de l'image ».
    const mod = await moderate(prompt, undefined, adminClient, userId)
    if (mod.blocked) {
      await logSecurityEvent(adminClient, userId, "moderation_blocked", mod.categories.join(","))
      return jsonError("content_rejected", 400)
    }

    // Quota — atomique (sauf comptes fondateur illimités)
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

    // Choix du primaire : catégorie d'abord (le « bon générateur »), sinon tier `model`.
    const kieConfig  = CATEGORY_PRIMARY[category] ?? KIE_MODELS[model] ?? KIE_MODELS.standard
    const imageBytes = base64ToBytes(imageBase64)
    const tempPath   = `${userId}/${Date.now()}.jpg`

    const { error: uploadError } = await adminClient.storage
      .from(STORAGE_BUCKET)
      .upload(tempPath, imageBytes, { contentType: "image/jpeg", upsert: true })

    let publicUrl: string | null = null
    if (uploadError) {
      console.warn("Storage upload failed:", uploadError)
    } else {
      const { data: signed, error: signError } =
        await adminClient.storage.from(STORAGE_BUCKET).createSignedUrl(tempPath, 120)
      if (signError || !signed?.signedUrl) {
        console.error("[tryon-generate] createSignedUrl failed:", signError)
        adminClient.storage.from(STORAGE_BUCKET).remove([tempPath]).catch(() => {})
        return jsonError("Image generation temporarily unavailable. Please try again.", 503)
      }
      publicUrl = signed.signedUrl

      // ── Modération de l'IMAGE (audit 007) ────────────────────────────────────
      // Jusqu'ici seul le prompt texte était filtré : un utilisateur pouvait envoyer
      // la photo d'un tiers non consentant avec un prompt anodin, sans aucun contrôle.
      // On réutilise l'URL signée (la doc OpenAI recommande image_url plutôt qu'un
      // base64 de plusieurs Mo) — l'URL vit 120 s, largement assez pour l'appel.
      //
      // ⚠️ PORTÉE RÉELLE — à ne pas surestimer : `sexual/minors` et `illicit` sont des
      // catégories TEXTE UNIQUEMENT chez omni-moderation (score 0 sur une image seule).
      // Ce contrôle attrape donc `violence/graphic` sur l'image, et rend visibles les
      // scores `sexual`/`self-harm`, mais il NE constitue PAS une détection CSAM.
      // Une vraie couverture exige un service dédié (PhotoDNA, Thorn Safer,
      // Cloudflare CSAM Scanning Tool). Voir docs/AUDIT-007-2026-08-09.md.
      const imgMod = await moderate(prompt, publicUrl, adminClient, userId)
      if (imgMod.blocked) {
        await logSecurityEvent(adminClient, userId, "moderation_blocked_image", imgMod.categories.join(","))
        adminClient.storage.from(STORAGE_BUCKET).remove([tempPath]).catch(() => {})
        return jsonError("content_rejected", 400)
      }
      // Signal sans blocage : `sexual` est volontairement hors des catégories bloquantes
      // (maillot de bain / lingerie sont légitimes ici), mais un score élevé mérite d'être
      // tracé pour repérer un détournement de l'app.
      if (imgMod.sexualScore !== undefined && imgMod.sexualScore >= SEXUAL_SCORE_ALERT) {
        await logSecurityEvent(
          adminClient, userId, "moderation_image_sexual_high",
          `score=${imgMod.sexualScore.toFixed(3)}`,
        )
      }
    }

    let resultBase64: string | null = null
    let provider = ""
    const errors: string[] = []

    if (publicUrl) {
      const cascade: KieModel[] = [kieConfig]
      if (kieConfig.model !== KIE_MODELS.premium.model) {
        cascade.push(KIE_MODELS.premium)
      }
      cascade.push(...KIE_FALLBACK_MODELS)

      // Dédup par nom de modèle — évite de re-tenter (et potentiellement re-facturer)
      // le même modèle quand le primaire catégorie figure déjà en fallback.
      const seenModels = new Set<string>()
      const dedupedCascade = cascade.filter((c) => {
        if (seenModels.has(c.model)) return false
        seenModels.add(c.model)
        return true
      })

      // Budget wall-clock : on garde ~40 s de marge sous la limite Edge (~150 s) pour
      // laisser Gemini/OpenAI tenter en secours rapide. On ne DÉMARRE pas un modèle Kie
      // s'il ne peut plus finir dans le budget, et chaque polling s'arrête à cette échéance.
      const kieDeadline = Date.now() + 110_000
      for (const cfg of dedupedCascade) {
        if (Date.now() >= kieDeadline) {
          errors.push("Kie.ai cascade: budget wall-clock épuisé, bascule secours")
          break
        }
        try {
          resultBase64 = await generateWithKie(cfg, publicUrl, generationPrompt, quality, aspectRatio, kieDeadline)
          provider = cfg.model
          break
        } catch (err) {
          errors.push(`Kie.ai ${cfg.model}: ${String(err)}`)
          console.warn(`Kie.ai ${cfg.model} failed:`, err)
        }
      }

      adminClient.storage.from(STORAGE_BUCKET).remove([tempPath]).catch((cleanupErr) => {
        console.error(`[tryon-generate] Storage cleanup failed (orphaned: ${tempPath}):`, cleanupErr)
      })
    }

    if (!resultBase64 && GOOGLE_API_KEY) {
      try {
        resultBase64 = await generateWithGemini(imageBase64, generationPrompt, aspectRatio)
        provider = "gemini-2.0-flash"
      } catch (e3) {
        errors.push(`Gemini: ${String(e3)}`)
      }
    }

    if (!resultBase64 && OPENAI_API_KEY) {
      try {
        resultBase64 = await generateWithOpenAI(imageBase64, generationPrompt)
        provider = "openai-gpt-image-1"
      } catch (e4) {
        errors.push(`OpenAI: ${String(e4)}`)
        console.error("All providers failed:", errors)
      }
    }

    if (!resultBase64) {
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
    console.error("[tryon-generate] Unhandled error:", e)
    return jsonError("Image generation temporarily unavailable. Please try again.", 500)
  }
})

async function generateWithKie(cfg: KieModel, imageUrl: string, prompt: string, _quality: string, aspectRatio: string, deadline?: number): Promise<string> {
  let taskId: string
  if (cfg.api === "flux_kontext") {
    taskId = await startFluxKontext(imageUrl, prompt, aspectRatio)
  } else if (cfg.api === "gpt4o_image") {
    taskId = await startGPT4oImage(imageUrl, prompt)
  } else {
    taskId = await startMarketTask(cfg.model, imageUrl, prompt, aspectRatio)
  }
  return await pollForResult(taskId, deadline)
}

function normalizeAspectRatio(raw: unknown): string {
  if (typeof raw === "string") {
    const trimmed = raw.trim()
    if (/^\d+:\d+$/.test(trimmed)) return trimmed
  }
  return TRYON_ASPECT_RATIO
}

// Cadrage par catégorie : bijoux → gros plan de la zone (la pièce doit dominer le cadre),
// vêtements/chaussures → plein corps tête-aux-pieds. Réglé côté serveur pour contrer
// le défaut « bague minuscule dans un portrait plein corps ».
function withTryOnFramingPrompt(prompt: string, aspectRatio: string, category: string): string {
  // PRESERVATION is the priority: the result must look like the user's OWN photo
  // (mannequin or selfie) with the jewelry/garment simply added — same background,
  // same lighting, same colours, same skin tone, same mood. And the piece must be
  // rendered at REALISTIC, true-to-life scale — never oversized or distorted.
  const preserve =
    `PRESERVE the input photo exactly: keep the same person, face, pose, skin tone and complexion, ` +
    `the same background, the same lighting, white balance, colours and overall mood/ambiance of the original. ` +
    `Do NOT relight, recolour, beautify, stylise or replace the background. ` +
    `Only add the item to the person so the result looks like the SAME photo with the item now worn. ` +
    `Photorealistic and seamlessly composited.`

  if (category === "jewelry") {
    return `${prompt}\n\nOUTPUT FRAMING: Vertical ${aspectRatio} portrait, framed on the body zone where the jewelry sits ` +
      `— hand & fingers for rings and bracelets, neckline & décolleté for necklaces, ears & side of the face for earrings, ` +
      `wrist for watches — so the piece is clearly visible. Render the jewelry at REALISTIC, true-to-life scale and ` +
      `proportions: correctly sized for the body, natural thickness, never oversized, stretched or distorted. ` +
      `Keep the metal colour and gemstone colours faithful to the reference jewelry. ${preserve}`
  }
  return `${prompt}\n\nOUTPUT FRAMING: Vertical ${aspectRatio} portrait (mobile story), full-body head-to-toe so the whole ` +
    `outfit/shoes are visible, at realistic human proportions and correct garment fit. ${preserve} ` +
    `Do not output a square 1:1 crop.`
}

async function startFluxKontext(imageUrl: string, prompt: string, aspectRatio: string): Promise<string> {
  const res = await kiePost("/api/v1/flux/kontext/generate", {
    prompt, imageUrl, aspectRatio, size: aspectRatio, nVariants: 1,
  })
  const taskId = res.data?.taskId ?? res.data?.task_id
  if (!taskId) throw new Error("Flux Kontext: no taskId in response")
  return taskId as string
}

async function startGPT4oImage(imageUrl: string, prompt: string): Promise<string> {
  const res = await kiePost("/api/v1/gpt4o-image/generate", {
    prompt, imageUrl, aspectRatio: "2:3", size: "2:3", nVariants: 1,
  })
  const taskId = res.data?.taskId ?? res.data?.task_id
  if (!taskId) throw new Error("GPT4o Image: no taskId in response")
  return taskId as string
}

async function startMarketTask(model: string, imageUrl: string, prompt: string, aspectRatio: string): Promise<string> {
  // Le nom du tableau d'images DIFFÈRE selon le modèle :
  //   • Nano Banana 2 / Pro        → input.image_input
  //   • GPT Image 2 image-to-image → input.input_urls
  // On envoie LES DEUX clés ; chaque modèle ignore celle qu'il ne connaît pas.
  const res = await kiePost("/api/v1/jobs/createTask", {
    model,
    input: {
      prompt,
      image_input:   [imageUrl],
      input_urls:    [imageUrl],
      aspect_ratio:  aspectRatio,
      resolution:    "2K",
      output_format: "jpg",
      nVariants:     1,
    },
  })
  const taskId = res.data?.taskId ?? res.data?.task_id
  if (!taskId) throw new Error(`Market task (${model}): no taskId`)
  return taskId as string
}

async function pollForResult(taskId: string, deadline?: number): Promise<string> {
  const DONE = new Set(["success", "completed", "finish", "succeeded", "finished"])
  const FAIL = new Set(["failed", "error", "timeout", "cancelled", "canceled"])

  for (let attempt = 0; attempt < POLL_MAX_ATTEMPTS; attempt++) {
    // Respecte le budget wall-clock de la cascade : on abandonne ce modèle si l'échéance
    // approche, pour laisser un fallback rapide (Gemini/OpenAI) tenter avant la limite Edge.
    if (deadline && Date.now() + POLL_INTERVAL_MS >= deadline) {
      throw new Error(`Kie.ai job ${taskId} abandonné (budget cascade atteint)`)
    }
    await sleep(POLL_INTERVAL_MS)
    const res    = await kieGet(`/api/v1/jobs/recordInfo?taskId=${encodeURIComponent(taskId)}`)
    const data   = res.data ?? {}
    const status = (data.status ?? data.state ?? "").toString().toLowerCase()

    if (FAIL.has(status)) throw new Error(`Kie.ai job ${taskId} failed with status: ${status}`)

    if (DONE.has(status)) {
      const outputUrl: string | undefined =
        data.outputUrls?.[0]  as string ??
        data.output_urls?.[0] as string ??
        data.imageUrl         as string ??
        data.image_url        as string ??
        data.url              as string ??
        (data.result as Record<string, unknown>)?.url as string ??
        ((data.resultJson ? JSON.parse(data.resultJson as string) : {}) as Record<string, unknown[]>)?.resultUrls?.[0] as string

      if (!outputUrl) throw new Error("Job done but no output URL found in response")
      const imgRes = await fetch(outputUrl)
      if (!imgRes.ok) throw new Error(`Failed to download result: ${imgRes.status}`)
      return bytesToBase64(new Uint8Array(await imgRes.arrayBuffer()))
    }
  }
  throw new Error(`Kie.ai job ${taskId} timed out after ${POLL_MAX_ATTEMPTS * POLL_INTERVAL_MS / 1000}s`)
}

async function kiePost(path: string, body: unknown): Promise<KieResponse> {
  const res = await fetch(`${KIE_BASE_URL}${path}`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${KIE_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  })
  const json = await res.json() as KieResponse
  checkKieError(json, res.status, path)
  return json
}

async function kieGet(path: string): Promise<KieResponse> {
  const res = await fetch(`${KIE_BASE_URL}${path}`, {
    headers: { "Authorization": `Bearer ${KIE_API_KEY}` },
  })
  return await res.json() as KieResponse
}

interface KieResponse {
  code?: number
  msg?:  string
  data?: Record<string, unknown>
}

function checkKieError(json: KieResponse, httpStatus: number, path: string): void {
  if (httpStatus === 401 || json.code === 401) throw new Error("Kie.ai: invalid API key")
  if (httpStatus === 402 || json.code === 402) throw new Error("Kie.ai: insufficient credits")
  if (httpStatus === 429 || json.code === 429) throw new Error("Kie.ai: rate limit")
  if (json.code && json.code !== 200) throw new Error(`Kie.ai ${path} error ${json.code}: ${json.msg ?? "unknown"}`)
}

async function generateWithGemini(imageBase64: string, prompt: string, aspectRatio: string): Promise<string> {
  if (!GOOGLE_API_KEY) throw new Error("GOOGLE_API_KEY not configured")
  const res = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GOOGLE_API_KEY },
      body: JSON.stringify({
        contents: [{ parts: [
          { text: prompt },
          { inlineData: { mimeType: "image/jpeg", data: imageBase64 } }
        ]}],
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
  const imgPart = parts.find(p => (p.inlineData as Record<string, string> | undefined)?.mimeType?.startsWith("image/"))
  if (!imgPart) throw new Error("Gemini: no image part in response")
  return (imgPart.inlineData as Record<string, string>).data
}

async function generateWithOpenAI(imageBase64: string, prompt: string): Promise<string> {
  if (!OPENAI_API_KEY) throw new Error("OPENAI_API_KEY not configured")
  const imageBytes = base64ToBytes(imageBase64)
  const formData   = new FormData()
  formData.append("model", "gpt-image-1")
  formData.append("prompt", prompt)
  formData.append("n", "1")
  formData.append("size", "1024x1536")
  formData.append("image", new Blob([imageBytes], { type: "image/png" }), "image.png")

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
  const b64 = json.data?.[0]?.b64_json as string | undefined
  if (b64) return b64
  const imgUrl = json.data?.[0]?.url as string | undefined
  if (imgUrl) {
    const imgRes = await fetch(imgUrl)
    if (!imgRes.ok) throw new Error(`OpenAI: image download failed ${imgRes.status}`)
    return bytesToBase64(new Uint8Array(await imgRes.arrayBuffer()))
  }
  throw new Error("OpenAI: no image in response")
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = ""
  const chunk = 8192
  for (let i = 0; i < bytes.length; i += chunk) bin += String.fromCharCode(...bytes.subarray(i, i + chunk))
  return btoa(bin)
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

const MODERATION_MODEL    = "omni-moderation-latest"
const MODERATION_TIMEOUT_MS = 3_000
// Categories that block generation outright. "sexual" (broad) is intentionally
// EXCLUDED: this is a fashion try-on app, so legitimate swimwear/lingerie must pass.
// "sexual/minors" (CSAM) is always blocked.
const BLOCK_CATEGORIES = ["sexual/minors", "violence/graphic", "illicit"]

// `ReturnType<typeof createClient>` résout les génériques vers leurs DÉFAUTS
// (`unknown, never, …`), alors que `createClient(url, key)` produit `<any, "public", any>` :
// d'où un TS2345 à chaque appel. Le déploiement Supabase ne type-checke pas, donc la prod
// v30 embarque déjà 7 de ces erreurs. On corrige ici la signature partagée plutôt que de
// caster à chaque site d'appel.
// deno-lint-ignore no-explicit-any
type AdminClient = ReturnType<typeof createClient<any, "public", any>>

// Au-delà de ce score `sexual` sur l'image, on trace (sans bloquer) — cf. appel plus haut.
const SEXUAL_SCORE_ALERT = 0.85
// L'appel avec image transite par une URL : plus lent qu'un simple prompt.
const MODERATION_IMAGE_TIMEOUT_MS = 10_000

interface ModerationOutcome {
  blocked: boolean
  categories: string[]
  sexualScore?: number
}

async function logSecurityEvent(
  admin: AdminClient,
  userId: string,
  eventType: string,
  message: string,
): Promise<void> {
  try {
    await admin.from("monitoring_events").insert({
      event_type: eventType,
      user_id: userId,
      error_domain: "moderation",
      error_message: message.slice(0, 500),
      platform: "edge",
    })
  } catch (_e) { /* fire-and-forget */ }
}

// Returns blocked=true only on a confident flag. On error/timeout: fail-open + log.
// `imageUrl` optionnelle : si fournie, la photo est jointe à l'analyse (multimodal).
async function moderate(
  prompt: string,
  imageUrl: string | undefined,
  admin: AdminClient,
  userId: string,
): Promise<ModerationOutcome> {
  if (!OPENAI_API_KEY) return { blocked: false, categories: [] }
  const ctrl = new AbortController()
  const t = setTimeout(
    () => ctrl.abort(),
    imageUrl ? MODERATION_IMAGE_TIMEOUT_MS : MODERATION_TIMEOUT_MS,
  )
  try {
    // Format multimodal officiel : tableau de parts typées.
    const input: unknown[] = [{ type: "text", text: prompt }]
    if (imageUrl) input.push({ type: "image_url", image_url: { url: imageUrl } })

    const res = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: MODERATION_MODEL, input }),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`moderation HTTP ${res.status}`)
    const json = await res.json()
    const result = json.results?.[0] ?? {}
    const cats   = (result.categories ?? {}) as Record<string, boolean>
    const scores = (result.category_scores ?? {}) as Record<string, number>
    const hit = BLOCK_CATEGORIES.filter((c) => cats[c] === true)
    return { blocked: hit.length > 0, categories: hit, sexualScore: scores["sexual"] }
  } catch (e) {
    // Fail-open : on ne bloque pas la génération, mais on trace le trou de couverture.
    await logSecurityEvent(
      admin, userId,
      imageUrl ? "moderation_image_unavailable" : "moderation_unavailable",
      String(e),
    )
    return { blocked: false, categories: [] }
  } finally {
    clearTimeout(t)
  }
}

function jsonError(msg: string, status: number): Response {
  return new Response(JSON.stringify({ error: msg }), {
    status,
    headers: { "Content-Type": "application/json", ...CORS }
  })
}
