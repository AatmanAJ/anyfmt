#!/usr/bin/env bash
# make dmg: Release build → signed app → styled DMG (background + Applications
# alias) → signed + notarized + stapled when credentials exist.
#
# Environment (all optional; without them the DMG is ad-hoc signed, see BLOCKERS.md B-002):
#   DEVELOPER_ID      "Developer ID Application: Name (TEAMID)"
#   TEAM_ID           Apple team id
#   NOTARY_PROFILE    notarytool keychain profile (xcrun notarytool store-credentials)
#   DMG_LAYOUT=0      skip the Finder AppleScript layout (headless CI)
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="$(sed -n 's/^BRAND_NAME = //p' Config/Brand.xcconfig)"
VERSION="$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig)"
DERIVED="$PWD/build/DerivedData"
OUT="$PWD/dist"
APP="$DERIVED/Build/Products/Release/$NAME.app"
DMG="$OUT/$NAME-$VERSION.dmg"
mkdir -p "$OUT"

sign_args=(CODE_SIGN_IDENTITY=- OTHER_CODE_SIGN_FLAGS=--timestamp=none)
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  sign_args=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" DEVELOPMENT_TEAM="${TEAM_ID:-}" OTHER_CODE_SIGN_FLAGS=--timestamp HALO_HARDENED_RUNTIME=YES)
  echo "▸ signing with $DEVELOPER_ID"
else
  echo "▸ no DEVELOPER_ID: building ad-hoc signed (not notarizable)"
fi

echo "▸ build Release"
xcodegen generate --quiet
xcodebuild -project Halo.xcodeproj -derivedDataPath "$DERIVED" -scheme Halo -configuration Release \
  "${sign_args[@]}" build -quiet

echo "▸ verify signatures"
codesign --verify --deep --strict --verbose=1 "$APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|flags|TeamIdentifier" || true

echo "▸ stage"
STAGE="$(mktemp -d)/$NAME"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
swift packaging/dmg/make-background.swift "$STAGE/.background" "$NAME" >/dev/null
tiffutil -cathidpicheck "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png" \
  -out "$STAGE/.background/background.tiff" >/dev/null 2>&1
rm "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png"

echo "▸ create image"
RW="$(mktemp -d)/rw.dmg"
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 40 ))
hdiutil create -quiet -srcfolder "$STAGE" -volname "$NAME" -fs HFS+ -format UDRW -size "${SIZE_MB}m" "$RW"
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')"

if [[ "${DMG_LAYOUT:-1}" == "1" ]]; then
  echo "▸ Finder layout"
  timeout 60 osascript <<EOF || echo "  (layout skipped: Finder scripting unavailable)"
tell application "Finder"
  tell disk "$(basename "$MOUNT")"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 12
    set background picture of opts to file ".background:background.tiff"
    set position of item "$NAME.app" of container window to {165, 195}
    set position of item "Applications" of container window to {495, 195}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
fi
chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach -quiet "$MOUNT" || hdiutil detach -force -quiet "$MOUNT"

echo "▸ compress"
rm -f "$DMG"
hdiutil convert -quiet "$RW" -format ULFO -o "$DMG"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "▸ notarize"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl -a -t open --context context:primary-signature -v "$DMG"
  else
    echo "▸ NOTARY_PROFILE not set: signed but not notarized"
  fi
fi

APP_MB="$(du -sm "$APP" | cut -f1)"
DMG_MB="$(du -sm "$DMG" | cut -f1)"
echo "✓ $DMG  (app ${APP_MB} MB on disk, dmg ${DMG_MB} MB)"
