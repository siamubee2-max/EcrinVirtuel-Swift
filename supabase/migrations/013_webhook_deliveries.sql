-- 013 — Delivery log for server-to-server webhooks (RevenueCat).
-- Written to (best-effort) by the revenuecat-webhook edge function so
-- deliveries can be verified by SQL even when the Supabase analytics/log
-- API is unavailable.
-- ⚠️ NON APPLIQUÉE (constat de la revue du 27/08/2026 ; la mention « applied 26 Aug » était
-- fausse). À poser APRÈS 012 et AVANT `functions deploy revenuecat-webhook` :
-- la fonction insère dans cette table à chaque livraison (best-effort, donc pas
-- bloquant, mais chaque livraison logue alors une erreur).

create table if not exists public.webhook_deliveries (
  id bigint generated always as identity primary key,
  received_at timestamptz not null default now(),
  source text not null default 'revenuecat',
  auth_ok boolean not null,
  event_type text,
  app_user_id text,
  outcome text,
  user_agent text
);

-- Only the service role (edge functions) may read/write: RLS on, no policies.
alter table public.webhook_deliveries enable row level security;
