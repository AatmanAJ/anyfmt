#!/usr/bin/env bash
# Two Swift files with the same name in one target collide in the build
# (object files and .stringsdata are named after the file). Fail early.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
check() { # <label> <dirs...>
  local label="$1"; shift
  local dups; dups="$(find "$@" -name '*.swift' 2>/dev/null | xargs -n1 basename | sort | uniq -d)"
  if [[ -n "$dups" ]]; then echo "✗ duplicate file names in $label: $dups"; status=1; fi
}
check AnyfmtCore Sources/Shared Sources/Engine Sources/Jobs/Core Sources/Tools/Core
check App Sources/App Sources/Wheel Sources/Cloud Sources/Tools/Editors Sources/Actions Sources/Jobs/UI Sources/Settings
check CoreTests Tests/Unit/Core
check AppTests Tests/Unit/App
[[ $status == 0 ]] && echo "✓ No duplicate Swift file names per target"
exit $status
