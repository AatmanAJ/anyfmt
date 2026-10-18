#!/usr/bin/env bash
# Builds the resvg SVG rasteriser CLI (Apache-2.0 OR MIT) from the pinned
# crates.io release using its own lockfile (--locked), so the dependency
# graph is exactly what upstream tested.
# Output: Engines/dist/Helpers/resvg
source "$(dirname "$0")/lib.sh"

command -v cargo >/dev/null || die "cargo not found; run make bootstrap (installs rustup)"
ROOT="$WORK/resvg-$RESVG_VERSION"
if [[ ! -x "$ROOT/bin/resvg" ]]; then
  log "cargo install resvg $RESVG_VERSION"
  # Build inside Engines/build (not $TMPDIR) so artifacts are inspectable
  # and proc-macro dylibs load from a normal location.
  CARGO_TARGET_DIR="$WORK/resvg-target" \
  MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN" CARGO_PROFILE_RELEASE_STRIP=false CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=false \
  CARGO_PROFILE_RELEASE_LTO=true CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
    cargo install resvg --version "$RESVG_VERSION" --locked --root "$ROOT"
fi
cp "$ROOT/bin/resvg" "$DIST/Helpers/resvg"
strip -x "$DIST/Helpers/resvg"
codesign --force -s - "$DIST/Helpers/resvg"
"$DIST/Helpers/resvg" --version
log "resvg done"
