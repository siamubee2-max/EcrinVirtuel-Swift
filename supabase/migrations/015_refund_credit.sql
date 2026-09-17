-- 015 — Rembourser le crédit d'une génération qui a échoué.
--
-- Le crédit est débité AVANT la génération (tryon-generate ligne ~249) : c'est
-- volontaire, `consume_credits` est la garde atomique du quota et doit rester
-- en amont, sinon N requêtes simultanées passeraient toutes avec 1 crédit.
--
-- Mais jusqu'ici RIEN ne le rendait quand la cascade échouait : l'utilisateur
-- payait et ne recevait pas d'image. Facturer un service non rendu produit des
-- demandes de remboursement, des avis à une étoile, et c'est un motif de rejet
-- possible en revue App Store.
--
-- `consume_credits` ne peut pas servir : elle lève INVALID_COST sur tout coût
-- <= 0, précisément pour empêcher qu'un appel négatif crédite un compte.

create or replace function public.refund_credit(
  p_user_id uuid,
  p_amount  integer default 1
)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_remaining integer;
begin
  -- Symétrique de consume_credits : un montant nul ou négatif n'a aucun sens
  -- ici et ouvrirait un moyen détourné de DÉBITER un compte.
  if p_amount is null or p_amount <= 0 then
    raise exception 'INVALID_AMOUNT';
  end if;

  -- Borne de sécurité : un remboursement ne rend jamais plus d'une génération
  -- à la fois. Sans elle, un appel malformé pourrait créditer arbitrairement.
  if p_amount > 1 then
    raise exception 'INVALID_AMOUNT';
  end if;

  update public.user_quotas
  set generations_remaining = generations_remaining + p_amount,
      updated_at            = now()
  where user_id = p_user_id
  returning generations_remaining into v_remaining;

  -- Aucune ligne de quota : rien à rembourser. Ne pas en créer une — ce serait
  -- offrir un crédit à un utilisateur qui n'en avait jamais consommé.
  if not found then
    return null;
  end if;

  return v_remaining;
end;
$function$;

-- Même durcissement que la migration 007 : jamais exposée à anon/authenticated
-- via /rest/v1/rpc, sinon n'importe qui se recrédite en boucle.
revoke all on function public.refund_credit(uuid, integer) from public;
revoke all on function public.refund_credit(uuid, integer) from anon;
revoke all on function public.refund_credit(uuid, integer) from authenticated;
grant execute on function public.refund_credit(uuid, integer) to service_role;

comment on function public.refund_credit(uuid, integer) is
  'Rend le credit d une generation echouee. Service role uniquement, 1 credit maximum par appel.';
