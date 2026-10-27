---
title: Uninstall anyfmt
description: Remove anyfmt completely. Delete the app and the command-line tool, clear its settings, presets, logs and packs, and revoke its permissions.
---

To uninstall anyfmt, quit it, delete the app, and remove the command-line link if you made one. If you want nothing left behind, also delete its settings, presets, logs and optional packs, and remove it from System Settings. Your converted files are never touched.

## 1. Before you delete the app

1. Open **Settings › General** and turn off **Launch anyfmt at login**.
2. If you linked the command-line tool, open **Settings › Advanced** and choose **Remove** next to **Command-line tool**.
3. Click the anyfmt menu bar icon and choose **Quit anyfmt**.

## 2. Delete the app

### If you installed the DMG

Drag `anyfmt.app` from **Applications** to the Trash.

If you linked the command-line tool by hand, or skipped step 3, delete the link from the folder you put it in, such as `/opt/homebrew/bin/anyfmt`, `/usr/local/bin/anyfmt`, `~/.local/bin/anyfmt` or `~/bin/anyfmt`. Check with:

```bash title="Terminal"
which anyfmt
```

### If you installed with Homebrew

```bash title="Terminal"
brew uninstall --cask anyfmt          # the app and its anyfmt link
brew uninstall --zap --cask anyfmt    # the same, plus its settings, caches, logs and support files
brew uninstall anyfmt-cli             # if you installed only the command-line tool
```

`--zap` removes the folders listed in the next step, except the Keychain items.

## 3. Remove what anyfmt stores

| What | Where |
|---|---|
| Presets, recent conversions, optional packs, received Mail and Photos files | `~/Library/Application Support/anyfmt` |
| Settings | `~/Library/Preferences/app.anyfmt.plist` |
| Caches | `~/Library/Caches/app.anyfmt` |
| Logs | `~/Library/Logs/anyfmt` |

To delete the files and folders in Terminal:

```bash title="Terminal"
rm -r ~/Library/Application\ Support/anyfmt ~/Library/Caches/app.anyfmt ~/Library/Logs/anyfmt
defaults delete app.anyfmt
```

The presets file is shared with the command-line tool. If you keep the CLI, keep `presets.json`.

## 4. Remove its permissions

anyfmt asks for permissions only for opt-in features. If you granted any, remove them in **System Settings › Privacy & Security**:

- **Accessibility** and **Input Monitoring**: select anyfmt and remove it.
- **Automation**: turn off anyfmt's switches for Finder, and for Pages, Keynote or Numbers if you used them.

## Reset instead of uninstalling

To start over without removing anything, use **Settings › Advanced › Reset All Settings…**. It puts every setting back to its default and leaves your files, launch at login and System Settings permissions alone.
