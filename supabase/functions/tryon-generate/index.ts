// Supabase Edge Function — génération d'image avec cascade Nano Banana + GPT Image 2
//
// Tiers (iOS model → Kie.ai) :
//   preview/standard → gpt-image-2-image-to-image (9:16 natif)
//   premium          → nano-banana-pro
// Fallbacks : nano-banana-2 → flux-kontext → gpt4o-image → Gemini → OpenAI

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"

const KIE_API_KEY               = Deno.env.get("KIE_API_KEY")!
const KIE_BASE_URL              = "https://api.kie.ai"
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!
const GOOGLE_API_KEY            = Deno.env.get("GOOGLE_API_KEY")
const OPENAI_API_KEY            = Deno.env.get("OPENAI_API_KEY")

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

const KIE_FALLBACK_MODELS: KieModel[] = [
  { api: "market_task",  model: "nano-banana-2", costUSD: 0.030 },
  { api: "flux_kontext", model: "flux-kontext",  costUSD: 0.020 },
  { api: "gpt4o_image",  model: "gpt4o-image",   costUSD: 0.080 },
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

    // Content moderation (fail-open, logged) — see logSecurityEvent.
    const mod = await moderate(prompt, adminClient, userId)
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

    const kieConfig  = KIE_MODELS[model] ?? KIE_MODELS.standard
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

      for (const cfg of cascade) {
        try {
          resultBase64 = await generateWithKie(cfg, publicUrl, generationPrompt, quality, aspectRatio)
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

async function generateWithKie(cfg: KieModel, imageUrl: string, prompt: string, _quality: string, aspectRatio: string): Promise<string> {
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

async function pollForResult(taskId: string): Promise<string> {
  const DONE = new Set(["success", "completed", "finish", "succeeded", "finished"])
  const FAIL = new Set(["failed", "error", "timeout", "cancelled", "canceled"])

  for (let attempt = 0; attempt < POLL_MAX_ATTEMPTS; attempt++) {
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

interface ModerationOutcome { blocked: boolean; categories: string[] }

async function logSecurityEvent(
  admin: ReturnType<typeof createClient>,
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
async function moderate(
  prompt: string,
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<ModerationOutcome> {
  if (!OPENAI_API_KEY) return { blocked: false, categories: [] }
  const ctrl = new AbortController()
  const t = setTimeout(() => ctrl.abort(), MODERATION_TIMEOUT_MS)
  try {
    const res = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: MODERATION_MODEL, input: prompt }),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`moderation HTTP ${res.status}`)
    const json = await res.json()
    const cats = (json.results?.[0]?.categories ?? {}) as Record<string, boolean>
    const hit = BLOCK_CATEGORIES.filter((c) => cats[c] === true)
    return { blocked: hit.length > 0, categories: hit }
  } catch (e) {
    // Fail-open: do not block generation, but record the gap.
    await logSecurityEvent(admin, userId, "moderation_unavailable", String(e))
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
