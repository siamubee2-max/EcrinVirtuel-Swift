-- ============================================================
-- L'Écrin Virtuel — Migration 002
-- Catalogue vêtements hommes/femmes pour essais de look
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── CLOTHING CATALOG ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clothing_catalog (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          TEXT NOT NULL,
    gender        TEXT CHECK (gender IN ('femme','homme','unisexe')) NOT NULL,
    category      TEXT NOT NULL,   -- top/bottom/dress/jacket/coat/shoes/bag/accessory
    subcategory   TEXT,            -- ex: "chemise", "jean", "robe cocktail"
    brand         TEXT,
    color         TEXT,
    material      TEXT,
    style_tags    TEXT[],          -- ["casual","chic","sport","soirée"]
    season        TEXT[],          -- ["printemps","été","automne","hiver"]
    image_url     TEXT,
    try_on_prompt TEXT NOT NULL,
    is_featured   BOOLEAN DEFAULT false,
    partner_id    UUID REFERENCES partner_brands(id),
    price_eur     DECIMAL(8,2),
    purchase_url  TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE clothing_catalog ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clothing catalog is public" ON clothing_catalog
    FOR SELECT USING (true);

-- ─── INDEX PERFORMANCES ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_clothing_gender   ON clothing_catalog (gender);
CREATE INDEX IF NOT EXISTS idx_clothing_category ON clothing_catalog (category);
CREATE INDEX IF NOT EXISTS idx_clothing_featured ON clothing_catalog (is_featured);

-- ─── DONNÉES SAMPLE (60 articles) ────────────────────────────

-- FEMME — Hauts (8)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Chemise Blanche Col V', 'femme', 'top', 'chemise', 'Sandro', 'blanc', 'soie', ARRAY['classique','bureau','chic'], ARRAY['printemps','automne'], 'wearing a crisp white V-neck silk shirt, soft drape, collar open, fashion editorial, neutral studio background', true, 189.00),
('Blouse Soie Ivoire', 'femme', 'top', 'blouse', 'IRO', 'ivoire', 'soie lavée', ARRAY['romantique','soirée','élégant'], ARRAY['printemps','été'], 'wearing a flowing ivory silk blouse with delicate buttons, lightweight fabric catching light softly, luxury fashion portrait', false, 245.00),
('Top Crop Noir', 'femme', 'top', 'crop top', 'Zara', 'noir', 'jersey', ARRAY['casual','sport','tendance'], ARRAY['été','printemps'], 'wearing a fitted black crop top, smooth fabric, modern streetwear look, editorial photography', false, 29.99),
('Pull Cachemire Beige', 'femme', 'top', 'pull', 'Officine Générale', 'beige', 'cachemire 100%', ARRAY['cozy','classique','hiver'], ARRAY['automne','hiver'], 'wearing a luxurious beige cashmere sweater, relaxed fit, warm texture visible, elegant casual fashion editorial', true, 420.00),
('Chemisier Fleuri', 'femme', 'top', 'chemisier', 'Rouje', 'multicolore', 'viscose', ARRAY['romantique','printanier','casual'], ARRAY['printemps','été'], 'wearing a floral print chiffon blouse with small colorful flowers, lightweight, feminine silhouette, natural light photography', false, 115.00),
('Body Noir', 'femme', 'top', 'body', 'Wolford', 'noir', 'microfibre', ARRAY['soirée','chic','tendance'], ARRAY['printemps','automne','hiver'], 'wearing a sleek black bodysuit with clean neckline, smooth fitted fabric, fashion editorial, high contrast lighting', false, 135.00),
('T-Shirt Oversize Blanc', 'femme', 'top', 't-shirt', 'Toteme', 'blanc', 'coton organique', ARRAY['casual','minimaliste','tendance'], ARRAY['printemps','été'], 'wearing a relaxed oversized white organic cotton t-shirt, dropped shoulders, effortlessly chic casual look, clean studio', false, 95.00),
('Blouse Romantique Écru', 'femme', 'top', 'blouse', 'Réalisation Par', 'écru', 'soie georgette', ARRAY['romantique','féminin','soirée'], ARRAY['printemps','été'], 'wearing a romantic écru georgette blouse with ruffled collar and puffed sleeves, dreamy feminine silhouette, soft natural light', true, 195.00);

-- FEMME — Bas (7)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Jean Slim Bleu', 'femme', 'bottom', 'jean', 'Frame', 'bleu indigo', 'denim stretch', ARRAY['casual','classique','quotidien'], ARRAY['printemps','automne','hiver'], 'wearing slim fit dark indigo jeans, tailored straight leg, polished casual look, full body fashion editorial photography', false, 220.00),
('Jupe Midi Plissée Verte', 'femme', 'bottom', 'jupe', 'Jacquemus', 'vert sauge', 'satin', ARRAY['élégant','soirée','chic'], ARRAY['printemps','été'], 'wearing a sage green pleated satin midi skirt, flowing movement, feminine silhouette, luxury fashion editorial, studio lighting', true, 350.00),
('Pantalon Tailleur Noir', 'femme', 'bottom', 'pantalon', 'The Row', 'noir', 'laine crépon', ARRAY['bureau','classique','chic'], ARRAY['automne','hiver','printemps'], 'wearing elegant black tailored wool trousers with a sharp crease, wide leg silhouette, power dressing, editorial fashion portrait', false, 680.00),
('Short en Jean', 'femme', 'bottom', 'short', 'Agolde', 'bleu clair', 'denim vintage', ARRAY['casual','été','tendance'], ARRAY['été'], 'wearing light blue vintage denim shorts, slightly distressed, relaxed summer style, natural outdoor light photography', false, 185.00),
('Jupe Crayon Bordeaux', 'femme', 'bottom', 'jupe', 'Roland Mouret', 'bordeaux', 'laine stretch', ARRAY['bureau','chic','soirée'], ARRAY['automne','hiver'], 'wearing a burgundy wool-blend pencil skirt, fitted silhouette below knee, sophisticated business chic, editorial photography', true, 490.00),
('Legging Noir', 'femme', 'bottom', 'legging', 'Alo Yoga', 'noir', 'nylon technique', ARRAY['sport','casual','confort'], ARRAY['printemps','automne','hiver'], 'wearing sleek black high-waist athletic leggings, smooth compression fabric, sporty chic look, fitness editorial photography', false, 128.00),
('Pantalon Palazzo Beige', 'femme', 'bottom', 'pantalon', 'Toteme', 'beige', 'laine', ARRAY['chic','confort','soirée'], ARRAY['automne','hiver'], 'wearing wide-leg beige palazzo trousers in flowing wool, dramatic volume, elegant drape, luxury fashion editorial, full body shot', true, 495.00);

-- FEMME — Robes (6)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Robe Cocktail Noire', 'femme', 'dress', 'robe cocktail', 'Saint Laurent', 'noir', 'crêpe', ARRAY['soirée','élégant','luxe'], ARRAY['automne','hiver'], 'wearing a sleek black cocktail dress, midi length, architectural cut, luxury fashion editorial, dramatic studio lighting', true, 1650.00),
('Robe Midi Fleurie', 'femme', 'dress', 'robe midi', 'Rouje', 'multicolore', 'viscose imprimée', ARRAY['romantique','printanier','casual'], ARRAY['printemps','été'], 'wearing a floral print midi dress with v-neckline, button front, feminine silhouette, natural outdoor light, Parisian style', false, 195.00),
('Robe Soirée Dorée', 'femme', 'dress', 'robe longue', 'Galvan', 'or', 'sequins', ARRAY['gala','luxe','soirée'], ARRAY['automne','hiver'], 'wearing a floor-length gold sequin evening gown, sparkling light reflections, glamorous red carpet look, luxury fashion photography', true, 1200.00),
('Robe Bohème Blanche', 'femme', 'dress', 'robe longue', 'Reformation', 'blanc cassé', 'lin', ARRAY['bohème','été','mariage','féminin'], ARRAY['printemps','été'], 'wearing a flowing white linen maxi dress, relaxed boho silhouette, natural fabric texture, outdoor golden hour photography', false, 298.00),
('Robe Portefeuille Rouge', 'femme', 'dress', 'robe portefeuille', 'Diane Von Furstenberg', 'rouge', 'jersey de soie', ARRAY['chic','bureau','soirée'], ARRAY['printemps','automne'], 'wearing a classic red wrap dress in silk jersey, V-neckline, belted waist, timeless feminine silhouette, fashion editorial', true, 495.00),
('Mini Robe en Jean', 'femme', 'dress', 'robe courte', 'Agolde', 'bleu moyen', 'denim', ARRAY['casual','été','tendance'], ARRAY['été','printemps'], 'wearing a denim mini dress with button front, casual summer style, easy-going silhouette, natural sunlight photography', false, 245.00);

-- FEMME — Vestes/Manteaux (4)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Blazer Blanc', 'femme', 'jacket', 'blazer', 'Frankie Shop', 'blanc', 'sergé', ARRAY['bureau','chic','tendance'], ARRAY['printemps','automne'], 'wearing an oversized white blazer with bold shoulders, clean lapels, power dressing editorial, neutral background, full body shot', true, 290.00),
('Trench Camel', 'femme', 'coat', 'trench-coat', 'Burberry', 'camel', 'gabardine coton', ARRAY['classique','luxe','printemps'], ARRAY['printemps','automne'], 'wearing a classic camel trench coat, belted, iconic collar up, luxury fashion editorial, rain-slicked urban street scene', true, 1990.00),
('Veste en Cuir Noir', 'femme', 'jacket', 'veste en cuir', 'AllSaints', 'noir', 'cuir agneau', ARRAY['rock','casual','tendance'], ARRAY['automne','hiver','printemps'], 'wearing a fitted black lamb leather moto jacket, zipped details, edgy chic look, dark fashion editorial photography', false, 449.00),
('Manteau Laine Gris', 'femme', 'coat', 'manteau', 'Max Mara', 'gris clair', 'laine vierge', ARRAY['luxe','classique','hiver'], ARRAY['automne','hiver'], 'wearing an elegant light grey pure wool coat, clean straight cut, minimal buttons, sophisticated winter fashion editorial', true, 2400.00);

-- FEMME — Chaussures (5)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Escarpins Nude', 'femme', 'shoes', 'escarpins', 'Gianvito Rossi', 'nude', 'suède', ARRAY['élégant','bureau','soirée'], ARRAY['printemps','automne'], 'wearing nude suede pointed-toe pumps with 9cm stiletto heel, elongating the leg, luxury fashion shoe photography, clean white background', true, 620.00),
('Bottes Cuissardes Noires', 'femme', 'shoes', 'bottes', 'Stuart Weitzman', 'noir', 'cuir', ARRAY['hiver','soirée','chic'], ARRAY['automne','hiver'], 'wearing sleek black over-the-knee leather boots, high flat heel, editorial fashion photography, full leg visible, dramatic lighting', false, 895.00),
('Sneakers Blanches', 'femme', 'shoes', 'sneakers', 'Golden Goose', 'blanc', 'cuir', ARRAY['casual','tendance','luxe casual'], ARRAY['printemps','été','automne'], 'wearing pristine white leather sneakers with subtle star logo, classic low-top, effortless luxe casual style, clean shoe photography', false, 445.00),
('Sandales Dorées', 'femme', 'shoes', 'sandales', 'Ancient Greek Sandals', 'or', 'cuir doré', ARRAY['été','soirée','fête'], ARRAY['été'], 'wearing strappy gold leather gladiator sandals, elegant ankle wrap, Mediterranean summer luxury, foot detail photography', true, 265.00),
('Mules en Daim Camel', 'femme', 'shoes', 'mules', 'Khaite', 'camel', 'daim', ARRAY['casual chic','bureau','printemps'], ARRAY['printemps','automne'], 'wearing camel suede mule shoes with chunky square heel, understated luxury, editorial shoe photography, profile view', false, 580.00);

-- HOMME — Hauts (7)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Chemise Oxford Blanche', 'homme', 'top', 'chemise', 'Sunspel', 'blanc', 'oxford coton', ARRAY['bureau','classique','casual chic'], ARRAY['printemps','automne'], 'wearing a classic white Oxford cotton shirt, collar slightly open, relaxed tuck, clean masculine fashion editorial photography', true, 145.00),
('Polo Bleu Marine', 'homme', 'top', 'polo', 'Lacoste', 'bleu marine', 'piqué coton', ARRAY['classique','casual','preppy'], ARRAY['printemps','été'], 'wearing a classic navy blue Lacoste piqué polo shirt, fitted but relaxed, quintessential casual chic menswear photography', false, 110.00),
('T-Shirt Gris Chiné', 'homme', 'top', 't-shirt', 'Aimé Leon Dore', 'gris chiné', 'coton heavy-weight', ARRAY['casual','streetwear','quotidien'], ARRAY['printemps','été','automne'], 'wearing a heather grey heavyweight cotton crew neck t-shirt, relaxed fit, subtle texture, casual menswear editorial photography', false, 75.00),
('Chemise Lin Bleu', 'homme', 'top', 'chemise', 'Officine Générale', 'bleu ciel', 'lin lavé', ARRAY['casual','été','vacances'], ARRAY['printemps','été'], 'wearing a relaxed light blue washed linen shirt, slightly rumpled, one button open at collar, summer vacation editorial photography', false, 195.00),
('Pull Col Roulé Noir', 'homme', 'top', 'pull', 'A.P.C.', 'noir', 'laine mérinos', ARRAY['chic','hiver','artistique'], ARRAY['automne','hiver'], 'wearing a slim fit black merino wool turtleneck sweater, intellectual chic aesthetic, clean menswear editorial photography', true, 245.00),
('Sweat Gris Oversize', 'homme', 'top', 'sweatshirt', 'Aimé Leon Dore', 'gris', 'molleton coton', ARRAY['casual','streetwear','confort'], ARRAY['automne','hiver','printemps'], 'wearing an oversized heather grey fleece crewneck sweatshirt, dropped shoulders, relaxed street style, urban fashion editorial', false, 185.00),
('Chemise À Carreaux', 'homme', 'top', 'chemise', 'Gitman Vintage', 'rouge/bleu', 'flanelle coton', ARRAY['casual','automne','worker chic'], ARRAY['automne','hiver'], 'wearing a red and blue plaid flannel overshirt, slightly open over t-shirt, rugged casual style, warm toned editorial photography', false, 175.00);

-- HOMME — Bas (5)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Jean Slim Noir', 'homme', 'bottom', 'jean', 'A.P.C.', 'noir', 'denim rigide', ARRAY['classique','chic','versatile'], ARRAY['printemps','automne','hiver'], 'wearing slim fit raw black denim jeans, clean lines, minimal styling, sharp menswear editorial photography, full body', true, 220.00),
('Chino Beige', 'homme', 'bottom', 'chino', 'Incotex', 'beige sable', 'coton gabardine', ARRAY['bureau','casual chic','preppy'], ARRAY['printemps','été','automne'], 'wearing tailored beige cotton chino trousers, slim but not tight, polished casual look, clean menswear editorial', false, 280.00),
('Pantalon Costume Gris', 'homme', 'bottom', 'pantalon de costume', 'Boglioli', 'gris anthracite', 'laine', ARRAY['bureau','formel','luxe'], ARRAY['automne','hiver'], 'wearing tailored charcoal grey wool suit trousers, sharp crease, sophisticated business attire, luxury menswear editorial', true, 580.00),
('Short Cargo Kaki', 'homme', 'bottom', 'short', 'Carhartt WIP', 'kaki', 'canvas coton', ARRAY['casual','été','outdoor'], ARRAY['été'], 'wearing khaki cargo shorts with side pockets, relaxed summer style, functional workwear aesthetic, casual street photography', false, 95.00),
('Jean Déchiré Bleu', 'homme', 'bottom', 'jean', 'Saint Laurent', 'bleu moyen', 'denim', ARRAY['rock','casual','tendance'], ARRAY['printemps','automne'], 'wearing ripped blue denim jeans, authentic distressing, slim fit with knee tears, rock chic menswear editorial', false, 490.00);

-- HOMME — Vestes/Manteaux (4)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Blazer Navy', 'homme', 'jacket', 'blazer', 'Suitsupply', 'bleu marine', 'laine', ARRAY['bureau','élégant','versatile'], ARRAY['printemps','automne'], 'wearing a tailored navy blue wool blazer, single button, notched lapel, smart casual menswear editorial, full body photography', true, 449.00),
('Bomber Kaki', 'homme', 'jacket', 'bomber', 'Alpha Industries', 'kaki', 'nylon', ARRAY['casual','streetwear','tendance'], ARRAY['printemps','automne'], 'wearing an olive green nylon bomber jacket, iconic silhouette, ribbed collar and cuffs, street style menswear editorial', false, 165.00),
('Veste Cuir Marron', 'homme', 'jacket', 'veste en cuir', 'Schott NYC', 'marron cognac', 'cuir bison', ARRAY['rock','classique','automne'], ARRAY['automne','hiver'], 'wearing a brown leather biker jacket, double buckle strap, slightly vintage patina, rugged masculine fashion editorial', true, 895.00),
('Doudoune Noire', 'homme', 'coat', 'doudoune', 'Moncler', 'noir', 'nylon/duvet', ARRAY['hiver','luxe','sport chic'], ARRAY['hiver'], 'wearing a sleek black quilted down puffer jacket, logo badge on sleeve, refined sporty luxury look, winter fashion editorial', false, 850.00);

-- HOMME — Chaussures (4)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Derby Noirs', 'homme', 'shoes', 'derby', 'Crockett & Jones', 'noir', 'cuir box calf', ARRAY['formel','bureau','luxe'], ARRAY['automne','hiver'], 'wearing classic black leather Oxford derby shoes, mirror shine on toe cap, white socks above ankle visible, luxury shoe photography', true, 520.00),
('Sneakers Blanches Homme', 'homme', 'shoes', 'sneakers', 'Common Projects', 'blanc', 'cuir pleine fleur', ARRAY['casual','luxe casual','minimaliste'], ARRAY['printemps','été','automne'], 'wearing minimalist white leather low-top sneakers with gold serial number, clean silhouette, luxury casual menswear shoe photography', true, 495.00),
('Mocassins Marron', 'homme', 'shoes', 'mocassins', 'Gucci', 'marron cognac', 'cuir', ARRAY['chic','casual','classique'], ARRAY['printemps','automne'], 'wearing rich brown leather Gucci horsebit loafers, no socks style, Riviera summer chic, Italian luxury shoe photography', false, 780.00),
('Boots Chelsea Noires', 'homme', 'shoes', 'boots', 'R.M. Williams', 'noir', 'cuir vachette', ARRAY['classique','chic','versatile'], ARRAY['automne','hiver'], 'wearing black leather Chelsea boots with elastic side panels, rounded toe, clean menswear editorial, ankle height visible', false, 550.00);

-- UNISEXE (10)
INSERT INTO clothing_catalog (name, gender, category, subcategory, brand, color, material, style_tags, season, try_on_prompt, is_featured, price_eur) VALUES
('Hoodie Gris Chiné', 'unisexe', 'top', 'hoodie', 'Champion', 'gris chiné', 'molleton coton', ARRAY['casual','streetwear','confort'], ARRAY['automne','hiver'], 'wearing a classic heather grey pullover hoodie, relaxed fit, drawstring visible, casual streetwear editorial photography, neutral background', false, 85.00),
('Trench Oversize Beige', 'unisexe', 'coat', 'trench-coat', 'Acne Studios', 'beige', 'coton', ARRAY['oversized','tendance','minimaliste'], ARRAY['printemps','automne'], 'wearing a voluminous oversized beige cotton trench coat, dramatic proportions, architectural minimalism, editorial fashion photography', true, 890.00),
('Parka Kaki', 'unisexe', 'coat', 'parka', 'Canada Goose', 'kaki vert', 'nylon/duvet', ARRAY['outdoor','hiver','fonctionnel'], ARRAY['automne','hiver'], 'wearing a versatile khaki green parka with removable inner liner, utility pockets, functional outdoor fashion photography', false, 750.00),
('Sneakers High-Top Blanc', 'unisexe', 'shoes', 'sneakers', 'Converse', 'blanc', 'canvas coton', ARRAY['casual','classique','intemporel'], ARRAY['printemps','été','automne'], 'wearing white canvas high-top Chuck Taylor All Stars, laces tied, classic casual style, clean shoe photography against neutral background', false, 90.00),
('Casquette Noire', 'unisexe', 'accessory', 'casquette', 'New Era', 'noir', 'laine acrylique', ARRAY['casual','streetwear','sport'], ARRAY['printemps','été','automne'], 'person wearing a black fitted baseball cap, brim forward, streetwear look, portrait photography, urban background', false, 40.00),
('Lunettes de Soleil Noires', 'unisexe', 'accessory', 'lunettes de soleil', 'Ray-Ban', 'noir', 'acétate', ARRAY['classique','été','intemporel'], ARRAY['printemps','été'], 'person wearing classic black Wayfarer sunglasses, iconic style, portrait photography, natural outdoor light, effortlessly cool', false, 185.00),
('Ceinture Cuir Noire', 'unisexe', 'accessory', 'ceinture', 'Hermès', 'noir', 'cuir box calf', ARRAY['classique','luxe','versatile'], ARRAY['printemps','automne','hiver'], 'person wearing a black leather belt with classic H buckle, waist detail shot, luxury accessory photography, clean studio', true, 490.00),
('Sac à Dos Noir', 'unisexe', 'bag', 'sac à dos', 'Cote&Ciel', 'noir', 'nylon technique', ARRAY['urbain','fonctionnel','design'], ARRAY['printemps','automne','hiver'], 'person wearing a sleek black technical backpack over one shoulder, minimal design, urban professional look, city background', false, 195.00),
('Bonnet Beige', 'unisexe', 'accessory', 'bonnet', 'Norse Projects', 'beige', 'laine mérinos', ARRAY['hiver','casual','cozy'], ARRAY['automne','hiver'], 'person wearing a chunky beige merino wool beanie, relaxed slouch, cozy winter styling, soft natural light portrait photography', false, 55.00),
('Écharpe Cachemire Grise', 'unisexe', 'accessory', 'écharpe', 'Loro Piana', 'gris perle', 'cachemire pur', ARRAY['luxe','hiver','classique'], ARRAY['automne','hiver'], 'person wearing a soft grey pure cashmere scarf loosely draped around neck, luxurious texture, warmth and elegance, editorial portrait', true, 680.00);
