#!/usr/bin/env python3
"""Sync Swift-extracted strings into the String Catalogs.

Command-line `xcodebuild` emits `<file>.stringsdata` (SWIFT_EMIT_LOC_STRINGS)
but only the Xcode IDE writes them back into `.xcstrings`. This does that step
so every user-facing string is in a catalog (BUILD.md §2), ready to translate.

Existing entries (comments, translations) are kept. Keys no longer in code are
marked stale, as Xcode does. Usage: scripts/sync-strings.py <DerivedData dir>
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = {
    # build intermediates folder → catalog
    "HaloCore.build": "Sources/Shared/Localizable.xcstrings",
    "App.build": "Sources/App/Resources/Localizable.xcstrings",
}


def extracted(derived, folder):
    keys = {}
    pattern = os.path.join(derived, "Build/Intermediates.noindex/Halo.build/*", folder, "**/*.stringsdata")
    for path in glob.glob(pattern, recursive=True):
        try:
            data = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for entry in data.get("tables", {}).get("Localizable", []):
            key = entry.get("key")
            if key:
                comment = entry.get("comment") or ""
                keys.setdefault(key, comment)
    return keys


def sync(derived):
    for folder, catalog in TARGETS.items():
        path = os.path.join(ROOT, catalog)
        doc = json.load(open(path, encoding="utf-8"))
        strings = doc.setdefault("strings", {})
        found = extracted(derived, folder)
        if not found:
            print(f"warning: no extracted strings for {folder} (build first)")
            continue
        added = stale = 0
        for key, comment in found.items():
            entry = strings.get(key)
            if entry is None:
                strings[key] = {"comment": comment} if comment else {}
                added += 1
            else:
                entry.pop("extractionState", None)
                if comment and not entry.get("comment"):
                    entry["comment"] = comment
        for key, entry in strings.items():
            if key not in found and entry.get("extractionState") != "manual":
                entry["extractionState"] = "stale"
                stale += 1
        doc["strings"] = dict(sorted(strings.items(), key=lambda kv: kv[0].lower()))
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2, separators=(",", " : "))
            f.write("\n")
        print(f"{catalog}: {len(found)} strings ({added} new, {stale} stale)")


if __name__ == "__main__":
    sync(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build/DerivedData"))
