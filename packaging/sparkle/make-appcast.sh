#!/usr/bin/env bash
# Signs release DMGs with the Sparkle EdDSA key and (re)generates appcast.xml.
#
# The PRIVATE key never lives in this repo. It was generated with
#   generate_keys --account anyfmt-updates
# and is stored in the maintainer's login Keychain (item "https://sparkle-project.org",
# account "anyfmt-updates"). Export a backup with
#   generate_keys --account anyfmt-updates -x anyfmt-updates-private.key
# and keep it in a password manager (BLOCKERS.md B-005). CI reads it from the
# SPARKLE_ED_PRIVATE_KEY secret (base64), never from disk.
#
# Usage: packaging/sparkle/make-appcast.sh <dir with DMGs> <download base URL>
set -euo pipefail
cd "$(dirname "$0")/../.."
DIR="${1:?dir with release DMGs}"
BASE="${2:?download URL prefix, e.g. https://github.com/AatmanAJ/anyfmt/releases/download/v0.1.0/}"
BIN="build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
[[ -x "$BIN/generate_appcast" ]] || { echo "Sparkle tools not found; run make build first"; exit 1; }

if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  KEYFILE="$(mktemp)"; trap 'rm -f "$KEYFILE"' EXIT
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$KEYFILE"
  "$BIN/generate_appcast" --ed-key-file "$KEYFILE" --download-url-prefix "$BASE" "$DIR"
else
  "$BIN/generate_appcast" --account anyfmt-updates --download-url-prefix "$BASE" "$DIR"
fi
echo "appcast: $DIR/appcast.xml (host it at the SUFeedURL in project.yml)"
