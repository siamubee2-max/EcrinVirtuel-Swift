#!/usr/bin/env bash
# Déploie tryon-generate sur Supabase (projet L'Écrin Virtuel).
# Prérequis : CLI Supabase authentifiée.
set -euo pipefail

PROJECT_REF="itjtshfzpknlzownpwte"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"

if ! command -v supabase >/dev/null 2>&1; then
  echo "❌ supabase CLI introuvable. Installez : brew install supabase/tap/supabase"
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]] && ! supabase projects list >/dev/null 2>&1; then
  echo "❌ Non authentifié. Exécutez une fois (interactif) :"
  echo "   supabase login"
  echo "   # ou export SUPABASE_ACCESS_TOKEN=<token depuis https://supabase.com/dashboard/account/tokens>"
  exit 1
fi

echo "→ Déploiement tryon-generate sur $PROJECT_REF …"
supabase functions deploy tryon-generate --project-ref "$PROJECT_REF"

echo ""
echo "→ Vérification JWT (sans token → 401 attendu) :"
HTTP=$(curl -s -o /tmp/tryon-test.json -w "%{http_code}" -X POST \
  "https://${PROJECT_REF}.supabase.co/functions/v1/tryon-generate" \
  -H "Content-Type: application/json" \
  -d '{"imageBase64":"eA==","prompt":"test"}')
echo "   HTTP $HTTP — $(head -c 120 /tmp/tryon-test.json)"
if [[ "$HTTP" != "401" ]]; then
  echo "⚠️  Attendu 401 sans Bearer JWT."
fi

echo ""
echo "Secrets requis (Dashboard → Edge Functions → Secrets) :"
echo "  GOOGLE_API_KEY, OPENAI_API_KEY"
echo "https://supabase.com/dashboard/project/${PROJECT_REF}/functions/secrets"
echo ""
echo "✅ Déploiement terminé."
