#!/bin/bash
# Fails when UI code hard-codes a colour, a font size or a corner radius instead of
# using DesignTokens (PLAN-PHASE2 §2: "Nothing hard-coded outside it").
#
# Allowed outside the token file: colours that are *content*, not UI (document
# writers, image-editor colour presets and swatches the user picks from, the
# onboarding sample photo), and the MIT RadialMenu package's own neutral defaults
# (hosts override them through RadialMenuStyle).
#
# Usage: scripts/check-tokens.sh [--report]   (--report lists hits without failing)
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOW=(
  'Sources/Shared/DesignTokens.swift'
  'Sources/Engine/Docs/'                       # DOCX/ODT/RTF writers: document colours
  'Sources/Engine/'                            # engines draw user content, not UI
  'Sources/Tools/Core/'                        # tool engines (watermark, background fills)
  'Sources/Tools/Editors/Image/Background/ImageBackgroundEditor.swift'  # user-pickable fill swatches
  'Sources/Tools/Editors/Image/Collage/ImageCollageEditor.swift'     # collage background swatches
  'Sources/Tools/Editors/Image/Redact/ImageRedactEditor.swift'      # redaction colours
  'Sources/Shared/Specs.swift'                 # tool option defaults (e.g. "#FFFFFF" fill)
  'Sources/Shared/Options.swift'               # option defaults
  'Sources/App/Onboarding/SampleArtwork.swift' # the sample photo's pixels
  'Sources/App/Redesign/DirectionBoard.swift'  # the approval mock-ups (historical)
  'Sources/App/Shared/AnyfmtColors.swift'        # hex → NSColor helper itself
  'Sources/CLI/'
)

PATTERNS=(
  'NSColor\((srgbRed|red|calibratedRed|deviceRed|white|calibratedWhite|genericGamma22White):'
  'srgbHex: *0x'
  'Color\((red|white|hue):'
  'Color\(hex: *0x'
  'NSColor\(hex: *0x'
  '0x[0-9A-Fa-f]{6}\b'
  '"#[0-9A-Fa-f]{6}"'
  '\.system(Purple|Indigo|Pink|Teal|Mint|Cyan|Brown)\b'
  '\.font\(\.system\(size: *[0-9]'
  'NSFont\.systemFont\(ofSize: *[0-9]'
  'cornerRadius: *[0-9]'
  'RoundedRectangle\(cornerRadius: *[0-9]'
)

allowed() {
  local f="$1"
  for a in "${ALLOW[@]}"; do [[ "$f" == $a* ]] && return 0; done
  return 1
}

hits=0
while IFS= read -r line; do
  file="${line%%:*}"
  allowed "$file" && continue
  # A trailing `// token-ok: <reason>` marks a deliberate exception.
  [[ "$line" == *"token-ok"* ]] && continue
  echo "$line"
  hits=$((hits + 1))
done < <(grep -rnE "$(IFS='|'; echo "${PATTERNS[*]}")" Sources --include='*.swift' 2>/dev/null)

if (( hits > 0 )); then
  echo "✗ $hits hard-coded colour / size / radius value(s) outside DesignTokens (see above)."
  echo "  Use DesignTokens (Semantic, Band, Shape, Typeface, TypeRamp, Radius), or add // token-ok: <reason>."
  [[ "${1:-}" == "--report" ]] && exit 0
  exit 1
fi
echo "✓ No hard-coded colours, font sizes or radii outside DesignTokens"
