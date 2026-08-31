-- 014 — Télémétrie du coût réel par génération.
--
-- Motivation : `tryon-generate` enchaîne jusqu'à cinq fournisseurs (nano-banana-2
-- 0,030 $ -> nano-banana-pro 0,100 $ -> flux-kontext 0,040 $ -> Gemini -> OpenAI)
-- mais n'enregistrait NULLE PART lequel a servi ni combien d'appels ont été
-- facturés. Le coût par génération réussie était donc inconnaissable : les
-- console.warn ne survivent pas 24 h et ne disent rien du volume.
--
-- Sans ce chiffre, aucune décision tarifaire n'est fondée — c'est la conclusion
-- de la contre-expertise du 30/08/2026.

create table if not exists public.generation_costs (
  id          bigserial primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid,
  -- Palier demandé par l'app : preview | standard | premium
  tier        text        not null,
  -- Modèle qui a FINALEMENT réussi, ou 'none' si toute la cascade a échoué.
  provider    text        not null,
  -- Appels effectivement FACTURÉS, y compris ceux qui ont échoué : un appel
  -- exécuté est facturé même s'il ne rend pas d'image.
  attempts    int         not null,
  -- Coût cumulé de la génération en dollars — somme des tentatives, et non le
  -- prix du seul modèle gagnant. C'est LE chiffre qui manquait.
  cost_usd    numeric(10,5) not null,
  duration_ms int,
  success     boolean     not null
);

create index if not exists generation_costs_created_at_idx
  on public.generation_costs (created_at desc);

-- Écriture réservée au service role (l'Edge Function). Aucune lecture cliente :
-- comptabilité interne, pas du contenu utilisateur.
alter table public.generation_costs enable row level security;

comment on table public.generation_costs is
  'Cout reel par generation IA - une ligne par appel a tryon-generate, alimentee par l Edge Function via le service role.';
