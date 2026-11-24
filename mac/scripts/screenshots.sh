#!/bin/bash
# Régénère les images du README dans docs/images, hors écran (rien ne s'affiche).
#   - la fenêtre des réglages, rendue depuis la vraie vue SwiftUI, en clair et en sombre ;
#   - les illustrations (hero, social, how-it-works) depuis leurs SVG, avec rsvg-convert (brew install librsvg).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT="../docs/images"

# Le bundle porte les .lproj : on le construit, puis un ordre explicite rend les captures en anglais,
# comme le README, quel que soit la langue du Mac.
./scripts/build-app.sh >/dev/null
"build/Glisse.app/Contents/MacOS/Glisse" --screenshots "$OUT" -AppleLanguages "(en)"

if command -v rsvg-convert >/dev/null; then
  for svg in "$OUT"/src/*.svg; do
    name="$(basename "${svg%.svg}")"
    rsvg-convert --zoom 2 "$svg" -o "$OUT/$name.png"
    echo "==> $OUT/$name.png"
  done
  # L'aperçu social de GitHub doit faire 1280 × 640.
  sips -z 640 1280 "$OUT/social.png" >/dev/null
else
  echo "rsvg-convert absent : les illustrations SVG ne sont pas regénérées (brew install librsvg)"
fi
