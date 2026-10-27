---
title: Keys and shortcuts
description: Every anyfmt key and shortcut, mid-drag and with a wheel in focus, in editors and panels, and how to change the trigger keys in Settings › Keys.
---

anyfmt is driven by modifier keys while you drag, and by ordinary keys once a wheel has the keyboard. This page lists every key and where it works, then shows how to change the trigger keys in **Settings › Keys**.

## While you drag

| Key | Does |
|---|---|
| ⇧ Shift | Opens the Convert wheel |
| ⌘ Command | Opens the Tools wheel |
| ⌃ Control | Opens the Actions wheel |
| Another trigger key | Switches to that wheel |
| ⌥ Option, tapped | Locks the highlighted segment. Tap again to release it |
| ⌥ Option, held as you drop | Opens the options panel instead of converting |
| ⌥ Option, held as you drop on Copy Path | Copies shell-quoted paths |

These are the defaults. A tap and a hold both open the wheel. To cancel, move to the centre of the wheel and let go.

## When a wheel has the keyboard

A wheel takes the keyboard when you open it without dragging: from the Services menu, the drop ring, the menu bar, or Return in Finder.

| Key | Does |
|---|---|
| ← → | Previous or next segment, wrapping around |
| ↑ ↓ | Out to the outer ring, or in to the inner ring. With one ring, previous or next |
| 1 to 9 | Highlights segment 1 to 9. Press Return to apply it |
| Return or Enter | Applies the highlighted segment |
| ⌥ Return | Opens the options panel for the highlighted segment |
| Space | Locks or releases the highlighted segment |
| Tab, ⇧ Tab | Next or previous wheel |
| Page Up, Page Down | Previous or next page of the outer ring |
| Escape | Cancels |
| Right-click a segment | Opens its options |
| Scroll | Flips the outer ring's pages |

When the wheel opens for a Finder selection, the first target is already highlighted, so Return converts to it.

## Shortcuts that work anywhere

| Shortcut | Does | Change it in |
|---|---|---|
| ⌃⌥Space | Opens an empty drop ring at the pointer | **Settings › Keys › Drop ring**. A new shortcut must include ⌘ or ⌃ |
| Return in Finder | Opens the wheel for the selected files. Off by default, needs three permissions | **Settings › Keys › Finder** |
| Your own | Runs **Services › Open in anyfmt Wheel** on the selected files | **System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders** |

## In editors and panels

| Key | Where | Does |
|---|---|---|
| Return | Tool editors, options panel, share-link sheet | Saves a copy, converts, or runs the main button |
| Esc | Tool editors, options panel, sheets | Cancels |
| B | Tool editors | Toggles Before / After |
| ⌘Z, ⇧⌘Z | Annotate | Undo, redo |
| ⌘Z | Redact | Undo |
| ⌥⌘ and a letter | Annotate | Picks a drawing tool. Hover a tool to see its letter |
| ↑ ↓, Return, 1 to 8, ⌘O, Esc | Move card | Pick a recent folder, open the chooser, or cancel |

## Menu bar menu

With the anyfmt menu open, ⌘, opens **Settings…** and ⌘Q quits. Hold ⌥ Option as you click the icon to also show **Wheel Gallery** and **Show Welcome…**.

## Change the trigger keys

1. Open **Settings › Keys**.
2. Under **Wheels**, choose a key for Convert, Tools and Actions: ⇧ Shift, ⌘ Command, ⌃ Control, ⌥ Option or fn Function. If you pick a key another wheel uses, the two swap.
3. Under **Open the wheel**, choose when a key opens it:
   - **When the key goes down (tap or hold)**, the default.
   - **Only on a quick tap.** Holds and combinations are ignored, so holding ⌘ mid-drag moves a file in Finder as usual.

With **Only on a quick tap**, a **Tap speed** slider sets the longest press that still counts as a tap, from 0.15 to 0.8 seconds (0.35 by default). A test area under it tells you whether each press counted as a tap. It watches keys only while the Settings window is open.

If you make ⌥ Option a trigger key, ⌥ no longer locks a segment.
