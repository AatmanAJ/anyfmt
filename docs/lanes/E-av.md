# Lane E: audio, video, subtitles

Status: **done**. 191 rows (187 AV + 4 subtitle) give 177 conversion options,
and every row passes on its fixture (`AVRowSweepTests`, 187/187 in about 12 s).
There are 127 lane tests, all green. No blockers.

## What I built

### `Sources/Engine/AV/`

| File | What it is |
|---|---|
| `AVRoutes.swift` | `AVRoutes.rows` (187) and `AVRoutes.resourceClass(for:options:)`, which says whether a hop should take the single VideoToolbox queue slot (see contract change E-4). |
| `AVEngines.swift` | `[FFmpegAVEngine(), AVFoundationEngine()]` |
| `AVInputFacts.swift` | `AVInputFacts` (main video with display rotation and size, VFR, bit depth; audio streams with depth, bitrate and default flag; subtitles; cover art; tags). `AVProbe` runs one ffprobe per input and decodes `MediaProbe` plus the extra fields from contract change E-1. |
| `AVCodecTables.swift` | Muxer per target, copy-legal codecs per container, subtitle mapping, canonical audio codec, `AVQualityPreset` (the calibrated table below), default audio bitrates, Vorbis quality mapping. |
| `AVConversionPlanner.swift` | **Pure** planner: (facts, target, options, metadata policy) → `AVConversionPlan` with exact ffmpeg passes, a decision per stream (`copy` or `encode(encoder)`), scratch files and a software-only fallback plan. All codec, copy, geometry and metadata logic lives here, and it's unit-tested without ffmpeg. |
| `FFmpegAVEngine.swift` | Probe → plan → `FFmpeg.run` per pass, with live progress (probe duration, updated every 250 ms). It retries once on the fallback plan if an encoder fails to start, deletes partial output and scratch files on failure, and reports 100 % only after checking the output. |
| `AVFoundationEngine.swift` | `AVAssetExportSession` passthrough remux MOV ⇄ MP4 ⇄ M4V, plus AppleM4A export. It polls `progress` at 10 Hz and calls `cancelExport` on Task cancel. Re-encodes, `stripAll` and incompatible sources go to `FFmpegAVEngine`. When ffmpeg is missing it re-encodes with an export preset instead. |

### `Sources/Engine/Subtitles/` (pure Swift, no engine binary)

| File | What it is |
|---|---|
| `SubtitleDocument.swift` | `SubtitleDocument` (dialect, cues, VTT header and NOTE/STYLE/REGION blocks with positions, BOM, line ending, warnings), `SubtitleCue` (id, start and end in **integer ms**, text lines kept verbatim, VTT settings), and decoding (UTF-8/UTF-16 BOMs, strict UTF-8, then CP1252, then Latin-1). |
| `SubtitleTime.swift` | Timestamp parse and format: `,` or `.` separators, `MM:SS.mmm`, hours ≥ 100, short fractions read as decimals. |
| `SRTParser.swift`, `VTTParser.swift` | Lenient readers that never throw. Malformed cues are skipped and reported as `SubtitleWarning(line:message:)`. |
| `SubtitleMarkup.swift` | SRT ⇄ VTT markup translation and plain-text stripping (table below). |
| `SubtitleWriters.swift` | `SRTWriter`, `VTTWriter`, `SubtitleTextWriter` (transcript, optional `[HH:MM:SS]` timestamps, rolling-caption de-duplication). |
| `SubtitleEngine.swift`, `SubtitleRoutes.swift`, `SubtitleEngines.swift` | Engine `EngineIDs.subtitles` with rows srt→vtt, vtt→srt, srt→txt and vtt→txt. The txt rows are `.terminalOnly` + `.lossyStructure` with the `subtitleText` schema. |

### Tests and fixtures

- `Tests/Fixtures/lanes/av.sh` (0.6 s) writes `sample.{mp3,m4a,wav,flac,ogg,opus,aiff,caf,wma,mp4,mov,mkv,webm,avi,wmv,m4v,srt,vtt}` and 35 edge fixtures. Media edge cases: cover art, 24-bit/96 kHz, 5.1, mono, AAC-in-CAF (via `afconvert`), rotated, odd size, no audio, VFR, location tags (mp4 and mov), HEVC, an MKV with an SRT track. Subtitle edge cases: BOM+CRLF, CR, no trailing newline, CP1252, UTF-16, overlaps, styling, hours ≥ 100, missing indexes, extra blanks, malformed, dot separator, glued cues, plus header blocks, settings, entities, short times, no blank line, rolling captions, malformed and no-signature VTT.
- `Tests/Unit/Core/Subtitles/` has 52 tests and `Tests/Unit/Core/AV/` has 75; details under Test results.

## Routes shipped

| Family | Inputs | Outputs | Engine (priority) | Rows |
|---|---|---|---|---|
| Audio ⇄ audio | mp3 m4a wav flac ogg opus aiff caf wma | mp3 m4a wav flac ogg opus aiff caf | ffmpeg (90) | 64 |
| Video ⇄ video | mp4 mov mkv webm avi wmv m4v | same | ffmpeg (90) | 42 |
| Video → GIF | 7 video formats | gif | ffmpeg (90) | 7 |
| Video → audio | 7 video formats | mp3 m4a wav flac ogg opus aiff **caf** | ffmpeg (90) | 56 |
| GIF → video | gif | mp4 mov webm mkv | ffmpeg (90) | 4 |
| Remux | mov mp4 m4v | mov mp4 m4v | AVFoundation (**110**) | 6 |
| M4A fallback | mp3 wav aiff caf flac mp4 mov m4v | m4a | AVFoundation (40) | 8 |
| Subtitles | srt vtt | srt vtt txt | subtitles (100) | 4 |

Schemas are `audioLossy` for mp3/m4a/ogg/opus, `audioLossless` for
wav/flac/aiff/caf (these rows are `.lossless`), `video` for video targets
and GIF → video, and `gif` for → GIF. Video → CAF is an extra direct row
beyond the brief: without it the router would plan video → WAV → CAF through
a full-size intermediate.

## Decisions (ready for DECISIONS.md)

### D-E1 VideoToolbox is the default video encoder, measured faster at equal quality

All numbers below are from an M5 Max (6 super + 12 performance cores), using
the bundled ffmpeg 9.0.2. SSIM is measured against the source.

Calibration: 60 s 1080p30 testsrc2, re-encoded to MP4. Two sources were used:
a clean one (87 MB, very easy to encode) and the same clip with temporal grain
added (80 MB, ≈11 Mb/s, closer to camera footage).

| Encoder setting | Clean: time / size / SSIM | Grain: time / size / SSIM |
|---|---|---|
| x264 medium CRF 18 | 3.98 s / 72.2 MB / 0.99842 | 7.98 s / 95.9 MB / 0.99634 |
| x264 medium CRF 23 | 4.91 s / 46.0 MB / 0.99559 | 6.50 s / 56.8 MB / 0.99300 |
| x264 medium CRF 28 | 3.95 s / 22.6 MB / 0.98751 | 5.25 s / 24.9 MB / 0.98463 |
| VT H.264 q45 | 3.39 s / 26.5 MB / 0.98862 | 3.42 s / 26.0 MB / 0.98591 |
| VT H.264 q55 | 3.40 s / 45.1 MB / 0.99514 | 3.39 s / 45.3 MB / 0.99235 |
| VT H.264 q60 | 3.40 s / 52.7 MB / 0.99641 | 3.39 s / 53.3 MB / 0.99359 |
| VT H.264 q70 | 3.39 s / 77.5 MB / 0.99843 | 3.39 s / 81.0 MB / 0.99540 |
| VT H.264 q75 | 3.39 s / 89.4 MB / 0.99891 | 3.40 s / 97.7 MB / 0.99589 |
| VT H.264 q80 | 3.40 s / 107.1 MB / 0.99934 | 3.42 s / 125.5 MB / 0.99651 |

HEVC calibration used a 20 s cut of the grain clip:

| Encoder setting | Time / size / SSIM |
|---|---|
| x265 medium CRF 22 | 5.56 s / 19.4 MB / 0.99379 |
| x265 medium CRF 27 | 5.20 s / 11.0 MB / 0.98964 |
| x265 medium CRF 32 | 3.97 s / 5.2 MB / 0.98258 |
| VT HEVC q50 | 1.34 s / 8.2 MB / 0.98491 |
| VT HEVC q55 | 1.34 s / 14.5 MB / 0.99122 |
| VT HEVC q60 | 1.34 s / 17.2 MB / 0.99312 |
| VT HEVC q65 | 1.34 s / 20.5 MB / 0.99411 |

What this shows:

- **Speed.** VT time doesn't depend on `-q:v`. It runs at about 530 fps for
  1080p H.264, and software decode alone takes only 0.75 s. Hardware decode
  (`-hwaccel videotoolbox`) was *slower* (4.8 s decode-only), so it isn't
  used. `-prio_speed` gained nothing.
- **Quality.** At matched SSIM, VT H.264 is the same size as x264 medium at
  balanced and small, and about 25–30 % larger at high. VT HEVC is the same
  size as x265 medium at the high and balanced presets.
- **Hardware.** x264 here benefits from 18 cores. A base M1 has 8 cores, so
  it would be about 3× slower there while VT barely changes. VT wins
  everywhere.

So `hardware = true` (the schema default) uses `h264_videotoolbox` /
`hevc_videotoolbox` / `prores_videotoolbox`, and `false` uses libx264 /
libx265 / prores_ks. If a VT session can't start (an older or virtualised
Mac, or VT busy), ffmpeg's error mentions the encoder and the conversion
reruns once on the software plan.

### D-E2 Quality presets (`videoQuality`), calibrated to equal SSIM per row

| | x264 CRF | VT H.264 q | x265 CRF | VT HEVC q | VP9 CRF | AV1 CRF | MPEG-4 q | WMV2 q | ProRes |
|---|---|---|---|---|---|---|---|---|---|
| high | 18 | 75 | 22 | 62 | 24 | 24 | 2 | 2 | HQ |
| balanced | 23 | 58 | 27 | 54 | 32 | 32 | 4 | 4 | 422 |
| small | 28 | 45 | 32 | 46 | 40 | 40 | 8 | 7 | LT |

Encoder settings:

- x264 and x265 use `-preset medium`.
- VP9 uses `-b:v 0 -deadline good -cpu-used 4 -row-mt 1`, which ran at 2–2.7× realtime at 1080p.
- libaom uses `-cpu-used 6 -row-mt 1`, and only when `videoCodec=av1` is requested. AV1 is slow and has no hardware encoder.

### D-E3 Codecs per container

| Target | Video copied as-is | Video encode | Audio copied as-is | Audio encode | Notes |
|---|---|---|---|---|---|
| mp4 | h264, hevc (tagged `hvc1`) | H.264 (VT) | aac, mp3, alac, ac3, eac3 | AAC `aac_at` 192k (384k > 2 ch), fallback `aac` | `+faststart`; subtitles → mov_text |
| m4v | h264, hevc | H.264 | aac, alac, ac3, eac3 | AAC | as mp4 |
| mov | h264, hevc, prores, mjpeg | H.264, or **keeps HEVC / ProRes** when that's the source | aac, alac, mp3, ac3, eac3, pcm | AAC | 10-bit HEVC stays 10-bit (`main10`, p010) |
| mkv | h264 hevc vp8 vp9 av1 mpeg4 mpeg2 prores ffv1 theora mjpeg | H.264, or HEVC if the source is | aac mp3 opus vorbis flac alac ac3 eac3 dts truehd pcm | Opus 160k (320k > 2 ch), 48 kHz | text subs copied, mov_text → srt, bitmap subs copied |
| webm | vp8, vp9, av1 | VP9 | opus, vorbis | Opus | subtitles → webvtt |
| avi | mpeg4, msmpeg4v3, mjpeg | MPEG-4 Part 2 (`-q:v`, tag XVID) | mp3, ac3, pcm_s16le | MP3 192k (≤ 2 ch) | no subtitles |
| wmv | wmv1/2/3, vc1 | WMV2 (`-q:v`) | wmav1/2, wmapro | WMA2 192k | ASF muxer |
| gif | — | palettegen (`stats_mode=diff`) → paletteuse (`dither=sierra2_4a:diff_mode=rectangle`), two passes, `loop 0` | — | — | width/fps options; never upscales or raises fps |

**Stream copy.** Streams are decided one by one. Video is copied when the
container takes the codec and no option asks for a re-encode: resolution
below the source's short edge, fps below the source rate, quality `small`,
or an explicit different `videoCodec`. `high` and `balanced` copy, because a
copy is the best possible quality. Audio inside a video container is copied
whenever it's legal, even when the video re-encodes. On mp4, m4v and mov,
`hevc` is copied with the `hvc1` tag so QuickTime and Finder play it. A remux
of a minute of 1080p takes 0.06–0.2 s.

### D-E4 Audio targets

| Target | Codec | Mapping |
|---|---|---|
| mp3 | libmp3lame **CBR** at the chosen bitrate | ID3v2.3 for macOS/Windows tag readers. CBR is the honest reading of a "Bitrate" control. |
| m4a | `aac_at` (AudioToolbox), muxer `ipod` | Falls back to ffmpeg `aac`. AudioToolbox clamps impossible combinations itself, for example mono at 320k → 256k. |
| ogg | libvorbis `-q:a` | Mapped from the bitrate: 96k→q2, 128k→q4, 160k→q5, 192k→q6, 224k→q7, 256k→q8, 320k→q9. |
| opus | libopus VBR, always **48 kHz** | Opus has no 44.1 kHz mode. Capped at 256 kbps per channel, so 320k mono works. |
| flac | compression level 5 | 16-bit `s16`, or 24-bit `s32` + `bits_per_raw_sample 24`. |
| wav, aiff | pcm_s16le/s24le, pcm_s16be/s24be | WAV uses `-rf64 auto` above 4 GB. AIFF writes ID3 tags. |
| caf | **ALAC** (lossless, about half the size of PCM, native to Apple) | AudioToolbox decodes ffmpeg's ALAC CAF (checked with `afconvert`). ffmpeg's CAF muxer can't write AAC. |

**Copy.** An audio-only target copies when the source codec is already the
target's and the layout and sample rate match. For lossy targets the source
bitrate must also be at most the requested one (+5 %): re-encoding a
128 kbps AAC "up" to 256 kbps would only lose quality. Video → M4A of an AAC
track is therefore a remux.

**Bit depth.** Going from 24-bit or float down to 16-bit uses triangular
dither. A "keep" value is also understood (see contract change E-2).

**Album art.** Cover art is kept for MP3, M4A and FLAC unless the policy is
`stripAll`. Other formats carry no art.

**Other options.** `sampleRate` maps to `-ar` and `channels` to `-ac`.
5.1 → MP3 is downmixed to stereo.

### D-E5 AVFoundation owns MOV ⇄ MP4 ⇄ M4V because of metadata, not speed

I measured this with a genuine iPhone-style MOV: QuickTime `mdta` keys
(location, make, model, software, capture date, title) written by
AVFoundation. Each output was read back with `AVURLAsset` and with ffprobe.

- **AVFoundation passthrough → MP4** writes location, capture date and title
  as 3GPP `loci`/`date`/`titl`. Apple apps read them, and ffprobe sees the
  location. **→ MOV** keeps every key verbatim.
- **ffmpeg remux → MP4/MOV** drops every `com.apple.quicktime.*` key. With
  `-movflags use_metadata_tags`, AVFoundation reads the keys back as numbered
  iTunes items (garbage) and the ftyp brands are duplicated, so it isn't used.

Speed is a wash: 0.21 s for AVFoundation against 0.06 s for ffmpeg on a
112 MB minute of 1080p. So the AVFoundation rows sit at 110. They hand off to
ffmpeg for any option that needs a re-encode, for `stripAll`, and for sources
that can't pass through (ProRes or PCM into MP4). Options are therefore never
ignored. On the ffmpeg side, Apple keys are translated into standard tags
that Apple reads: `title` → ©nam, `creationdate` → ©day plus the movie
creation time in UTC, and with keep, `location`/`make`/`model` → ©xyz/©mak/©mod.

### D-E6 Metadata policies

| Policy | ffmpeg | AVFoundation |
|---|---|---|
| keep | `-map_metadata 0` (chapters by default), ftyp pseudo-tags blanked (otherwise MKV stores `MAJOR_BRAND` etc.), Apple keys translated (D-E5). Rotation survives a copy (display matrix, also into MKV) and is applied to the pixels on re-encode. | Passthrough default |
| stripPrivate | `-metadata k=` for every private key at container and stream level: anything with location/gps/©xyz, make/model/software/author/serial, `com.apple.quicktime.{make,model,software,camera*,content.identifier,live-photo*}`, `com.android.*`. Titles, dates, artists and album art stay. | Apple's `AVMetadataItemFilter.forSharing()`. It removes location (and also the title); the capture date stays. |
| stripAll | `-map_metadata -1 -map_chapters -1 -fflags +bitexact`, and no album art. MKV keeps a bare `Lavf` muxing-app string. | Delegated to ffmpeg: passthrough always writes a creation date, even with `metadata = []`. |

### D-E7 Resolution means the short edge

`resolution` = 720 gives 1280×720 for landscape and 720×1280 for portrait,
computed on the display size, so rotation is applied first. It never
upscales. Sizes are always even: odd sources round down (321×241 → 320×240),
and scaled sizes round to the nearest even number. `fps` only ever lowers the
frame rate. VFR sources keep their timestamps in mp4/mkv/webm, and ffmpeg
makes them constant-rate for AVI/WMV.

### D-E8 Subtitle model keeps the source dialect

Cue text is stored exactly as written, and writers translate only when the
dialect changes. That makes VTT → VTT byte-identical (tested) and keeps
timing exact to the millisecond (integer ms throughout).

| SRT | WebVTT |
|---|---|
| `<i> <b> <u>` | same (VTT classes dropped going to SRT) |
| `<font color="red">` (8 default colours) | `<c.red>` |
| `<font color="#f80">`, `orange` | `<c.c_ff8800>` plus a generated `STYLE` rule. Going back to SRT, class colours are read from STYLE blocks. |
| `{\an1-9}`, legacy `{\aN}` | `line:-1/50%/0` + `align:start/end`. Going back, only explicit `line` settings become `{\anN}`, so YouTube's `align:start position:0%` doesn't turn into bottom-left. |
| `{\i1}…{\i0}`, `\b`, `\u` | `<i>…</i>` etc. Other overrides are dropped. |
| raw `& < >` | `&amp; &lt; &gt;` (also stops `-->` breaking a cue) |
| — | `<v>`, `<lang>`, `<ruby>`, timestamps: tags dropped, text kept; `<rt>` text dropped |
| — | NOTE / STYLE / REGION and cue settings dropped going to SRT |

Writers sort cues by start time (stable, so overlaps keep their order and
are never merged) and number SRT cues 1…n. They keep the source's BOM and
line ending and always write well-formed files, adding the trailing newline
if it was missing. TXT gives one line per cue, strips all markup and decodes
entities. It removes rolling-caption repeats (a cue repeating the previous
cue's last lines), and `timestamps` prefixes each line with `[HH:MM:SS]`.

## Performance (BUILD.md §10)

`AVPerfTests` (opt-in: `TEST_RUNNER_HALO_PERF=1`) runs a 60 s 1920×1080
30 fps H.264 + AAC MOV (112 MB) → MP4 through the real engines on the M5 Max:

| Path | Time | Size | SSIM |
|---|---|---|---|
| **(a) stream copy, shipped route (AVFoundation passthrough)** | **0.21 s** | 111.9 MB | (bit-exact) |
| (a) stream copy, ffmpeg remux | 0.06 s | 111.9 MB | (bit-exact) |
| **(b) re-encode, VideoToolbox, balanced (default)** | **3.39 s** | 45.4 MB | 0.99514 |
| (c) re-encode, libx264 CRF 23, balanced | 4.91 s | 44.3 MB | 0.99500 |
| (b) VideoToolbox, high | 3.41 s | 87.7 MB | 0.99835 |
| (c) libx264 CRF 18, high | 5.41 s | 70.9 MB | 0.99792 |
| (b) VideoToolbox, small | 3.86 s | 24.9 MB | 0.98818 |
| (c) libx264 CRF 28, small | 4.47 s | 21.2 MB | 0.98730 |

**Winner.** At equal quality, VideoToolbox is 1.45× faster at balanced (same
size, same SSIM), and that's the default. A plain MOV → MP4 with default
options is a passthrough remux in 0.2 s.

## Test results

All 143 CoreTests tests pass, 127 of them lane E's; only the opt-in perf test
is skipped. The run takes 23 s.

| Suite | Tests | Covers |
|---|---|---|
| SubtitleTimeTests | 5 | Timestamp parse and format, boundaries, hours ≥ 100 |
| SRTParserTests | 14 | BOM/CRLF/CR/UTF-16/CP1252, missing newline and indexes, glued cues, overlaps, malformed cues with warnings, fuzzing (random bytes never crash) |
| VTTParserTests | 9 | Header blocks, short times, no blank lines, signature rules |
| SubtitleWriterTests | 18 | Every markup rule, VTT → VTT verbatim, SRT → VTT → SRT and VTT → SRT → VTT round trips (timing and text), transcripts |
| SubtitleEngineTests | 6 | Every edge fixture → the other format re-parses with identical timing, BOM and line ending; errors; never overwrites |
| AVPlannerTests | 31 | Codec per container and option, copy rules, presets, fallback plans, geometry, rotation, subtitles, audio options, dither, cover art, GIF, metadata arguments, Apple-key translation |
| AVProbeTests | 4 | JSON decoding (rotation, attached_pic, depth, bitrate, leniency), real fixtures |
| FFmpegProgressParserTests | 4 | Fractions, monotonic, cap, no duration, pass scaling |
| AVRoutesTests | 6 | Row counts and flags, schemas, priorities, router picks, availability, resource class, a fixture for every input |
| AVConversionTests | 15 | Real conversions in every family (duration ±0.1 s, codecs, stream counts, sizes), options, cover art, edge media, subtitle tracks, GIF both ways, extraction, errors, live progress |
| AVFoundationEngineTests | 7 | Decisions, passthrough is bit-exact (size unchanged), HEVC, delegation, ProRes fallback, working without ffmpeg |
| AVMetadataTests | 4 | keep, stripPrivate and stripAll through both engines on camera-style and iPhone-style files, checked by ffprobe and by AVFoundation |
| AVCancellationTests | 2 | ffmpeg stops within 3 s, no orphan process, no partial file, never shows 100 %; AVFoundation `cancelExport` |
| AVRowSweepTests | 1 | All 187 rows on their fixtures (≈ 12 s) |
| AVPerfTests | 1 | Opt-in benchmark above |

To run them:

```bash
xcodebuild -project anyfmt.xcodeproj -derivedDataPath build/DerivedData -scheme anyfmt -configuration Debug test \
  -only-testing:CoreTests/AVPlannerTests   # etc.; the target is CoreTests, not AnyfmtCoreTests
```

The tests find the engines through `ANYFMT_ENGINES_DIR`, or by walking up from
the test file to a checkout with `Engines/dist`. They generate fixtures once
per run by calling `Tests/Fixtures/lanes/av.sh`.

## Not shipped / gaps (for PARITY.md)

| Gap | What it would take |
|---|---|
| WMA output | Input only, per the brief. wmav2 encode exists if wanted. |
| GIF → AVI / WMV / M4V | The router forbids still → video chains. Each would need its own direct row (trivial). |
| AV1 output by default | No hardware encoder on any Mac and libaom is slow. Available via `videoCodec=av1` (CLI/tools) for mp4, mkv and webm. |
| Apple-visible location in MP4 written by ffmpeg (re-encode path) | ffmpeg writes ©xyz, which AVFoundation reads in MOV but not MP4. The common path (passthrough) is fine. A fix would write a 3GPP `loci` box, which ffmpeg doesn't support. |
| AVFoundation `stripPrivate` also drops the title | That's Apple's `forSharing` semantics. Routing stripPrivate through ffmpeg would keep it, but lose Apple's own definition of private. |
| HDR (HDR10/HLG/Dolby Vision) on re-encode | Not verified. Copy and passthrough keep it. Re-encode may drop mastering metadata. |
| Timecode, telemetry and other data tracks | Dropped on the ffmpeg path, kept by AVFoundation passthrough. |
| Opus/FLAC audio in MP4/MOV | Transcoded to AAC, because QuickTime doesn't play them. |
| Subtitles: ASS/SSA input, VTT regions in SRT, `<v>` speaker names in SRT | Not part of the brief. Text is always kept; voice names and region layout are dropped. |
| Burning subtitles into video, picking audio tracks | Tool territory (lane G). |

## Contract change requests

Detail in `docs/contract-changes/E-av.md`.

- **E-1** `MediaProbe.Stream` should decode disposition, rotation, sample depth, sample format and bitrate. Lane E decodes them itself for now.
- **E-2** `audioLossless.bitDepth` needs a "Keep" default. Today's "16" default truncates 24-bit sources (with dither).
- **E-3** `FFmpegProgressParser` reports 1.0 on `progress=end` even after SIGTERM. Lane E caps it locally.
- **E-4** Let lane C use `AVRoutes.resourceClass(for:options:)` for its queue class.
- **E-5** Nits: the `-only-testing` target name is `CoreTests`; empty source directories need `.gitkeep`; three new `L()` keys need syncing; there is no `lavfi` device in the bundled ffmpeg; and a Release `anyfmt-matrix` fails to load the ad-hoc AnyfmtCore under hardened runtime, so `make matrix` needs a Config fix.

## Licences and size

Nothing new is bundled. Lane E uses the ffmpeg/ffprobe from D-020 (GPL
build) and Apple frameworks only (AVFoundation, AudioToolbox and
VideoToolbox through ffmpeg).
