#!/usr/bin/env bash
# Répare le chemin du fichier StoreKit dans le schéma après `xcodegen generate`.
#
# XcodeGen écrit `identifier = "../../EcrinVirtuel.storekit"` dans la
# LaunchAction. Le schéma vit dans
# EcrinVirtuel.xcodeproj/xcshareddata/xcschemes/, donc deux niveaux plus haut
# on tombe sur le bundle .xcodeproj — le chemin désigne
# EcrinVirtuel.xcodeproj/EcrinVirtuel.storekit, qui n'existe pas. Il faut en
# remonter trois pour atteindre la racine du dépôt.
#
# Xcode ne signale RIEN quand cette référence est morte : il lance simplement
# l'app sans configuration StoreKit. Sur simulateur, aucun des produits ne se
# résout, chaque écran retombe sur ses prix codés en dur, et c'est
# indiscernable d'un problème RevenueCat ou App Store Connect. Vérifié le
# 18/09/2026 : la génération réécrit bien le mauvais chemin.
#
# Idempotent : sans effet si le chemin est déjà correct.
#
# Usage :  ./scripts/fix-storekit-scheme-path.sh [--check]
#   --check  ne corrige rien, sort en 1 si le chemin est faux (pour la CI)

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="EcrinVirtuel.xcodeproj/xcshareddata/xcschemes/EcrinVirtuel.xcscheme"
WRONG='identifier = "../../EcrinVirtuel.storekit"'
RIGHT='identifier = "../../../EcrinVirtuel.storekit"'

if [[ ! -f "$SCHEME" ]]; then
    echo "✗ schéma introuvable : $SCHEME" >&2
    exit 1
fi

if [[ ! -f "EcrinVirtuel.storekit" ]]; then
    echo "✗ EcrinVirtuel.storekit absent de la racine du dépôt" >&2
    exit 1
fi

if grep -qF "$RIGHT" "$SCHEME"; then
    echo "✓ chemin StoreKit correct (../../../EcrinVirtuel.storekit)"
    exit 0
fi

if ! grep -qF "$WRONG" "$SCHEME"; then
    echo "✗ aucune référence StoreKit reconnue dans le schéma." >&2
    echo "  Attendu l'une de ces deux lignes :" >&2
    echo "    $WRONG" >&2
    echo "    $RIGHT" >&2
    echo "  Trouvé :" >&2
    grep -n "StoreKitConfigurationFileReference" -A1 "$SCHEME" >&2 || true
    exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
    echo "✗ chemin StoreKit cassé : ../../EcrinVirtuel.storekit" >&2
    echo "  Il pointe vers EcrinVirtuel.xcodeproj/EcrinVirtuel.storekit, qui n'existe pas." >&2
    echo "  Xcode lancera l'app SANS configuration StoreKit, sans rien dire." >&2
    echo "  Corrige avec : ./scripts/fix-storekit-scheme-path.sh" >&2
    exit 1
fi

# sed -i diffère entre BSD (macOS) et GNU : passer par un fichier temporaire.
tmp="$(mktemp)"
sed "s|$WRONG|$RIGHT|" "$SCHEME" > "$tmp"
mv "$tmp" "$SCHEME"

echo "✓ chemin StoreKit corrigé : ../../ → ../../../"
echo "  (XcodeGen le recassera à la prochaine génération — relance ce script)"
