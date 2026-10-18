#!/usr/bin/env bash
# Lane D (Image + PDF) fixtures. Contract: Tests/Fixtures/make-fixtures.sh.
# Writes sample.<ext> for every image/SVG/PDF input lane D ships, plus edge-*.
# ImageIO-encodable formats come from images-fixtures.swift; WebP (and AVIF on
# Macs whose ImageIO can't encode it) from the bundled ffmpeg.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:?OUT must point at the fixtures directory}"
FFMPEG="${FFMPEG:-}"
mkdir -p "$OUT"

# Swift writes its module cache next to the script by default; keep it in a temp dir.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swift -module-cache-path "$tmp/mc" "$here/images-fixtures.swift" "$OUT"

src="$OUT/.images-src.png"
[[ -x "$FFMPEG" ]] || { echo "images.sh: bundled ffmpeg not found at '$FFMPEG'" >&2; exit 1; }
ff() { "$FFMPEG" -hide_banner -nostdin -loglevel error -y "$@"; }

# Still WebP with alpha, and an animated WebP from the 5-frame GIF.
ff -i "$src" -frames:v 1 -c:v libwebp -pix_fmt bgra -quality 85 "$OUT/sample.webp"
ff -i "$OUT/sample.gif" -c:v libwebp_anim -pix_fmt bgra -quality 80 -loop 0 -fps_mode passthrough "$OUT/edge-animated.webp"
if [[ ! -s "$OUT/sample.avif" ]]; then
  ff -i "$src" -frames:v 1 -c:v libaom-av1 -still-picture 1 -crf 30 -cpu-used 8 -pix_fmt yuv420p "$OUT/sample.avif"
fi
rm -f "$src"
