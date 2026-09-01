// Supabase Edge Function — styliste-chat
//
// Assistant styliste conversationnel de L'Écrin Virtuel. Appelé par
// SupabaseService.chatWithStyliste(history:context:).
//
// Requête  : { messages: [{ role: "user"|"assistant", content: string }], context: string }
// Réponse  : { reply: string }
// Fournisseurs : OpenAI gpt-4o-mini si OPENAI_API_KEY, sinon Gemini 2.0 Flash.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const OPENAI_API_KEY    = Deno.env.get("OPENAI_API_KEY")
const GOOGLE_API_KEY    = Deno.env.get("GOOGLE_API_KEY")

const MAX_MESSAGES     = 40
// Plafond quotidien par utilisateur. Sans lui, un seul JWT valide (3 essais
// gratuits suffisent à en obtenir un) pouvait boucler sans limite sur un
// endpoint LLM facturé. 100/jour est loin au-dessus de tout usage réel de
// conseil mode, et loin en dessous d'un abus de scripting.
const MAX_CHAT_PER_DAY = 100
const MAX_CONTENT_LEN  = 4_000

const SYSTEM_PROMPT = `Tu es la styliste personnelle de L'Écrin Virtuel, une application
iOS d'essayage virtuel de bijoux et de vêtements. Tu conseilles avec chaleur et
expertise : accords bijoux/tenues, morphologie, couleurs, occasions (mariage,
soirée, bureau), tendances. Réponds dans la langue de l'utilisateur (français
par défaut), de manière concise (2-4 phrases), concrète et bienveillante.
Tu peux t'appuyer sur le contexte fourni (garde-robe, météo, préférences).`

serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401)

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return json({ error: "unauthorized" }, 401)

  // Limitation de débit (migration 017) : compteur quotidien atomique.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
  const { error: rateError } = await admin.rpc("increment_chat_usage", {
    p_user_id: user.id,
    p_max:     MAX_CHAT_PER_DAY,
  })
  if (rateError) {
    if (rateError.message?.includes("RATE_LIMITED")) return json({ error: "rate_limited" }, 429)
    // Compteur indisponible ≠ chat interdit : on laisse passer mais on trace.
    console.error("[styliste-chat] rate limit check failed:", rateError)
  }

  try {
    const { messages, context } = await req.json()
    if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
      return json({ error: "messages required" }, 400)
    }
    const history = messages
      .filter((m: Record<string, unknown>) =>
        (m.role === "user" || m.role === "assistant") &&
        typeof m.content === "string" && m.content.length <= MAX_CONTENT_LEN)
      .map((m: Record<string, string>) => ({ role: m.role, content: m.content }))
    if (history.length === 0) return json({ error: "messages required" }, 400)

    const ctx = typeof context === "string" ? context.slice(0, MAX_CONTENT_LEN) : ""
    const system = ctx ? `${SYSTEM_PROMPT}\n\nCONTEXTE UTILISATEUR :\n${ctx}` : SYSTEM_PROMPT

    let reply: string | null = null
    const errors: string[] = []

    if (OPENAI_API_KEY) {
      try { reply = await chatOpenAI(system, history) }
      catch (e) { errors.push(`OpenAI: ${String(e)}`) }
    }
    if (!reply && GOOGLE_API_KEY) {
      try { reply = await chatGemini(system, history) }
      catch (e) { errors.push(`Gemini: ${String(e)}`) }
    }

    if (!reply) {
      console.error("[styliste-chat] all providers failed:", errors)
      return json({ error: "service_unavailable" }, 503)
    }
    return json({ reply })
  } catch (e) {
    console.error("[styliste-chat] Unhandled error:", e)
    return json({ error: "bad_request" }, 400)
  }
})

async function chatOpenAI(system: string, history: { role: string, content: string }[]): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type":  "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [{ role: "system", content: system }, ...history],
      max_tokens: 500,
      temperature: 0.7,
    }),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  const jsonRes = await res.json()
  const reply = jsonRes.choices?.[0]?.message?.content
  if (!reply) throw new Error("no reply in response")
  return reply
}

async function chatGemini(system: string, history: { role: string, content: string }[]): Promise<string> {
  const contents = history.map(m => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }))
  const res = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GOOGLE_API_KEY! },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
        generationConfig: { maxOutputTokens: 500, temperature: 0.7 },
      }),
    }
  )
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  const jsonRes = await res.json()
  const reply = jsonRes.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("")
  if (!reply) throw new Error("no reply in response")
  return reply
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}
