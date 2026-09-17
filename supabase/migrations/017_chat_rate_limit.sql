-- 017 — Limitation de débit du styliste conversationnel.
--
-- styliste-chat appelait gpt-4o-mini / Gemini avec pour seule garde
-- auth.getUser() : n'importe quel JWT valide (les 3 essais gratuits suffisent
-- à en obtenir un) pouvait boucler sans limite sur un endpoint LLM facturé.
-- Aucun quota, aucun compteur, rien dans generation_costs.
--
-- Un compteur quotidien atomique, calqué sur consume_credits : pas de crédit
-- débité (le chat reste un avantage, pas un produit), juste un plafond.

create table if not exists public.chat_usage (
  user_id uuid not null,
  day     date not null default (now() at time zone 'utc')::date,
  count   integer not null default 0,
  primary key (user_id, day)
);

alter table public.chat_usage enable row level security;
-- Aucune policy : seule la RPC service-role y touche.

create or replace function public.increment_chat_usage(
  p_user_id uuid,
  p_max     integer
)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_count integer;
begin
  insert into public.chat_usage (user_id, day, count)
  values (p_user_id, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day) do update
    set count = public.chat_usage.count + 1
  returning count into v_count;

  if v_count > p_max then
    raise exception 'RATE_LIMITED';
  end if;
  return v_count;
end;
$function$;

revoke all on function public.increment_chat_usage(uuid, integer) from public;
revoke all on function public.increment_chat_usage(uuid, integer) from anon;
revoke all on function public.increment_chat_usage(uuid, integer) from authenticated;
grant execute on function public.increment_chat_usage(uuid, integer) to service_role;

comment on function public.increment_chat_usage(uuid, integer) is
  'Compteur quotidien atomique du chat styliste. Service role uniquement. Leve RATE_LIMITED au-dela de p_max.';
