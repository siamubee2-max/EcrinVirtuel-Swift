#!/usr/bin/env bash
# Vérifie que le numéro de build commité dans le .xcodeproj correspond à
# project.yml.
#
# project.pbxproj est GÉNÉRÉ par XcodeGen mais quand même versionné : c'est
# lui qu'utilisent la CI et tout développeur qui compile sans relancer
# `xcodegen generate`. Modifier CURRENT_PROJECT_VERSION dans project.yml sans
# régénérer laisse donc les deux fichiers en désaccord, en silence — et c'est
# le .xcodeproj qui gagne.
#
# Le symptôme est cruel : l'archive part avec l'ANCIEN numéro, et App Store
# Connect refuse l'upload pour doublon alors que project.yml affiche bien le
# nouveau. Arrivé le 18/09/2026 en passant de 10023 à 10024.
#
# Usage :  ./scripts/check-build-number-sync.sh

set -euo pipefail

cd "$(dirname "$0")/.."

PBXPROJ="EcrinVirtuel.xcodeproj/project.pbxproj"

yml=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml \
      | sed 's/.*CURRENT_PROJECT_VERSION:[[:space:]]*//' | tr -d '"'"'"' ')

if [[ -z "$yml" ]]; then
    echo "✗ CURRENT_PROJECT_VERSION introuvable dans project.yml" >&2
    exit 1
fi

mapfile -t pbx < <(grep 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" \
                   | sed 's/.*= *//' | tr -d ' ;')

if [[ ${#pbx[@]} -eq 0 ]]; then
    echo "✗ CURRENT_PROJECT_VERSION introuvable dans $PBXPROJ" >&2
    exit 1
fi

bad=0
for v in "${pbx[@]}"; do
    [[ "$v" == "$yml" ]] || bad=1
done

if [[ $bad -eq 1 ]]; then
    echo "✗ numéro de build désynchronisé" >&2
    echo "    project.yml      : $yml" >&2
    echo "    $PBXPROJ : ${pbx[*]}" >&2
    echo >&2
    echo "  Le .xcodeproj commité fait foi pour la CI et pour qui compile sans" >&2
    echo "  régénérer. Relance 'xcodegen generate' puis" >&2
    echo "  './scripts/fix-storekit-scheme-path.sh', et commite le .xcodeproj." >&2
    exit 1
fi

echo "✓ numéro de build synchronisé : $yml"
