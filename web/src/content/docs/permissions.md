---
title: Permissions
description: The anyfmt wheel needs no macOS permissions. See what it reads, which optional extras ask for access and why, and when anyfmt uses the network.
---

The wheel needs no macOS permissions at all. anyfmt reads the mouse button, the modifier keys and the system drag pasteboard, which any app can read without a grant. Two optional extras ask for more, and both stay off until you turn them on.

## What the wheel reads

| It reads | Why |
|---|---|
| Whether the mouse button is down | To know a drag might be in progress |
| The system drag pasteboard | To see that the drag carries files, and of which type |
| Which modifier keys are down (⇧ ⌘ ⌃ ⌥ fn) | To open the wheel you asked for |

anyfmt never logs keystrokes, and it can't: it doesn't see ordinary keys. A drag of text or an image that isn't a file is ignored.

The wheel works with no Accessibility or Input Monitoring grant. This was checked in the same process that runs the drag detection.

## Optional: press Return in Finder

You can select files in Finder and press Return to open the wheel, instead of dragging. It's off by default. Turn it on in **Settings › Keys › Finder › Return opens the wheel for the Finder selection**, or on the permissions page of the welcome window.

It needs three permissions:

| Permission | Why |
|---|---|
| Accessibility | To catch Return in Finder before Finder starts renaming the file |
| Input Monitoring | To notice the Return key while Finder is in front. Every other key is passed through untouched |
| Automation for Finder | To ask Finder which files are selected. Nothing else is read |

When you turn the setting on, anyfmt lists each permission with one sentence about it and a button that opens the exact pane of **System Settings › Privacy & Security**. It notices the grant as soon as you give it, with no restart. If one is missing, it says which.

While the shortcut is on, Return opens the wheel only when Finder is in front, files are selected, and you aren't typing in a text field, so renaming still works.

The menu bar item **Open Wheel for Finder Selection** also asks Finder for the selection, so macOS asks for Automation for Finder the first time you use it.

## Ways in that need no permission

- **Services menu.** Right-click files in Finder and choose **Services › Open in anyfmt Wheel**. You can give it a shortcut in **System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders**.
- **Drop ring.** Press ⌃⌥Space to open an empty ring at the pointer, then drag files onto it. Change the shortcut in **Settings › Keys › Drop ring**.

## Optional: Pages, Keynote and Numbers

Exporting to `.pages`, and opening `.key` and `.numbers` files, works by asking your installed iWork apps to do the conversion. That needs **Automation** for Pages, Keynote or Numbers, and macOS asks once per app.

> [!WARNING]
> iWork conversions are opt-in, have no switch in Settings yet, and haven't been tested end to end. To try them, install the iWork apps and run `defaults write app.anyfmt optIn.iWorkAppleEvents -bool YES` in Terminal.

## Files and Folders prompts from Terminal

The `anyfmt` command-line tool needs no permission to convert files you can read. If you convert files in Desktop, Documents or Downloads from Terminal, macOS may show a Files and Folders prompt. macOS asks on behalf of your terminal app, not anyfmt, so grant it to the terminal.

## The network

- **Local conversions make no network requests.** The bundled ffmpeg is built without network support. A test samples the sockets of the app, the CLI and the engines during a workload, and finds none.
- **Update checks are opt-in.** When on, anyfmt fetches an update feed once a day and sends nothing else.
- **Optional packs are never downloaded by anyfmt.** **Install** in **Settings › Engines** opens the official download page in your browser. You choose the downloaded file, and anyfmt checks it against a pinned SHA-256 before installing it.
- **Nothing uploads.** anyfmt has no account and no cloud features. Your files never leave your Mac.

## Turn a permission off

1. Turn the feature off in **Settings › Keys**.
2. In **System Settings › Privacy & Security**, remove anyfmt from **Accessibility** and **Input Monitoring**, and turn off anyfmt's entries under **Automation**.

macOS ties these grants to the app's bundle id, `app.anyfmt`.
