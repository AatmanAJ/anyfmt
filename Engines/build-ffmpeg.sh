#!/usr/bin/env bash
# Builds a self-contained arm64 ffmpeg + ffprobe (GPL build) from pinned
# sources. Codec libraries are linked statically into the shared libav*
# dylibs, which ffmpeg and ffprobe share. Network support is compiled out:
# the bundled engine cannot open a socket even if asked to.
#
# Output:
#   Engines/dist/Helpers/{ffmpeg,ffprobe}
#   Engines/dist/Frameworks/lib{avcodec,avformat,avfilter,avutil,swscale,swresample}.N.dylib
source "$(dirname "$0")/lib.sh"

build_x264() {
  built "x264-$X264_COMMIT" && return
  local d; d="$(unpack "$(fetch "$X264_URL" "$X264_SHA256")" x264)"
  (cd "$d" && ./configure --prefix="$PREFIX" --host=aarch64-apple-darwin \
      --enable-static --enable-pic --disable-cli --disable-opencl \
      --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" \
    && make -j"$JOBS" && make install)
  mark "x264-$X264_COMMIT"
}

build_x265() {
  built "x265-$X265_VERSION" && return
  local d; d="$(unpack "$(fetch "$X265_URL" "$X265_SHA256")" x265)"
  mkdir -p "$d/build-arm64"
  (cd "$d/build-arm64" && cmake ../source -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DENABLE_PIC=ON \
    && ninja && ninja install)
  # x265.pc needs the C++ runtime when linked statically.
  sed -i '' 's/^Libs.private:.*/Libs.private: -lc++/' "$PREFIX/lib/pkgconfig/x265.pc"
  mark "x265-$X265_VERSION"
}

build_aom() {
  built "aom-$AOM_VERSION" && return
  local d; d="$(unpack "$(fetch "$AOM_URL" "$AOM_SHA256")" aom)"
  mkdir -p "$d/build-arm64"
  (cd "$d/build-arm64" && cmake .. -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
      -DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=OFF -DENABLE_EXAMPLES=OFF \
      -DENABLE_TESTS=OFF -DENABLE_TOOLS=OFF -DCONFIG_AV1_DECODER=0 \
    && ninja && ninja install)
  mark "aom-$AOM_VERSION"
}

build_dav1d() {
  built "dav1d-$DAV1D_VERSION" && return
  local d; d="$(unpack "$(fetch "$DAV1D_URL" "$DAV1D_SHA256")" dav1d)"
  (cd "$d" && meson setup build --prefix="$PREFIX" --libdir=lib \
      --buildtype=release --default-library=static \
      -Denable_tools=false -Denable_tests=false \
    && ninja -C build && ninja -C build install)
  mark "dav1d-$DAV1D_VERSION"
}

build_vpx() {
  built "vpx-$VPX_VERSION" && return
  local d; d="$(unpack "$(fetch "$VPX_URL" "$VPX_SHA256")" vpx)"
  (cd "$d" && ./configure --prefix="$PREFIX" --target=arm64-darwin20-gcc \
      --enable-static --disable-shared --enable-pic --enable-vp9-highbitdepth \
      --disable-examples --disable-tools --disable-docs --disable-unit-tests \
      --extra-cflags="-mmacosx-version-min=$MACOS_MIN" \
    && make -j"$JOBS" && make install)
  mark "vpx-$VPX_VERSION"
}

autotools_static() { # name url sha [extra configure args...]
  local name="$1" url="$2" sha="$3"; shift 3
  local d; d="$(unpack "$(fetch "$url" "$sha")" "$name")"
  if [[ "$name" == vorbis ]]; then
    # libvorbis 1.3.7 passes -force_cpusubtype_ALL on darwin, which the
    # arm64 linker rejects. Strip it (same fix Homebrew applies).
    sed -i '' 's/-force_cpusubtype_ALL//g' "$d/configure"
  fi
  (cd "$d" && ./configure --prefix="$PREFIX" --disable-shared --enable-static \
      --with-pic "$@" && make -j"$JOBS" && make install)
}

build_opus()   { built "opus-$OPUS_VERSION"   || { autotools_static opus   "$OPUS_URL"   "$OPUS_SHA256" --disable-doc --disable-extra-programs; mark "opus-$OPUS_VERSION"; }; }
build_ogg()    { built "ogg-$OGG_VERSION"     || { autotools_static ogg    "$OGG_URL"    "$OGG_SHA256"; mark "ogg-$OGG_VERSION"; }; }
build_vorbis() { built "vorbis-$VORBIS_VERSION" || { autotools_static vorbis "$VORBIS_URL" "$VORBIS_SHA256" --with-ogg="$PREFIX" --disable-examples --disable-docs; mark "vorbis-$VORBIS_VERSION"; }; }
build_lame()   { built "lame-$LAME_VERSION"   || { autotools_static lame   "$LAME_URL"   "$LAME_SHA256" --disable-frontend --disable-decoder; mark "lame-$LAME_VERSION"; }; }
build_webp()   { built "webp-$WEBP_VERSION"   || { autotools_static webp   "$WEBP_URL"   "$WEBP_SHA256" --enable-libwebpmux --enable-libwebpdemux --disable-png --disable-jpeg --disable-tiff --disable-gif --disable-wic --disable-sdl; mark "webp-$WEBP_VERSION"; }; }

build_ffmpeg() {
  local d; d="$(unpack "$(fetch "$FFMPEG_URL" "$FFMPEG_SHA256")" ffmpeg)"
  local out="$WORK/ffmpeg-install"
  rm -rf "$out"
  (cd "$d" && ./configure \
      --prefix="$out" \
      --arch=arm64 --cc=clang --cxx=clang++ \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$PREFIX/include $CFLAGS" \
      --extra-ldflags="-L$PREFIX/lib $LDFLAGS" \
      --extra-libs="-lc++ -liconv" \
      --install-name-dir='@rpath' \
      --enable-gpl --enable-shared --disable-static \
      --disable-autodetect \
      --enable-videotoolbox --enable-audiotoolbox \
      --enable-zlib --enable-bzlib --enable-iconv --enable-pthreads --enable-neon \
      --enable-libx264 --enable-libx265 --enable-libvpx --enable-libaom --disable-decoder=libaom_av1 --enable-libdav1d \
      --enable-libopus --enable-libmp3lame --enable-libvorbis --enable-libwebp \
      --disable-network --disable-ffplay --disable-doc --disable-debug \
      --disable-avdevice --disable-indevs --disable-outdevs \
    && make -j"$JOBS" && make install)

  log "staging into $DIST"
  rm -f "$DIST/Helpers/ffmpeg" "$DIST/Helpers/ffprobe" "$DIST/Frameworks"/libav*.dylib "$DIST/Frameworks"/libsw*.dylib
  for exe in ffmpeg ffprobe; do
    cp "$out/bin/$exe" "$DIST/Helpers/$exe"
    install_name_tool -add_rpath '@loader_path/../Frameworks' "$DIST/Helpers/$exe"
  done
  # Copy each real dylib under the file name its install name (@rpath/...)
  # refers to, so no symlinks need to ship inside the bundle.
  for lib in "$out"/lib/lib*.dylib; do
    [[ -L "$lib" ]] && continue
    local id; id="$(otool -D "$lib" | tail -1)"
    local base; base="$(basename "$id")"
    cp "$lib" "$DIST/Frameworks/$base"
    install_name_tool -add_rpath '@loader_path' "$DIST/Frameworks/$base" 2>/dev/null || true
  done
  strip -x "$DIST/Helpers/ffmpeg" "$DIST/Helpers/ffprobe" "$DIST/Frameworks"/libav*.dylib "$DIST/Frameworks"/libsw*.dylib
  # Ad-hoc sign so the binaries run on Apple silicon after install_name_tool.
  codesign --force -s - "$DIST/Frameworks"/libav*.dylib "$DIST/Frameworks"/libsw*.dylib "$DIST/Helpers/ffmpeg" "$DIST/Helpers/ffprobe"
  # Guard: nothing may link outside the bundle or the OS.
  if otool -L "$DIST/Helpers/ffmpeg" "$DIST/Frameworks"/lib*.dylib | grep -E '/(opt|usr/local)/' ; then
    die "non-relocatable dependency found"
  fi
  "$DIST/Helpers/ffmpeg" -hide_banner -version | head -1
}

build_x264; build_x265; build_aom; build_dav1d; build_vpx
build_opus; build_ogg; build_vorbis; build_lame; build_webp
build_ffmpeg
log "ffmpeg done"
