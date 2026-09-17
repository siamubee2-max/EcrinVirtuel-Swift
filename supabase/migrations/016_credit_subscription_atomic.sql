-- 016 — Octroi ATOMIQUE des crédits d'abonnement.
--
-- Le webhook faisait, pour un abonnement, DEUX écritures séparées :
--   1. insert credit_transactions            (le registre)
--   2. select + upsert user_quotas           (le solde)
-- Si la 2 échouait, RevenueCat retentait la livraison ; au retry, la 1 tombait
-- sur la contrainte UNIQUE et la fonction répondait « already_processed » SANS
-- jamais créditer. Registre marqué crédité, solde jamais incrémenté :
-- 14,99 € payés pour 0 crédit, sans rattrapage possible.
--
-- Le SELECT+upsert était de plus une course : un achat de pack (ou un
-- consume_credits) entre les deux écrasait ou offrait des crédits.
--
-- C'est exactement le bug que 012_credit_generations_atomic a corrigé pour les
-- packs — refait à la main pour les abonnements. Même remède : registre ET
-- solde dans UNE transaction Postgres. credit_generations_atomic ne suffit pas
-- tel quel : un abonnement doit aussi poser plan_type et reset_at.

create or replace function public.credit_subscription_atomic(
  p_user_id        uuid,
  p_product_id     text,
  p_transaction_id text,
  p_credits        integer,
  p_plan           text
)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_remaining integer;
begin
  if p_credits is null or p_credits <= 0 then
    raise exception 'INVALID_CREDITS';
  end if;

  -- Le registre d'abord : la contrainte UNIQUE(transaction_id) posée par la
  -- migration 012 porte l'idempotence. Un retry lève ALREADY_CREDITED et
  -- l'appelant sait que ce coupon a déjà été honoré — solde compris, puisque
  -- les deux écritures vivent dans la même transaction.
  begin
    insert into public.credit_transactions (user_id, product_id, transaction_id, credits_added)
    values (p_user_id, p_product_id, p_transaction_id, p_credits);
  exception when unique_violation then
    raise exception 'ALREADY_CREDITED';
  end;

  -- Incrément RELATIF (jamais un total recalculé) : insensible aux achats de
  -- packs et aux consommations concurrentes.
  insert into public.user_quotas (user_id, generations_remaining, plan_type, reset_at, updated_at)
  values (p_user_id, p_credits, p_plan, now() + interval '30 days', now())
  on conflict (user_id) do update set
    generations_remaining = public.user_quotas.generations_remaining + p_credits,
    plan_type             = excluded.plan_type,
    reset_at              = excluded.reset_at,
    updated_at            = now()
  returning generations_remaining into v_remaining;

  return v_remaining;
end;
$function$;

-- Même durcissement que 007/015 : jamais exposée via /rest/v1/rpc aux clients.
revoke all on function public.credit_subscription_atomic(uuid, text, text, integer, text) from public;
revoke all on function public.credit_subscription_atomic(uuid, text, text, integer, text) from anon;
revoke all on function public.credit_subscription_atomic(uuid, text, text, integer, text) from authenticated;
grant execute on function public.credit_subscription_atomic(uuid, text, text, integer, text) to service_role;

comment on function public.credit_subscription_atomic(uuid, text, text, integer, text) is
  'Credite un abonnement : registre + solde + plan dans UNE transaction. Service role uniquement.';
