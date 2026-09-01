// Supabase Edge Function — revenuecat-webhook
//
// Reçoit les événements serveur RevenueCat (renouvellements, expirations…)
// et synchronise user_quotas. Auth : header Authorization comparé au secret
// RC_WEBHOOK_SECRET (à configurer des deux côtés — dashboard RevenueCat →
// Webhooks → Authorization header). verify_jwt désactivé : RevenueCat
// n'envoie pas de JWT Supabase.
//
// Idempotent par event.id via credit_transactions (UNIQUE transaction_id).
// Barème abonnements : starter=15, premium=40, elite/founder=100.
// Barème packs consommables : voir PACK_CREDITS (aligné credit-generations + ASC).
//
// ⚠️ PRÉREQUIS : migration 012 (UNIQUE transaction_id + credit_generations_atomic)
// et secret RC_WEBHOOK_SECRET POSÉ AVANT tout `functions deploy` — la version
// déployée aujourd'hui contient un repli en dur qui disparaît avec ce fichier ;
// déployer sans le secret met la fonction en 503 et COUPE les paiements.
//
// Chaque livraison est journalisée (best-effort) dans public.webhook_deliveries
// (migration 013) pour permettre la vérification par SQL même quand l'API
// analytics des logs Supabase est indisponible.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const RC_WEBHOOK_SECRET         = Deno.env.get("RC_WEBHOOK_SECRET")

const CREDIT_EVENTS = new Set([
  "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "NON_RENEWING_PURCHASE", "UNCANCELLATION",
])
const DOWNGRADE_EVENTS = new Set(["EXPIRATION"])

// Packs consommables — le webhook est le FILET de sécurité du chemin d'octroi :
// `credit-generations` est appelée par l'app juste après l'achat, mais elle peut
// échouer (app tuée, réseau, RevenueCat pas encore propagé). Sans cette table, un
// NON_RENEWING_PURCHASE de pack tombait sur `ignored unknown_product` et l'achat
// n'était crédité NULLE PART.
//
// Totaux identiques à VALID_PACKS de credit-generations et aux libellés App Store
// Connect (70 / 150, sans bonus implicite). Les deux chemins partagent la même clé
// d'idempotence (store transaction_id) et la même RPC atomique : le second passage
// lève ALREADY_CREDITED. ⚠️ Suppose la migration 012 appliquée (contrainte UNIQUE
// + credit_generations_atomic) — sans elle, double-crédit possible.
const PACK_CREDITS: Record<string, number> = {
  // Grille du 31/08/2026. Le SERVEUR fait foi : ces nombres sont ce que
  // l'utilisatrice reçoit réellement, l'app ne fait que les afficher.
  "ecrin_credits_spark":    10,   //  2,99 € -> 0,299 €/crédit
  "ecrin_credits_eclat":    40,   // 10,99 € -> 0,275 €/crédit  (était 70 à 16,99 €)
  "ecrin_credits_diamant": 140,   // 29,99 € -> 0,214 €/crédit  (était 150)
  // Retiré de la vente : à 7,99 € pour 30 crédits (0,266 €/cr) il se plaçait
  // entre Essentiel et Éclat et cassait la décroissance du prix unitaire.
  // La correspondance reste pour créditer un achat encore en vol.
  "ecrin_credits_glow":     30,
}

function planForProduct(productId: string): { plan: string, credits: number } | null {
  const p = productId.toLowerCase()
  // Elite et Fondateur sont retirés de la vente ; la correspondance reste pour
  // honorer un abonnement encore actif plutôt que de le laisser sans crédits.
  if (p.includes("elite") || p.includes("founder") || p.includes("lifetime"))
    return { plan: "elite", credits: 100 }
  // Signature — 14,99 €/mois, 0,250 €/crédit. Portée par l'identifiant
  // `premium` conservé : changer d'identifiant App Store obligerait à recréer
  // le produit et lui ferait perdre son historique.
  if (p.includes("premium")) return { plan: "premium", credits: 60 }
  // Essentiel — 6,99 €/mois, 0,280 €/crédit. Était Starter, 15 crédits à
  // 4,99 €, soit 0,333 €/crédit : le pire tarif de tout le catalogue.
  if (p.includes("starter")) return { plan: "starter", credits: 25 }
  return null
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface DeliveryMeta {
  auth_ok: boolean
  event_type: string | null
  app_user_id: string | null
  outcome: string
}

serve(async (req) => {
  const meta: DeliveryMeta = { auth_ok: false, event_type: null, app_user_id: null, outcome: "" }
  const res = await handle(req, meta)
  // Best-effort delivery log — must never break the webhook response.
  try {
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    await admin.from("webhook_deliveries").insert({
      source:      "revenuecat",
      auth_ok:     meta.auth_ok,
      event_type:  meta.event_type,
      app_user_id: meta.app_user_id,
      outcome:     `${res.status} ${meta.outcome}`.trim(),
      user_agent:  req.headers.get("user-agent"),
    })
  } catch (e) {
    console.error("[revenuecat-webhook] delivery log failed:", e)
  }
  return res
})

async function handle(req: Request, meta: DeliveryMeta): Promise<Response> {
  if (RC_WEBHOOK_SECRET) {
    const auth = req.headers.get("Authorization") ?? ""
    if (auth !== RC_WEBHOOK_SECRET && auth !== `Bearer ${RC_WEBHOOK_SECRET}`) {
      meta.outcome = "unauthorized"
      return json({ error: "unauthorized" }, 401)
    }
    meta.auth_ok = true
  } else {
    // Sans secret configuré, refuser — ne jamais traiter un webhook non authentifié.
    console.error("[revenuecat-webhook] RC_WEBHOOK_SECRET not configured — rejecting")
    meta.outcome = "webhook_secret_not_configured"
    return json({ error: "webhook_secret_not_configured" }, 503)
  }

  try {
    const { event } = await req.json()
    if (!event?.type) {
      meta.outcome = "bad_payload"
      return json({ error: "bad_payload" }, 400)
    }
    meta.event_type = event.type

    // app_user_id = auth.uid (RevenueCatService.logIn côté iOS). Les ids
    // anonymes ($RCAnonymousID:…) ne sont pas mappables → ignorés proprement.
    const appUserId: string = event.app_user_id ?? ""
    meta.app_user_id = appUserId || null
    if (!UUID_RE.test(appUserId)) {
      meta.outcome = "ignored non_uuid_app_user_id"
      return json({ ignored: "non_uuid_app_user_id" })
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    if (DOWNGRADE_EVENTS.has(event.type)) {
      await admin.from("user_quotas")
        .update({ plan_type: "free" })
        .eq("user_id", appUserId)
      meta.outcome = "downgraded"
      return json({ ok: true, action: "downgraded" })
    }

    if (!CREDIT_EVENTS.has(event.type)) {
      meta.outcome = `ignored ${event.type}`
      return json({ ignored: event.type })
    }

    const productId: string = event.product_id ?? ""

    // Idempotence : clé = transaction_id du store quand RevenueCat le fournit,
    // pour partager la même clé que credit-generations (appelée par l'app avec
    // le transaction_id StoreKit brut) — sinon un même achat serait crédité
    // deux fois (une fois par chemin). Repli : rc_<event.id>.
    const storeTxId = typeof event.transaction_id === "string" && event.transaction_id
      ? event.transaction_id : null
    const eventId: string = event.id ?? crypto.randomUUID()
    const txId = storeTxId ?? `rc_${eventId}`

    // ── Pack consommable : octroi atomique, sans toucher au plan_type ──────────
    const packCredits = PACK_CREDITS[productId]
    if (packCredits) {
      const { data: newTotal, error: packError } = await admin.rpc("credit_generations_atomic", {
        p_user_id:        appUserId,
        p_product_id:     productId,
        p_transaction_id: txId,
        p_credits:        packCredits,
      })
      if (packError) {
        if (packError.message?.includes("ALREADY_CREDITED")) {
          meta.outcome = "already_processed"
          return json({ ok: true, action: "already_processed" })
        }
        console.error("[revenuecat-webhook] credit_generations_atomic:", packError)
        meta.outcome = "pack_credit_failed"
        return json({ error: "service_unavailable" }, 503)
      }
      meta.outcome = `credited pack ${packCredits}`
      return json({ ok: true, new_total: newTotal })
    }

    const mapping = planForProduct(productId)
    if (!mapping) {
      meta.outcome = `ignored unknown_product ${productId}`
      return json({ ignored: "unknown_product", product_id: productId })
    }

    // ── Abonnement : octroi ATOMIQUE (migration 016) ─────────────────────────
    // L'ancien chemin faisait insert registre PUIS select+upsert du solde :
    // un échec entre les deux + le retry RevenueCat donnait « already_processed »
    // sans crédit (l'insert tombait sur l'UNIQUE), et le select+upsert était une
    // course avec les packs et consume_credits. Registre, solde, plan_type et
    // reset_at vivent désormais dans UNE transaction Postgres.
    const { data: newTotal, error: subError } = await admin.rpc("credit_subscription_atomic", {
      p_user_id:        appUserId,
      p_product_id:     productId,
      p_transaction_id: txId,
      p_credits:        mapping.credits,
      p_plan:           mapping.plan,
    })
    if (subError) {
      if (subError.message?.includes("ALREADY_CREDITED")) {
        meta.outcome = "already_processed"
        return json({ ok: true, action: "already_processed" })
      }
      console.error("[revenuecat-webhook] credit_subscription_atomic:", subError)
      meta.outcome = "sub_credit_failed"
      return json({ error: "service_unavailable" }, 503)
    }

    meta.outcome = `credited ${mapping.credits}`
    return json({ ok: true, new_total: newTotal })
  } catch (e) {
    console.error("[revenuecat-webhook] Unhandled error:", e)
    meta.outcome = "unhandled_error"
    return json({ error: "bad_request" }, 400)
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}
