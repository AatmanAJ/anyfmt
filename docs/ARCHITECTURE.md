# Architecture

anyfmt is a menu-bar agent (`LSUIElement`). There's no Dock icon and no main window.
Everything starts from a drag.

```mermaid
flowchart LR
    subgraph Finder["Finder (owns the drag session)"]
        D[User drags files]
    end

    subgraph Sense["DragSense · MIT package"]
        P[Poller: buttons, drag pasteboard changeCount, modifier flags]
        M[Global mouse monitor: wake-up only]
        SM[State machine: idle → dragging → wheelOpen(kind) → dropped / cancelled]
        M --> P --> SM
    end

    subgraph Wheel["Wheel · RadialMenu MIT package + Sources/Wheel"]
        C[WheelContentProvider: targets / tools / actions for these files]
        O[Overlay NSPanel: non-activating, accepts the drop]
        R[RadialMenuView: layout, hover, keyboard, VoiceOver]
        C --> R --> O
    end

    subgraph Core["AnyfmtCore.framework (no UI)"]
        F[Formats + FileKind]
        T[(CapabilityTable: lane route files)]
        RT[Router: ≤3 hops, cost model, multi-file intersection]
        EX[RouteExecutor: hop by hop in a temp dir]
        EN[Engines: ImageIO · PDFKit · AVFoundation · ffmpeg · resvg · docs · sheets · archives · subtitles]
        TR[ToolRunners: 26 tools]
        J[Job / JobQueue: CPU = P-cores − 1, VideoToolbox = 1]
        N[OutputNamer / OutputPlacer: never overwrite, Finder-style names]
        T --> RT --> EX --> EN
        J --> EX
        J --> TR
        J --> N
    end

    subgraph AppUI["App target"]
        PW[Progress windows: stack, ETA, cancel, reveal]
        ED[Editors: shared EditorShell]
        AC[Actions: AirDrop, Float, Copy, Move, Copy Path, Terminal]
        CL[Cloud client: Pro only, gated, zero network when signed out]
        ST[Settings, onboarding, menu bar]
    end

    D -- "drag pasteboard (read-only, no TCC)" --> P
    SM -- "tap Shift / Command / Control" --> C
    C --> RT
    O -- "drop on segment" --> J
    O -- "tool with editor" --> ED --> J
    O -- "action" --> AC
    O -- "Pro segment" --> CL --> J
    J --> PW
    N -- "result beside the original" --> Finder
    CLI["anyfmt CLI"] --> RT
    CLI --> J
    MX["anyfmt-matrix"] --> EX
```

## Layers

| Layer | Where | Depends on | Knows about files? |
|---|---|---|---|
| DragSense | `Packages/DragSense` (MIT) | AppKit | Only as URLs on the drag pasteboard |
| RadialMenu | `Packages/RadialMenu` (MIT) | AppKit, QuartzCore | No: generic items |
| AnyfmtCore | `Sources/{Shared,Engine,Jobs/Core,Tools/Core}` | Foundation, ImageIO, PDFKit, AVFoundation, Vision, WebKit (for HTML→PDF) | Yes |
| App | `Sources/{App,Wheel,Jobs/UI,Tools/Editors,Actions,Cloud,Settings}` | AnyfmtCore, DragSense, RadialMenu, Sparkle | Yes |
| CLI / matrix | `Sources/CLI`, `Tests/Matrix` | AnyfmtCore | Yes |

## The single table

`CapabilityTable.default` concatenates each lane's route file. A row is
`(from, to, engine, options schema, priority, cost, arity, flags, minimum macOS)`.
The router plans over the rows whose engine reports itself available at
runtime: binary present, OS encoder present, optional pack installed, opt-in
granted. Adding a format is one `Format` in `FormatCatalog.swift` plus one row and one
engine method.

## A conversion, end to end

1. **Sense.** The mouse goes down, so the poller switches to 240 Hz. The drag
   pasteboard's `changeCount` moves and it carries file types, so the state is
   `dragging(urls)`. A Shift tap gives `wheelOpen(.convert)`.
2. **Content.** `Formats.detect` runs on each URL, then
   `Router.commonTargets(for:)`. Favourites are ordered first and hidden formats
   removed. Over 8 targets, a second ring is added.
3. **Show.** The overlay panel appears under the pointer (pushed inward at
   screen edges) without taking focus. Finder still owns the drag.
4. **Drop.** `performDragOperation` resolves the segment by angle from the hub.
   File promises are received into a temp dir. A `ConversionJob` is queued per
   file (or one job for `.combine` rows).
5. **Run.** `RouteExecutor` runs each hop into `tmp/stepN/`, and progress flows
   through `ProgressSink` into `Progress`.
6. **Place.** `OutputPlacer` builds the name (`photo.jpg`, `photo 2.jpg`, …) and
   moves the file with `renamex_np(RENAME_EXCL)`. Dates are copied for
   conversions. The file is revealed in Finder (per setting) and the progress
   window shows the success state.

## Concurrency

- Swift 6 strict concurrency. UI types are `@MainActor`. Engines are `Sendable`
  structs, and jobs run in Tasks.
- `JobQueue` admits at most (performance cores − 1) CPU jobs and 1 VideoToolbox
  job at a time, so a batch of 40 HEICs doesn't starve the UI and two hardware
  encodes don't fight over the media engine.
- Subprocesses (`ProcessRunner`) terminate on Task cancellation (SIGTERM, then
  SIGKILL after 2 s).

## Privacy boundary

- Nothing in AnyfmtCore opens a network connection. The bundled ffmpeg is built
  with `--disable-network`.
- `Sources/Cloud` is the only code that talks to a server, and only after
  sign-in plus an explicit cloud action. Sparkle runs only if the user opted in.
- `scripts/check-entitlements.sh` (part of `make test`) fails the build if local
  code consults `Entitlements`.
