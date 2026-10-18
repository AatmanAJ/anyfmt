#!/usr/bin/env python3
"""Writes docs/REDESIGN.md: the phase 2 redesign, before and after, side by side.

before = docs/screens/before (phase 1 renders), after = docs/screens/after (current).
Pairs by file name; onboarding pages were renumbered, so they're paired by page."""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
BEFORE = os.path.join(ROOT, "docs/screens/before")
AFTER = os.path.join(ROOT, "docs/screens/after")

GROUPS = [
    ("Wheel", ["wheel-"]), ("Options", ["options-"]), ("Progress and toasts", ["progress-", "toast-"]),
    ("Float, Move and actions", ["float-", "move-", "action-", "airdrop", "terminal", "clipboard"]),
    ("Settings", ["settings-"]), ("Cloud", ["cloud-"]), ("Editors", ["editor-"]), ("About and icon", ["about", "app-icon"]),
]
# Phase 1 onboarding page → phase 2 page (welcome was added in front).
ONBOARDING = {"onboarding-1": "onboarding/onboarding-2", "onboarding-2": "onboarding/onboarding-3",
              "onboarding-3": "onboarding/onboarding-4", "onboarding-4": "onboarding/onboarding-5"}

def files(d):
    return sorted(f for f in os.listdir(d) if f.endswith(".png"))

def group_of(name):
    for title, prefixes in GROUPS:
        if any(name.startswith(p) for p in prefixes):
            return title
    return "Other"

before, after = files(BEFORE), set(files(AFTER))
out = ["# Redesign: before and after", "",
       "Phase 2 moved every surface to the approved direction (BLOCKERS B-014, decisions D-039 and D-042):",
       "near-black surfaces, cobalt and orange pills, the heat band used once per surface,",
       "Inter Display for format names, headlines and numerals, and two radii.",
       "Left: phase 1 (`docs/screens/before/`). Right: now (`docs/screens/after/`, from `make gallery`).",
       "", "The approved direction board is in `docs/screens/after/direction/`.", "",
       "![Direction: wheel](screens/after/direction/1-wheel-locked-presets-dark.png)", ""]
rows = {}
for b in before:
    stem = b[:-4]
    a = None
    if b in after:
        a = "after/" + b
    else:
        for old, new in ONBOARDING.items():
            if stem == old or stem.startswith(old + "-"):
                cand = new + stem[len(old):] + ".png"
                if os.path.exists(os.path.join(AFTER, cand)):
                    a = "after/" + cand
    if a:
        rows.setdefault("Onboarding" if stem.startswith("onboarding") else group_of(b), []).append((b, a))
order = ["Wheel", "Options", "Onboarding", "Progress and toasts", "Float, Move and actions", "Settings", "Cloud",
         "Editors", "About and icon", "Other"]
for g in order:
    if g not in rows:
        continue
    out += [f"## {g}", "", "| Before | After |", "|---|---|"]
    for b, a in rows[g]:
        out.append(f"| ![{b}](screens/before/{b}) | ![{a}](screens/{a}) |")
    out.append("")
paired = {a for rs in rows.values() for _, a in rs}
new = sorted(x for x in after if "after/" + x not in paired)
new_onb = sorted("onboarding/" + x for x in files(os.path.join(AFTER, "onboarding"))
                 if "after/onboarding/" + x not in paired)
if new or new_onb:
    out += ["## New in phase 2 (no phase 1 equivalent)", ""]
    for x in new_onb + new:
        out.append(f"![{x}](screens/after/{x})")
    out.append("")
open(os.path.join(ROOT, "docs/REDESIGN.md"), "w").write("\n".join(out))
print(f"REDESIGN.md: {sum(len(r) for r in rows.values())} pairs, {len(new) + len(new_onb)} new")
