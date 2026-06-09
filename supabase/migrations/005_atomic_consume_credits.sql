-- Migration 005 — Fonction atomique de consommation de crédits
-- Remplace le pattern SELECT + UPDATE non-atomique de l'Edge Function
-- qui permettait un bypass paywall via des requêtes concurrentes (race condition).
--
-- Usage depuis l'Edge Function :
--   const { data, error } = await adminClient.rpc('consume_credits', {
--     p_user_id: userId, p_cost: 1
--   })
--   if (error?.message?.includes('QUOTA_EXCEEDED')) { ... }

CREATE OR REPLACE FUNCTION consume_credits(
  p_user_id UUID,
  p_cost    INTEGER DEFAULT 1
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_remaining INTEGER;
BEGIN
  -- Tentative UPDATE atomique avec vérification du solde dans la même opération
  UPDATE user_quotas
  SET
    generations_remaining = generations_remaining - p_cost,
    updated_at            = NOW()
  WHERE user_id             = p_user_id
    AND generations_remaining >= p_cost
  RETURNING generations_remaining INTO v_remaining;

  -- Si aucune ligne mise à jour → quota insuffisant ou utilisateur inexistant
  IF NOT FOUND THEN
    -- Vérifier si l'utilisateur existe mais n'a pas de crédits
    IF EXISTS (SELECT 1 FROM user_quotas WHERE user_id = p_user_id) THEN
      RAISE EXCEPTION 'QUOTA_EXCEEDED';
    ELSE
      -- Première utilisation : créer le quota et consommer
      INSERT INTO user_quotas (user_id, generations_remaining, plan_type)
      VALUES (p_user_id, 3 - p_cost, 'free')
      RETURNING generations_remaining INTO v_remaining;
    END IF;
  END IF;

  RETURN v_remaining;
END;
$$;

-- Révoquer l'accès public, accès service_role uniquement
REVOKE ALL ON FUNCTION consume_credits(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION consume_credits(UUID, INTEGER) TO service_role;
