// Supabase Edge Function — suppression définitive du compte utilisateur (v2)
// Cascade explicite des données user-owned (RGPD) AVANT la suppression du compte auth.
// Les tables prod n'ont pas toutes de FK ON DELETE CASCADE vers auth.users, donc
// auth.admin.deleteUser seul laissait des données orphelines. Voir 009_prod_baseline.sql.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS })
  }

  // Vérifier le JWT de l'appelant
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json", ...CORS }
    })
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json", ...CORS }
    })
  }

  // Vérifier que l'userId dans le body correspond bien à l'utilisateur authentifié
  const { user_id } = await req.json()
  if (user_id !== user.id) {
    return new Response(JSON.stringify({ error: "forbidden" }), {
      status: 403, headers: { "Content-Type": "application/json", ...CORS }
    })
  }

  try {
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // User-owned tables (table, owning column) — from 009_prod_baseline.sql.
    const OWNED: Array<[string, string]> = [
      ["try_on_results", "user_id"],
      ["wardrobe_items", "user_id"],
      ["jewelry_items", "user_id"],
      ["outfit_presets", "user_id"],
      ["post_comments", "user_id"],
      ["post_likes", "user_id"],
      ["post_reports", "reporter_id"],
      ["community_posts", "user_id"],
      ["credit_transactions", "user_id"],
      ["user_quotas", "user_id"],
    ]

    const failures: string[] = []
    const deleted: Record<string, boolean> = {}

    // messages first (FK via conversations), then conversations.
    try {
      const { data: convs } = await adminClient
        .from("conversations").select("id").eq("user_id", user.id)
      const convIds = (convs ?? []).map((c: { id: string }) => c.id)
      if (convIds.length > 0) {
        const { error } = await adminClient.from("messages").delete().in("conversation_id", convIds)
        if (error) failures.push(`messages: ${error.message}`)
      }
      const { error: convErr } = await adminClient.from("conversations").delete().eq("user_id", user.id)
      if (convErr) failures.push(`conversations: ${convErr.message}`)
      else deleted["conversations"] = true
    } catch (e) { failures.push(`conversations/messages: ${String(e)}`) }

    for (const [table, col] of OWNED) {
      const { error } = await adminClient.from(table).delete().eq(col, user.id)
      if (error) failures.push(`${table}: ${error.message}`)
      else deleted[table] = true
    }

    // Profile row (users.id == auth.uid()).
    {
      const { error } = await adminClient.from("users").delete().eq("id", user.id)
      if (error) failures.push(`users: ${error.message}`)
      else deleted["users"] = true
    }

    if (failures.length > 0) {
      // Do NOT delete the auth user while data remains — RGPD must be complete.
      console.error("[delete-user-account] partial delete:", failures)
      return new Response(JSON.stringify({ error: "partial_delete", failures }), {
        status: 500, headers: { "Content-Type": "application/json", ...CORS }
      })
    }

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id)
    if (deleteError) {
      return new Response(JSON.stringify({ error: "delete_failed", details: deleteError.message }), {
        status: 500, headers: { "Content-Type": "application/json", ...CORS }
      })
    }

    return new Response(JSON.stringify({ success: true, deleted }), {
      status: 200, headers: { "Content-Type": "application/json", ...CORS }
    })

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { "Content-Type": "application/json", ...CORS }
    })
  }
})
