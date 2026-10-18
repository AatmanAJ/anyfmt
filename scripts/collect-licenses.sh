#!/usr/bin/env bash
# Copies the exact licence texts of every bundled engine (from the pinned source
# trees `make engines` built) into LICENSES/, and lists resvg's Rust crates.
# Run after `make engines`. LICENSES/ is committed; re-run when versions change.
set -euo pipefail
cd "$(dirname "$0")/.."
source Engines/versions.env
SRC=Engines/build/src
OUT=LICENSES
mkdir -p "$OUT"

copy() { # <lib dir> <dest name> <files...>
  local lib="$1" dest="$2"; shift 2
  mkdir -p "$OUT/$dest"
  for f in "$@"; do
    [[ -f "$SRC/$lib/$f" ]] && cp -f "$SRC/$lib/$f" "$OUT/$dest/$f"
  done
}
copy ffmpeg "ffmpeg-$FFMPEG_VERSION" COPYING.GPLv2 COPYING.LGPLv2.1 LICENSE.md
copy x264 "x264-${X264_COMMIT:0:7}" COPYING AUTHORS
copy x265 "x265-$X265_VERSION" COPYING
copy aom "libaom-$AOM_VERSION" LICENSE PATENTS AUTHORS
copy dav1d "dav1d-$DAV1D_VERSION" COPYING
copy vpx "libvpx-$VPX_VERSION" LICENSE PATENTS AUTHORS
copy opus "opus-$OPUS_VERSION" COPYING AUTHORS
copy ogg "libogg-$OGG_VERSION" COPYING AUTHORS
copy vorbis "libvorbis-$VORBIS_VERSION" COPYING AUTHORS
copy lame "lame-$LAME_VERSION" COPYING LICENSE
copy webp "libwebp-$WEBP_VERSION" COPYING PATENTS AUTHORS

# resvg + its crate graph (all permissive; recorded for attribution).
RESVG_SRC="$(ls -d "$HOME"/.cargo/registry/src/*/resvg-"$RESVG_VERSION" 2>/dev/null | head -1 || true)"
if [[ -n "$RESVG_SRC" ]]; then
  mkdir -p "$OUT/resvg-$RESVG_VERSION"
  cp "$RESVG_SRC"/LICENSE* "$OUT/resvg-$RESVG_VERSION/" 2>/dev/null || true
  # Crates actually compiled are the ones present in the local registry cache
  # (cargo install --locked fetched exactly the lockfile's non-dev graph).
  python3 - "$RESVG_SRC" > "$OUT/resvg-$RESVG_VERSION/CRATES.md" <<'PY'
import os, re, sys, glob
src = sys.argv[1]
lock = open(os.path.join(src, "Cargo.lock")).read()
pkgs = re.findall(r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"', lock)
root = os.path.dirname(src)
rows = []
for name, ver in sorted(set(pkgs)):
    d = os.path.join(root, f"{name}-{ver}")
    if not os.path.isdir(d):
        continue  # dev-only dependency, not compiled into the binary
    lic = "see crate"
    try:
        m = re.search(r'^license\s*=\s*"([^"]+)"', open(os.path.join(d, "Cargo.toml")).read(), re.M)
        if m: lic = m.group(1)
    except OSError:
        pass
    rows.append((name, ver, lic))
print("# Rust crates compiled into the bundled resvg binary\n")
print("| Crate | Version | Licence |\n|---|---|---|")
for r in rows: print(f"| {r[0]} | {r[1]} | {r[2]} |")
PY
fi

# Sparkle (SwiftPM checkout)
SPARKLE="$(ls -d build/DerivedData/SourcePackages/checkouts/Sparkle 2>/dev/null || true)"
if [[ -n "$SPARKLE" ]]; then mkdir -p "$OUT/Sparkle-2.10.0"; cp -f "$SPARKLE"/LICENSE* "$OUT/Sparkle-2.10.0/"; fi

echo "licences collected into $OUT/"
ls "$OUT"
