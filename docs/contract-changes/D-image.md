# Contract change requests from lane D (Image + PDF)

All of these are worked around locally; nothing in lane D is blocked.

## 1. `StandardSchemas.imageOpaqueLossless` (Sources/Shared/Options.swift)

**What.** A schema for lossless formats that can't hold alpha (BMP): background colour + max size, no
quality slider (`imageOpaque` shows a quality slider BMP ignores).

```swift
public static let imageOpaqueLossless = OptionsSchema("image.opaque.lossless", [
    OptionSpec(OptionKey.background, L("Background for transparency"), .color, default: .string("#FFFFFF")),
    OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0),
               help: L("Longest edge in pixels. 0 keeps the original size.")),
])
// and add it to `StandardSchemas.all` (so `schema(_ id:)` finds it).
```

**Workaround.** `ImageRoutes.opaqueLosslessSchema` with the same id and specs. When the standard one lands,
`ImageRoutes.schema(for: .bmp)` switches to it (one line).

## 2. `EngineIDs.pdfKit` belongs to lane D

`EngineRegistry` is keyed by engine id, so two engines with the same id silently replace each other.
Lane D's `PDFKitEngine` (id `pdfkit`) serves PDF → images and PDF → TXT. If lane F renders or extracts PDFs
for DOCX/PPTX/XLSX/EPUB/MD/HTML it should use its own id (e.g. `ooxml`, `markdown`, `epub`, already in
`EngineIDs`), or call `PDFKitEngine` internally. No signature change; a note for the merge.

## 3. Let unit tests see the bundled engines

`EngineLocator.shared` reads `ANYFMT_ENGINES_DIR`, but `xcodebuild test` doesn't reliably forward the shell's
environment to the test process. Proposed (project.yml, scheme `anyfmt` → test):

```yaml
    test:
      environmentVariables:
        ANYFMT_ENGINES_DIR: $(ENGINES_DIST)
```

**Workaround.** `ImageTestSupport` finds `Engines/dist` by walking up from the test file, builds its own
`EngineLocator` for every request, and `setenv`s `ANYFMT_ENGINES_DIR` (no overwrite) before first use of
`EngineLocator.shared`.

## 4. Matrix runner notes (Tests/Matrix, Phase 4)

- Animated AVIF written by ffmpeg exposes **two** video streams to ffprobe: the still primary item (1 frame)
  and the sequence track (N frames). Count frames on the longest stream (`-select_streams v`, max of
  `nb_read_frames`), not `v:0`.
- `.multiOutput` PDF rows return one file per page (`sample-001.png`…; a one-page PDF returns `sample.png`).
  `sample.pdf` has 3 pages.
- Lane D's own sweep (`ImageRouteSweepTests`) already validates every image row; its `validate(_:route:)`
  can be lifted into the matrix runner as-is.

## 5. New localisable strings in AnyfmtCore

Added via `L(...)`; please add to `Sources/Shared/Localizable.xcstrings` when merging:

- `“%@” is password-protected. Open it in Preview, remove the password, then try again.`
- `No text was found in “%@”.`
- (`Background for transparency`, `Max size`, `Longest edge in pixels. 0 keeps the original size.` reuse
  existing keys.)
