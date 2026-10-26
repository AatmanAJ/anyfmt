#!/usr/bin/env bash
# Shared helpers for Engines/build-*.sh. Sourced, never executed directly.
set -euo pipefail

ENGINES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
source "$ENGINES_DIR/versions.env"

WORK="${ANYFMT_ENGINES_WORK:-$ENGINES_DIR/build}"
SRC="$WORK/src"
PREFIX="$WORK/prefix"
DIST="$ENGINES_DIR/dist"
JOBS="$(sysctl -n hw.ncpu)"

export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
export CFLAGS="-arch arm64 -mmacosx-version-min=$MACOS_MIN -O2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -mmacosx-version-min=$MACOS_MIN"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

mkdir -p "$SRC" "$PREFIX" "$DIST/Helpers" "$DIST/Frameworks"

log() { printf '\033[1;34m[engines]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[engines]\033[0m %s\n' "$*" >&2; exit 1; }

# fetch URL SHA256 -> prints path of verified tarball
fetch() {
  local url="$1" sha="$2" name
  name="$(basename "$url")"
  local out="$SRC/$name"
  if [[ ! -f "$out" ]]; then
    log "download $name"
    curl -fsSL --retry 3 -o "$out.part" "$url"
    mv "$out.part" "$out"
  fi
  local got
  got="$(shasum -a 256 "$out" | cut -d' ' -f1)"
  [[ "$got" == "$sha" ]] || die "checksum mismatch for $name: got $got want $sha"
  printf '%s' "$out"
}

# unpack TARBALL DIRNAME -> fresh source dir path
unpack() {
  local tarball="$1" dir="$SRC/$2"
  rm -rf "$dir"
  mkdir -p "$dir"
  tar -xf "$tarball" -C "$dir" --strip-components 1
  printf '%s' "$dir"
}

# built MARKER -> true if step already completed for the pinned version
built() { [[ -f "$PREFIX/.done-$1" ]]; }
mark() { touch "$PREFIX/.done-$1"; }
