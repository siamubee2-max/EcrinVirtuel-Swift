#!/usr/bin/env bash
# Deploy web/public/ecrin/ to the VPS that serves inferencevision.store.
# Usage (from the repo root, on a machine that has SSH access to the VPS):
#   ./scripts/deploy-site-ecrin.sh root@72.62.17.184
# It finds the live /ecrin folder on the server (the one that holds privacy.html),
# makes a dated backup next to it, then copies the files. Nothing else is touched:
# no nginx change, no restart.
set -euo pipefail

TARGET="${1:?usage: $0 user@host}"
SRC="$(cd "$(dirname "$0")/.." && pwd)/web/public/ecrin"
[ -f "$SRC/index.html" ] || { echo "missing $SRC/index.html" >&2; exit 1; }

REMOTE_DIR="$(ssh "$TARGET" 'find /var/www /usr/share/nginx /srv /home /opt /root -type f -path "*/ecrin/privacy.html" -not -path "*/node_modules/*" 2>/dev/null | head -5')"
COUNT="$(printf '%s\n' "$REMOTE_DIR" | grep -c . || true)"
if [ "$COUNT" -ne 1 ]; then
  echo "Expected exactly one live ecrin/privacy.html on the server, found $COUNT:" >&2
  printf '%s\n' "$REMOTE_DIR" >&2
  echo "Pass the folder yourself: REMOTE_ECRIN=/path/to/ecrin $0 $TARGET" >&2
  [ -n "${REMOTE_ECRIN:-}" ] || exit 1
fi
REMOTE_ECRIN="${REMOTE_ECRIN:-$(dirname "$REMOTE_DIR")}"

echo "Deploying to $TARGET:$REMOTE_ECRIN"
ssh "$TARGET" "cp -a '$REMOTE_ECRIN' '$REMOTE_ECRIN.bak-$(date +%Y%m%d-%H%M%S)'"
scp "$SRC/index.html" "$SRC/privacy.html" "$SRC/terms.html" "$SRC/support.html" "$TARGET:$REMOTE_ECRIN/"
ssh "$TARGET" "mkdir -p '$REMOTE_ECRIN/gift'"
scp "$SRC/gift/index.html" "$TARGET:$REMOTE_ECRIN/gift/index.html"

for path in "" privacy.html terms.html support.html gift/; do
  printf '%s -> ' "https://inferencevision.store/ecrin/$path"
  curl -s -o /dev/null -w '%{http_code}\n' "https://inferencevision.store/ecrin/$path"
done
curl -s https://inferencevision.store/ecrin/ | grep -q "id6760768389" && echo "App Store button is live." || echo "WARNING: App Store button not found on the live page." >&2
