# Lane G2: media tools (video 12–18, audio 19–22, PDF 25–26)

All 13 runners ship in `MediaToolRunners.all`, and all 8 editors open through
`MediaEditors.open`. Both are built on the frozen contracts (`ToolRunner`,
`EditorShell`/`EditorWindow`, `FFmpeg`, `ProcessRunner`). Nothing here touches the
network or the user's files. Runners write only inside `request.outputDirectory` and
remove their own `.halo-scratch-*` folders, and the tests check both.

## What's built

### Core (`Sources/Tools/Core/Media/`, HaloCore)

| File | What |
|---|---|
| `MediaToolRunners.swift` | Registry of the 13 runners |
| `MediaInfo.swift` | `MediaInfo` (one ffprobe JSON call: rotation from the display matrix, SAR, sample formats, MD5 extradata hashes, cover art excluded) and `KeyframeIndex` (packet scan, no decoding) |
| `MediaTimes.swift` | Parsing of time, range and list options; timecodes; `TrimPlanner.cut` → `TrimPlan`; `SplitPlan.make` |
| `MediaEncoders.swift` | `MediaContainer` (extension → muxer), `VideoQuality` tables, encoder attempts per container (VideoToolbox first, then software), audio args that keep the codec family and bitrate, `MetadataPolicy` → ffmpeg args |
| `MediaRun.swift` | Shared plumbing: output naming, scratch dir, encoder fallback (`runAttempts`), stream maps, human errors (`noAudio`, `noVideo`) |
| `VideoEditRunners.swift` | 12 Trim, 13 Crop (`PixelCrop`, `CGRectValue`), 14 Speed |
| `VideoSplitJoinRunners.swift` | 15 Split, 16 Join (`JoinPlanner.verdict` and `.order`) |
| `VideoFrameCompressRunners.swift` | 17 Snapshot, 18 Compress video |
| `AudioToolRunners.swift` | 19 Trim audio, 20 Normalize (`LoudnessMeasurement`), 21 Bleep, 22 Channels |
| `PDFToolRunners.swift` | 25 Organise (`PDFPageRef`), 26 Compress PDF |

Public API other lanes may want: `MediaInfo.load`, `KeyframeIndex.load`, `MediaTimes`,
`TrimPlanner`, `SplitPlan`, `JoinPlanner`, `PDFPageRef.parse/format`,
`LoudnessMeasurement.parse`, `MediaEncoders.video/audio/metadata`.

### Editors (`Sources/Tools/Editors/Media/`, app)

| Editor | Highlights |
|---|---|
| Trim video | Filmstrip of thumbnails sized to the strip, draggable in/out handles, playhead, AVPlayerView preview with an exact still when paused. ←/→ steps one frame (from the probed frame rate), ⇧←/→ jumps 1 s, I/O set in/out, Space plays the selection in a loop. Timecode fields. A live "lossless when possible" verdict, plus a dashed outline showing where a keyframe cut really lands. |
| Crop video | Crop rectangle drawn over the real frame: dimmed surround, thirds grid, 8 handles, move by dragging, live W×H badge. Aspect presets are drawn to scale. Locked presets give exact-ratio even pixels (4:3 → 8m × 6m) that round-trip through the runner. Pixel W/H fields, reset, filmstrip scrubber. |
| Split | Split markers on the filmstrip (M or Split Here, ⌫ removes the nearest one), or "every N seconds" with presets. A coloured parts bar previews the number and length of parts. Says whether the split is lossless and lists the real cut times. |
| Join | Reorderable list (drag, ↑/↓ buttons, VoiceOver actions) with thumbnails, duration, size, codec, fps and sound. Each clip gets a mismatch badge. An upfront verdict ("joined losslessly" or "re-encodes to MP4 at W×H", with reasons) and a proportional result bar. |
| Snapshot | Scrubber, F or Add Frame captures the exact frame on screen, a list with thumbnails, PNG/JPG. With no captures it saves the middle frame. |
| Trim audio | Waveform (min/max envelope from AVAssetReader, cached per file, drawn while it decodes), handles, zoom (buttons, slider, ⌘=/⌘−, ⌥ or ⌘ scroll, pinch), overview bar when zoomed, playback loop. Quiet files get display gain (≤ 4×). |
| Bleep | Drag across the waveform to mark ranges; handles resize; ⌫ deletes; M marks half a second. The waveform shows the result (a tone band or silence). Playback previews live: the player mutes inside ranges and a 1 kHz tone (AVAudioEngine) plays for tone mode. |
| Organise PDF | Thumbnail grid across every input (lettered A/B/C), drag to reorder, click/⌘-click/⇧-click select, hover buttons, ⌘L/⌘R rotate, ⌫ delete (never every page), "split into single pages", reset. Before/after shows the original order. |

Shared kit (`Kit/`): `MediaSession` (probe, playable asset or **preview proxy**,
player, filmstrip), `PlayerController` (coalesced zero-tolerance seeks, frame stepping,
range looping, exact still), `FilmstripTimeline`, `WaveformEnvelope`, `WaveformLoader`,
`WaveformTimeline` (zoom/pan and marked ranges), `KeyMonitor` (a local monitor scoped to the
editor window that ignores text fields: macOS 13 has no `onKeyPress`), `ScrollMonitor`,
`TonePlayer`, and `MediaStyle` (DesignTokens colours resolved per appearance).

`MediaOptionsPanel(tool:options:)` gives compact option views (~280 pt) for the
instant tools (speed, compress video, normalize, channels, compress PDF) for the wheel's
options popover. `MediaOptionsPanel.supports(_:)` says which tools it covers.

Screenshots (offscreen, generated sample media, light at 2×, dark at 1×), in
`docs/screens/`: `editor-trim`, `editor-crop-video`, `editor-split`, `editor-join`,
`editor-snapshot`, `editor-trim-audio`, `editor-bleep`, `editor-organize-pdf`,
`options-media`, each with a `-dark` variant. To regenerate:
`TEST_RUNNER_HALO_EDITOR_SCREENS=1 xcodebuild … test -only-testing:AppTests/MediaEditorScreenshotTests`.

## Decisions (ready for DECISIONS.md)

**G2-1. Lossless trim = keyframe-aligned stream copy, else a frame-exact re-encode.**
Cut points snap to frames first. A lossless cut prefers to *enclose* the request (in moves
back to the keyframe at or before it, out moves forward to the keyframe at or after it).
If that keyframe is more than `TrimPlanner.maxSnap` (1 s) away, it takes the nearest
keyframe on the other side if that one is within 1 s. Otherwise it re-encodes. This is
measured: VideoToolbox output with a 2 s GOP offset by 0.37 s re-encoded every cut before
the near-side rule. The copy is `-ss <kf>` (input seek) + `-t` (bounds audio) +
**`-frames:v N`**, where N is the packet count between the cuts. That bound matters because
`-t` alone lets the next GOP's I/P packets leak in: 62 frames instead of 60, verified. The
output starts at 0 with discard-flagged audio priming. A re-encode seeks to
`start − ½ frame`, so the first kept frame is exactly the in frame.

**G2-2. Split uses the segment muxer.** It's lossless when every cut has a keyframe after it
within `min(1 s, max(frame, ¼ × shortest part))`. Otherwise it does one re-encode with
`-force_key_frames` at the cuts, and every part starts exactly on time. Parts are
`<base>-001.<ext>`…, and the job layer groups them into a folder.

**G2-3. Join copies only when the clips really match.** The concat demuxer runs with stream
copy only when the clips share the same codec, display size, frame rate, pixel format,
rotation, **extradata hash** (different SPS/PPS in one MP4 sample description decode
wrongly), and audio codec, rate, channels and extradata. Otherwise there's one filter-graph
re-encode to H.264/AAC MP4 on the largest clip's canvas (by pixel area). Smaller clips are
letterboxed, never stretched. Frame rate is the highest (capped at 60), and silent clips
get matching silence.

**G2-4. Compress presets use VideoToolbox constant quality capped at a fraction of the
source bitrate.** High = q 65, ≤ 80 %. Balanced = q 55, ≤ 60 %. Small = q 45, ≤ 40 %. The
cap is a `-maxrate` VBV, which VT honours in CQ mode: on a 1.08 Mbps screen recording,
q 50 alone gave 3.1 MB and q 55 capped at 600 k gave 1.15 MB. Without the cap,
already-efficient sources get *bigger*. The software fallbacks are x264 CRF 21/24/28 and
x265 CRF 23/26/29. VP9 uses constrained quality (`-crf` plus `-b:v` as the ceiling),
because libvpx rejects a VBV cap in pure CRF mode, which the coverage test caught. If the
output isn't smaller, the user gets a human error, not a bigger "compressed" copy.

**G2-5. Target size is a two-pass software encode.** It uses x264, or libvpx-vp9 for WebM,
mpeg4 for AVI and wmv2 for WMV. The budget is `target × 8 / duration × 0.97`, minus audio
at 48/96/128 kbps by total rate. Measured: 4 s 320×240 at a 120 KB target came out at 1.009×,
and 60 s 1080p at a 20 MB target came out at 19.5 MB. When bits per pixel would drop below
0.03, it scales down automatically (1080/720/540/480/360). Pass 1 writes through the real
muxer into scratch, not `-f null`, because WMV's two-pass failed with "Input is longer than
2-pass log file" when the muxers' frame-rate handling differed. If the target is larger than
the file, the user gets a human error.

**G2-6. Normalize is EBU R128 in two passes.** Pass 1 runs `loudnorm print_format=json`,
with `-loglevel info` re-specified after `FFmpeg.run`'s `error`, because the later flag
wins. Pass 2 applies `linear=true` with the measured values, TP −1 dBTP, and LRA raised to
at least the measured LRA so loudnorm stays linear. The result is resampled back to the
source rate. Video and other audio tracks are copied. The tests measure within ±1 LU
for −14 and −23.

**G2-7. Bleep is one `aeval` expression.** It uses the sample's own `t` after
`asetpts=PTS-STARTPTS`, sample-exact, with 5 ms raised edges so cuts don't click. The tone
is 1 kHz at 0.3 (−10.5 dBFS). Overlapping ranges are merged.

**G2-8. Channels use explicit `pan` matrices.** Stereo→mono is (L+R)/2, mono→stereo
duplicates, and swap is L↔R. More than 2 channels go through `aresample` layout downmix. A
no-op request (mono→mono, swap on mono) gets a human error.

**G2-9. Codec and container policy.** Output keeps the input's extension and codec family
(see `MediaEncoders`). HEVC stays HEVC (VideoToolbox, then x265, `hvc1`-tagged in
QuickTime containers, Main10 kept). ProRes stays ProRes on VideoToolbox. WebM → VP9/Opus,
AVI → MPEG-4 (XVID)/MP3, WMV → wmv2/wmav2, PCM → the same PCM, FLAC keeps 16/24-bit, and
AAC uses `aac_at`. Every VideoToolbox attempt falls back to software on `engineFailed`
(never on cancel), and partial outputs are deleted first. `resourceClass` is
`.videoToolbox` for trim, crop, speed, split, join and compress, and `.cpu` for the rest.

**G2-10. Metadata policy.** `.keep` → `-map_metadata 0 -map_chapters 0`. `.stripAll` →
`-map_metadata -1 -map_chapters -1 -fflags +bitexact`. `.stripPrivate` keeps the tags and
blanks keys matching location/GPS/©xyz/make/model/software/author/creator/encoder (a tested
title and artist survive). For PDF: author, creator and producer are removed for private
mode, everything for strip-all. Speed also drops chapters and subtitles, since their
timing would be wrong after retiming.

**G2-11. PDF organise uses PDFKit page copies.** Content streams are copied, never
rasterised; text stays selectable, and tests extract it. Rotation is added to the page's
own rotation. Bookmarks are rebuilt: each kept page's source outline items are copied,
and with several inputs they're nested under one entry per file. PDFKit only persists a
*new* outline on a document it assembled itself, which is why the output is always a new
`PDFDocument`. Locked PDFs get a human error.

**G2-12. PDF compress uses our own Quartz filter applied while PDFKit saves.**
`PDFDocument.write(to:withOptions:)` with the key `"QuartzFilter"` (documented in
`PDFDocument.h`) and `QuartzFilter(properties:)` (public, `QuartzFilters.framework`). The
filter is our own dictionary: JPEG at the chosen quality, images resampled to the chosen
DPI. Text and vectors pass through untouched, and so do bookmarks (tested). Options
measured on a 3-page fixture with a 2400×1800 Flate image (4,129,066 bytes):

| Approach | Result | Verdict |
|---|---|---|
| Quartz filter, q 0.8 / 300 DPI | 986 KB, text intact | used for "high" settings |
| Quartz filter, q 0.6 / 150 DPI (default) | 315 KB, text intact | **default** |
| Quartz filter, q 0.4 / 72 DPI | 96 KB, text intact | |
| `.saveImagesAsJPEGOption` + `.optimizeImagesForScreenOption` (macOS 13.4+) | 4,129,079 bytes (no change), no DPI or quality control | rejected |
| Re-render pages as JPEG | text becomes pixels | rejected, never shipped |

Target size runs a binary search over a 9-step ladder (300/0.8 … 50/0.2) and keeps the
gentlest setting that fits. If none fits, it keeps the smallest result that's still smaller
than the original. If nothing gets smaller (text-only PDFs), the user gets a human error.

**G2-13. Editors preview through a proxy when AVFoundation can't play the input.** This
covers MKV, WebM, AVI, WMV, Ogg and Opus. The proxy is a ≤720p H.264 (VT, then x264
ultrafast) or AAC copy in a private temp folder, removed when the editor closes. Timestamps
stay aligned with the source, so the editor's times apply to the original file, which is
what gets saved.

**G2-14. A paused frame is an exact still.** It's an `AVAssetImageGenerator` frame with zero
tolerance, drawn over the AVPlayerView. Scrubbing uses coalesced zero-tolerance seeks
(one in flight, the latest wins). The still is also what offscreen renders capture,
since `cacheDisplay` can't capture the video layer.

**G2-15. The waveform envelope.** Bins of about 5 ms (`sampleRate / 200` frames) hold
min/max with channels folded. It's built in one streaming pass (published every 0.2 s while
decoding), cached per file path and modification date, and reduced per pixel column at any
zoom. It costs about 6 MB per hour of audio.

## Shipped / not shipped (for PARITY.md)

Shipped: all 13 tools, every container the catalogue lists for video (MP4, MOV, M4V,
MKV, WebM, AVI, WMV) and audio (MP3, M4A, WAV, FLAC, AIFF, OGG, Opus, CAF, WMA), checked
by `ContainerCoverageTests`. All 8 editors and the 5 option panels.

Not shipped, or limited:
- **Smart-render trim** (re-encode only the first GOP, copy the rest) isn't done. Frame-exact
  trims re-encode the whole range. With VT that's about 10× realtime at 1080p.
- **HDR snapshots** aren't tone-mapped (10-bit HEVC → 16-bit PNG, JPG 8-bit).
- **Normalize, bleep and channels** process the first audio track. Normalize copies the
  others unchanged; bleep and channels output only the first.
- **Join** copies the first audio track only. Subtitle and data tracks are dropped.
- **Lossless split** cut points may move to the next keyframe (shown in the editor; see
  contract change 2 for instant runs).
- The **bleep preview** tone is switched on 60 Hz ticks (±16 ms). The saved file is
  sample-exact.

## Contract change requests (detail in `docs/contract-changes/G2.md`)

1. `pdf.organize` needs `.combine(minimum: 1)` arity. Today it's `.perFile`, so a multi-PDF
   merge would run once per file.
2. An optional `note: String?` on `ConversionOutput`, so instant runs can report snapped cut
   times.
3. (Not a contract) `scripts/embed-engines.sh` signing. See Blockers.

## Tests

Core (`Tests/Unit/Core/ToolsMedia/`, 53 tests, all passing; 1 opt-in perf test skipped by
default):
- `MediaPlanningTests` (14): parsing, trim/split planning including the near-side keyframe
  rule, atempo chains, crop maths, PDF order parsing, encoder choice, private metadata,
  bleep expression, target-size budget, loudnorm report, registry.
- `VideoToolsTests` (18):
  - trim lossless (exactly 60 frames, same extradata) and re-encode (±1 frame); long-GOP fallback.
  - crop dims with audio copied; crop and snapshot of a rotated (portrait) clip.
  - speed 2×/0.5×, and with no audio.
  - split every 1 s (4 × 30 frames, lossless) and at 1.5/2.5 s (45/30/45 frames, re-encoded).
  - join copy (180 frames, same extradata) and re-encode (640×360 letterbox, silence added).
  - snapshot dims and middle frame; frame maths.
  - compress to 120 KB within ±10 %, preset smaller with 180p scaling, and a human error when
    the target is larger than the file.
  - metadata keep / strip-private / strip-all.
- `AudioToolsTests` (9): MP3 trim stream copy at 192 kbps, WAV sample-exact, M4A AAC.
  Normalize −14/−23 within ±1 LU (FLAC), and on video with the video copied. Error for
  silent video. Bleep tone RMS ≈ 0.3/√2 inside ranges, silence < 0.001, untouched outside.
  Mono/stereo/swap verified per channel. MP3 keeps MP3.
- `PDFToolsTests` (9): merge + reorder + rotate + delete with nested bookmarks, merge-all,
  single-input outline, split into 3 single pages, bad order, metadata policy. Compress is
  < 25 % of the original with text extractable and bookmarks kept. Target 400 KB fits and
  isn't over-crushed. Text-only PDF gets a human error.
- `ContainerCoverageTests` (2): every video container through trim (re-encode and
  lossless), speed, split and target-size compress, checking codec family kept. Every
  audio container through bleep, channels, trim and normalize, with the codec kept.

App-hosted (`Tests/Unit/App/EditorsMedia/`, 26 tests, all passing):
- `MediaEditorModelTests` (10): options from every editor model; crop rect → pixels round
  trip; crop geometry bounds and ratio; MKV preview proxy; PDF organise edits → order text.
- `WaveformEnvelopeTests` (3): builder channel folding and chunk-boundary independence;
  column reduction and padding; loader peak and duration on a real WAV, then the cache.
- `MediaEditorsOpenTests` (5): `MediaEditors.open` (and `EditorFactory.open`) returns true
  and opens a titled window for each of the 8 editor tools; refuses other tools and empty
  inputs; editor result state; option panel coverage; option panel screenshots.
- `MediaEditorScreenshotTests` (8): renders every editor, light and dark.

Perf (M5 Max, `TEST_RUNNER_HALO_MEDIA_PERF=1`, 60 s 1080p30 H.264 8 Mbps source, 60 MB):

| Operation | Time | Output |
|---|---|---|
| Trim 10–50 s lossless (keyframe-snapped) | 0.09 s | 40.7 MB |
| Trim 10.5–49.5 s frame-exact (VT) | 4.0 s | 34.1 MB |
| Crop to half (VT) | 2.3 s | 34.4 MB |
| Speed 2× (VT) | 3.2 s | 30.5 MB |
| Split every 10 s, lossless | 0.09 s | 6 files |
| Snapshot 3 frames | 0.27 s | |
| Compress, Balanced preset (VT) | 5.7 s | 25.0 MB |
| Compress to 20 MB (x264, 2 passes) | 5.9 s | 19.5 MB |
| Normalize to −16 LUFS | 3.0 s | video copied |
| Join 2 clips losslessly | 0.11 s | 122 MB |
| Compress a 3-page 4.1 MB PDF | 0.11 s | 0.3 MB |

## Blockers

- **Engines embedded in the app don't load (ad-hoc signing + hardened runtime).** Running
  `build/DerivedData/Build/Products/Debug/Halo.app/Contents/Helpers/ffmpeg -version` fails
  with `Library not loaded: @rpath/libavfilter.12.dylib … different Team IDs`. Every
  ffmpeg-backed feature in the app is affected, not just this lane's. The fix, verified on
  a scratch copy, is for the owner of `scripts/embed-engines.sh` to sign helpers with
  `--entitlements` setting `com.apple.security.cs.disable-library-validation` = true when
  the identity is ad hoc. A real Developer ID shares the team ID and doesn't need it. Until
  then, this lane's app-hosted tests set `HALO_ENGINES_DIR` to `Engines/dist`.
- Locally created, untracked empty source directories (`Sources/Wheel`, `Sources/Cloud`,
  `Sources/Actions`, `Sources/Jobs/UI`, `Sources/Settings`) are needed for `xcodegen` in a
  fresh worktree. They aren't committed: git doesn't track empty directories and they
  belong to other lanes.
