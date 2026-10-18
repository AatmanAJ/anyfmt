# Performance

Measured on the build machine: MacBook Pro, Apple M5 Max, macOS 27.0.1, Release build,
2026-10-18. Reproduce with `make perf` (scripts/perf.sh). Lane-level measurements are
linked where they come from a dedicated benchmark.

## Budgets (BUILD.md §10)

| Budget | Target | Measured | | Method |
|---|---|---|---|---|
| Key tap → wheel visible | < 50 ms p95 | **median 37.6 ms, max 48.3 ms** (live, real hardware, **Release**, phase 2 look, n = 7) | ✅ | In-app probe (`DragSense.diagnostics`), from the poll sample where the key went down to window-server "visible", during the hands-on session. The painted wheel (D-042) did not slow it down: the earlier Release samples were 43.0 / 44.3 / 44.8 ms. Seven samples give a nearest-rank p95 equal to the max, 48.3 ms. A larger sample would tighten that. Main-thread share of a show: 6–8 ms in Debug (`WheelShowPerfTests`). |
| Idle CPU | ~0 % | **0.05 %** of one core (phase 2 build; 0.22 % before) (whole app, 60 s idle after launch) | ✅ | `ps cputime` delta, sampled from 8 s after launch, so the one-off background route warm-up (D-037) isn't counted. The drag sensor alone: 0.04 % ([A](lanes/A-dragsense.md)). |
| Idle memory | < 40 MB | **30 MB** `phys_footprint` after the phase 2 redesign (28 MB before; RSS 85 MB includes shared framework pages) | ✅ | `footprint -p`. The warm route memo adds nothing measurable (28 MB with and without it). The wider prewarm (D-037) costs about 2 MB (26 MB with the old one). |
| App launch → ready | < 300 ms | **147 ms** median of 5 (`make perf` straight after a build: 165–168 ms, phase 2 redesign included) | ✅ | `--perf-report`: kernel process start → end of `applicationDidFinishLaunching` with sensor, wheel prewarm, status item and services running. The prewarm is 23–28 ms of that, about 10 ms more than before D-037, in exchange for a first wheel with no one-off work. The background route warm-up doesn't change it (147 ms either way). |
| 12 MP HEIC → JPG | < 400 ms | **74 ms** (69 ms on the previous run) (CLI, start-up subtracted); 34 ms upright / 109 ms with EXIF rotation in-engine ([D](lanes/D-image.md)) | ✅ | 4032 × 3024 HEIC |
| 1 min 1080p MOV → MP4 | report; hardware where faster | see below | ✅ | |

## 1 minute 1080p30 H.264 MOV → MP4

| Path | Time | Size | Quality |
|---|---|---|---|
| **Default: lossless passthrough** (AVFoundation keeps Apple metadata) | **0.23 s** | 111.9 MB | bit-exact |
| Stream copy via ffmpeg | 0.06 s | 111.9 MB | bit-exact |
| Re-encode, VideoToolbox, balanced | **3.39 s** | 45.4 MB | SSIM 0.9951 |
| Re-encode, libx264 CRF 23, balanced | 4.91 s | 44.3 MB | SSIM 0.9950 |
| Re-encode, VideoToolbox, high | 3.41 s | 87.7 MB | SSIM 0.9984 |
| Re-encode, libx264, high | 5.41 s | 70.9 MB | SSIM 0.9979 |
| Re-encode to 720p, VideoToolbox (`make perf`) | **1.89 s** | 14.7 MB | |
| Re-encode to 720p, libx264 (`make perf`) | 2.47 s | 11.7 MB | |

At equal quality (SSIM matched per preset) VideoToolbox is 1.3–1.6× faster, so it's the
default whenever a re-encode is needed and the hardware option is on ([E](lanes/E-av.md)).
When no re-encode is needed, nothing is re-encoded at all.

## Other measured numbers

| What | Result | Source |
|---|---|---|
| Matrix: every shipped route on its fixture, validated | 442 routes in 28 s (9 parallel) | `make matrix` |
| Wheel target lookup after warm-up (331-row table) | 0.025 ms (cold: 10.5 ms) | [C](lanes/C-jobs.md) |
| PDF → WebP, 3 pages @ 300 DPI | 0.97 s | [D](lanes/D-image.md) |
| JPEG compress to a 1 MB target (12 MP) | 0.29 s | [G1](lanes/G1-image-tools.md) |
| Resize / adjust (12 MP) | 65 ms / 74 ms | [G1](lanes/G1-image-tools.md) |
| Adjust editor live preview, worst case | 24 ms (Debug) | [G1](lanes/G1-image-tools.md) |
| PDF compress fixture | 4.1 MB → 315 KB (text stays vector) | [G2](lanes/G2-media-tools.md) |
| Zero network | 0 sockets from app, CLI and engines during a 40 s workload | `make netcheck` |

## App size

| | Size |
|---|---|
| Halo.app on disk | **63 MB** (all engines + every lane) |
| DMG (ULFO compressed) | **27 MB** |
| Bundled engines (ffmpeg, ffprobe, libav*, resvg) | 39 MB |

Budget: < 150 MB. The reference app ships at 97.6 MB.
