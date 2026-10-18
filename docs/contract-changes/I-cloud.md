# Contract changes proposed by lane I (cloud client)

Nothing here blocks the lane: the cloud client works with the frozen
contracts as they are. These are small additions that make the Pro tools
configurable like every other tool.

## 1. Option schemas for the three cloud tools (`Sources/Shared/Specs.swift`)

**What.** `ToolIDs.transcribe`, `.upscale` and `.removeBackgroundHQ` are
declared with `schema: .none`, so the options popover can't offer SRT vs VTT,
a language, or an upscale factor. Today the client defaults to SRT /
`language=auto` / 2×.

**Proposed signature** (add to `ToolSchemas`, and pass `schema:` in the three
`ToolCatalog.all` rows):

```swift
public static let transcribe = OptionsSchema("tool.transcribe", [
    OptionSpec("format", L("Format"), .choice([
        OptionChoice("srt", "SRT"), OptionChoice("vtt", "WebVTT"), OptionChoice("txt", L("Plain text")),
    ]), default: .string("srt")),
    OptionSpec("language", L("Language"), .choice([
        OptionChoice("auto", L("Detect automatically")), OptionChoice("en", "English"), OptionChoice("es", "Español"),
        OptionChoice("fr", "Français"), OptionChoice("de", "Deutsch"), OptionChoice("ja", "日本語"),
    ]), default: .string("auto")),
])

public static let upscale = OptionsSchema("tool.upscale", [
    OptionSpec("scale", L("Scale"), .choice([OptionChoice("2", "2×"), OptionChoice("4", "4×")]), default: .string("2")),
])
```

**Why.** Every other tool's options come from the shared schema; the cloud
tools should too. The client already forwards whatever `OptionValues` it is
given (`CloudJobOperation.tool(_:target:options:)`), and the contract's
`JobOperation.options` is free-form, so no server change is needed.

**Client side: already done.** `CloudJobOperation.forTool(_:options:)` reads
`format` (→ the job's target format), `language` and `scale` when present and
falls back to SRT / `auto` / 2× when they aren't, so merging the schemas needs
no change in Sources/Cloud.

