// Supabase Edge Function — credit-generations
//
// Crédite le quota mensuel après un achat RevenueCat réussi, côté client iOS
// (SupabaseService.creditGenerations). Idempotent par transaction_id via la
// table credit_transactions (UNIQUE transaction_id) : un même reçu StoreKit
// rejoué ne crédite jamais deux fois.
//
// Requête  : { product_id: string, transaction_id: string }
// Réponse  : { new_total: number }
// Barème   : starter=15, premium=40, elite/founder=100 (aligné User.swift trialLimit)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!

function planForProduct(productId: string): { plan: string, credits: number } | null {
  const p = productId.toLowerCase()
  if (p.includes("elite") || p.includes("founder") || p.includes("lifetime"))
    return { plan: "elite", credits: 100 }
  if (p.includes("premium")) return { plan: "premium", credits: 40 }
  if (p.includes("starter")) return { plan: "starter", credits: 15 }
  return null
}

serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401)

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return json({ error: "unauthorized" }, 401)

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    const { product_id, transaction_id } = await req.json()
    if (typeof product_id !== "string" || typeof transaction_id !== "string" ||
        !product_id || !transaction_id || transaction_id.length > 256) {
      return json({ error: "product_id and transaction_id required" }, 400)
    }

    const mapping = planForProduct(product_id)
    if (!mapping) return json({ error: "unknown_product" }, 400)

    // Idempotence : la ligne de transaction est posée en premier ; si elle
    // existe déjà (unique_violation), le crédit a déjà été appliqué.
    const { error: txError } = await admin.from("credit_transactions").insert({
      user_id:        user.id,
      product_id,
      transaction_id,
      credits_added:  mapping.credits,
    })

    if (txError) {
      if (txError.code === "23505") {
        const { data: quota } = await admin.from("user_quotas")
          .select("generations_remaining").eq("user_id", user.id).maybeSingle()
        return json({ new_total: quota?.generations_remaining ?? 0, already_credited: true })
      }
      console.error("[credit-generations] tx insert failed:", txError)
      return json({ error: "service_unavailable" }, 503)
    }

    // Crédit + bascule de plan (upsert si première fois)
    const { data: existing } = await admin.from("user_quotas")
      .select("generations_remaining").eq("user_id", user.id).maybeSingle()

    const newTotal = (existing?.generations_remaining ?? 0) + mapping.credits
    const { error: upsertError } = await admin.from("user_quotas").upsert({
      user_id:               user.id,
      plan_type:             mapping.plan,
      generations_remaining: newTotal,
      reset_at:              new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString(),
    }, { onConflict: "user_id" })

    if (upsertError) {
      console.error("[credit-generations] quota upsert failed:", upsertError)
      return json({ error: "service_unavailable" }, 503)
    }

    return json({ new_total: newTotal })
  } catch (e) {
    console.error("[credit-generations] Unhandled error:", e)
    return json({ error: "bad_request" }, 400)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}
