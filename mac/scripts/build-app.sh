#!/bin/bash
# Compile en release et assemble build/Glisse.app.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Compilation (release)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

APP="build/Glisse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/GlisseApp" "$APP/Contents/MacOS/Glisse"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>fr</string>
  <key>CFBundleIdentifier</key>
  <string>io.snouzy.glisse</string>
  <key>CFBundleName</key>
  <string>Glisse</string>
  <key>CFBundleExecutable</key>
  <string>Glisse</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
</dict>
</plist>
PLIST

# Signature : Developer ID si disponible (l'autorisation Accessibilité survit alors aux recompilations),
# sinon ad hoc. Forcer une identité : SIGN_IDENTITY="…" ./scripts/build-app.sh
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)}"
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  echo "==> Signature : $IDENTITY"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  echo "==> Signature ad hoc (l'autorisation Accessibilité sera redemandée à chaque compilation)"
  codesign --force --sign - "$APP"
fi
echo "OK : $APP"
