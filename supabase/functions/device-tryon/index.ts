import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Harmonisé avec la promesse onboarding « 3 essais offerts » et le trigger
// handle_new_user (try_on_credits_jewelry = 3).
const MAX_FREE_TRYONS = 3;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const { device_fingerprint, action = "check" } = body;

  if (!device_fingerprint || typeof device_fingerprint !== "string") {
    return new Response(
      JSON.stringify({ error: "device_fingerprint requis" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Upsert — crée l'entrée si elle n'existe pas
  await supabase.from("device_tryons").upsert(
    { device_fingerprint, try_on_count: 0, max_free_tryons: MAX_FREE_TRYONS },
    { onConflict: "device_fingerprint", ignoreDuplicates: true }
  );

  // Lire l'état actuel
  const { data: record, error } = await supabase
    .from("device_tryons")
    .select("try_on_count, max_free_tryons, last_try_on_at")
    .eq("device_fingerprint", device_fingerprint)
    .single();

  if (error || !record) {
    return new Response(
      JSON.stringify({ error: "Impossible de récupérer les données" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const canTryOn = record.try_on_count < record.max_free_tryons;
  const remaining = Math.max(0, record.max_free_tryons - record.try_on_count);

  // Si action = "consume" et que l'essai est possible → décrémenter
  if (action === "consume" && canTryOn) {
    await supabase
      .from("device_tryons")
      .update({
        try_on_count: record.try_on_count + 1,
        last_try_on_at: new Date().toISOString(),
      })
      .eq("device_fingerprint", device_fingerprint);
  }

  return new Response(
    JSON.stringify({
      can_try_on: canTryOn,
      try_on_count: record.try_on_count,
      max_free_tryons: record.max_free_tryons,
      remaining: action === "consume" && canTryOn ? remaining - 1 : remaining,
      consumed: action === "consume" && canTryOn,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
