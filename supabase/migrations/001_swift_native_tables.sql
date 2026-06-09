-- ============================================================
-- L'Écrin Virtuel — Migration Swift Native
-- Nouvelles tables pour les features iOS uniquement.
-- Les tables existantes (jewelry, body_parts, try_on_sessions)
-- sont déjà en place sur ce projet Supabase.
-- ============================================================

-- Extension UUID si pas déjà activée
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── USERS (profils étendus) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id       UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    email         TEXT,
    display_name  TEXT,
    avatar_url    TEXT,
    skin_undertone TEXT CHECK (skin_undertone IN ('warm','cool','neutral')),
    skin_depth    TEXT CHECK (skin_depth IN ('fair','light','medium','tan','deep')),
    language      TEXT DEFAULT 'fr',
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own their data" ON users
    USING (auth_id = auth.uid());

-- ─── SAVED LOOKS (Occasion Vault) ────────────────────────────
CREATE TABLE IF NOT EXISTS saved_looks (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    occasion    TEXT NOT NULL,
    jewelry_ids UUID[],
    notes       TEXT,
    is_favorite BOOLEAN DEFAULT false,
    tags        TEXT[],
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE saved_looks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own saved looks" ON saved_looks
    USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ─── WEDDING LOOKS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wedding_looks (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id            UUID REFERENCES users(id) ON DELETE CASCADE,
    name               TEXT NOT NULL DEFAULT 'Mon Mariage',
    wedding_date       DATE,
    pieces             JSONB DEFAULT '[]',
    bridesmaid_emails  TEXT[] DEFAULT '{}',
    is_finalized       BOOLEAN DEFAULT false,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE wedding_looks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own wedding looks" ON wedding_looks
    USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ─── GIFT CARDS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gift_cards (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id    UUID REFERENCES users(id),
    jewelry_id      UUID,
    jewelry_name    TEXT,
    message         TEXT,
    occasion        TEXT,
    share_token     TEXT UNIQUE NOT NULL,
    is_revealed     BOOLEAN DEFAULT false,
    expires_at      TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
-- Pas de RLS sur gift_cards : accessible via share_token public

-- ─── COMMUNITY POSTS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS community_posts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
    jewelry_id   UUID,
    jewelry_name TEXT,
    caption      TEXT,
    image_url    TEXT,
    likes        INTEGER DEFAULT 0,
    challenge_id UUID,
    tags         TEXT[],
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Posts are public" ON community_posts FOR SELECT USING (true);
CREATE POLICY "Users own their posts" ON community_posts
    FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ─── POST LIKES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_likes (
    post_id  UUID REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id  UUID REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
);
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes are public" ON post_likes FOR SELECT USING (true);
CREATE POLICY "Users manage own likes" ON post_likes
    FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ─── COMMUNITY CHALLENGES ────────────────────────────────────
CREATE TABLE IF NOT EXISTS community_challenges (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title             TEXT NOT NULL,
    description       TEXT,
    hashtag           TEXT,
    prize             TEXT,
    end_date          TIMESTAMPTZ,
    participant_count INTEGER DEFAULT 0,
    is_active         BOOLEAN DEFAULT true,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE community_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Challenges are public" ON community_challenges FOR SELECT USING (true);

-- ─── PARTNER BRANDS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS partner_brands (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    tagline         TEXT,
    description     TEXT,
    website_url     TEXT,
    country         TEXT,
    category        TEXT CHECK (category IN ('artisanal','luxe','creator','vintage')),
    is_verified     BOOLEAN DEFAULT false,
    commission_rate DECIMAL(4,2) DEFAULT 0.15,
    monthly_fee     DECIMAL(8,2) DEFAULT 199.00,
    total_sales     INTEGER DEFAULT 0,
    joined_at       TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE partner_brands ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Partner brands are public" ON partner_brands FOR SELECT USING (true);

-- ─── INSERT MONIATTITUDE ─────────────────────────────────────
INSERT INTO partner_brands (name, tagline, description, website_url, country, category, is_verified, commission_rate)
VALUES (
    'Moni''attitude',
    'Bijoux artisanaux & bien-être',
    'Créations artisanales uniques en pierres semi-précieuses. Chaque bijou est une invitation au bien-être et à l''authenticité.',
    'https://www.moniattitude.com',
    'Belgique',
    'artisanal',
    true,
    0.15
) ON CONFLICT DO NOTHING;

-- ─── STORAGE BUCKETS ─────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('tryon-results', 'tryon-results', false)
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('gift-previews', 'gift-previews', false)
ON CONFLICT DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('community-posts', 'community-posts', true)
ON CONFLICT DO NOTHING;
