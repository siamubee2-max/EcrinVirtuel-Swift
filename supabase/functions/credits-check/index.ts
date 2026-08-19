import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET" && req.method !== "POST") {
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

  // Lire item_type depuis query string ou body
  let itemType = "jewelry";
  if (req.method === "POST") {
    try {
      const body = await req.json();
      itemType = body.item_type ?? "jewelry";
    } catch { /* ignore */ }
  } else {
    itemType = new URL(req.url).searchParams.get("item_type") ?? "jewelry";
  }

  const { data: userData, error } = await supabase
    .from("users")
    .select("subscription_tier, try_on_credits_jewelry, try_on_credits_clothing, is_yearly_subscription")
    .eq("id", user.id)
    .single();

  if (error || !userData) {
    return new Response(
      JSON.stringify({ error: "User data not found" }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const credits = itemType === "clothing"
    ? (userData.try_on_credits_clothing ?? 0)
    : (userData.try_on_credits_jewelry ?? 0);

  return new Response(
    JSON.stringify({
      can_try_on: credits > 0,
      credits_jewelry: userData.try_on_credits_jewelry ?? 0,
      credits_clothing: userData.try_on_credits_clothing ?? 0,
      subscription_tier: userData.subscription_tier ?? "free",
      is_yearly: userData.is_yearly_subscription ?? false,
      requested_type: itemType,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
