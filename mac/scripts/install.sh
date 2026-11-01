#!/bin/bash
# Construit Glisse, l'installe dans ~/Applications et le lance.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
DEST="$HOME/Applications/Glisse.app"

./scripts/build-app.sh

if pgrep -x Glisse >/dev/null; then
  echo "==> Fermeture de Glisse"
  osascript -e 'quit app "Glisse"' >/dev/null 2>&1 || true
  for _ in $(seq 1 25); do pgrep -x Glisse >/dev/null || break; sleep 0.2; done
  pkill -x Glisse 2>/dev/null || true
fi

echo "==> Installation dans $DEST"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/Glisse.app "$DEST"

echo "==> Lancement"
# Juste après la fermeture, LaunchServices refuse parfois d'ouvrir (erreur -600) : on insiste.
for _ in 1 2 3 4 5; do open "$DEST" 2>/dev/null && break; sleep 1; done
