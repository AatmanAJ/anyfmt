#!/bin/bash
# Puts anyfmt back to its first-run state on this Mac, for testing onboarding.
#
# Dry run by default: prints every step. Pass --yes to do it.
#
# What it resets (bundle id from Config/Brand.xcconfig, default app.anyfmt):
#   1. Quits anyfmt if it's running.
#   2. Preferences: `defaults delete <bundle id>` (onboarding state, keys, formats, sync switch…).
#   3. Keychain: every generic password in the services <bundle id>.cloud (sign-in tokens)
#      and <bundle id>.licence (Pro licence key). Never <bundle id>.licence-signing (the
#      developer's signing key) or anything else.
#   4. Files: ~/Library/Application Support/anyfmt (presets, recents, received files),
#      ~/Library/Caches/<bundle id>, ~/Library/Logs/anyfmt. Moved to the Trash, not deleted.
#   5. The `anyfmt` CLI symlink, only if it's a symlink into an anyfmt.app.
#   6. The launch-at-login item: `anyfmt --unregister-login-item` (SMAppService needs the app).
#   7. Privacy grants for the bundle id: `tccutil reset All <bundle id>` (Accessibility,
#      Input Monitoring, Automation…). The wheel itself needs none of them.
#
# Usage: scripts/reset-first-run.sh [--yes] [--app path/to/anyfmt.app]
set -euo pipefail

CONFIRM=0
APP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) CONFIRM=1 ;;
    --app) APP="$2"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$(sed -n 's/^BRAND_NAME = //p' "$ROOT/Config/Brand.xcconfig")"
SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"
BUNDLE_ID="dev.aiwithaj.$SLUG"
[[ -z "$APP" ]] && APP="$ROOT/build/DerivedData/Build/Products/Debug/$NAME.app"

run() {
  if (( CONFIRM )); then
    echo "+ $*"
    "$@" || echo "  (nothing to do or failed: $?)"
  else
    echo "would run: $*"
  fi
}

trash() {
  local path="$1"
  [[ -e "$path" ]] || { echo "absent: $path"; return; }
  local dest="$HOME/.Trash/$(basename "$path") (anyfmt reset $(date +%Y%m%d-%H%M%S))"
  run mv "$path" "$dest"
}

(( CONFIRM )) || echo "Dry run. Re-run with --yes to reset $NAME ($BUNDLE_ID)."

# 1. Quit
if pgrep -x "$NAME" >/dev/null; then
  run osascript -e "tell application id \"$BUNDLE_ID\" to quit"
  (( CONFIRM )) && sleep 1 && pkill -x "$NAME" 2>/dev/null || true
fi

# 6. Login item first, while the app is still where we expect it.
if [[ -x "$APP/Contents/MacOS/$NAME" ]]; then
  run "$APP/Contents/MacOS/$NAME" --unregister-login-item
else
  echo "skip login item: no app at $APP (pass --app)"
fi

# 2. Preferences
run defaults delete "$BUNDLE_ID"

# 3. Keychain (exact service names only)
for service in "$BUNDLE_ID.cloud" "$BUNDLE_ID.licence"; do
  while security find-generic-password -s "$service" >/dev/null 2>&1; do
    if (( CONFIRM )); then
      echo "+ security delete-generic-password -s $service"
      security delete-generic-password -s "$service" >/dev/null || break
    else
      echo "would run: security delete-generic-password -s $service (each item)"
      break
    fi
  done
done

# 4. Files
trash "$HOME/Library/Application Support/$NAME"
trash "$HOME/Library/Caches/$BUNDLE_ID"
trash "$HOME/Library/Logs/$NAME"

# 5. CLI symlink
for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
  link="$dir/$SLUG"
  if [[ -L "$link" ]] && [[ "$(readlink "$link")" == *"$NAME.app"* ]]; then
    run rm "$link"
  fi
done

# 7. Privacy grants
run tccutil reset All "$BUNDLE_ID"

(( CONFIRM )) && echo "Done. Launch $NAME to see onboarding from the start." || true
