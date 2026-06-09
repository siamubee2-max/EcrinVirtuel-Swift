// Supabase Edge Function — génération d'image avec cascade 3 niveaux
//
// Fournisseurs dans l'ordre de tentative :
//   1. Kie.ai  (Flux Kontext / GPT-4o Image / Seedream) — primaire, moins cher
//   2. Google Gemini 2.0 Flash                           — sauvetage si Kie.ai KO
//   3. OpenAI GPT Image 1                                — dernier recours
//
// La clé API n'est JAMAIS exposée côté client iOS.
//
// Tiers (iOS model → Kie.ai) :
//   preview  → seedream/4.5-edit         ~$0.008 éco
//   standard → flux-kontext              ~$0.020 ⭐ identity preservation
//   premium  → gpt4o-image               ~$0.080 best quality

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const KIE_API_KEY               = Deno.env.get("KIE_API_KEY")!
const KIE_BASE_URL              = "https://api.kie.ai"
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!
const GOOGLE_API_KEY            = Deno.env.get("GOOGLE_API_KEY")   // optionnel — sauvetage
const OPENAI_API_KEY            = Deno.env.get("OPENAI_API_KEY")   // optionnel — dernier recours

// CORS : restreint au domaine de l'app web et au Studio Supabase.
// Les clients iOS natifs n'appliquent pas CORS — ce header protège les appels browser.
const CORS = {
  "Access-Control-Allow-Origin": "https://ecrin.app",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

const STORAGE_BUCKET         = "tryon-temp"
const MAX_PROMPT_CHARS       = 4_000
const MAX_IMAGE_BASE64_CHARS = 6 * 1024 * 1024   // ~4.5 MB binaire
const POLL_INTERVAL_MS       = 2_500
const POLL_MAX_ATTEMPTS      = 20                  // 20 × 2.5s = 50s max

// Comptes fondateur — pas de décompte quota (aligné iOS UnlimitedAccess.swift)
const UNLIMITED_EMAILS = new Set([
  "siamubee2@gmail.com",
  "monia.valenza@gmail.com",
])

function isUnlimitedEmail(email: string | undefined): boolean {
  return !!email && UNLIMITED_EMAILS.has(email.toLowerCase())
}

// ─── Mapping tiers iOS → configuration Kie.ai ────────────────────────────────

interface KieModel {
  api:     "flux_kontext" | "gpt4o_image" | "market_task"
  model:   string
  costUSD: number
}

// Essayage virtuel → format vertical 9:16 (multi-vues, essayage rapide).
// Primaire : GPT Image 2 i2i (aspect_ratio 9:16 validé hors app, generated/9x16/).
// Premium tenues multi-pièces : Nano Banana Pro. Puis NB2 / Flux / GPT4o en secours.
const KIE_MODELS: Record<string, KieModel> = {
  preview:  { api: "market_task",  model: "gpt-image-2-image-to-image", costUSD: 0.030 },
  standard: { api: "market_task",  model: "gpt-image-2-image-to-image", costUSD: 0.030 },
  premium:  { api: "market_task",  model: "nano-banana-pro",            costUSD: 0.060 },
}

// Cascade de secours (essayée dans l'ordre après le modèle demandé)
const KIE_FALLBACK_MODELS: KieModel[] = [
  { api: "market_task",  model: "nano-banana-2", costUSD: 0.030 },
  { api: "flux_kontext", model: "flux-kontext",  costUSD: 0.020 },
  { api: "gpt4o_image",  model: "gpt4o-image",   costUSD: 0.080 },
]

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

  try {
    const {
      imageBase64,
      prompt,
      model = "standard",
      quality = "medium",
      aspectRatio: aspectRatioRaw,
    } = await req.json()

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

    // ── Upload Storage pour Kie.ai (besoin d'une URL publique) ───────────────
    const kieConfig  = KIE_MODELS[model] ?? KIE_MODELS.standard
    const imageBytes = base64ToBytes(imageBase64)
    const tempPath   = `${userId}/${Date.now()}.jpg`

    const { error: uploadError } = await adminClient.storage
      .from(STORAGE_BUCKET)
      .upload(tempPath, imageBytes, { contentType: "image/jpeg", upsert: true })

    const publicUrl = uploadError
      ? null
      : adminClient.storage.from(STORAGE_BUCKET).getPublicUrl(tempPath).data.publicUrl

    if (uploadError) {
      console.warn("Storage upload failed — Kie.ai unavailable, using direct APIs:", uploadError)
    }

    // ── Cascade de fournisseurs ───────────────────────────────────────────────
    let resultBase64: string | null = null
    let provider = ""
    const errors: string[] = []

    // ── Fournisseur 1 : Kie.ai avec cascade Nano Banana → Flux → GPT4o ───────
    if (publicUrl) {
      // Construit la cascade : modèle demandé puis fallbacks dans l'ordre
      const cascade: KieModel[] = [kieConfig]
      // Ajoute nano-banana-pro si on n'est pas déjà dessus (escalade premium)
      if (kieConfig.model !== KIE_MODELS.premium.model) {
        cascade.push(KIE_MODELS.premium)
      }
      // Ajoute les fallbacks Flux Kontext puis GPT4o-Image
      cascade.push(...KIE_FALLBACK_MODELS)

      for (const cfg of cascade) {
        try {
          resultBase64 = await generateWithKie(cfg, publicUrl, generationPrompt, quality, aspectRatio)
          provider = cfg.model
          break // succès → on sort de la cascade
        } catch (err) {
          errors.push(`Kie.ai ${cfg.model}: ${String(err)}`)
          console.warn(`Kie.ai ${cfg.model} failed:`, err)
        }
      }

      // Nettoyage Storage — loggé en cas d'échec pour détecter les fuites
      adminClient.storage.from(STORAGE_BUCKET).remove([tempPath]).catch((cleanupErr) => {
        console.error(`[tryon-generate] Storage cleanup failed (orphaned file: ${tempPath}):`, cleanupErr)
      })
    }

    // ── Fournisseur 2 : Google Gemini ─────────────────────────────────────────
    if (!resultBase64 && GOOGLE_API_KEY) {
      try {
        resultBase64 = await generateWithGemini(imageBase64, generationPrompt, aspectRatio)
        provider = "gemini-2.0-flash"
        console.warn(`Fell back to Gemini. Kie.ai errors: ${errors.join(" | ")}`)
      } catch (e3) {
        errors.push(`Gemini: ${String(e3)}`)
        console.warn("Gemini fallback failed:", e3)
      }
    }

    // ── Fournisseur 3 : OpenAI GPT Image ──────────────────────────────────────
    if (!resultBase64 && OPENAI_API_KEY) {
      try {
        resultBase64 = await generateWithOpenAI(imageBase64, generationPrompt)
        provider = "openai-gpt-image-1"
        console.warn(`Fell back to OpenAI. Previous errors: ${errors.join(" | ")}`)
      } catch (e4) {
        errors.push(`OpenAI: ${String(e4)}`)
        console.error("All providers failed:", errors)
      }
    }

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

// ─── Kie.ai : génération + polling ───────────────────────────────────────────

async function generateWithKie(
  cfg: KieModel,
  imageUrl: string,
  prompt: string,
  _quality: string,
  aspectRatio: string
): Promise<string> {
  let taskId: string

  if (cfg.api === "flux_kontext") {
    taskId = await startFluxKontext(imageUrl, prompt, aspectRatio)
  } else if (cfg.api === "gpt4o_image") {
    taskId = await startGPT4oImage(imageUrl, prompt)
  } else {
    taskId = await startMarketTask(cfg.model, imageUrl, prompt, aspectRatio)
  }

  return await pollForResult(taskId)
}

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
  return `${prompt}\n\nOUTPUT FRAMING: Vertical ${aspectRatio} portrait (mobile story). Full-body head-to-toe when outfit try-on applies. Do not output a square 1:1 crop.`
}

async function startFluxKontext(imageUrl: string, prompt: string, aspectRatio: string): Promise<string> {
  // Flux Kontext (kie.ai) accepte `aspectRatio` en camelCase.
  // On envoie aussi `size` au cas où une variante de l'API utilise ce nom.
  // Valeurs supportées: "1:1", "16:9", "9:16", "4:3", "3:4", "21:9", "9:21".
  const res = await kiePost("/api/v1/flux/kontext/generate", {
    prompt,
    imageUrl,
    aspectRatio,
    size:        aspectRatio,
    nVariants:   1,
  })
  const taskId = res.data?.taskId ?? res.data?.task_id
  if (!taskId) throw new Error("Flux Kontext: no taskId in response")
  return taskId as string
}

async function startGPT4oImage(imageUrl: string, prompt: string): Promise<string> {
  // GPT4o-Image (kie.ai) supporte 1:1, 3:2, 2:3 — utilise 2:3 (portrait)
  // car 9:16 n'est pas dans la liste officielle de gpt4o-image.
  const res = await kiePost("/api/v1/gpt4o-image/generate", {
    prompt,
    imageUrl,
    aspectRatio: "2:3",
    size:        "2:3",
    nVariants:   1,
  })
  const taskId = res.data?.taskId ?? res.data?.task_id
  if (!taskId) throw new Error("GPT4o Image: no taskId in response")
  return taskId as string
}

async function startMarketTask(
  model: string,
  imageUrl: string,
  prompt: string,
  aspectRatio: string
): Promise<string> {
  // Schéma Market API — le nom du tableau d'images DIFFÈRE selon le modèle :
  //   • Nano Banana 2 / Pro         → input.image_input  (vérifié docs.kie.ai)
  //   • GPT Image 2 image-to-image  → input.input_urls   (vérifié docs.kie.ai)
  // On envoie LES DEUX clés ; chaque modèle ignore celle qu'il ne connaît pas.
  // Sans ça, le modèle primaire (gpt-image-2) ignore la photo source → résultat faux.
  //   input.aspect_ratio  = enum incluant "9:16" — jamais "auto" (défaut API → carré)
  //   input.resolution    = "1K" | "2K" | "4K"
  //   input.output_format = "png" | "jpg"
  const res = await kiePost("/api/v1/jobs/createTask", {
    model,
    input: {
      prompt,
      image_input:   [imageUrl],   // Nano Banana 2 / Pro
      input_urls:    [imageUrl],   // GPT Image 2 image-to-image
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

async function pollForResult(taskId: string): Promise<string> {
  const DONE = new Set(["success", "completed", "finish", "succeeded", "finished"])
  const FAIL = new Set(["failed", "error", "timeout", "cancelled", "canceled"])

  for (let attempt = 0; attempt < POLL_MAX_ATTEMPTS; attempt++) {
    await sleep(POLL_INTERVAL_MS)

    const res    = await kieGet(`/api/v1/jobs/recordInfo?taskId=${encodeURIComponent(taskId)}`)
    const data   = res.data ?? {}
    const status = (data.status ?? data.state ?? "").toString().toLowerCase()

    if (FAIL.has(status)) {
      throw new Error(`Kie.ai job ${taskId} failed with status: ${status}`)
    }

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

// ─── Kie.ai HTTP helpers ──────────────────────────────────────────────────────

async function kiePost(path: string, body: unknown): Promise<KieResponse> {
  const res = await fetch(`${KIE_BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${KIE_API_KEY}`,
      "Content-Type":  "application/json",
    },
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
  if (json.code && json.code !== 200) {
    throw new Error(`Kie.ai ${path} error ${json.code}: ${json.msg ?? "unknown"}`)
  }
}

// ─── Google Gemini 2.0 Flash : sauvetage ─────────────────────────────────────

async function generateWithGemini(
  imageBase64: string,
  prompt: string,
  aspectRatio: string
): Promise<string> {
  if (!GOOGLE_API_KEY) throw new Error("GOOGLE_API_KEY not configured")

  // Modèle image dédié + imageConfig.aspectRatio (sinon sortie souvent 1:1).
  const res = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent",
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
            { inlineData: { mimeType: "image/jpeg", data: imageBase64 } }
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
