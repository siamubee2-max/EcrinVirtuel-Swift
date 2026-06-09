-- Genre vestimentaire pour Look du Jour (Phase 5 spec météo)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS preferred_gender TEXT
  CHECK (preferred_gender IN ('femme', 'homme', 'unisexe'));

COMMENT ON COLUMN users.preferred_gender IS 'Genre pour recommandations Look du Jour (femme/homme/unisexe)';
