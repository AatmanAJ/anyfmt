---
title: Settings
description: Every anyfmt setting in its seven panes, General, Keys, Output, Formats, Engines, Account and Advanced, with what each one does and its default.
---

Open Settings from the anyfmt menu bar icon › **Settings…**, or press ⌘, while that menu is open. Settings has seven panes: General, Keys, Output, Formats, Engines, Account and Advanced. Everything here is stored on this Mac unless you turn on Pro sync.

## General

| Setting | What it does | Default |
|---|---|---|
| Launch anyfmt at login | Starts anyfmt quietly in the menu bar when you log in | Chosen in the welcome window |
| Play sounds | A soft chime when a conversion finishes | On |
| Haptic feedback | A light tick on Force Touch trackpads as you move between segments | On |
| Open Terminal action in | Which app the Terminal action opens: Terminal, iTerm2, Ghostty or Warp, whichever are installed | Terminal |
| Recent Move folders | The folders the Move card offers. **Clear** empties the list | Empty |
| Check for updates automatically | Checks the update server once a day. Nothing else is sent | Off |
| Check Now | Asks the update server once, even with automatic checks off | |

macOS doesn't deliver haptics to an app that isn't active, so you won't feel the tick during a Finder drag.

## Keys

| Setting | What it does | Default |
|---|---|---|
| Wheels: Convert, Tools, Actions | The key that opens each wheel: ⇧ Shift, ⌘ Command, ⌃ Control, ⌥ Option or fn Function. Picking a key in use swaps the two | ⇧, ⌘, ⌃ |
| Open the wheel | **When the key goes down (tap or hold)**, or **Only on a quick tap** | When the key goes down |
| Tap speed | With quick taps only: the longest press that still counts, 0.15 to 0.8 s. A test area shows whether each press counted | 0.35 s |
| Open a drop ring with a shortcut | A shortcut opens an empty ring at the pointer to drop files on. Needs no permissions | On |
| Shortcut | The drop ring's shortcut. Must include ⌘ or ⌃ | ⌃⌥Space |
| Return opens the wheel for the Finder selection | Select files and press Return instead of dragging. Lists the three permissions it needs, with buttons to grant them | Off |

The **Finder** section also explains the Services menu item and has a **Keyboard Shortcuts…** button that opens the right pane of System Settings. See [Keys and shortcuts](/docs/keyboard) and [Permissions](/docs/permissions).

## Output

| Setting | What it does | Default |
|---|---|---|
| Save converted files | **Beside the original**, or a folder you pick with **Choose Folder…** | Beside the original |
| Show in Finder when done | Selects the new file in a Finder window | On |
| Name pattern | How converted files are named. Insert **{name}**, **{format}** and **{date}**; a live example shows the result. Tools also add their suffix, such as "compressed" | `{name}` |
| In converted copies | **Keep everything**, **Remove private details** (location, device and author; keeps orientation and colour profile), or **Remove all** (everything the format allows, including orientation and colour profile) | Keep everything |
| Keep the original's dates | Converted copies get the original's created and modified dates. Tool results are dated now | On |

Files are never overwritten. If a name is taken, a number is added, as Finder does. If the folder you chose goes missing, files are saved beside the original until you choose another.

## Formats

The Formats pane has two tabs.

**Formats** lists every format by kind, with a search field. Star a format to make it a favourite: favourites sit first on the ring, in the order of the **Favourites** list, which you can drag to reorder. Select a format to see:

| Setting | What it does |
|---|---|
| Show on the wheel | Turn off to hide the format from the wheel. Hidden formats stay available from the command line |
| Also offer it for other kinds of files | Shows opt-in routes to this format, such as a photo to it through PDF and text recognition. Off by default; see [How routes work](/docs/routes) |
| Favourite | Same as the star |
| Defaults for converting to… | The options the wheel uses for this target. **Restore Defaults** puts back the shipped values |
| Presets | This format's presets, with **Save Current Defaults as Preset** and **Restore Built-in Presets**. Each preset has **Use as Defaults**, **Move Up**, **Move Down** and **Delete Preset** (or **Hide Built-in Preset**) |

**Tools** lists every local tool by group, Images, Video, Audio, Metadata and PDF, with a switch to show or hide it on the Tools wheel. Each one says whether it opens an editor or runs straight away. See [Options and presets](/docs/options-presets).

## Engines

**Bundled engines** lists every engine inside the app with its version and licence. **Licence…** opens that engine's licence folder, and **All Licences…** opens the folder with all of them. anyfmt also uses macOS's own frameworks.

**Optional packs** lists the packs this build offers, such as pandoc and the Office pack (LibreOffice), each with **Install** or **Remove**. Packs are never downloaded unless you choose **Install**: it opens the official download page in your browser, then you pick the downloaded file and anyfmt checks it against a pinned SHA-256. The Office pack can't be installed yet because its checksum isn't pinned.

## Account

> [!PREVIEW]
> The Account pane is built and tested against a mock server, but the hosted server isn't live yet. Nothing here is needed for anything that runs on your Mac.

| Section | What it does |
|---|---|
| Account | **Sign In…** opens the server's sign-in page in your browser and emails you a link. If you open the link on another device, choose **Opened the link on another device?** and type the code. Signed in, it shows your email, plan and usage, and **Sign Out** |
| Pro licence key | Paste an `ANYFMT1-…` key and choose **Activate**. **Remove Licence…** takes it off this Mac. See [Licence keys](/docs/licence-keys) |
| Sync | **Sync across your Macs**: favourites, wheel order, presets, recipes and settings. **Sync Now**. Off by default |
| Inbox | **Receive files from your phone or browser**: new files are saved to a folder you choose (**Save to**), then removed from the server. **Check Now**. Off by default |
| Server | **Server URL**, **Validate**, **Use This Server** and **Reset to Default**, for pointing anyfmt at your own server. Each server keeps its own sign-in. See [Self-host the server](/docs/self-host) |

The menu bar item **Pro Licence & Account…** opens this pane.

## Advanced

| Setting | What it does | Default |
|---|---|---|
| Conversions at once | How many conversions run in parallel. Automatic is your performance cores minus one, so the Mac stays responsive. Hardware video encodes run one at a time | Automatic |
| Detailed logging | Adds each engine step to the system log. Turn it on before reproducing a problem | Off |
| Read the log in Terminal | **Copy Command** copies `log show --last 1h --info --debug --predicate 'subsystem == "app.anyfmt"'` | |
| Logs folder | `~/Library/Logs/anyfmt`. **Show in Finder** opens it | |
| Diagnostics for a bug report | **Copy Diagnostics** copies versions, macOS, engines and settings, with no file names or paths | |
| Command-line tool | **Install** links `anyfmt` into a folder on your `PATH`, with no password; **Remove** unlinks it. **Copy Command** copies the `ln -s` line instead | |
| Reset All Settings… | Puts every setting back to its default. Your files, launch at login and System Settings permissions aren't touched | |

## Where settings are stored

| What | Where |
|---|---|
| Settings | The `app.anyfmt` preferences domain (`~/Library/Preferences/app.anyfmt.plist`) |
| Presets and recent conversions | `~/Library/Application Support/anyfmt/presets.json` and `recents.json` |
| Optional packs | `~/Library/Application Support/anyfmt/Packs/` |
| Logs | `~/Library/Logs/anyfmt` |
| Licence key and sign-in | Your login Keychain, not synced to iCloud |
