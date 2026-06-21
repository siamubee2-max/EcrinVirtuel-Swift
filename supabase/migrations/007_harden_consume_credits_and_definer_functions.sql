-- Migration 007 — Security hardening (007 defensive audit, 2026-06-19)
-- Applied to prod itjtshfzpknlzownpwte via MCP. Reconciles SECURITY DEFINER functions.
--
-- Findings closed:
--  • consume_credits was EXECUTABLE by anon + authenticated via /rest/v1/rpc/consume_credits
--    with no positive-cost guard → a client could call it with p_cost < 0 to GRANT itself
--    unlimited credits (paywall bypass), or with a victim's user_id to drain their quota.
--    (migration 005's REVOKE never stuck — CREATE OR REPLACE re-grants EXECUTE to PUBLIC.)
--  • consume_credits / update_quota_timestamp had a mutable search_path (definer-fn risk).
--  • handle_new_user (auth trigger) was needlessly EXECUTABLE as a public RPC.

-- 1) consume_credits: strict positive-cost guard + locked search_path. Logic otherwise
--    identical to the prod definition. Only service_role (the Edge Function) may call it.
CREATE OR REPLACE FUNCTION public.consume_credits(p_user_id uuid, p_cost integer DEFAULT 1)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_remaining integer;
BEGIN
  -- Reject non-positive cost: prevents p_cost < 0 from INCREASING a balance.
  IF p_cost IS NULL OR p_cost <= 0 THEN
    RAISE EXCEPTION 'INVALID_COST';
  END IF;

  UPDATE public.user_quotas
  SET generations_remaining = generations_remaining - p_cost,
      updated_at            = NOW()
  WHERE user_id = p_user_id
    AND generations_remaining >= p_cost
  RETURNING generations_remaining INTO v_remaining;

  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM public.user_quotas WHERE user_id = p_user_id) THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    ELSE
      INSERT INTO public.user_quotas (user_id, generations_remaining, plan_type)
      VALUES (p_user_id, 3 - p_cost, 'free')
      RETURNING generations_remaining INTO v_remaining;
    END IF;
  END IF;

  RETURN v_remaining;
END;
$function$;

-- 2) Lock execution to service_role only (revoke AFTER create — it re-grants PUBLIC).
REVOKE ALL ON FUNCTION public.consume_credits(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_credits(uuid, integer) FROM anon;
REVOKE ALL ON FUNCTION public.consume_credits(uuid, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.consume_credits(uuid, integer) TO service_role;

-- 3) handle_new_user is an auth.users INSERT trigger, not a public RPC.
--    Revoking EXECUTE does not disable the trigger (it fires as definer).
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated;

-- 4) Lock search_path on the remaining mutable-search_path definer function.
ALTER FUNCTION public.update_quota_timestamp() SET search_path = '';
