// Supabase Edge Function — revenuecat-webhook
//
// Reçoit les événements serveur RevenueCat (renouvellements, expirations…)
// et synchronise user_quotas. Auth : header Authorization comparé au secret
// RC_WEBHOOK_SECRET (à configurer des deux côtés — dashboard RevenueCat →
// Webhooks → Authorization header). verify_jwt désactivé : RevenueCat
// n'envoie pas de JWT Supabase.
//
// Idempotent par event.id via credit_transactions (UNIQUE transaction_id).
// Barème : starter=15, premium=40, elite/founder=100 (aligné credit-generations).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const RC_WEBHOOK_SECRET         = Deno.env.get("RC_WEBHOOK_SECRET")

const CREDIT_EVENTS = new Set([
  "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "NON_RENEWING_PURCHASE", "UNCANCELLATION",
])
const DOWNGRADE_EVENTS = new Set(["EXPIRATION"])

function planForProduct(productId: string): { plan: string, credits: number } | null {
  const p = productId.toLowerCase()
  if (p.includes("elite") || p.includes("founder") || p.includes("lifetime"))
    return { plan: "elite", credits: 100 }
  if (p.includes("premium")) return { plan: "premium", credits: 40 }
  if (p.includes("starter")) return { plan: "starter", credits: 15 }
  return null
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

serve(async (req) => {
  if (RC_WEBHOOK_SECRET) {
    const auth = req.headers.get("Authorization") ?? ""
    if (auth !== RC_WEBHOOK_SECRET && auth !== `Bearer ${RC_WEBHOOK_SECRET}`) {
      return json({ error: "unauthorized" }, 401)
    }
  } else {
    // Sans secret configuré, refuser — ne jamais traiter un webhook non authentifié.
    console.error("[revenuecat-webhook] RC_WEBHOOK_SECRET not configured — rejecting")
    return json({ error: "webhook_secret_not_configured" }, 503)
  }

  try {
    const { event } = await req.json()
    if (!event?.type) return json({ error: "bad_payload" }, 400)

    // app_user_id = auth.uid (RevenueCatService.logIn côté iOS). Les ids
    // anonymes ($RCAnonymousID:…) ne sont pas mappables → ignorés proprement.
    const appUserId: string = event.app_user_id ?? ""
    if (!UUID_RE.test(appUserId)) return json({ ignored: "non_uuid_app_user_id" })

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    if (DOWNGRADE_EVENTS.has(event.type)) {
      await admin.from("user_quotas")
        .update({ plan_type: "free" })
        .eq("user_id", appUserId)
      return json({ ok: true, action: "downgraded" })
    }

    if (!CREDIT_EVENTS.has(event.type)) return json({ ignored: event.type })

    const productId: string = event.product_id ?? ""
    const mapping = planForProduct(productId)
    if (!mapping) return json({ ignored: "unknown_product", product_id: productId })

    // Idempotence par event.id
    const eventId: string = event.id ?? crypto.randomUUID()
    const { error: txError } = await admin.from("credit_transactions").insert({
      user_id:        appUserId,
      product_id:     productId,
      transaction_id: `rc_${eventId}`,
      credits_added:  mapping.credits,
    })
    if (txError) {
      if (txError.code === "23505") return json({ ok: true, action: "already_processed" })
      console.error("[revenuecat-webhook] tx insert failed:", txError)
      return json({ error: "service_unavailable" }, 503)
    }

    const { data: existing } = await admin.from("user_quotas")
      .select("generations_remaining").eq("user_id", appUserId).maybeSingle()
    const newTotal = (existing?.generations_remaining ?? 0) + mapping.credits

    const { error: upsertError } = await admin.from("user_quotas").upsert({
      user_id:               appUserId,
      plan_type:             mapping.plan,
      generations_remaining: newTotal,
      reset_at:              new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString(),
    }, { onConflict: "user_id" })
    if (upsertError) {
      console.error("[revenuecat-webhook] quota upsert failed:", upsertError)
      return json({ error: "service_unavailable" }, 503)
    }

    return json({ ok: true, new_total: newTotal })
  } catch (e) {
    console.error("[revenuecat-webhook] Unhandled error:", e)
    return json({ error: "bad_request" }, 400)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}
