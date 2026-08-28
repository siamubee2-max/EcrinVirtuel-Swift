-- Migration 012 — Idempotence réelle + octroi atomique des crédits (audit 007, 2026-08-09)
-- ⚠️ NON APPLIQUÉE (constat de la revue du 27/08/2026 : `credit_generations_atomic`
-- absente en base). À exécuter manuellement — voir docs/AUDIT-007-CREDITS.md.
-- PREMIÈRE de la séquence de déploiement — doit être posée AVANT :
--   • `functions deploy credit-generations` (la v10 appelle cette RPC ; sans elle → 503)
--   • `functions deploy revenuecat-webhook`  (le chemin packs appelle cette RPC, et
--     l'idempotence inter-chemins repose sur la contrainte UNIQUE ci-dessous ;
--     sans elle, un pack peut être crédité deux fois).
--
-- Constats fermés (Edge Function `credit-generations`) :
--  • C2a — L'idempotence reposait sur un SELECT-puis-INSERT applicatif, sans contrainte
--    UNIQUE sur credit_transactions.transaction_id → deux requêtes concurrentes passent
--    toutes deux le contrôle « already_credited » et créditent deux fois.
--  • C2b — Le solde était lu puis réécrit (read-modify-write) : deux achats simultanés
--    perdent l'un des deux incréments (lost update).
--  • C2c — L'INSERT du registre n'était pas contrôlé en erreur ET arrivait APRÈS l'octroi
--    des crédits : un échec d'écriture laissait des crédits accordés sans trace, donc
--    le même transaction_id restait rejouable indéfiniment.
--
-- Principe du correctif : le registre est écrit EN PREMIER, et c'est la violation de
-- contrainte UNIQUE qui PORTE l'idempotence — plus aucun contrôle applicatif racé.
-- Tout tient dans une seule transaction Postgres.

-- ── 1) Pré-vol : refuser de créer la contrainte si des doublons existent déjà ────────
-- Un doublon préexistant = trace d'un double-crédit (bug ou exploitation de C1/C2).
-- On échoue bruyamment plutôt que de supprimer des lignes de registre financier.
DO $$
DECLARE
  v_dupes integer;
BEGIN
  SELECT COUNT(*) INTO v_dupes FROM (
    SELECT transaction_id
    FROM public.credit_transactions
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
  ) d;

  IF v_dupes > 0 THEN
    RAISE EXCEPTION
      'ABORT: % transaction_id en doublon dans credit_transactions. Auditer ces lignes AVANT de poser la contrainte UNIQUE (requête dans le commentaire ci-dessous).', v_dupes;
  END IF;
END $$;

-- Pour inspecter les doublons éventuels :
--   SELECT transaction_id, COUNT(*), SUM(credits_added), array_agg(user_id)
--   FROM public.credit_transactions GROUP BY transaction_id HAVING COUNT(*) > 1;

-- ── 2) La contrainte qui porte l'idempotence ────────────────────────────────────────
ALTER TABLE public.credit_transactions
  ADD CONSTRAINT credit_transactions_transaction_id_key UNIQUE (transaction_id);

-- ── 3) Octroi atomique ──────────────────────────────────────────────────────────────
-- Registre d'abord (UNIQUE = idempotence), puis incrément du solde, dans UNE transaction.
-- Renvoie le nouveau solde. Lève ALREADY_CREDITED si le transaction_id est déjà connu.
CREATE OR REPLACE FUNCTION public.credit_generations_atomic(
  p_user_id        uuid,
  p_product_id     text,
  p_transaction_id text,
  p_credits        integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_total integer;
BEGIN
  -- Le montant vient d'une table serveur, jamais du client — on le vérifie quand même
  -- (leçon de la migration 007 : p_cost négatif = crédit gratuit).
  IF p_credits IS NULL OR p_credits <= 0 THEN
    RAISE EXCEPTION 'INVALID_CREDITS';
  END IF;
  IF p_transaction_id IS NULL OR length(trim(p_transaction_id)) = 0 THEN
    RAISE EXCEPTION 'INVALID_TRANSACTION_ID';
  END IF;

  -- Registre EN PREMIER : si le transaction_id existe déjà, on sort ici sans rien créditer.
  BEGIN
    INSERT INTO public.credit_transactions (user_id, product_id, transaction_id, credits_added)
    VALUES (p_user_id, p_product_id, p_transaction_id, p_credits);
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'ALREADY_CREDITED';
  END;

  -- Incrément atomique du solde (plus de read-modify-write applicatif).
  INSERT INTO public.user_quotas (user_id, generations_remaining, plan_type)
  VALUES (p_user_id, p_credits, 'free')
  -- Dans ON CONFLICT DO UPDATE, la ligne existante se référence par le NOM de la table
  -- (`user_quotas`), jamais par son nom schéma-qualifié — `public.user_quotas.col` échoue.
  ON CONFLICT (user_id) DO UPDATE
    SET generations_remaining = user_quotas.generations_remaining + p_credits,
        updated_at            = NOW()
  RETURNING generations_remaining INTO v_total;

  RETURN v_total;
END;
$function$;

-- ── 4) Verrouiller l'exécution au service_role ──────────────────────────────────────
-- ⚠️ REVOKE APRÈS le CREATE : `CREATE OR REPLACE FUNCTION` re-accorde EXECUTE à PUBLIC.
-- C'est précisément le piège qui avait fait échouer le REVOKE de la migration 005.
REVOKE ALL ON FUNCTION public.credit_generations_atomic(uuid, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.credit_generations_atomic(uuid, text, text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.credit_generations_atomic(uuid, text, text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.credit_generations_atomic(uuid, text, text, integer) TO service_role;
