#!/usr/bin/env bash
# Enforces BUILD.md §9b: no local feature consults Entitlements.
# Only Sources/Cloud/** and the cloud segment builder may reference the
# entitlement API. Declarations in Sources/Shared (the contract itself and
# the catalogue's `cloudFeature` tags) are allowed.
set -euo pipefail
cd "$(dirname "$0")/.."

allowed='^Sources/(Cloud/|Wheel/CloudSegments\.swift|Shared/Entitlements\.swift|Shared/Specs\.swift|Settings/AccountSettings)'
pattern='Entitlements|entitlements\.|\.can\(\.|isSignedIn|CloudFeature'

violations="$(grep -rnE "$pattern" Sources --include='*.swift' | grep -vE "$allowed" || true)"
if [[ -n "$violations" ]]; then
  echo "✗ Local code consults cloud entitlements (BUILD.md §9b):"
  echo "$violations"
  exit 1
fi
echo "✓ No local feature consults Entitlements"
