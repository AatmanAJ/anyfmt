---
title: What Pro adds
description: anyfmt Pro adds features that need a server, share links, cloud video jobs, sync, an inbox from your phone, transcription, upscaling and HQ background removal.
---

Pro adds the features that need a server: share links, cloud conversions for heavy video, sync across your Macs, an inbox for files from your phone, and GPU tools for transcription, upscaling and high-quality background removal. Nothing that runs on your Mac is ever behind a paywall, and every conversion, tool and action works without an account.

> [!PREVIEW]
> The Mac side of every Pro feature is built and tested end to end against a mock server, but the server itself isn't built yet. Until it is, Pro features can't be used, and signing in has nowhere to go.

## What Pro adds

| Feature | What it does | Where you find it |
|---|---|---|
| **Share links** | Uploads files and copies a link. Set an expiry, a password and a download limit | The **Share link** segment on the Actions wheel. See [Actions and Float](/docs/actions#share-link-pro) |
| **Cloud jobs** | Sends a heavy video conversion or compression to the server when your Mac is slow or on battery. The result lands beside the original, as a local conversion would | **Convert in the cloud (Pro, uploads the file)** in a video target's options |
| **Sync** | Keeps favourites, wheel order, presets, recipes and settings the same across your Macs | **Settings › Account › Sync across your Macs** |
| **Inbox** | Files you send from your phone or a browser land in a folder on your Mac, then are removed from the server | **Settings › Account › Receive files from your phone or browser** |
| **Transcribe** | Audio or video to an SRT or VTT transcript | The Tools wheel |
| **Upscale** | Makes an image larger | The Tools wheel |
| **Remove background HQ** | A higher-quality cutout than the local tool | The Tools wheel |

Pro segments on the wheel carry a small cloud glyph and a **Pro** chip, so you can always tell what will upload.

## What stays free

Everything that runs on your Mac: all 793 conversions, all 26 local tools, all six actions, the Float shelf, batches, presets, the command line and the MCP server, including commercial use. The local **Remove background** tool stays free; Pro adds a GPU version beside it.

## Pricing

| Plan | Price | Includes |
|---|---|---|
| Self-host | Free | Build the app from source and run your own server, with every feature for its users |
| Desktop | $19 once | The signed, notarized app and every update, on up to 3 Macs |
| Pro | $8 a month, or $6 a month billed yearly | Desktop, plus the server features on this page |

These prices are proposals until checkout opens. See [pricing](/pricing). If you stop paying for Pro, everything on your Mac keeps working as before.

## Before anything uploads

- **Signed out, anyfmt makes no cloud requests at all.** Choosing a Pro segment opens a one-screen explanation of what it does, what uploads and where. **Not Now** closes it, and nothing happens to the file.
- **The first upload to a server always tells you which server it's going to**, once per server, with **Continue** and **Cancel**.
- **No request at launch.** Your plan is cached and refreshed only when you sign in, choose **Refresh**, or start a cloud action. The only background traffic is sync and the inbox, and only when you turn them on.
- **Your sign-in token goes only to the server you chose.** Downloads from other hosts never get it.

## Sign in

1. Open **Settings › Account**, or choose **Pro Licence & Account…** from the menu bar icon.
2. Choose **Sign In…**. The server's sign-in page opens in your browser and emails you a link.
3. Open the link. The browser sends you back to anyfmt, which finishes signing in.

If you open the link on another device, the page shows a code. Choose **Opened the link on another device?** in anyfmt and type it in. Sign-in tokens are kept in your login Keychain and aren't synced to iCloud. Signing out keeps every local feature working.

## Licence keys

A Pro or Team licence key (`ANYFMT1-…`) can be pasted into **Settings › Account › Pro licence key**. It's checked on your Mac, offline, and shows your plan without a server. It never switches on or changes anything local, and cloud features still need you to sign in. See [Licence keys](/docs/licence-keys).

## Use your own server

You can point anyfmt at a server you run: **Settings › Account › Server URL**. A self-hosted server gives its users every feature. See [Self-host the server](/docs/self-host).

## Not built yet

Beyond the server itself, a few parts of the Mac client aren't built:

- A list of your share links, to revoke them or see their stats, in the app.
- A list of your signed-in devices.
- Options for the Pro tools.
