# Bundled engine versions

Exact versions, sources and build flags of every binary inside the app
(GPL/LGPL source-offer compliance). The source of truth for pins and SHA-256
checksums is `Engines/versions.env`. The builds are `Engines/build-ffmpeg.sh` and
`Engines/build-resvg.sh`. Licence texts are in `LICENSES/`.

| Component | Version | Source (pinned tarball) | Licence | In the app as |
|---|---|---|---|---|
| FFmpeg | 9.0.2 | https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz | GPL-2.0-or-later (as configured with `--enable-gpl`) | `Contents/Helpers/ffmpeg`, `ffprobe`, `Contents/Frameworks/libav*.dylib`, `libsw*.dylib` |
| x264 | stable @ b35605ace3dd | code.videolan.org archive of that commit | GPL-2.0-or-later | statically inside libavcodec |
| x265 | 4.2 | https://bitbucket.org/multicoreware/x265_git/downloads/x265_4.2.tar.gz | GPL-2.0-or-later | statically inside libavcodec |
| libaom (encoder only) | 3.15.2 | https://storage.googleapis.com/aom-releases/libaom-3.15.2.tar.gz | BSD-2-Clause + AOM patent licence | statically inside libavcodec |
| dav1d | 1.5.4 | https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz | BSD-2-Clause | statically inside libavcodec |
| libvpx | 1.17.0 | https://github.com/webmproject/libvpx/archive/refs/tags/v1.17.0.tar.gz | BSD-3-Clause + patent grant | statically inside libavcodec |
| Opus | 1.6.1 | https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz | BSD-3-Clause | statically inside libavcodec |
| libogg | 1.3.6 | https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz | BSD-3-Clause | statically inside libavcodec/libavformat |
| libvorbis | 1.3.7 | https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz | BSD-3-Clause | statically inside libavcodec |
| LAME | 3.100 | https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz | LGPL-2.0-or-later | statically inside libavcodec |
| libwebp | 1.6.0 | https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz | BSD-3-Clause + patent grant | statically inside libavcodec |
| resvg | 0.48.1 | crates.io `resvg` 0.48.1, `cargo install --locked` | Apache-2.0 OR MIT (crate graph: `LICENSES/resvg-0.48.1/CRATES.md`) | `Contents/Helpers/resvg` |
| Sparkle | 2.10.0 | SwiftPM, github.com/sparkle-project/Sparkle tag 2.10.0 | MIT | `Contents/Frameworks/Sparkle.framework` |

Only one patch is applied to upstream sources: libvorbis 1.3.7's `configure` has
`-force_cpusubtype_ALL` removed, because the arm64 linker rejects it. This is
the same change Homebrew makes, done with `sed` in `build-ffmpeg.sh`.

## FFmpeg configure line

```
./configure --arch=arm64 --cc=clang --cxx=clang++ --pkg-config-flags=--static \
  --extra-cflags="-I<prefix>/include -arch arm64 -mmacosx-version-min=13.0 -O2" \
  --extra-ldflags="-L<prefix>/lib -arch arm64 -mmacosx-version-min=13.0" \
  --extra-libs="-lc++ -liconv" --install-name-dir=@rpath \
  --enable-gpl --enable-shared --disable-static --disable-autodetect \
  --enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-bzlib --enable-iconv \
  --enable-pthreads --enable-neon \
  --enable-libx264 --enable-libx265 --enable-libvpx --enable-libaom --disable-decoder=libaom_av1 \
  --enable-libdav1d --enable-libopus --enable-libmp3lame --enable-libvorbis --enable-libwebp \
  --disable-network --disable-ffplay --disable-doc --disable-debug \
  --disable-avdevice --disable-indevs --disable-outdevs
```

Dependencies are configured as static, PIC, `-mmacosx-version-min=13.0`, arm64.
The exact flags are in `Engines/build-ffmpeg.sh`.

## Relocation

Install names are `@rpath/libX.N.dylib`. Executables carry the rpath
`@loader_path/../Frameworks`, and dylibs carry `@loader_path`. The build fails
if anything links outside the bundle or the OS (`otool -L` guard).

## Reproducing

```bash
make bootstrap && make engines
shasum -a 256 Engines/build/src/*   # compare with Engines/versions.env
```
