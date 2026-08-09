import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Crédits alloués par produit RevenueCat
const PRODUCT_CONFIG: Record<string, { jewelry: number; clothing: number; tier: string; yearly: boolean }> = {
  "bijoux_monthly":  { jewelry: 100, clothing: 0,   tier: "bijoux",   yearly: false },
  "premium_monthly": { jewelry: 150, clothing: 150, tier: "premium",  yearly: false },
  "premium_yearly":  { jewelry: 150, clothing: 150, tier: "premium",  yearly: true  },
  // Packs crédits (achats consommables)
  "credits_50":  { jewelry: 50,  clothing: 0, tier: "", yearly: false },
  "credits_100": { jewelry: 100, clothing: 0, tier: "", yearly: false },
  "credits_250": { jewelry: 250, clothing: 0, tier: "", yearly: false },
  "credits_500": { jewelry: 500, clothing: 0, tier: "", yearly: false },
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // ── Vérification secret webhook — FAIL-CLOSED (correctif audit 007, C3) ───────────
  // AVANT : `if (SECRET && auth !== SECRET)`. Le secret n'étant PAS configuré en prod,
  // le test était court-circuité et la fonction acceptait n'importe quel appel anonyme
  // (pas de garde JWT non plus : un GET renvoyait 405 depuis ce code, pas 401).
  // Or elle écrit en service_role dans `users` pour un `app_user_id` ARBITRAIRE.
  // Désormais : sans secret configuré, on refuse — l'absence de config ne peut plus
  // désactiver silencieusement l'authentification.
  if (!REVENUECAT_WEBHOOK_SECRET) {
    console.error("[revenuecat-webhook] REVENUECAT_WEBHOOK_SECRET absent — refus");
    return new Response("Service Unavailable", { status: 503 });
  }
  if (!safeEqual(req.headers.get("Authorization") ?? "", REVENUECAT_WEBHOOK_SECRET)) {
    console.warn("[revenuecat-webhook] auth échouée");
    return new Response("Unauthorized", { status: 401 });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const eventData = payload?.event;
  if (!eventData) {
    return new Response(JSON.stringify({ error: "Missing event" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  const { type, app_user_id, product_id } = eventData;
  console.log(`[RevenueCat] ${type} | user: ${app_user_id} | product: ${product_id}`);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Chercher l'utilisateur (par revenuecat_app_user_id OU par id direct)
  let userId: string | null = null;
  let currentCreditsJewelry = 3;
  let currentCreditsClothing = 0;

  const { data: byRcId } = await supabase
    .from("users")
    .select("id, try_on_credits_jewelry, try_on_credits_clothing")
    .eq("revenuecat_app_user_id", app_user_id)
    .maybeSingle();

  if (byRcId) {
    userId = byRcId.id;
    currentCreditsJewelry = byRcId.try_on_credits_jewelry ?? 3;
    currentCreditsClothing = byRcId.try_on_credits_clothing ?? 0;
  } else {
    // RevenueCat utilise souvent le UID Supabase directement
    const { data: byId } = await supabase
      .from("users")
      .select("id, try_on_credits_jewelry, try_on_credits_clothing")
      .eq("id", app_user_id)
      .maybeSingle();
    if (byId) {
      userId = byId.id;
      currentCreditsJewelry = byId.try_on_credits_jewelry ?? 3;
      currentCreditsClothing = byId.try_on_credits_clothing ?? 0;
      // Enregistrer le lien RevenueCat
      await supabase.from("users").update({ revenuecat_app_user_id: app_user_id }).eq("id", userId);
    }
  }

  if (!userId) {
    console.error("User not found for app_user_id:", app_user_id);
    // On retourne 200 pour éviter les re-tentatives RevenueCat
    return new Response(JSON.stringify({ received: true, warning: "user_not_found" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const config = PRODUCT_CONFIG[product_id];

  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL": {
      if (!config) { console.warn("Unknown product:", product_id); break; }
      if (config.tier) {
        // Abonnement : reset + attribution crédits mensuels
        await supabase.from("users").update({
          subscription_tier: config.tier,
          is_yearly_subscription: config.yearly,
          try_on_credits_jewelry: config.jewelry,
          try_on_credits_clothing: config.clothing,
          revenuecat_app_user_id: app_user_id,
        }).eq("id", userId);
      } else {
        // Pack crédits : ajout aux crédits existants
        await supabase.from("users").update({
          try_on_credits_jewelry: currentCreditsJewelry + config.jewelry,
        }).eq("id", userId);
      }
      break;
    }

    case "NON_RENEWING_PURCHASE": {
      // Achat unique (pack crédits)
      if (config && !config.tier) {
        await supabase.from("users").update({
          try_on_credits_jewelry: currentCreditsJewelry + config.jewelry,
          revenuecat_app_user_id: app_user_id,
        }).eq("id", userId);
      }
      break;
    }

    case "CANCELLATION":
    case "EXPIRATION": {
      // Retour au tier free — on garde les crédits restants
      await supabase.from("users").update({
        subscription_tier: "free",
        is_yearly_subscription: false,
      }).eq("id", userId);
      break;
    }

    case "REFUND": {
      if (config && config.tier) {
        await supabase.from("users").update({
          subscription_tier: "free",
          is_yearly_subscription: false,
          try_on_credits_jewelry: 3,
          try_on_credits_clothing: 0,
        }).eq("id", userId);
      }
      break;
    }

    default:
      console.log(`Unhandled event: ${type}`);
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});

// Comparaison à temps constant — évite qu'un attaquant devine le secret octet par octet
// en mesurant le temps de réponse. Longueurs différentes → on compare quand même une
// longueur fixe pour ne pas fuiter la taille du secret.
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  const len = Math.max(ab.length, bb.length);
  let diff = ab.length ^ bb.length;
  for (let i = 0; i < len; i++) {
    diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0);
  }
  return diff === 0;
}
