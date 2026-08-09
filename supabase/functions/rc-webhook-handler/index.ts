import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "jsr:@supabase/supabase-js@2"

const WEBHOOK_SECRET = Deno.env.get("RC_WEBHOOK_SECRET") ?? ""

const CRITICAL_EVENTS = new Set([
  "BILLING_ISSUE",
  "CANCELLATION",
  "EXPIRATION",
  "REFUND",
  "SUBSCRIPTION_PAUSED",
])

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 })
  }

  // ── Secret partagé — FAIL-CLOSED (correctif audit 007, C3) ──────────────────────
  // AVANT : `if (WEBHOOK_SECRET) { ... }`. Le secret RC_WEBHOOK_SECRET n'étant pas
  // configuré en prod, le contrôle était entièrement sauté et la fonction acceptait
  // n'importe quel appel anonyme (aucune garde JWT : GET → 405 depuis ce code).
  // Effet limité — elle n'écrit que dans monitoring_events — mais cela permettait
  // d'inonder la table de supervision (bruit, coût, masquage d'alertes réelles).
  if (!WEBHOOK_SECRET) {
    console.error("[rc-webhook-handler] RC_WEBHOOK_SECRET absent — refus")
    return new Response("Service Unavailable", { status: 503 })
  }
  if (!safeEqual(req.headers.get("Authorization") ?? "", WEBHOOK_SECRET)) {
    return new Response("Unauthorized", { status: 401 })
  }

  let payload: Record<string, unknown>
  try {
    payload = await req.json()
  } catch {
    return new Response("Bad Request", { status: 400 })
  }

  const evt = payload.event as Record<string, unknown> | undefined
  if (!evt) {
    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
    })
  }

  const eventType  = String(evt.type ?? "UNKNOWN")
  const productId  = String(evt.product_id ?? "")
  const userId     = String(evt.app_user_id ?? "")
  const store      = String(evt.store ?? "")
  const currency   = String(evt.currency ?? "")
  const price      = evt.price ?? null
  const isCritical = CRITICAL_EVENTS.has(eventType)

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  // Log to monitoring_events
  const { error } = await supabase.from("monitoring_events").insert({
    event_type:    `rc_${eventType.toLowerCase()}`,
    product_id:    productId || null,
    error_domain:  "RevenueCat",
    error_code:    isCritical ? 1 : 0,
    error_message: JSON.stringify({ user_id: userId, store, currency, price }),
    platform:      "revenuecat",
  })

  if (error) console.error("monitoring_events insert error:", error.message)

  if (isCritical) {
    console.error(`[ALERT] RC ${eventType} — user=${userId} product=${productId}`)
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  })
})

// Comparaison à temps constant — voir revenuecat-webhook/index.ts.
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const ab = enc.encode(a)
  const bb = enc.encode(b)
  const len = Math.max(ab.length, bb.length)
  let diff = ab.length ^ bb.length
  for (let i = 0; i < len; i++) {
    diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0)
  }
  return diff === 0
}
