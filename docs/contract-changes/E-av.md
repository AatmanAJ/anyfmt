# Contract change requests: lane E (audio, video, subtitles)

Nothing here blocks lane E. Each item says what lane E does in the meantime.

## E-1 `MediaProbe.Stream`: decode the fields AV planning needs

**What.** Add these optional fields to `MediaProbe.Stream` in `Sources/Engine/FFmpeg.swift`:

```swift
public let disposition: [String: Int]?      // "attached_pic", "default", …
public let side_data_list: [SideData]?      // display-matrix rotation
public let bits_per_raw_sample: String?
public let bits_per_sample: Int?
public let sample_fmt: String?
public let bit_rate: String?

public struct SideData: Sendable, Decodable { public let side_data_type: String?; public let rotation: Double? }
```

Also base `MediaProbe.video` on `disposition.attached_pic != 1` instead of
excluding the `mjpeg` and `png` codecs. Today a Motion-JPEG movie (old
cameras, AVI/MOV) has no `video` stream according to `MediaProbe`.

**Why.** Rotation (display size, resize maths), cover art versus a real
video stream, source bit depth (lossless copy and dithering) and the
per-stream bitrate (copy AAC instead of re-encoding it upwards) all depend
on them.

**Meanwhile.** `Engine/AV/AVInputFacts.swift` (`AVProbe`) runs ffprobe once
through `ProcessRunner` and decodes both `MediaProbe` and these extras from
the same JSON. It decodes leniently, so a field with an unexpected type
becomes nil instead of failing the probe. Once E-1 lands, `AVProbe` can
switch to `FFmpeg.probe` with a one-line change.

## E-2 `StandardSchemas.audioLossless`: a "Keep" bit depth, as the default

**What.**

```swift
OptionSpec(OptionKey.bitDepth, L("Bit depth"), .choice([
    OptionChoice("keep", L("Keep")), OptionChoice("16", "16-bit"), OptionChoice("24", "24-bit"),
]), default: .string("keep")),
```

**Why.** With the current default of `"16"`, every 24-bit FLAC → WAV, AIFF
→ FLAC or similar conversion drops to 16 bits. The rows are flagged
`.lossless`, and a 16-bit result isn't lossless. Lane E dithers when it
reduces depth (triangular), so the result is good 16-bit audio, but it still
isn't what the user had.

**Meanwhile.** Lane E already honours `"keep"` and `"0"`: 16-bit and lower
sources stay 16-bit, and anything deeper becomes 24-bit. That's covered by
`AVPlannerTests.testBitDepthAndDither`.

## E-3 `FFmpegProgressParser`: don't report 1.0 on `progress=end`

**What.** Drop the `progress=end → sink(1)` case. `FFmpeg.run` already calls
`progress(1)` after a successful exit.

**Why.** ffmpeg prints `progress=end` even when it stops because of SIGTERM,
so a cancelled job briefly reads 100 %.

**Meanwhile.** `FFmpegAVEngine` caps its passes at 0.999 and reports 1 only
after it has checked the output (`AVCancellationTests`). Other callers of
`FFmpeg.run` (image fallbacks, tools) still see the 1.0 on cancel.

## E-4 Resource class for conversion jobs

**What.** Either lane C calls `AVRoutes.resourceClass(for:options:)`, or the
engine protocol gains a requirement with a `.cpu` default:

```swift
func resourceClass(for capability: Capability, options: OptionValues) -> ResourceClass
```

**Why.** ARCHITECTURE.md limits VideoToolbox jobs to one at a time. Only the
engine knows that a video target with `hardware = true` uses the media
engine, while audio and subtitle jobs are plain CPU work.

**Meanwhile.** `AVRoutes.resourceClass(for:options:)` exists and is tested.
It returns `.videoToolbox` for video and GIF targets when hardware is on,
and `.cpu` otherwise.

## E-5 Docs and repo nits found while working

- LANE_RULES.md says `-only-testing:AnyfmtCoreTests/<Class>`, but the test
  *target* is `CoreTests` (its product is AnyfmtCoreTests). The working form is
  `-only-testing:CoreTests/<Class>`.
- A fresh worktree has no `Sources/{Wheel,Cloud,Actions,Settings,Jobs/UI}`
  (git doesn't track empty directories), so `xcodegen generate` fails.
  A `.gitkeep` in each would fix it. Lane E created them locally and didn't
  commit them.
- New `L()` keys from lane E, to sync into `Sources/Shared/Localizable.xcstrings`:
  "This file has no audio to convert.", "This file has no video to turn into
  a GIF.", "The converted subtitles couldn’t be saved."
- The bundled ffmpeg has no `lavfi` input device. Fixture scripts must put
  source filters inside `-filter_complex` (as `Tests/Fixtures/lanes/av.sh`
  does), not use `-f lavfi -i …`.
- **`make matrix` will fail to launch as configured.** A Release
  `anyfmt-matrix` (and the Release CLI) is ad-hoc signed with hardened
  runtime, so library validation refuses the ad-hoc `AnyfmtCore.framework`:
  `dyld: … not valid for use in process: mapping process and mapped file
  (non-platform) have different Team IDs`. Debug builds run. Possible fixes
  (Config/Makefile, not lane E): set `ENABLE_HARDENED_RUNTIME = NO` for the
  Matrix target, give the Matrix and CLI targets the
  `com.apple.security.cs.disable-library-validation` entitlement for ad-hoc
  builds, or sign with the Developer ID when one exists.
