#!/usr/bin/env bash
# Packs the command-line tool from the Release app into the tarball the
# `anyfmt-cli` Homebrew formula installs (layout in anyfmt-cli.rb), and prints
# the SHA-256 of it and of the DMG for the tap.
#
# Usage: packaging/homebrew/make-cli-tarball.sh   (after `make dmg`)
set -euo pipefail
cd "$(dirname "$0")/../.."

NAME="$(sed -n 's/^BRAND_NAME = //p' Config/Brand.xcconfig)"
VERSION="$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig)"
APP="build/DerivedData/Build/Products/Release/$NAME.app"
[[ -d "$APP" ]] || { echo "no Release build at $APP; run make dmg first" >&2; exit 1; }

D="$NAME-cli-$VERSION-arm64"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/$D/Helpers" "$STAGE/$D/Frameworks"
for helper in "$NAME" ffmpeg ffprobe resvg; do
  ditto "$APP/Contents/Helpers/$helper" "$STAGE/$D/Helpers/$helper"
done
ditto "$APP/Contents/Frameworks/AnyfmtCore.framework" "$STAGE/$D/Frameworks/AnyfmtCore.framework"
# ffmpeg and ffprobe link the libav* dylibs beside the framework.
for lib in "$APP"/Contents/Frameworks/lib*.dylib; do ditto "$lib" "$STAGE/$D/Frameworks/$(basename "$lib")"; done
cp LICENSE "$STAGE/$D/" && ditto LICENSES "$STAGE/$D/LICENSES"

mkdir -p dist
tar -czf "dist/$D.tar.gz" -C "$STAGE" "$D"
rm -rf "$STAGE"

echo "✓ dist/$D.tar.gz"
echo "cask    sha256 $(shasum -a 256 "dist/$NAME-$VERSION.dmg" 2>/dev/null | cut -d' ' -f1)"
echo "formula sha256 $(shasum -a 256 "dist/$D.tar.gz" | cut -d' ' -f1)"
