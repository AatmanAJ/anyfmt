# anyfmt.app design rules

The site keeps the Flare look (ink, paper greys, one ember accent, fluted glass) and these rules.
They exist because the first version broke them; check a page against them before calling it done.

## Type
- Page H1: `text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em]`.
- Section H2: `text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]`.
- H3: 22px semibold, tracking -0.025em. Body: 17px, leading 1.55, `text-mute`. Small: 15px. Captions: 13 to 14px `text-mute-2`.
- Nothing below 12px. Numbers that line up use `tabular-nums`.
- Bricolage (condensed) is for the wordmark and for version numbers on the changelog, nothing else. JetBrains Mono is for commands, code, file names and hex values; dates and step numbers are Inter Tight with tabular figures.

## Colour
- Text: `text-ink`, `text-mute` (#3a3a3a), `text-mute-2` (#6a6a6a). `text-mute-3` only when nothing else fits.
- `text-flare` fails contrast below 18px on white: use it for marks, dots and large type only.
- Volt is a highlight for one thing per screen. Format chips take `KIND_TINT` with `kindInk()` for the text.

## Shape
- Panels: `rounded-[28px]`. Things inside panels: 20px or 12px. Buttons and toggles: full pills.
- White cards on sand use `ring-1 ring-black/[.07]`, no shadow. Shadows only on things that float (nav pill, popovers, keycaps, dragged files).
- Group with space and hairlines (`divide-line`, `border-line`) before reaching for another box.

## Labels and copy
- One Eyebrow (square + words) per section at most. No letter-spaced uppercase labels; use 14px semibold sentence case.
- Headlines state the specific fact ("anyfmt is $19, once."). No two-beat aphorisms ("Pay for X. Never for Y."), no marketing words (unlock, seamless, supercharge), no em dashes.

## Icons and marks
- Phosphor icons only, one weight per context. Apple and GitHub use the official marks in `components/Marks.tsx`, never an icon-set redraw.

## Interaction
- Every control has `focus-visible:ring-2 focus-visible:ring-flare`.
- Hover says what a click will do. No tilting tickets, stamps, glows or pointer-following gradients on cards.
- Motion respects reduced motion; content is visible without JavaScript.

## Checking
- `node ~/.claude/skills/web-designer/scripts/shoot.mjs http://localhost:5310/<path> --widths 390,1440 --out <dir> --wait 800`
- Zero FAILs, and every full-page slice looked at, at both widths.
