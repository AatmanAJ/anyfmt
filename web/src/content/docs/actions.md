---
title: Actions and Float
description: Use the anyfmt Actions wheel to AirDrop, float, copy, move, copy the path of, or open a terminal at any file or folder, plus the Float shelf and share links.
---

Actions do something with files without changing them: send them with AirDrop, park them on the Float shelf, copy them, move them, copy their paths, or open a terminal there. Press ⌃ Control mid-drag for the Actions wheel. Actions work on files, folders and mixed selections, including files that have nothing to convert.

## The six actions

| Action | What happens |
|---|---|
| **AirDrop** | Opens the AirDrop picker with every item you dragged. Several files and folders work. |
| **Float** | Puts the items on the Float shelf, a small floating window you can drag them out of later. See [The Float shelf](#the-float-shelf). |
| **Copy** | Puts the files on the clipboard. Press ⌘V in Finder to paste copies. Paste into a text field and you get their paths instead. |
| **Move** | Opens a small card at the drop point with up to 8 recent folders and **Choose Folder…**. Pick one and the items move there. |
| **Copy Path** | Copies the full paths, one per line. Hold ⌥ Option as you drop to copy shell-quoted paths separated by spaces, ready to paste into a command. |
| **Terminal** | Opens your terminal app at the folder you dropped, or at a file's folder. For several items, it opens the deepest folder they share. |

### Move

- With no recent folders yet, Move goes straight to the folder chooser (**Move Here**).
- In the card: ↑ and ↓ move, Return chooses, 1 to 8 pick a folder, ⌘O opens the chooser, Esc cancels. Clicking elsewhere cancels too.
- **Move never overwrites.** A taken name gets a Finder-style one, such as `photo 2.jpg` or `Project 2`, and folders are never merged.
- **Across disks**, anyfmt copies first and removes the original only after the copy is complete, so an interrupted move never leaves a half-copied file under the real name.
- Moving a folder into itself is refused before anything is touched.
- There's no undo for Move yet.

Clear the recent folders in **Settings › General › Actions › Recent Move folders**.

### Terminal

Choose the app in **Settings › General › Actions › Open Terminal action in**. Only terminals you have installed are listed: Terminal, iTerm2, Ghostty and Warp. If the one you chose is gone, Terminal is used.

Ghostty opens a new tab rather than a window. To get a window, set `macos-dock-drop-behavior = new-window` in Ghostty's config. The Terminal action needs no Automation permission.

### Files from Mail and Photos

Mail attachments and Photos items arrive as promised files. anyfmt receives them into `~/Library/Application Support/anyfmt/Received/` and deletes each batch after 3 days. The originals stay in Mail and Photos.

## The Float shelf

The Float shelf holds files so you can drag them somewhere else later, for example from one Space to another. It holds references to your files, not copies.

### Open it

- Drop files on **Float** on the Actions wheel. The shelf pops up at the drop point.
- Or click the anyfmt menu bar icon and choose **Show Float Shelf**. An empty shelf says "Drop files here".

The shelf floats above other windows, stays put when you change Spaces, and sits over full-screen apps.

### Use it

- **Collapsed**, the shelf shows the newest 3 items as a small pile, with a count and a summary such as "2 images, 1 folder".
- **Click the pile**, or rest the pointer on it for a moment, to see every item in a grid.
- **Drag the pile out** to take every item, or drag one item from the grid. The destination treats it like a drag from Finder: the same disk moves, another disk copies, ⌥ Option copies.
- **A plain drag out removes the items from the shelf. Hold ⌥ Option to keep them.** A cancelled drag puts them back.
- **Drop more files on the shelf** at any time, including Mail attachments and Photos items.
- **Right-click** (or the ⋯ button) for Reveal in Finder, Copy, Copy Paths, AirDrop All…, Show All or Collapse, and Clear Shelf. Right-click one item in the grid for Open, Reveal, Copy, Copy Path, AirDrop… and Remove from Shelf. Double-click an item to open it.
- The ✕ in the corner clears the shelf.

The shelf follows files you rename or move, and drops files you delete or trash. When it's empty, it closes. Drag it by its background to move it: it snaps to a screen edge and remembers where you left it.

### Limits

- No Quick Look on shelf items yet.
- No arrow-key navigation between items yet. VoiceOver can reach and act on every item.

## Share link (Pro)

> [!PREVIEW]
> Share links are built and tested in the app against a mock server, but the hosted server isn't live yet. Signed out, choosing Share link explains what it does and uploads nothing.

Share link is a Pro segment on the Actions wheel, marked with a cloud glyph and a **Pro** chip. It uploads the files, makes a link, and copies the link to your clipboard.

1. Drop files on **Share link**.
2. Set the link options: **Expires**, **Require a password** (at least 4 characters), and **Limit downloads**. A custom **Domain** appears when your plan includes one.
3. Choose **Create Link**.
4. The first time you upload to a server, a one-time note says the files will leave your Mac and which server they go to. Choose **Continue**.

The link is copied to your clipboard when it's ready.

Uploads resume after a dropped connection. A "Your links" list for revoking links from the app isn't built yet. See [What Pro adds](/docs/pro).
