# Contributing

Thanks for helping. anyfmt is a menu-bar app, so most changes touch one of three
places: the **capability table** (formats), a **tool**, or the **wheel**.

## Licence of contributions

anyfmt is AGPL-3.0, and `Packages/DragSense` and `Packages/RadialMenu` are MIT.
Your contribution goes in under the same licence as the code it touches, and you
keep the copyright.

We use the [Developer Certificate of Origin](https://developercert.org) (DCO)
instead of a contributor agreement. Sign off every commit to say you wrote it, or
otherwise have the right to submit it under the project's licence:

```bash
git commit -s -m "fix(wheel): …"
```

That adds a `Signed-off-by: Your Name <you@example.com>` line. The DCO check on
your pull request fails if a commit is missing one. To fix earlier commits, run
`git rebase --signoff main` and force-push your branch.

Why a DCO? See `docs/DECISIONS.md` D-044.

## Build from source

```bash
make bootstrap   # build-machine tools: xcodegen, meson, ninja, nasm… (users never need these)
make engines     # ffmpeg/ffprobe/resvg from pinned, checksummed sources (~10 min, once)
make build       # generates anyfmt.xcodeproj from project.yml and builds
make test        # package tests + unit tests + policy checks
make matrix      # every conversion on a generated fixture, validated → docs/MATRIX.md
```

`anyfmt.xcodeproj` is generated. Edit `project.yml`, never the project file.

## Add a format in one row

Say ImageIO learned to write a new format `foo`.

1. **Describe the format once** in `Sources/Shared/FormatCatalog.swift`:

   ```swift
   public static let foo: FormatID = "foo"
   // in `all`:
   Format(foo, kind: .image, label: "FOO", name: L("Foo image"), extensions: ["foo"], types: ["org.example.foo"], order: 180),
   ```

2. **Add one capability row** in the lane file that owns the engine, here
   `Sources/Engine/Image/ImageRoutes.swift`:

   ```swift
   Capability(Formats.png, Formats.foo, EngineIDs.imageIO, schema: StandardSchemas.imageLossy),
   ```

   The router does the rest: every format that reaches PNG now reaches FOO,
   within three hops. Multi-file drags, the wheel, the CLI (`anyfmt convert x.heic --to foo`)
   and the matrix all pick it up from the same table.

3. **Teach the engine the one method it needs**, if it doesn't already handle
   the target generically. For ImageIO that's usually just mapping `foo` to its
   UTType in the encoder.

4. **Add a fixture** for new *input* formats: `Tests/Fixtures/lanes/<lane>.sh`
   must write `sample.foo`.

5. Run `make matrix`. The new routes show up in `docs/MATRIX.md` and must pass.

If a route can't be done well, don't ship a bad one. Leave the row out and add
a line to `docs/PARITY.md` saying what it would take.

## Add a tool

1. Declare it in `ToolCatalog` (`Sources/Shared/Specs.swift`): id, title,
   glyph, kinds, arity, options schema, output suffix.
2. Implement a `ToolRunner` (`Sources/Tools/Core/...`) and register it.
3. If it needs an editor, build it on `EditorShell` (`Sources/Tools/Editors/Shell`)
   so it gets the standard preview, before/after toggle, sidebar and "Save copy".

## Rules the build enforces

- **Local is free, forever.** Nothing that runs on the Mac may consult
  `Entitlements`. `scripts/check-entitlements.sh` fails `make test` otherwise.
- **Never overwrite.** Engines write into their temp directory, and `OutputPlacer`
  places results with Finder-style names using an exclusive rename.
- **No network** outside `Sources/Cloud`. The bundled ffmpeg is built with
  `--disable-network`.
- Swift 6 strict concurrency, macOS 13 deployment target, no force unwraps
  outside tests, `os.Logger` instead of `print`, every user-facing string localisable.
- **No private APIs**, and no code copied from other projects. Reading for ideas is fine.

## Commits and PRs

Use conventional commits (`feat(image): …`, `fix(wheel): …`), keep `main`
green (`make build && make test`), and include screenshots for UI changes. The
Wheel Gallery (`make gallery`) renders every wheel state into `docs/screens/`.
