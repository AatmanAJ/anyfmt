#!/usr/bin/env bash
# Xcode post-build phase: copies the bundled engines into the app and signs
# every nested binary with the app's identity and hardened runtime.
#   Engines/dist/Helpers/*    → Halo.app/Contents/Helpers/
#   Engines/dist/Frameworks/* → Halo.app/Contents/Frameworks/
set -euo pipefail

dist="${ENGINES_DIST:-$SRCROOT/Engines/dist}"
if [[ ! -d "$dist/Helpers" ]]; then
  # Git worktrees (parallel lanes) share the main checkout's built engines.
  common="$(git -C "$SRCROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [[ -n "$common" ]] && dist="$(dirname "$common")/Engines/dist"
fi
if [[ ! -d "$dist/Helpers" ]]; then
  if [[ "${CONFIGURATION:-Debug}" == "Release" ]]; then
    echo "error: engines not built; run 'make engines'" >&2
    exit 1
  fi
  echo "warning: engines not built (make engines); app will run with Apple-framework routes only"
  exit 0
fi

app="$TARGET_BUILD_DIR/$WRAPPER_NAME"
helpers="$app/Contents/Helpers"
frameworks="$app/Contents/Frameworks"
mkdir -p "$helpers" "$frameworks"
rsync -a "$dist/Helpers/" "$helpers/"
rsync -a "$dist/Frameworks/" "$frameworks/"

identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
[[ -z "$identity" ]] && identity="-"
sign() {
  if [[ "$identity" == "-" ]]; then
    # Ad-hoc: no hardened runtime, or library validation blocks our own dylibs.
    codesign --force --sign - "$@"
  else
    codesign --force --sign "$identity" --options runtime --timestamp "$@"
  fi
}
for f in "$frameworks"/libav*.dylib "$frameworks"/libsw*.dylib; do [[ -f "$f" ]] && sign "$f"; done
for f in "$helpers"/*; do [[ -f "$f" && -x "$f" ]] && sign "$f"; done
echo "embedded engines from $dist"
