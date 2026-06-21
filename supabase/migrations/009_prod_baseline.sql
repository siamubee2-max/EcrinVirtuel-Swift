-- Migration 009 — PROD BASELINE (reference snapshot, captured 2026-06-21 via Supabase MCP)
-- ============================================================================
-- DO NOT RE-APPLY. This file documents the REAL production schema of
-- itjtshfzpknlzownpwte to reconcile the heavy drift between repo migrations
-- 001–006 and production. Migrations 007 and 008 ARE real applied hardening
-- changes; this snapshot already reflects their effects (e.g. device_tryons
-- has 0 policies = service-role-only; consume_credits search_path is locked).
-- Everything below is an inventory for audit reference only.
-- ============================================================================

-- ── TABLES, COLUMNS, RLS (public schema, 18 tables — all RLS ENABLED) ────────

-- clothing_catalog            RLS✔ policies:1   (public read catalogue)
--   id uuid NN | name text NN | gender text | category text NN | subcategory text
--   brand text | color text | material text | style_tags text[] | season text[]
--   image_url text | try_on_prompt text | is_featured bool=false | is_active bool=true
--   price_eur numeric | purchase_url text | sort_order int | created_at timestamptz=now()

-- community_posts             RLS✔ policies:4   (id/user_id are VARCHAR = auth.uid() text)
--   id varchar NN=gen_random_uuid() | user_id varchar NN | try_on_result_id varchar
--   caption text | image_url text NN | likes_count int=0 | comments_count int=0
--   created_at timestamp=CURRENT_TIMESTAMP | type text='look'

-- conversations               RLS✔ policies:3   (AI styliste chat)
--   id varchar NN=gen_random_uuid() | user_id varchar NN | title text | created_at timestamp

-- credit_transactions         RLS✔ policies:1   (RevenueCat purchase ledger)
--   id uuid NN=gen_random_uuid() | user_id uuid NN | product_id text NN
--   transaction_id text NN | credits_added int NN | created_at timestamptz=now()

-- device_tryons               RLS✔ policies:0   (SERVICE-ROLE ONLY after migration 008)
--   id varchar NN=gen_random_uuid() | device_fingerprint varchar NN
--   created_at timestamp | try_on_count int=0 | max_free_tryons int=2 | last_try_on_at timestamp

-- jewelry                     RLS✔ policies:1   (public catalogue, 39 MONI'ATTITUDE rows)
--   id uuid NN | user_id uuid | name text NN | type text NN | metal text | gems text[]
--   brand text | collection text | image_url text | angle_images text[] | tags text[]
--   is_favorite bool=false | created_at timestamptz=now()

-- jewelry_items               RLS✔ policies:4   (per-user jewelry, id/user_id varchar)
--   id varchar NN | user_id varchar NN | name text NN | type text NN | brand text
--   metal text | gems text | price int | image_url text | angle_images text | tags text
--   is_favorite bool=false | created_at timestamp

-- messages                    RLS✔ policies:2   (chat messages; RLS via conversations join)
--   id int NN=seq | conversation_id varchar NN | role text NN | content text NN | created_at timestamp

-- monitoring_events           RLS✔ policies:2   (INSERT authenticated true; ALL service_role)
--   id bigint NN=seq | created_at timestamptz=now() | event_type text NN | product_id text
--   error_domain text NN='' | error_code int=0 | error_message text NN='' | platform text='ios'
--   app_version text='unknown' | build_number text='0' | user_id uuid

-- outfit_presets              RLS✔ policies:4   (per-user saved outfits, varchar keys)
--   id varchar NN | user_id varchar NN | name text NN | description text | clothing_ids text
--   jewelry_ids text | preview_image_url text | occasion text | season text
--   is_favorite bool=false | created_at timestamp

-- partnership_requests        RLS✔ policies:1   (INSERT public true — public partner form)
--   id varchar NN | brand_name text NN | email text NN | website text | description text
--   status text='pending' | created_at timestamp

-- post_comments               RLS✔ policies:4   (varchar keys)
--   id varchar NN | post_id varchar NN | user_id varchar NN | content text NN | created_at timestamp

-- post_likes                  RLS✔ policies:3   (varchar keys)
--   id varchar NN | post_id varchar NN | user_id varchar NN | created_at timestamp

-- post_reports                RLS✔ policies:2   (moderation reports; reporter_id-scoped)
--   id varchar NN | post_id varchar NN | reporter_id varchar NN | reason text NN
--   status text='pending' | created_at timestamp

-- try_on_results              RLS✔ policies:4   (select own OR is_public; varchar keys)
--   id varchar NN | user_id varchar NN | type text NN | original_image_url text
--   result_image_url text | jewelry_item_id text | wardrobe_item_id text | prompt text
--   is_favorite bool=false | created_at timestamp | item_type text='jewelry' | item_ids text
--   is_public bool=false

-- user_quotas                 RLS✔ policies:1   (SELECT own; writes via consume_credits service_role)
--   user_id uuid NN (PK, = auth.users.id) | plan_type text NN='free' | generations_remaining int NN=3
--   generations_used_total int NN=0 | reset_at timestamptz | updated_at timestamptz NN=now()

-- users                       RLS✔ policies:3   (id IS auth.uid() — NOT a separate auth_id)
--   id varchar NN=gen_random_uuid() (== auth.uid() text) | username text NN='' | email text NN
--   password text | display_name text | avatar_url text | bio text | preferred_language text='fr'
--   is_premium bool=false | stripe_customer_id text | stripe_subscription_id text | created_at timestamp
--   preferred_style text='classique' | unit_system text='metric' | gender text='female'
--   height int | weight int | bust int | waist int | hips int | shoe_size text | ring_size text
--   wrist_size text | pin_code text | biometric_enabled bool=false | revenuecat_app_user_id text
--   subscription_tier text='free' | is_yearly_subscription bool=false
--   try_on_credits_jewelry int=3 | try_on_credits_clothing int=0 | preferred_gender text
--   ⚠ AUDIT (M2): `password` and `pin_code` columns exist on a user-readable table.

-- wardrobe_items              RLS✔ policies:4   (varchar keys)
--   id varchar NN | user_id varchar NN | name text NN | type text NN | category text
--   brand text | color text | image_url text | is_favorite bool=false | created_at timestamp

-- ── RLS POLICIES (current production, post-007/008) ─────────────────────────
-- Identity model: every per-user table keys on  (auth.uid())::text = (<key>)::text
-- where <key> is `user_id` (or `id` for users, `reporter_id` for post_reports).
--
-- clothing_catalog : SELECT public USING(true)
-- jewelry          : SELECT public USING(true)
-- community_posts  : SELECT USING(true); INSERT/UPDATE/DELETE own
-- post_comments    : SELECT USING(true); INSERT/UPDATE/DELETE own
-- post_likes       : SELECT USING(true); INSERT/DELETE own
-- conversations    : SELECT/INSERT/DELETE own
-- messages         : SELECT/INSERT own (own = auth.uid() == conversations.user_id via subselect)
-- jewelry_items    : SELECT/INSERT/UPDATE/DELETE own
-- outfit_presets   : SELECT/INSERT/UPDATE/DELETE own
-- wardrobe_items   : SELECT/INSERT/UPDATE/DELETE own
-- try_on_results   : SELECT own-or-public; INSERT/UPDATE/DELETE own
-- post_reports     : SELECT/INSERT own (reporter_id)
-- credit_transactions : SELECT own (auth.uid() = user_id)
-- user_quotas      : SELECT own (auth.uid() = user_id); writes only via consume_credits (service_role)
-- users            : SELECT/INSERT/UPDATE own (auth.uid()::text = id::text)
-- monitoring_events: INSERT authenticated WITH CHECK(true); ALL service_role
-- partnership_requests : INSERT public WITH CHECK(true)
-- device_tryons    : (no policies) — RLS enabled, service-role only

-- ── FUNCTIONS (public, post-007 hardening) ──────────────────────────────────
-- consume_credits(p_user_id uuid, p_cost integer)  SECURITY DEFINER  search_path=''
--     EXECUTE: service_role only (revoked from anon/authenticated in migration 007)
--     Guards p_cost > 0; atomic decrement of user_quotas.generations_remaining.
-- handle_new_user()                                 SECURITY DEFINER  search_path=public
--     auth.users INSERT trigger → public.users; EXECUTE revoked from anon/authenticated (007).
-- update_quota_timestamp()                          SECURITY INVOKER  search_path=''
--     BEFORE UPDATE trigger on user_quotas (sets updated_at).
