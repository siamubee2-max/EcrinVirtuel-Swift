-- Migration 003 — Table user_quotas pour comptage serveur des générations
-- Obligatoire pour empêcher le bypass du paywall (compteur iOS-only bypassable)

CREATE TABLE IF NOT EXISTS public.user_quotas (
    user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_type    TEXT NOT NULL DEFAULT 'free' CHECK (plan_type IN ('free','starter','premium','elite','founder')),
    generations_remaining INT NOT NULL DEFAULT 3,
    generations_used_total INT NOT NULL DEFAULT 0,
    reset_at     TIMESTAMPTZ,  -- prochaine réinitialisation mensuelle (NULL = plan free sans reset)
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour les lookups fréquents
CREATE INDEX IF NOT EXISTS idx_user_quotas_user_id ON public.user_quotas(user_id);

-- RLS : chaque utilisateur voit uniquement ses propres quotas
ALTER TABLE public.user_quotas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own quota" ON public.user_quotas
    FOR SELECT USING (auth.uid() = user_id);

-- La mise à jour du quota est faite par l'Edge Function avec service_role (bypass RLS)
-- Pas de politique UPDATE pour les utilisateurs normaux

-- Trigger : mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_quota_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER quota_updated_at
    BEFORE UPDATE ON public.user_quotas
    FOR EACH ROW EXECUTE FUNCTION update_quota_timestamp();

-- Quotas initiaux pour les plans RevenueCat
-- Ces valeurs sont gérées par un webhook RevenueCat → Supabase Edge Function
-- Voir supabase/functions/revenuecat-webhook/ (à créer)
COMMENT ON TABLE public.user_quotas IS
    'Quotas mensuels de générations IA par utilisateur.
     Mis à jour par Edge Function tryon-generate (décrémentation)
     et revenuecat-webhook (upgrade/renouvellement).
     free=3, starter=20/mois, premium=60/mois, elite=500/mois, founder=illimité (999999)';
