// Supabase Edge Function — crédit d'essais après achat consommable RevenueCat (v10)
//
// ⚠️ PRÉREQUIS DE DÉPLOIEMENT (dans cet ordre, sinon la fonction est inopérante) :
//    1. migration 012 appliquée  → fournit la RPC `credit_generations_atomic`
//    2. secrets posés            → REVENUECAT_SECRET_KEY (obligatoire, fail-closed 503),
//                                  REVENUECAT_PROJECT_ID,
//                                  ALLOW_SANDBOX_PURCHASES=true tant que TestFlight /
//                                  App Review achètent en sandbox (sinon 402 sur un
//                                  achat de revue parfaitement légitime)
//    3. `supabase functions deploy credit-generations`
//
// ─── Ce que corrige cette version ────────────────────────────────────────────────
// C1 (CRITIQUE) — la v9 n'avait AUCUNE vérification d'achat : `transaction_id` venait
//   du client et n'était jamais confronté à Apple ni à RevenueCat. Un compte gratuit
//   pouvait poster un transaction_id arbitraire et se créditer sans fin.
//   → On interroge maintenant l'API RevenueCat, qui a elle-même validé le reçu Apple.
//
// C2 (CRITIQUE) — idempotence applicative racée (SELECT-puis-INSERT), solde en
//   read-modify-write, registre écrit après l'octroi et sans contrôle d'erreur.
//   → Tout est délégué à `credit_generations_atomic` (migration 012) : registre
//     d'abord, contrainte UNIQUE comme garantie, une seule transaction Postgres.
//
// ─── Principe de confiance ───────────────────────────────────────────────────────
// L'app_user_id interrogé auprès de RevenueCat est TOUJOURS `user.id` issu du JWT
// vérifié — jamais une valeur du corps de requête. Sans cela, un attaquant pourrait
// faire valider l'achat d'un autre utilisateur pour se créditer lui-même.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!

// Clé secrète RevenueCat v2 (Dashboard → API keys → Secret API keys). OBLIGATOIRE.
// Permissions requises sur la clé :
//   • customer_information:purchases:read   (lire les achats d'un client)
//   • project_configuration:products:read   (résoudre product_id → store_identifier)
const REVENUECAT_SECRET_KEY = Deno.env.get("REVENUECAT_SECRET_KEY") ?? ""
// Identifiant projet AU FORMAT v2 (Project Settings → Project ID), pas le slug d'URL.
const RC_PROJECT_ID = Deno.env.get("REVENUECAT_PROJECT_ID") ?? "projc8c287c3"
// Autoriser les achats sandbox (TestFlight / Xcode). Défaut : NON en production.
const ALLOW_SANDBOX = (Deno.env.get("ALLOW_SANDBOX_PURCHASES") ?? "false") === "true"

// ⚠️ API v2 — les clés secrètes émises aujourd'hui par RevenueCat sont v2, et la doc est
// explicite : « v1 API keys are not compatible with v2 [...] generate new v2 secret keys ».
// Viser /v1/subscribers avec une clé v2 exposait à un 401 permanent — donc, la fonction
// étant fail-closed, à ne créditer AUCUN achat légitime. On cible donc v2 directement.
const RC_API_BASE      = "https://api.revenuecat.com/v2"
const RC_TIMEOUT_MS    = 8_000
const MAX_ID_CHARS     = 256
// L'app appelle cette fonction immédiatement après l'achat ; RevenueCat n'a parfois pas
// encore ingéré la transaction. Sans tolérance, un achat LÉGITIME serait refusé et
// l'utilisateur aurait payé Apple pour rien. On retente uniquement les motifs de
// propagation (jamais un refus ferme), en restant loin du budget Edge (~150 s).
const RC_PROPAGATION_RETRIES  = 3
const RC_RETRY_DELAY_MS       = 2_000
const RETRYABLE_REASONS = new Set([
  "subscriber_unknown",
  "no_purchase_for_product",
  "transaction_not_found",
])

// CORS restreint (aligné sur tryon-generate — la v9 laissait "*").
const CORS = {
  "Access-Control-Allow-Origin": "https://ecrin.app",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

// Barème serveur — le nombre de crédits ne vient JAMAIS du client.
// IDs = ceux réellement créés dans App Store Connect (docs/appstore/2026-06-22-asc-iap-setup-RESULT.md)
// et vendus par l'app (Sources/Features/Credits/CreditsPack.swift). Les anciens
// `ecrin_credits_10/30/100` n'existaient dans AUCUN store : les 4 packs réels
// tombaient donc sur `unknown_product` (400) — achat encaissé, crédits jamais accordés.
// Totaux = EXACTEMENT le nombre annoncé par le produit App Store Connect
// (« 70 crédits », « 150 crédits ») : c'est ce que l'acheteur lit sur la feuille
// de confirmation Apple. Aucun bonus implicite ici.
const VALID_PACKS: Record<string, number> = {
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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS })
  if (req.method !== "POST")    return jsonError("method_not_allowed", 405)

  // Fail-closed : sans clé RevenueCat, on ne peut pas vérifier l'achat → on ne crédite pas.
  // (Inversion volontaire du patron `if (SECRET)` des webhooks, qui se désactivait tout seul.)
  if (!REVENUECAT_SECRET_KEY) {
    console.error("[credit-generations] REVENUECAT_SECRET_KEY absente — refus de créditer")
    return jsonError("service_unavailable", 503)
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return jsonError("unauthorized", 401)

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return jsonError("unauthorized", 401)

  try {
    const { product_id, transaction_id } = await req.json()

    if (typeof product_id !== "string" || typeof transaction_id !== "string" ||
        !product_id || !transaction_id ||
        product_id.length > MAX_ID_CHARS || transaction_id.length > MAX_ID_CHARS) {
      return jsonError("product_id and transaction_id required", 400)
    }

    const creditsToAdd = VALID_PACKS[product_id]
    if (!creditsToAdd) return jsonError("unknown_product", 400)

    // ── Vérification de l'achat auprès de RevenueCat ────────────────────────────
    // app_user_id = user.id (JWT), jamais une valeur du corps de requête.
    const verdict = await verifyPurchaseWithRetry(user.id, product_id, transaction_id)
    if (!verdict.ok) {
      console.warn(`[credit-generations] achat refusé user=${user.id} produit=${product_id} motif=${verdict.reason}`)
      // Message volontairement opaque : ne pas indiquer à un attaquant ce qui a échoué.
      return jsonError("purchase_not_verified", 402)
    }

    // ── Octroi atomique (migration 012) ─────────────────────────────────────────
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: newTotal, error: rpcError } = await adminClient.rpc("credit_generations_atomic", {
      p_user_id:        user.id,
      p_product_id:     product_id,
      p_transaction_id: transaction_id,
      p_credits:        creditsToAdd,
    })

    if (rpcError) {
      if (rpcError.message?.includes("ALREADY_CREDITED")) {
        return jsonError("already_credited", 409)
      }
      console.error("[credit-generations] credit_generations_atomic:", rpcError)
      return jsonError("service_unavailable", 503)
    }

    return new Response(JSON.stringify({
      success: true,
      credits_added: creditsToAdd,
      new_total: newTotal,
    }), { status: 200, headers: { "Content-Type": "application/json", ...CORS } })

  } catch (e) {
    // Détail côté serveur uniquement — la v9 renvoyait String(e) au client.
    console.error("[credit-generations] erreur non gérée:", e)
    return jsonError("service_unavailable", 503)
  }
})

// ─── Vérification RevenueCat ───────────────────────────────────────────────────
// RevenueCat a déjà validé le reçu auprès d'Apple. On confirme simplement que CE
// compte possède bien CET achat non-renouvelable pour CE produit.
//
// Réponse : subscriber.non_subscriptions[product_id] = [{ id, store_transaction_id,
//           purchase_date, store, is_sandbox }, ...]

interface Verdict { ok: boolean; reason: string }

// Enveloppe de reprise : ne retente QUE les motifs de propagation (achat pas encore
// visible côté RevenueCat). Un refus ferme — sandbox rejeté, HTTP 4xx d'authentification —
// n'est jamais retenté : ce serait masquer un vrai refus derrière de la latence.
async function verifyPurchaseWithRetry(
  appUserId: string,
  productId: string,
  transactionId: string,
): Promise<Verdict> {
  let last: Verdict = { ok: false, reason: "not_attempted" }

  for (let attempt = 0; attempt <= RC_PROPAGATION_RETRIES; attempt++) {
    if (attempt > 0) await sleep(RC_RETRY_DELAY_MS)
    last = await verifyPurchase(appUserId, productId, transactionId)
    if (last.ok) return last
    if (!RETRYABLE_REASONS.has(last.reason)) return last
  }
  return last
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function verifyPurchase(
  appUserId: string,
  productId: string,
  transactionId: string,
): Promise<Verdict> {
  // ── 1) Les achats de CE client (customer_id = app_user_id = user.id du JWT) ────
  const purchasesUrl =
    `${RC_API_BASE}/projects/${encodeURIComponent(RC_PROJECT_ID)}` +
    `/customers/${encodeURIComponent(appUserId)}/purchases?limit=50`

  const purchases = await rcGet(purchasesUrl)
  if (!purchases.ok) return { ok: false, reason: purchases.reason }

  const items = purchases.json?.items
  if (!Array.isArray(items) || items.length === 0) {
    return { ok: false, reason: "no_purchase_for_product" }
  }

  // ── 2) Retrouver l'achat par l'identifiant de transaction du store ────────────
  // Comparaison en chaîne : le champ est numérique chez certains stores.
  const match = items.find(
    (p: Record<string, unknown>) => String(p?.store_purchase_identifier) === transactionId,
  )
  if (!match) return { ok: false, reason: "transaction_not_found" }

  // ── 3) L'achat doit être détenu, et non remboursé/révoqué ─────────────────────
  if (match.status !== "owned") {
    return { ok: false, reason: `purchase_status_${String(match.status)}` }
  }

  if (match.environment !== "production" && !ALLOW_SANDBOX) {
    return { ok: false, reason: "sandbox_purchase_rejected" }
  }

  // ── 4) L'achat doit porter sur le produit RÉCLAMÉ ─────────────────────────────
  // Indispensable : sans ce contrôle, la transaction d'un pack à 2,99 € permettrait
  // de réclamer les 120 crédits du pack à 29,99 €. En v2, `product_id` est l'ID
  // interne RevenueCat — il faut le résoudre pour obtenir le `store_identifier`.
  const rcProductId = match.product_id
  if (typeof rcProductId !== "string" || !rcProductId) {
    return { ok: false, reason: "purchase_without_product" }
  }

  const product = await rcGet(
    `${RC_API_BASE}/projects/${encodeURIComponent(RC_PROJECT_ID)}` +
    `/products/${encodeURIComponent(rcProductId)}`,
  )
  if (!product.ok) return { ok: false, reason: `product_lookup: ${product.reason}` }

  if (product.json?.store_identifier !== productId) {
    return { ok: false, reason: "product_mismatch" }
  }

  return { ok: true, reason: "verified" }
}

interface RcResult { ok: boolean; reason: string; json?: Record<string, unknown> }

// Toute erreur réseau/HTTP est un ÉCHEC de vérification, jamais un laissez-passer :
// une indisponibilité RevenueCat ne vaut pas preuve d'achat.
async function rcGet(url: string): Promise<RcResult> {
  let res: Response
  try {
    res = await fetch(url, {
      headers: { "Authorization": `Bearer ${REVENUECAT_SECRET_KEY}` },
      signal:  AbortSignal.timeout(RC_TIMEOUT_MS),
    })
  } catch (e) {
    return { ok: false, reason: `rc_unreachable: ${String(e)}` }
  }

  if (res.status === 404) return { ok: false, reason: "subscriber_unknown" }
  // 401/403 = clé invalide ou permission manquante sur la clé → à corriger côté config,
  // surtout pas à contourner. Tracé côté serveur par l'appelant.
  if (!res.ok)            return { ok: false, reason: `rc_http_${res.status}` }

  const json = await res.json().catch(() => null)
  if (!json) return { ok: false, reason: "rc_bad_json" }
  return { ok: true, reason: "ok", json }
}

function jsonError(msg: string, status: number): Response {
  return new Response(JSON.stringify({ error: msg }), {
    status, headers: { "Content-Type": "application/json", ...CORS },
  })
}
