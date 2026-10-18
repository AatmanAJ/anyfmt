#!/usr/bin/env bash
# Generates one small fixture per input format into Tests/Fixtures/generated/.
# Nothing here is committed: every fixture is produced from scratch with the
# bundled ffmpeg, ImageIO (sips), PDFKit/textutil and our own writers.
#
# Each lane contributes Tests/Fixtures/lanes/<lane>.sh. Contract for a lane script:
#   - write files named  sample.<primary extension>  into "$OUT"
#     (folders: "$OUT/sample-folder/", packages like rtfd: "$OUT/sample.rtfd/")
#   - optional extra edge-case fixtures: edge-<name>.<ext>
#   - use "$FFMPEG", "$FFPROBE", "$RESVG" (bundled engines) and system tools only
#   - be idempotent and fast (< 30 s per lane)
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${OUT:-$PWD/Tests/Fixtures/generated}"
ENG="${HALO_ENGINES_DIR:-$PWD/Engines/dist}"
if [[ ! -x "$ENG/Helpers/ffmpeg" ]]; then
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [[ -n "$common" ]] && ENG="$(dirname "$common")/Engines/dist"
fi
export OUT FFMPEG="$ENG/Helpers/ffmpeg" FFPROBE="$ENG/Helpers/ffprobe" RESVG="$ENG/Helpers/resvg"
mkdir -p "$OUT"
for s in Tests/Fixtures/lanes/*.sh; do
  [[ -e "$s" ]] || continue
  echo "fixtures: $(basename "$s")"
  bash "$s"
done
echo "fixtures in $OUT: $(ls "$OUT" | wc -l | tr -d ' ')"
