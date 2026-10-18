# Performance

Measured on the build machine: MacBook Pro, Apple M5 Max, macOS 27.0.1, Release build,
2026-10-18. Reproduce with `make perf` (scripts/perf.sh). Lane-level measurements are
linked where they come from a dedicated benchmark.

## Budgets (BUILD.md §10)

| Budget | Target | Measured | | Method |
|---|---|---|---|---|
| Key tap → wheel visible | < 50 ms p95 | **≈ 30 ms p95** (estimate) | ✅ | Poll interval ≤ 4.2 ms (240 Hz, [A](lanes/A-dragsense.md)) + build 22-item wheel p95 6.0 ms + `panel.show` → window-server visible p95 26 ms ([B](lanes/B-wheel.md), n = 40). The Phase 0 spike measured order-front → visible p95 14.8 ms (D-001). A real key tap needs a human (BLOCKERS B-001); the app records it live via `DragSense.diagnostics.latencySummary()`. |
| Idle CPU | ~0 % | **0.18 %** of one core (whole app, 60 s idle after launch) | ✅ | `ps cputime` delta. The drag sensor alone: 0.04 % ([A](lanes/A-dragsense.md)). |
| Idle memory | < 40 MB | **22 MB** `phys_footprint` (RSS 65 MB, which includes shared framework pages) | ✅ | `footprint -p` |
| App launch → ready | < 300 ms | **111 ms** median of 5 | ✅ | `--perf-report`: kernel process start → end of `applicationDidFinishLaunching` with sensor, wheel prewarm, status item and services running |
| 12 MP HEIC → JPG | < 400 ms | **84 ms** (CLI, start-up subtracted); 34 ms upright / 109 ms with EXIF rotation in-engine ([D](lanes/D-image.md)) | ✅ | 4032 × 3024 HEIC |
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
| Halo.app on disk | see `make dmg` output (46 MB at the first integration build) |
| DMG (ULFO compressed) | 22 MB at the first integration build |
| Bundled engines (ffmpeg, ffprobe, libav*, resvg) | 39 MB |

Budget: < 150 MB. The reference app ships at 97.6 MB.
