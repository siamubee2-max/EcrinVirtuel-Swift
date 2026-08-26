-- Migration 007 — Lock down gift_cards (security hardening)
--
-- gift_cards was created in 001_swift_native_tables.sql with RLS explicitly
-- disabled ("Pas de RLS sur gift_cards : accessible via share_token public").
-- In Supabase, RLS being off means the *entire table* is readable/writable
-- through the anon-key PostgREST API — not just rows matched by a caller-
-- supplied token. Any client could run `select=*` on /rest/v1/gift_cards and
-- dump every sender's email, display name and personal gift message ever
-- created, plus forge/alter/delete arbitrary gifts.
--
-- Fix: enable RLS, scope table access to the sender who owns a gift, and
-- expose single-gift lookup (what recipients actually need, following the
-- "ecrin://gift/<id>" deep link) only through a SECURITY DEFINER RPC that
-- takes one id and returns one row — never a bulk table scan.

ALTER TABLE gift_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own sent gifts" ON gift_cards
    FOR ALL
    USING (from_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()))
    WITH CHECK (from_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Recipient-facing lookup: fetch one gift by id and mark it revealed.
-- SECURITY DEFINER lets this bypass the owner-only RLS policy above for the
-- single matched row, without ever exposing the underlying table to anon.
CREATE OR REPLACE FUNCTION get_gift_card(gift_id UUID)
RETURNS TABLE (
    id                 UUID,
    from_display_name  TEXT,
    from_email         TEXT,
    jewelry_json       TEXT,
    jewelry_name       TEXT,
    jewelry_image_url  TEXT,
    message            TEXT,
    occasion           TEXT,
    is_revealed        BOOLEAN,
    expires_at         TIMESTAMPTZ,
    created_at         TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE gift_cards g SET is_revealed = true
        WHERE g.id = gift_id AND g.expires_at > NOW();

    RETURN QUERY
    SELECT g.id, g.from_display_name, g.from_email, g.jewelry_json,
           g.jewelry_name, g.jewelry_image_url, g.message, g.occasion,
           g.is_revealed, g.expires_at, g.created_at
    FROM gift_cards g
    WHERE g.id = gift_id AND g.expires_at > NOW();
END;
$$;

GRANT EXECUTE ON FUNCTION get_gift_card(UUID) TO anon, authenticated;
