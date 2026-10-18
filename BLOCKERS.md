# Blockers

Hard stops hit during the unattended build. Each entry says what was tried,
what a human needs to do, and the exact command or credential required.
Everything not listed here was completed.

---

## B-001 Real-hardware verification of mid-drag detection (needs a person, ~5 min)

**Why blocked:** the build machine's harness has no Accessibility permission and
can't synthesise mouse/keyboard input, so no real Finder drag plus key tap was
ever performed. All detection code uses permission-free public API (D-001), and
latency/CPU were measured with self-tests, but a human has to drag once.

**Do this:**

```bash
cd Spikes/DragProbe && swift run -c release DragProbe
```

Then drag a file from Finder and, mid-drag, tap Shift, then Command, then
Control. Drop on a segment. Repeat from the Desktop, a Finder list view,
Spotlight, a Mail attachment and Photos. The log (`~/Library/Logs/DragProbe.log`)
shows which source saw what first and the measured trigger→visible latency.
Expected: `A(poll): DRAG START`, `A(poll): TAP shift`, `overlay: draggingEntered`,
`overlay: DROP`.

Optional: repeat on a fresh macOS user account to confirm no TCC prompt appears.
