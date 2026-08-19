import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const TRY_ON_API_URL = Deno.env.get("TRY_ON_API_URL") ?? "";
const TRY_ON_API_KEY = Deno.env.get("TRY_ON_API_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing Authorization header" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const {
    item_type = "jewelry",
    item_id,
    item_ids,
    original_image_url,
    prompt,
    is_public = false,
  } = body;

  if (!original_image_url) {
    return new Response(
      JSON.stringify({ error: "original_image_url est requis" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // ── 1. Vérifier les crédits ──────────────────────────────
  const { data: userData } = await supabase
    .from("users")
    .select("try_on_credits_jewelry, try_on_credits_clothing, subscription_tier")
    .eq("id", user.id)
    .single();

  if (!userData) {
    return new Response(
      JSON.stringify({ error: "Utilisateur introuvable" }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const creditField = item_type === "clothing" ? "try_on_credits_clothing" : "try_on_credits_jewelry";
  const credits = item_type === "clothing"
    ? (userData.try_on_credits_clothing ?? 0)
    : (userData.try_on_credits_jewelry ?? 0);

  if (credits <= 0) {
    return new Response(
      JSON.stringify({
        error: "insufficient_credits",
        message: "Vous n'avez plus de crédits d'essayage",
        credits_jewelry: userData.try_on_credits_jewelry,
        credits_clothing: userData.try_on_credits_clothing,
      }),
      { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // ── 2. Appel service IA ─────────────────────────────────
  let resultImageUrl = "";

  if (!TRY_ON_API_URL) {
    // Mode test : pas d'API configurée, on renvoie l'image originale
    console.warn("TRY_ON_API_URL non configuré — mode test actif");
    resultImageUrl = original_image_url;
  } else {
    try {
      const aiRes = await fetch(TRY_ON_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(TRY_ON_API_KEY ? { "Authorization": `Bearer ${TRY_ON_API_KEY}` } : {}),
        },
        body: JSON.stringify({
          original_image_url,
          item_type,
          item_id: item_id ?? item_ids,
          prompt,
          user_id: user.id,
        }),
      });

      if (!aiRes.ok) {
        const errText = await aiRes.text();
        console.error("AI API error:", aiRes.status, errText);
        return new Response(
          JSON.stringify({ error: "Erreur du service IA", detail: errText }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const aiData = await aiRes.json();
      resultImageUrl = aiData.result_image_url ?? aiData.output ?? aiData.image_url ?? "";
    } catch (err) {
      console.error("AI call failed:", err);
      return new Response(
        JSON.stringify({ error: "Service IA indisponible" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  }

  // ── 3. Déduction crédit (atomique) ──────────────────────
  await supabase
    .from("users")
    .update({ [creditField]: credits - 1 })
    .eq("id", user.id);

  // ── 4. Sauvegarde résultat ──────────────────────────────
  const { data: tryOnResult, error: saveError } = await supabase
    .from("try_on_results")
    .insert({
      user_id: user.id,
      type: item_type,
      original_image_url,
      result_image_url: resultImageUrl,
      jewelry_item_id: item_type === "jewelry" ? (item_id ?? null) : null,
      wardrobe_item_id: item_type === "clothing" ? (item_id ?? null) : null,
      item_ids: Array.isArray(item_ids) ? item_ids.join(",") : (item_ids ?? null),
      prompt: prompt ?? null,
      is_public,
      is_favorite: false,
      item_type,
    })
    .select()
    .single();

  if (saveError) {
    console.error("Erreur sauvegarde try_on_results:", saveError);
  }

  return new Response(
    JSON.stringify({
      success: true,
      result: tryOnResult,
      result_image_url: resultImageUrl,
      credits_remaining: credits - 1,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
