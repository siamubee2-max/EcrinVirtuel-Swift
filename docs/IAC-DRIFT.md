# IaC Drift Register — repo migrations vs production (`itjtshfzpknlzownpwte`)

Captured 2026-06-21 via Supabase MCP during milestone M0.
Source of truth for the live schema: **`supabase/migrations/009_prod_baseline.sql`**.

## Summary

Repo migrations `001`–`006` do **not** reflect production. They describe an
earlier React-Native-era design that diverged. Migrations `007`/`008` are real,
applied hardening changes. Treat `009_prod_baseline.sql` as the current truth.

## Confirmed discrepancies (repo → prod)

| Repo migration says | Production reality |
|---|---|
| `gift_cards` table (001) | **Absent.** Gift feature degrades to local-only (`GiftViewModel` catches the error). |
| `gaming_profiles` table | **Absent.** Gaming cloud-sync silently no-ops. |
| `users` has separate `id` + `auth_id` (001) | `users.id` **IS** `auth.uid()` (varchar). No `auth_id` column. |
| `saved_looks`, `wedding_looks`, `community_challenges`, `partner_brands` (001) | **Absent** (or renamed). |
| `community_posts.author_email` removed (006) | Column never existed in prod's `community_posts` shape. |
| user-scoped tables key on profile `id` | All key on **`auth.uid()::text = user_id::text`** directly. |

## Tables present in prod but in NO repo migration

`conversations`, `messages` (AI styliste chat), `credit_transactions`,
`device_tryons`, `jewelry_items`, `outfit_presets`, `post_comments`,
`post_likes`, `post_reports`, `try_on_results`, `partnership_requests`.

Note: `jewelry` (a **public catalogue** table, `SELECT USING(true)`) is a
**separate** table from `jewelry_items` (per-user, 4 owner-scoped policies) —
similar names, very different RLS posture. Don't conflate them in M2.

## Identity model (RESOLVES an earlier audit concern)

The 007 audit flagged a possible `auth_id` vs `users.id` mismatch that could
break account deletion and inserts. **That concern was an artifact of the
drifted repo migrations.** In production the model is consistent: `users.id`
equals `auth.uid()` and every per-user table is keyed and RLS-scoped on
`auth.uid()`. Most tables use a `varchar` key and cast
(`auth.uid()::text = user_id::text`); **two tables are the exception** —
`user_quotas.user_id` and `credit_transactions.user_id` are native `uuid`
keys whose RLS uses `auth.uid() = user_id` with no cast. The Swift code (which
passes the auth uid as `user_id`) is correct against prod in all cases.

## New items for the M2 code/security audit

- **`users.password` and `users.pin_code` columns** exist on a user-readable
  table (RLS restricts to own row, but a `password` column alongside Supabase
  Auth is worth auditing — is it written? plaintext? dead?).
- `monitoring_events` INSERT `WITH CHECK(true)` for authenticated and
  `partnership_requests` INSERT `WITH CHECK(true)` for public are by-design
  (client logging / public partner form) but should be confirmed acceptable.

## Consequence for later milestones

- Any new migration must be diffed against `009_prod_baseline.sql`, **not**
  against repo migrations `001`–`006`.
- M2 (audit) must read prod column/RLS names from the baseline, not the repo.
