// Supabase Edge Function — delete-user-account
//
// Suppression complète du compte (Apple Guideline 5.1.1(v)). Appelée par
// SupabaseService.deleteAccount() avec { user_id }. L'appelant ne peut
// supprimer QUE son propre compte (user_id doit matcher le JWT).
//
// La suppression auth.users cascade via FK :
//   users.auth_id → users (puis community_posts, wardrobe_items, … via users.id)
//   user_quotas.user_id, credit_transactions.user_id → purgés directement.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY")!

serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401)

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: authError } = await userClient.auth.getUser()
  if (authError || !user) return json({ error: "unauthorized" }, 401)

  try {
    const { user_id } = await req.json().catch(() => ({}))
    // Seul son propre compte est supprimable — le body sert de confirmation.
    if (user_id && user_id.toLowerCase() !== user.id.toLowerCase()) {
      return json({ error: "forbidden" }, 403)
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Purge préalable des lignes publiques sans FK cascade sur auth.users
    // (users.id est un varchar indépendant — la cascade passe par auth_id).
    await admin.from("users").delete().eq("id", user.id)

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
    if (deleteError) {
      console.error("[delete-user-account] deleteUser failed:", deleteError)
      return json({ error: "deletion_failed" }, 500)
    }

    return json({ success: true })
  } catch (e) {
    console.error("[delete-user-account] Unhandled error:", e)
    return json({ error: "deletion_failed" }, 500)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" }
  })
}
