# Notices and source offer

anyfmt is free software, licensed under the **GNU Affero General Public License
v3.0 only** (`LICENSE` at the repository root). The reusable packages
`Packages/DragSense` and `Packages/RadialMenu` are **MIT** (each has its own
`LICENSE`).

anyfmt bundles the third-party engines below so it works with nothing else
installed. Each runs as a separate program inside the app bundle
(`Contents/Helpers`) or as a dynamic library it loads (`Contents/Frameworks`).
Each keeps its own licence. The full texts are in the folders next to this file.

| Component | Version | Licence | Licence files |
|---|---|---|---|
| FFmpeg (ffmpeg, ffprobe, libav*) | 9.0.2 | GPL-2.0-or-later | `ffmpeg-9.0.2/` |
| x264 | stable @ b35605a | GPL-2.0-or-later | `x264-b35605a/` |
| x265 | 4.2 | GPL-2.0-or-later | `x265-4.2/` |
| libaom | 3.15.2 | BSD-2-Clause + AOM Patent License 1.0 | `libaom-3.15.2/` |
| dav1d | 1.5.4 | BSD-2-Clause | `dav1d-1.5.4/` |
| libvpx | 1.17.0 | BSD-3-Clause + patent grant | `libvpx-1.17.0/` |
| Opus | 1.6.1 | BSD-3-Clause | `opus-1.6.1/` |
| libogg | 1.3.6 | BSD-3-Clause | `libogg-1.3.6/` |
| libvorbis | 1.3.7 | BSD-3-Clause | `libvorbis-1.3.7/` |
| LAME | 3.100 | LGPL-2.0-or-later | `lame-3.100/` |
| libwebp | 1.6.0 | BSD-3-Clause + patent grant | `libwebp-1.6.0/` |
| resvg (and 68 Rust crates) | 0.48.1 | Apache-2.0 OR MIT (crates: MIT/Apache/Zlib/BSD/Unicode, see `CRATES.md`) | `resvg-0.48.1/` |
| Sparkle | 2.10.0 | MIT | `Sparkle-2.10.0/` |
| Inter Display (Black, ExtraBold; UI display face, `Contents/Resources/Fonts`) | 4.1 | SIL OFL 1.1 | `inter-4.1/` |

Optional packs are **never bundled**. Users download them only if they choose
to, from the Settings › Engines pane, and they keep their own licences:
- **Office pack**: LibreOffice (MPL-2.0)
- **pandoc pack**: pandoc 3.12.1 (GPL-2.0-or-later)

Apple system frameworks used at runtime (ImageIO, PDFKit, AVFoundation,
VideoToolbox, Vision, WebKit, Quick Look) and the system tools `bsdtar`,
`ditto`, `gzip`, `qlmanage` and `textutil` are part of macOS and are not
redistributed.

## Written offer of source code

Every release of anyfmt links the exact source tag it was built from. That source
contains:

1. **All of anyfmt's own code** (AGPL-3.0 / MIT) at that tag.
2. **The complete corresponding source of every bundled GPL/LGPL engine**:
   the pinned upstream tarballs listed in `Engines/versions.env` (URL + SHA-256),
   the one-line build patch, and the build scripts `Engines/build-ffmpeg.sh` and
   `Engines/build-resvg.sh` with their exact configure flags (`Engines/VERSIONS.md`).
   Running `make engines` reproduces the shipped binaries.

The release workflow also attaches a `anyfmt-<version>-engine-sources.tar.gz`
containing those exact upstream tarballs, so the sources stay available even
if an upstream URL disappears.

For at least three years after we last distribute a given version, we will
also give anyone who asks a copy of that complete corresponding source, on a
medium customarily used for software interchange, for no more than the cost of
physically performing the distribution. Ask through the project's issue tracker
or the maintainer contact listed in the README.

**AGPL §13 (network use):** anyfmt's optional cloud features talk to a server
that is a separate program and isn't covered by this offer. The desktop client
that talks to it is covered, and it's all in this repository.
