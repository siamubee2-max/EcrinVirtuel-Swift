# M1 — Sécurité Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
>
> **Execution note:** Steps marked **[CONTROLLER/MCP]** must be run by the controller (Supabase MCP is session-auth-bound; subagents cannot reach it). Steps marked **[SUBAGENT]** are pure file authoring and can be delegated. Each task interleaves authoring (subagent) with deploy/verify (controller).

**Goal:** Harden the live `tryon-generate` and `delete-user-account` Edge Functions (content moderation, signed temp URLs, RGPD cascade delete), privatize the `tryon-temp` bucket, and remove the founder email list from the iOS binary — deployed to prod via MCP with a capture→smoke-test→cutover sequence.

**Architecture:** Edit the captured-live Edge sources (not the stale repo copies). Insert a `moderate()` step before quota consumption (fail-open with 3s timeout + logging); replace `getPublicUrl` with `createSignedUrl(120)`; pin Deno imports. Rewrite `delete-user-account` to cascade-delete user-owned rows via service_role before deleting the auth user. iOS derives founder/unlimited status from the server instead of a hardcoded email list.

**Tech Stack:** Supabase Edge Functions (Deno/TypeScript), Supabase MCP (`get_edge_function`, `deploy_edge_function`, `apply_migration`, `execute_sql`, `get_advisors`), Swift 6 / SwiftUI, xcodebuild.

## Global Constraints

- Backend project: `itjtshfzpknlzownpwte`. Bucket: `tryon-temp`.
- Moderation: OpenAI `omni-moderation-latest`, **3s timeout, fail-open + logged** (`monitoring_events`).
- Signed URL TTL: **120 seconds**.
- Founder emails server-side stay the source of truth; **no founder email list in the IPA**.
- Cutover order: capture live → deploy v22 (bucket public) → smoke-test (founder generation) → migration 010 (bucket private) → re-smoke-test → delete-v2.
- Rollback = redeploy the captured archive + set bucket public.
- iOS build/test ONLY via `xcodebuild` (never `swift build`); simulator `iPhone 17`.
- Work on branch `m1-security-phase1` (NOT main). Commit per task.
- `verify_jwt: true` on both functions (unchanged).

---

### Task 1: Capture live Edge sources (rollback archive) — [CONTROLLER/MCP]

**Files:**
- Create: `supabase/functions/tryon-generate/index.live-20260621.ts`
- Create: `supabase/functions/delete-user-account/index.live-20260621.ts`

- [ ] **Step 1:** `get_edge_function tryon-generate` and `get_edge_function delete-user-account`; write each returned `files[0].content` verbatim into the archive paths above. (These already match what the controller fetched while planning — versions tryon-generate v21, delete-user-account v5.)
- [ ] **Step 2:** Commit.
```bash
git add supabase/functions/tryon-generate/index.live-20260621.ts supabase/functions/delete-user-account/index.live-20260621.ts
git commit -m "chore(m1): archive live tryon-generate v21 + delete-user-account v5 (rollback point)"
```

---

### Task 2: `tryon-generate` v22 — moderation + signed URL + pinning — [SUBAGENT authors, CONTROLLER deploys+tests]

**Files:**
- Modify: `supabase/functions/tryon-generate/index.ts` (overwrite with v22, based on the live v21 archive from Task 1)

**Interfaces:**
- Produces: HTTP 400 `{error:"content_rejected"}` when moderation flags the prompt; otherwise unchanged response shape `{result, provider}`. Inserts `monitoring_events` rows of `event_type` `moderation_blocked` or `moderation_unavailable`.

- [ ] **Step 1 [SUBAGENT]: Pin imports.** Change the two import lines at the top of `index.ts`:
```ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4"
```

- [ ] **Step 2 [SUBAGENT]: Add the moderation helper** (place near the other helper functions, e.g. above `jsonError`):
```ts
const MODERATION_MODEL    = "omni-moderation-latest"
const MODERATION_TIMEOUT_MS = 3_000
// Categories that block generation outright.
const BLOCK_CATEGORIES = ["sexual/minors", "sexual", "violence/graphic", "illicit"]

interface ModerationOutcome { blocked: boolean; categories: string[] }

async function logSecurityEvent(
  admin: ReturnType<typeof createClient>,
  userId: string,
  eventType: string,
  message: string,
): Promise<void> {
  try {
    await admin.from("monitoring_events").insert({
      event_type: eventType,
      user_id: userId,
      error_domain: "moderation",
      error_message: message.slice(0, 500),
      platform: "edge",
    })
  } catch (_e) { /* fire-and-forget */ }
}

// Returns blocked=true only on a confident flag. On error/timeout: fail-open + log.
async function moderate(
  prompt: string,
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<ModerationOutcome> {
  if (!OPENAI_API_KEY) return { blocked: false, categories: [] }
  const ctrl = new AbortController()
  const t = setTimeout(() => ctrl.abort(), MODERATION_TIMEOUT_MS)
  try {
    const res = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: { "Authorization": `Bearer ${OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: MODERATION_MODEL, input: prompt }),
      signal: ctrl.signal,
    })
    if (!res.ok) throw new Error(`moderation HTTP ${res.status}`)
    const json = await res.json()
    const cats = (json.results?.[0]?.categories ?? {}) as Record<string, boolean>
    const hit = BLOCK_CATEGORIES.filter((c) => cats[c] === true)
    return { blocked: hit.length > 0, categories: hit }
  } catch (e) {
    // Fail-open: do not block generation, but record the gap.
    await logSecurityEvent(admin, userId, "moderation_unavailable", String(e))
    return { blocked: false, categories: [] }
  } finally {
    clearTimeout(t)
  }
}
```

- [ ] **Step 3 [SUBAGENT]: Call moderation before quota.** In the request handler, immediately AFTER the `const generationPrompt = withTryOnFramingPrompt(...)` line and BEFORE the `// Quota` block, insert:
```ts
    // Content moderation (fail-open, logged) — see logSecurityEvent.
    const mod = await moderate(prompt, adminClient, userId)
    if (mod.blocked) {
      await logSecurityEvent(adminClient, userId, "moderation_blocked", mod.categories.join(","))
      return jsonError("content_rejected", 400)
    }
```

- [ ] **Step 4 [SUBAGENT]: Replace `getPublicUrl` with a signed URL.** Replace the block:
```ts
    const publicUrl = uploadError
      ? null
      : adminClient.storage.from(STORAGE_BUCKET).getPublicUrl(tempPath).data.publicUrl

    if (uploadError) console.warn("Storage upload failed:", uploadError)
```
with:
```ts
    let publicUrl: string | null = null
    if (uploadError) {
      console.warn("Storage upload failed:", uploadError)
    } else {
      const { data: signed, error: signError } =
        await adminClient.storage.from(STORAGE_BUCKET).createSignedUrl(tempPath, 120)
      if (signError || !signed?.signedUrl) {
        console.error("[tryon-generate] createSignedUrl failed:", signError)
        adminClient.storage.from(STORAGE_BUCKET).remove([tempPath]).catch(() => {})
        return jsonError("Image generation temporarily unavailable. Please try again.", 503)
      }
      publicUrl = signed.signedUrl
    }
```

- [ ] **Step 5 [SUBAGENT]: Commit the authored v22.**
```bash
git add supabase/functions/tryon-generate/index.ts
git commit -m "feat(m1): tryon-generate v22 — moderation (fail-open) + signed temp URL + pinned imports"
```

- [ ] **Step 6 [CONTROLLER/MCP]: Deploy v22** (bucket still public). `deploy_edge_function` name `tryon-generate`, `verify_jwt: true`, files=[{name:"index.ts", content: <authored v22>}].

- [ ] **Step 7 [CONTROLLER/MCP]: Smoke-test a real generation via a founder account.** Mint a session for `siamubee2@gmail.com` (founder — unlimited, no quota decrement) and POST a small base64 image + benign prompt to `/functions/v1/tryon-generate`. Expected: HTTP 200 with `{result, provider}`. (Confirms moderation pass + signed-URL fetch by Kie.ai works while bucket is still public.) If it fails, ROLLBACK: redeploy the Task 1 archive.

---

### Task 3: Privatize `tryon-temp` bucket — [CONTROLLER/MCP]

**Files:**
- Create: `supabase/migrations/010_tryon_temp_private.sql`

- [ ] **Step 1 [SUBAGENT]: Author the migration.**
```sql
-- Migration 010 — privatize tryon-temp (M1). Apply ONLY after tryon-generate v22
-- (signed URLs) is deployed and smoke-tested, else generation breaks.
update storage.buckets set public = false where id = 'tryon-temp';
```
Commit:
```bash
git add supabase/migrations/010_tryon_temp_private.sql
git commit -m "feat(m1): privatize tryon-temp bucket (signed URLs only)"
```
- [ ] **Step 2 [CONTROLLER/MCP]:** `apply_migration` name `010_tryon_temp_private` with that SQL.
- [ ] **Step 3 [CONTROLLER/MCP]: Re-smoke-test** the founder generation (as Task 2 Step 7). Expected: still HTTP 200 — proves Kie.ai fetches the **signed** URL from the now-private bucket. If it fails, ROLLBACK: `update storage.buckets set public=true where id='tryon-temp'`.
- [ ] **Step 4 [CONTROLLER/MCP]: Verify** the bucket: `execute_sql` `select public from storage.buckets where id='tryon-temp'` → expect `false`.

---

### Task 4: `delete-user-account` v2 — RGPD cascade — [SUBAGENT authors, CONTROLLER deploys+tests]

**Files:**
- Modify: `supabase/functions/delete-user-account/index.ts` (overwrite, based on the live v5 archive)

**Interfaces:**
- Produces: deletes all user-owned rows then the auth user; returns `{success:true, deleted:{...}}` on full success, or `{error:"partial_delete", failures:[...]}` (auth user NOT deleted) if any table delete failed.

- [ ] **Step 1 [SUBAGENT]: Insert the cascade before `auth.admin.deleteUser`.** Keep the existing JWT + `user_id === user.id` checks and the adminClient creation. Replace the body of the `try { ... }` block (from adminClient creation through the deleteUser call) with:
```ts
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
```
Also pin the imports as in Task 2 Step 1 (`std@0.224.0`, `supabase-js@2.45.4`).

- [ ] **Step 2 [SUBAGENT]: Commit.**
```bash
git add supabase/functions/delete-user-account/index.ts
git commit -m "feat(m1): delete-user-account v2 — explicit RGPD cascade before auth delete"
```

- [ ] **Step 3 [CONTROLLER/MCP]: Deploy** `delete-user-account` (`verify_jwt: true`).

- [ ] **Step 4 [CONTROLLER/MCP]: Smoke-test with a disposable account.**
  1. Create a throwaway user via `execute_sql`/auth admin (or OTP) — capture its `id`.
  2. `execute_sql` INSERT one row each into `try_on_results`, `wardrobe_items`, `user_quotas` with `user_id` = that id.
  3. Call `delete-user-account` with that user's JWT (or invoke the same deletion logic with service_role for the test).
  4. `execute_sql` `select count(*)` across the seeded tables for that id → expect 0; confirm the auth user is gone.
  5. Report the before/after counts as the proof of cascade.

---

### Task 5: iOS founder-list hygiene — [SUBAGENT]

**Files:**
- Modify: `Sources/Core/Services/UnlimitedAccess.swift`
- Test: `Tests/UnlimitedAccessTests.swift`

**Interfaces:**
- Produces: `UnlimitedAccess.isUnlimited(remainingCredits:)` deriving unlimited status from the server-provided credit balance; the hardcoded email `Set` is removed. `UnlimitedAccess.quotaDisplayValue` stays `999_999`.

- [ ] **Step 1: Write the failing test** `Tests/UnlimitedAccessTests.swift`:
```swift
import XCTest
@testable import EcrinVirtuel

final class UnlimitedAccessTests: XCTestCase {
    func testUnlimitedWhenBalanceAtSentinel() {
        XCTAssertTrue(UnlimitedAccess.isUnlimited(remainingCredits: UnlimitedAccess.quotaDisplayValue))
    }
    func testUnlimitedWhenBalanceAboveThreshold() {
        XCTAssertTrue(UnlimitedAccess.isUnlimited(remainingCredits: 500_000))
    }
    func testNotUnlimitedForNormalBalance() {
        XCTAssertFalse(UnlimitedAccess.isUnlimited(remainingCredits: 3))
    }
}
```
- [ ] **Step 2: Run it — expect FAIL** (`isUnlimited(remainingCredits:)` undefined):
```bash
DEST="platform=iOS Simulator,name=iPhone 17"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel -destination "$DEST" \
  -only-testing:EcrinVirtuelTests/UnlimitedAccessTests -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "TEST FAILED|error:"
```
- [ ] **Step 3: Rewrite `UnlimitedAccess.swift`** (remove the email list; derive from balance):
```swift
import Foundation

/// Statut "illimité" (comptes fondateur / QA). La source de vérité est le SERVEUR :
/// l'Edge Function renvoie un quota au sentinel pour ces comptes. Le client ne stocke
/// AUCUNE liste d'emails (évite d'embarquer des PII / la liste de bypass dans l'IPA).
enum UnlimitedAccess {
    static let quotaDisplayValue = 999_999

    /// Seuil au-delà duquel on considère le solde comme "illimité".
    private static let unlimitedThreshold = 100_000

    /// Dérive le statut illimité du solde de crédits renvoyé par le serveur.
    static func isUnlimited(remainingCredits: Int) -> Bool {
        remainingCredits >= unlimitedThreshold
    }
}
```
- [ ] **Step 4: Update the one call site in `CreditsManager.sync()`.** Replace the founder-email branch:
```swift
        if UnlimitedAccess.isUnlimited(email: session.user.email) {
            isUnlimited = true
            remaining = UnlimitedAccess.quotaDisplayValue
            hasLoaded = true
            return
        }

        isUnlimited = false
        if let count = try? await SupabaseService.shared.fetchRemainingCredits() {
            remaining = max(0, count)
        }
```
with:
```swift
        if let count = try? await SupabaseService.shared.fetchRemainingCredits() {
            remaining = max(0, count)
            isUnlimited = UnlimitedAccess.isUnlimited(remainingCredits: count)
        } else {
            isUnlimited = false
        }
```
(If any other file references `UnlimitedAccess.isUnlimited(email:)`, grep `UnlimitedAccess.isUnlimited` under `Sources/` and update each to the balance-based form; report if a call site can't be cleanly migrated.)
- [ ] **Step 5: Run the focused test + full unit suite — expect PASS** (no regressions):
```bash
DEST="platform=iOS Simulator,name=iPhone 17"
xcodebuild test -project EcrinVirtuel.xcodeproj -scheme EcrinVirtuel -destination "$DEST" \
  -only-testing:EcrinVirtuelTests -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|Executed [0-9]+ test" | tail -2
```
Expected: `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit.**
```bash
git add Sources/Core/Services/UnlimitedAccess.swift Sources/Core/Services/CreditsManager.swift Tests/UnlimitedAccessTests.swift EcrinVirtuel.xcodeproj/project.pbxproj
git commit -m "feat(m1): derive unlimited status from server balance; drop founder email list from IPA"
```

---

### Task 6: M1 acceptance — advisors + monitoring + tag — [CONTROLLER/MCP]

- [ ] **Step 1 [CONTROLLER/MCP]: `get_advisors` (security)** → confirm no new WARN/ERROR introduced (the `tryon-temp public_bucket_allows_listing` lint should be GONE now that the bucket is private; the function lints stay resolved).
- [ ] **Step 2 [CONTROLLER/MCP]: Verify monitoring** — `execute_sql` `select event_type, count(*) from monitoring_events where event_type in ('moderation_blocked','moderation_unavailable') group by 1` (rows appear only if those paths fired during smoke-tests; absence is acceptable, the schema acceptance is that the inserts don't error).
- [ ] **Step 3:** Full iOS unit suite green (Task 5 Step 5 re-run if needed).
- [ ] **Step 4: Tag.** `git tag m1-security-phase1`.

---

## Self-Review

**1. Spec coverage:** C1 moderation+signedURL+pinning → Task 2; C2 bucket private → Task 3; C3 delete v2 cascade → Task 4; C4 monitoring events → Task 2 (`logSecurityEvent`) + Task 6 verify; C5 iOS founder hygiene → Task 5; cutover sequence (capture→deploy→smoke→private→delete) → Tasks 1→2→3→4 in order; rollback archive → Task 1; disposable-account delete verification → Task 4 Step 4. All spec sections mapped.

**2. Placeholder scan:** No TBD/TODO. `supabase-js@2.45.4` and `std@0.224.0` are concrete pins; if `@2.45.4` fails to deploy, the controller bumps to a valid published 2.x and records it (deploy + smoke-test catch a bad pin) — this is a known, bounded resolution, not a placeholder.

**3. Type consistency:** `moderate()`/`logSecurityEvent()` signatures defined in Task 2 and used only there. `UnlimitedAccess.isUnlimited(remainingCredits:)` defined in Task 5 Step 3 and consumed in Task 5 Step 4 + its tests. `monitoring_events` insert columns match `009_prod_baseline.sql` (event_type, user_id, error_domain, error_message, platform). Delete cascade tables/columns match the baseline.

**Note on execution:** [CONTROLLER/MCP] steps run in the controlling session; [SUBAGENT] steps are delegable. A subagent-driven run dispatches Tasks 2/4/5 authoring to subagents and the controller performs the deploy/migration/smoke-test/advisor steps inline.
