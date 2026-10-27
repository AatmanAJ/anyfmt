# Competitor research for anyfmt comparison pages

Access date for every source below: 2026-10-27.

Method: pages were read with TinyFish fetch. Pages that load prices or version history with JavaScript (CloudConvert pricing, Clop pricing, the Tangerine App Store version history) were read in a browser. A few counts were checked with the public GitHub API and the Clop Sparkle update feed. Prices are in USD unless a bullet says otherwise. "Unverified:" bullets mark anything I could not confirm from a primary source.

anyfmt reference points, taken from the internal brief and not re-checked here: free, AGPL-3.0, macOS 13 or later on Apple silicon, 793 tested routes, 26 local tools, 6 actions, CLI, MCP server, on-device processing, drag in Finder and tap Shift to open a format wheel.

---

## 1. Tangerine for Mac (Leap Studio)

- Name and maker: listed on the Mac App Store as "Tangerine: File Converter". Seller and developer: LEAP STUDIO. Copyright line: "© 2026 Leap Studio". https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Price and model (US App Store): shown as "Free · In-App Purchases", with one in-app purchase, "Tangerine Full Unlock $24.99". https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Trial: the App Store description says Tangerine "is free for your first 20 files" and that "a single one-time purchase unlocks unlimited use, with no subscription". https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- The website mentions a "conversion allowance" and says file actions do not count against it. https://tangerineformac.com
- Price conflict: the press kit still says "$29.99 USD, one-time purchase" and "Version 1.4". The App Store currently charges $24.99 and is on version 2.0.1. https://tangerineformac.com/press
- Public launch: 7 September 2026, per the press kit. https://tangerineformac.com/press
- Latest version: 2.0.1, dated Oct 17, with the note "Fixed bug which caused some conversion options to be hidden". https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Version 2.0 (Oct 14) added these, per the App Store version history: https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
  - an Actions wheel (AirDrop, Float, Copy, Move, Copy Path, Terminal), opened by tapping Control during a drag
  - support for EPUB, Word, Pages, PowerPoint and spreadsheets
  - a floating file feature
  - percentage compression for single files and batches
- App size: 97.6 MB (matches our notes). https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Requirements: macOS 13.0 or later on an Apple M1 chip or later. https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12 and https://tangerineformac.com
- Platforms: Mac only. The website links only to the Mac App Store. https://tangerineformac.com
- Local or upload: local.
  - The website says "Everything happens locally on your Mac". https://tangerineformac.com
  - The privacy policy says files are never uploaded and that Tangerine "has no server to upload them to". It also says the app has no analytics, advertising or tracking, and that purchases go through Apple and RevenueCat. https://tangerineformac.com/privacy
  - App Store privacy label: "Purchases", not linked to the user. https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Counts on the homepage: "275 Conversion options", "26 Advanced file tools" and "6 File actions" (all match our notes). The press kit calls them "275 conversion paths". https://tangerineformac.com and https://tangerineformac.com/press
- Formats listed on the homepage: https://tangerineformac.com
  - Images: JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP. PDF export. SVG input only.
  - Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA.
  - Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF. MP3 export.
  - PDF to DOCX, PAGES, PPTX, XLSX, JPG, PNG, EPUB, TXT, MD.
  - Documents: DOCX, PAGES, Markdown, TXT, EPUB. RTF, RTFD and text clippings as input. HTML export.
  - Slides: PPT/PPTX to PDF, JPG, PNG. PDF to PPTX.
  - Spreadsheets: XLSX, ODS, CSV, TSV. PDF export. XLS input only.
  - Subtitles: SRT, VTT. TXT export.
  - Archives: ZIP, TAR, GZIP. RAR input only.
- How you use it: drag a file, then tap a key. Shift opens the format wheel, Command opens file tools and Control opens file actions. The wheel stays open until you drop, the keys can be changed in Settings, and the converted copy is saved next to the original. https://tangerineformac.com and https://tangerineformac.com/press
- Conflict on the tools key: the App Store description says "Hold Option and Shift" for tools, not Command. https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
- Other features (App Store description): https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12
  - menu-bar app with batch processing
  - compress to a target file size
  - photo crop, adjust, annotate and redact
  - video trim, crop, speed, split, join and snapshots
  - audio normalize, trim, bleep and channel changes
  - read, edit or remove metadata
  - merge, split and reorganize PDFs, and build PDFs and collages from images
  - QR code reading
- Open source: none of the site, the press kit or the App Store listing mentions a source repository or licence.
- CLI or MCP server: none of the site, the press kit or the App Store listing mentions either.
- Unverified: whether $24.99 is a temporary sale or the new list price, and whether $29.99 is still charged anywhere.
- Unverified: how the 20-file trial is counted (per file, per job or per batch).
- Unverified: whether there is a version sold outside the App Store.

## 2. convt (convt.app, opencoredev/convt)

- Name and maker: convt. The GitHub organisation is opencoredev and the README ends "Built by @leodev". Polar is the merchant of record, and the terms are governed by Florida law. https://github.com/opencoredev/convt and https://convt.app/terms
- Price and model: https://convt.app and https://convt.app/terms
  - Desktop: $29 once, covering every future desktop version on macOS, Windows and Linux.
  - Pro: $12 a month, or $96 a year ($8 a month). Includes Desktop plus cloud conversions.
- Trial (from the terms): https://convt.app/terms
  - The app works fully for 7 days from the first conversion.
  - The 7-day Pro trial needs a card and becomes a paid subscription unless cancelled. One Pro trial per account.
- Refund: full refund within 14 days of paying for Desktop or Pro. https://convt.app/terms
- API pricing: 1 cent per successful job. Failed and cancelled jobs are free, there is a spend cap, and billing is monthly in arrears. https://convt.app/docs and https://convt.app/terms
- API limits: inputs up to 2 GB, 120 requests per minute per key, 10 minutes per attempt, 3 attempts per job. Jobs, uploads and outputs expire after 24 hours. https://convt.app/docs/reference/limits
- API status:
  - The docs say `api.convt.app` "does not resolve yet" and give a Railway fallback host. https://convt.app/docs/api
  - The README says the `@convt/sdk` package is "not on npm yet". https://github.com/opencoredev/convt
- Pro cloud allowance: up to 50 GB of input a month, files up to 2 GB each. Cloud files are deleted 24 hours after the job is created. https://convt.app/terms and https://convt.app/privacy
- Platforms (v0.5.0 release assets): https://github.com/opencoredev/convt/releases
  - macOS: Apple silicon (arm64) DMG, Developer ID signed and notarized.
  - Windows: x86_64 MSI, unsigned.
  - Linux: x86_64 AppImage, deb, rpm and tarball, unsigned.
  - There is also a Homebrew cask for Apple silicon. https://github.com/opencoredev/convt
- Local or upload: local by default.
  - The CLI never uploads a file. The app uploads only when you pick Cloud for a job, and asks for agreement before the first upload. https://convt.app/privacy
  - The app checks convt.app for updates at every launch and every 5 hours. The website uses PostHog analytics, which can be turned off. https://convt.app/privacy
- Format count: the site says "40 formats" (14 image, 5 video, 7 audio, 14 document), while the README says "49 formats". https://convt.app/formats and https://github.com/opencoredev/convt
- Route count: convt does not publish one. Counting the "Converts to" targets on the formats page gives 579 source-to-target pairs (my count). https://convt.app/formats
- Engines: FFmpeg, LibreOffice, PDFium, image plus resvg, and libheif (or `sips` on macOS for HEIC). Routes can chain up to three steps. https://github.com/opencoredev/convt
- Office formats are an optional one-time download (a LibreOffice "document pack"). https://convt.app/formats
- How you use it:
  - Right-click a file and choose "Convert with convt" in the Finder. On Linux the menu works in Nautilus, Dolphin, Nemo and Thunar. https://convt.app/changelog and https://github.com/opencoredev/convt
  - The README says the Windows Explorer menu "is built ... but not yet in the release installer". https://github.com/opencoredev/convt
  - There is also a desktop app with batch folders, presets and automations. Since 0.3.0 the automations watch the real screenshot and screen-recording folders. https://github.com/opencoredev/convt/releases
  - A `convt` CLI. https://github.com/opencoredev/convt
  - A Raycast extension built by a third party (Dhruv Suthar). https://github.com/opencoredev/convt
  - A Chrome and Edge extension that converts images in the browser. https://convt.app/privacy
- AI agents: `convt --skill` prints a SKILL.md for AI coding agents (added in 0.4.0). An MCP server is not mentioned. https://github.com/opencoredev/convt/releases
- Licence: AGPL-3.0, per the README and the GitHub API. The signed desktop builds, convt Cloud and the API are paid. The README says "Ordinary source builds are unrestricted". https://github.com/opencoredev/convt and https://api.github.com/repos/opencoredev/convt
- GitHub stats on 2026-10-27: 354 stars, 27 forks. The repository was created on 2026-10-06. https://api.github.com/repos/opencoredev/convt
- Latest release: v0.5.0, published 2026-10-15. It added a guide for turning on the Finder menu on macOS 15 and later, and a choice of which formats the right-click menu shows. https://github.com/opencoredev/convt/releases
- Stale changelog: the site's changelog page still lists only 0.1.0 as "Unreleased". https://convt.app/changelog
- Sign-in at first run: since 0.4.0, first run starts with a convt.app account sign-in, or a licence key instead. https://github.com/opencoredev/convt/releases
- Unverified: whether the Windows right-click menu ships in any current installer.
- Unverified: whether an Intel Mac build exists. Only an arm64 DMG is listed.
- Unverified: whether the Desktop trial works without a convt.app account.

## 3. Permute (Charlie Monroe Software)

- Name and maker: Permute 4, by Charlie Monroe Software, s.r.o. The company is EU-based and prices in EUR. https://software.charliemonroe.net/permute/ and https://apps.apple.com/us/app/permute-4/id6774079417?mt=12
- Price and model: https://software.charliemonroe.net/permute/
  - $14.99 for a permanent licence bought direct. This excludes VAT, and the base price is in EUR.
  - $14.99 on the Mac App Store.
  - Downie 4 + Permute 4 bundle: $26.99.
  - Licences cover one major version, and Permute 4 needs a new licence. Up to 3 activations.
- Setapp: available.
  - The Permute page on Setapp says "From $14.99/month. Free for 7 days." and "From $4.99/year. Permute app only." https://setapp.com/apps/permute
  - Setapp membership plans start at $14.99 a month plus tax, with a 7-day free trial. https://setapp.com/pricing
- Older Macs: Permute 3, for macOS 11 to 15 and Intel Macs, is sold for $14.99 with a free upgrade to Permute 4 later. https://software.charliemonroe.net/permute/
- Requirements:
  - Permute 4 needs macOS 26 or later and Apple silicon. https://software.charliemonroe.net/permute/
  - App Store listing: macOS 26.0 or later on M1 or later, 49.2 MB. https://apps.apple.com/us/app/permute-4/id6774079417?mt=12
  - Setapp listing: 195.6 MB. https://setapp.com/apps/permute
- Latest version: 4.1, released 15 October 2026 (16 Oct on the App Store). Permute 4.0 shipped on May 26, 2026. https://software.charliemonroe.net/trial/permute/v4/rnotes.html
- Platforms: Mac only.
- What it converts: video, audio, images, PDF and text.
  - The product page claims "100+ Formats supported", while its meta description still says "50 different formats". https://software.charliemonroe.net/permute/
  - The App Store description names AVI, WMV, MKV, WebM, MOV, MP4, H.264, HEVC, AV1, ProRes; MP3, AAC, FLAC, WAV, AIFF, Opus, Apple Lossless; HEIC, JPEG, PNG, WebP, AVIF; and RAW (ARW, CR2, CR3, NEF). It also lists PDF pages to PNG, JPEG, TIFF and WebP. https://apps.apple.com/us/app/permute-4/id6774079417?mt=12
- Local or upload: local.
  - Transcription uses on-device AI, "processed entirely on your Mac". https://software.charliemonroe.net/permute/
  - The privacy policy says some apps send anonymous analytics, and licence activation stores a computer identifier. https://software.charliemonroe.net/policy/privacy/
  - App Store privacy label: Usage Data and Diagnostics, not linked to the user. https://apps.apple.com/us/app/permute-4/id6774079417?mt=12
- How you use it: drag files onto the main window or the Dock icon and pick a preset in a queue. There are also Drop Zones (4.0), a Services menu item (4.0.2) and automation. https://software.charliemonroe.net/help/permute/?article=app_store and https://software.charliemonroe.net/trial/permute/v4/rnotes.html
- Notable features (product page and App Store): https://software.charliemonroe.net/permute/ and https://apps.apple.com/us/app/permute-4/id6774079417?mt=12
  - trim, crop, resize, rotate
  - stitch files, or split them by time, CUE or EDL
  - extract tracks without re-encoding
  - add subtitles and audio tracks
  - target file size
  - image filters
  - transcription to text or SRT
  - text to speech and OCR
  - ringtone maker
  - HLS output and hardware ProRes
  - IP-camera file repair
  - a raw FFmpeg "Advanced Custom" preset
  - a metadata editor
- Licence: proprietary. No source is offered.
- Limits:
  - The App Store version is sandboxed. Saving next to the original and detecting subtitles automatically both need extra file access. https://software.charliemonroe.net/help/permute/?article=app_store
  - Licence codes issued after March 2025 do not work on macOS 10.15 or lower. https://software.charliemonroe.net/permute/
- Unverified: the trial terms. The direct download is hosted under a `/trial/` path, but no time or feature limit is stated on the pages I read.
- Unverified: the Setapp "From $4.99/year. Permute app only." price. It is printed on the Setapp page, but I could not confirm it at checkout.

## 4. CloudConvert

- Name and maker: CloudConvert, run by Lunaweb GmbH in Grünwald, Germany. Founded in 2012. https://cloudconvert.com/privacy and https://cloudconvert.com/security
- Free tier: https://cloudconvert.com/pricing
  - 10 conversion credits a day, reset daily
  - 1 GB maximum file size
  - 5 minutes maximum processing time
  - 5 concurrent tasks
  - low processing priority
  - The page says: "Start free with 10 conversions per day. No credit card required."
- Paid tiers: https://cloudconvert.com/pricing
  - Packages are one-time purchases whose credits never expire. Subscriptions give monthly credits that do not roll over.
  - Both remove the file size and processing time limits, and give high priority and unlimited concurrent tasks.
- Prices at 1,000 credits: package US$17.00, subscription US$9.00 a month, before VAT. https://cloudconvert.com/pricing
  - From my location the page showed US$20.40 and US$10.80 a month "incl. 20% VAT".
  - Its search-index snippet reads "Packages from $17.00 · Subscriptions from $9.00/month".
  - The volume slider runs from 500 to 1,000,000 credits.
- How credits are spent: usually one credit per minute of conversion time. Base costs: General 1, Office to PDF 2, iWork to PDF 2, PDF to Office 4. Only successful conversions are charged. https://cloudconvert.com/pricing
- Platforms: website and REST API. https://cloudconvert.com/privacy
- Local or upload: upload. Files are sent to CloudConvert's servers and stored there temporarily. https://cloudconvert.com/privacy
- Data handling (privacy policy): https://cloudconvert.com/privacy
  - Files are deleted immediately with the delete button, or automatically after 24 hours at the latest.
  - Log data (IP address, user agent, referrer) is kept for 180 days.
  - Account data is deleted within 72 hours of deleting the account.
  - The policy says "We do not read, look into, or mine any data from your files".
- Security: https://cloudconvert.com/security
  - ISO 27001 certified ISMS, certified by TÜV Süd
  - each conversion runs in its own isolated container
  - processing stays in the geographic region the customer selects
  - GDPR, with a DPA on request
- AI features, added to the privacy policy on October 19, 2026: https://cloudconvert.com/privacy
  - An AI chat and API "AI tasks" use Claude via Amazon Bedrock in EU data centres by default, with Qwen via OVHcloud as an option.
  - The model receives the request, the file names and task metadata, but not the file content.
- What it converts: "212 formats across 11 categories", including office files, camera RAW, CAD, archives, ebooks and production media. https://cloudconvert.com/formats
- How you use it: drop a file on the web page and pick a target format. The API builds jobs from import, convert and export tasks. https://cloudconvert.com/formats
- Open source: the pages I read state no licence for the service.
- Latest version: none. It is a hosted service. The privacy policy was last changed on October 19, 2026. https://cloudconvert.com/privacy
- Unverified: whether people who are not signed in get the same 10 a day. The pricing table pairs the free tier with "Sign Up".
- Unverified: prices at other credit volumes.

## 5. HandBrake

- Name and maker: HandBrake, made by the HandBrake Team, an open-source project built by volunteers. https://handbrake.fr/
- Price: free. https://handbrake.fr/
- Licence: GNU GPL version 2, per the README. GitHub's licence detection reports "Other" (NOASSERTION) for the repository. https://github.com/HandBrake/HandBrake and https://api.github.com/repos/HandBrake/HandBrake
- Platforms: https://handbrake.fr/downloads.php
  - macOS: universal disk image for macOS 10.13 and later.
  - Windows: Windows 10 and later, x64 and ARM64.
  - Linux: Flatpak.
  - The docs mark macOS 14, 15 and 26 as supported and macOS 13 and older as "Deprecated". https://handbrake.fr/docs/en/latest/technical/system-requirements.html
- Local or upload: local desktop app.
- What it converts: video only.
  - Its stated purpose is converting video "to MP4, MKV, or WebM format". https://handbrake.fr/docs/en/latest/introduction/about.html
  - Version 1.11.0 added encoding to the MOV container, plus ProRes and DNxHR encoders. https://github.com/HandBrake/HandBrake/releases
  - Inputs are whatever FFmpeg's libavformat can open, plus DVD and Blu-ray. It does not handle DRM-protected content. https://handbrake.fr/docs/en/latest/technical/source-formats.html
  - No image, document or audio-only output is documented. Audio is handled only as tracks inside a video (passthrough, downmix, volume). https://handbrake.fr/docs/en/latest/introduction/about.html
- What it does not do, per the docs: combine clips, pass video through without re-encoding, or create discs. https://handbrake.fr/docs/en/latest/introduction/about.html
- How you use it: a GUI app with presets and a queue, plus a separate command-line download. https://handbrake.fr/downloads.php
- Latest version: 1.11.2, released 7 June 2026. It bundles FFmpeg 8.0.2 and SVT-AV1 4.1.0. https://github.com/HandBrake/HandBrake/releases and https://handbrake.fr/downloads.php
- GitHub stars on 2026-10-27: 24.8k. https://github.com/HandBrake/HandBrake
- Hardware the docs recommend: Apple silicon M1 or newer, and 16 GB of RAM for SD/HD transcoding (32 GB for 4K). https://handbrake.fr/docs/en/latest/technical/system-requirements.html

## 6. macOS built-in options

### Finder "Convert Image" Quick Action

- How to open it: Control-click an image, choose Quick Actions, then More, then Convert Image, and "choose a format and a size". https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/mac
- macOS version: Apple's guide documents Convert Image in the macOS Monterey 12 version of this page but not in the Big Sur 11 version, which points to Monterey as the first release with it. https://support.apple.com/guide/mac-help/mchl97ff9142/12.0/mac/12.0 and https://support.apple.com/guide/mac-help/mchl97ff9142/11.0/mac/11.0
  - Other World Computing called it "a new Quick Action in macOS Monterey" in November 2021. https://eshop.macsales.com/blog/78735-how-to-convert-an-image-with-quick-action-in-macos-monterey/
- Output formats: JPEG, PNG and HEIF. https://osxdaily.com/2023/02/28/convert-images-on-mac-quickly-from-finder/ and https://eshop.macsales.com/blog/78735-how-to-convert-an-image-with-quick-action-in-macos-monterey/
- Sizes and metadata: Small, Medium, Large or Actual Size, and a "Preserve Metadata" checkbox. https://eshop.macsales.com/blog/78735-how-to-convert-an-image-with-quick-action-in-macos-monterey/
- Inputs: also accepts other image types such as PSD and TIFF. https://eshop.macsales.com/blog/78735-how-to-convert-an-image-with-quick-action-in-macos-monterey/
- Output location: saved in the same folder with the same base name and the new extension. https://osxdaily.com/2023/02/28/convert-images-on-mac-quickly-from-finder/
- Other Quick Actions in the same menu: Rotate, Markup, Trim (movies and audio), Create PDF and Remove Background. https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/mac
- Price, platform, processing and licence: free, built into macOS, runs on the Mac, closed source.
- Unverified: Apple's own docs do not list the format menu. They only give .heic to .jpeg or .png as examples. The JPEG, PNG and HEIF list comes from the third-party sources above.

### Preview > File > Export

- Formats: HEIC, JPEG, JPEG-2000, OpenEXR, PDF, PNG and TIFF. Holding Option while clicking the Format menu shows "specialized or older formats". https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac
- Options: JPEG and JPEG-2000 have a quality setting. PDF export can apply a Quartz filter and add password encryption. https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac
- Batch: open several files in one window, select them in the sidebar, then export. https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac
- How you use it: open the file in the Preview app, choose File > Export, pick a format and save. https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac
- Unverified: the full list of extra formats behind the Option-click menu on current macOS.

## 7. FreeConvert (chosen over Zamzar for its clearer published limits)

- Name and maker: FreeConvert.com, owned by TRMedia Inc., a Canadian company. Launched in 2018. https://www.freeconvert.com/about
- Free tier:
  - "Max file size 1GB". https://www.freeconvert.com/
  - 20 conversion minutes a day for web and API, with a 5-minute limit per file. https://www.freeconvert.com/pricing
  - No account is needed for the free web minutes. https://www.freeconvert.com/pricing
  - The homepage upsell, "convert large files without a queue or Ads", implies the free tier has a queue and ads. https://www.freeconvert.com/
- Paid plans (monthly, cancel any time): https://www.freeconvert.com/pricing
  - Basic: $12.99 a month, 1.5 GB maximum file size.
  - Standard: $24.99 a month, 2 GB.
  - Pro: $29.99 a month, 5 GB, with GPU or CPU video encoding.
  - Scale: on demand, up to 20 GB.
  - Yearly billing is offered as "Get 2 months free".
  - Every paid plan includes 100 conversions at a time, merging 100 files, web and API use, and no ads.
  - One-time credits expire 30 days after purchase.
- Local or upload: upload. The homepage says files are encrypted in transit with 256-bit SSL and deleted automatically after 8 hours. https://www.freeconvert.com/
- What it converts: images, video, audio, documents, ebooks and archives, plus compression, trimming, cropping and PDF tools. The homepage body says "more than 1500 file conversions", while its meta description says "2000+". https://www.freeconvert.com/
- Platforms: web, in any browser, plus an API. https://www.freeconvert.com/
- How you use it: upload from your device, Dropbox, Google Drive, OneDrive or a URL, then choose a target format. https://www.freeconvert.com/
- Open source: the pages I read state no licence.
- Unverified: exact yearly prices.
- Unverified: whether the 1 GB free limit applies without an account. The homepage shows both "Upgrade for more" and "Sign Up for more".
- Zamzar, for comparison:
  - The homepage warns about files that exceed "our 50MB free limit" and claims 1,100+ (elsewhere 1,200+) formats. https://www.zamzar.com/
  - Unverified: Zamzar's paid prices. https://www.zamzar.com/pricing/ returned a 404.

## 8. FFmpeg

- Name and maker: FFmpeg, a community project. "FFmpeg is a trademark of Fabrice Bellard". https://ffmpeg.org/legal.html
- Licence: LGPL 2.1 or later. Some optional parts are under GPL 2 or later, and if they are used, the GPL applies to all of FFmpeg. It is "not available under any other licensing terms". https://ffmpeg.org/legal.html
- Price: free. The project "only provides source code". Compiled binaries come from third parties. https://ffmpeg.org/download.html
- What it is: "A complete, cross-platform solution to record, convert and stream audio and video". https://ffmpeg.org/
  - End-user tools: `ffmpeg`, `ffplay` and `ffprobe`. https://ffmpeg.org/about.html
  - Developer libraries: libavcodec, libavformat, libavfilter, libswscale, libswresample and others. https://ffmpeg.org/about.html
- How you use it: on the command line. There is no official GUI converter.
- Local or upload: local.
- Latest release: 9.0.2 "Lei", released 2026-09-18. The 8.1 branch is at 8.1.3, released 2026-09-21. https://ffmpeg.org/download.html
- Used inside other products in this file: HandBrake (FFmpeg 8.0.2), convt and Clop (FFmpeg 9.0 on Apple silicon). Permute's "Advanced Custom" preset gives access to FFmpeg. https://github.com/HandBrake/HandBrake/releases, https://github.com/opencoredev/convt, https://files.lowtechguys.com/clop/changelog.html and https://software.charliemonroe.net/permute/

## 9. Smart Converter (ShedWorx / Systemic Pty Ltd)

- Name and maker: Smart Converter. The App Store developer name is ShedWorx and the seller is Systemic Pty Ltd. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
- Price and model: free on the Mac App Store. No in-app purchases are listed. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
- Paid sibling: Smart Converter Pro, sold separately, "shares the same conversion engine" and adds batch conversion and advanced preferences. https://support.shedworx.com/support/solutions/articles/6000235124-supported-file-types
  - Its product page also lists folder monitoring, metadata lookup and subtitles. https://shedworx.com/smart-converter-pro/
- Latest version: 3.1.6, dated 02/16/2025 ("Added iPhone 16 output"). https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
- Requirements:
  - App Store: macOS 10.15 or later, 47 MB. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
  - The developer site says macOS 10.13 or later. https://shedworx.com/smart-converter/
- Platforms: Mac only.
- What it converts: video and audio only.
  - The App Store says "100s of file types including MKV and AVI". https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
  - Explicitly supported video: AVI, AVCHD (MTS, M2TS, with limited support), MKV, FLV, WMV, and MOV with H.264 only (ProRes and AIC are not supported). https://support.shedworx.com/support/solutions/articles/6000235124-supported-file-types
  - Explicitly supported audio: WMA, M4A, FLAC. https://support.shedworx.com/support/solutions/articles/6000235124-supported-file-types
- Output: presets for devices such as Apple TV, iPad, iPhone and Smart TV. https://shedworx.com/smart-converter/
- How you use it: drag a file into the window, pick an output preset and click Convert. Converted files can be added to the TV and Music apps automatically. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12 and https://shedworx.com/smart-converter/
- How conversion works: it analyses the file and re-encodes only the streams that need it. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
- Local or upload: no cloud processing is described anywhere. App Store privacy label: "Other Data", not linked to the user. https://apps.apple.com/us/app/smart-converter/id447513724?mt=12
- Open source: no source or licence is published.
- Unverified: the price of Smart Converter Pro. The page shows "BUY NOW" with no price in the fetched text.
- Unverified: whether Smart Converter runs natively on Apple silicon.

## 10. Clop (lowtechguys)

- Name and maker: Clop, by "The low-tech guys". https://lowtechguys.com/clop/
- What it does: a file optimiser, with format conversion as a secondary feature. https://lowtechguys.com/clop/
  - It automatically optimises images copied to the clipboard and screen recordings as they finish, and can watch folders for images, videos, PDFs and audio.
  - It shows a drop zone at the cursor when you tap Option, plus "preset zones".
  - Pipelines chain steps such as crop, convert and optimise.
  - Other features: fit under a target size, downscale and crop, and Ctrl-O in Finder.
- Conversions: a "format bar" converts to JPEG XL, WebP, AVIF, AV1, WebM or HEVC. Audio is re-encoded (WAV to MP3, AIFF or FLAC to AAC), and PDFs are optimised. https://lowtechguys.com/clop/
- Price and model: https://lowtechguys.com/clop/
  - Free version, with "Clop Pro" sold as a lifetime licence. The site lists the price as €15.
  - 14-day Pro trial with no credit card. After it ends the free features keep working.
  - Refunds within 14 days.
- Price history: the changelog says Clop 2.0.0 introduced Pro as "an $8 paid tier as a one-time purchase". https://files.lowtechguys.com/clop/changelog.html
- Free-version limits: watched-folder optimisation, conversion to modern formats, drop zones, on-demand optimisation and the `clop` CLI are each limited to "5 per session". At most 5 files per drop. Batch mode and the MCP server are Pro only. https://lowtechguys.com/clop/
- Platforms: macOS only.
  - The site says "compatible with macOS 14.0+". https://lowtechguys.com/clop/
  - The Sparkle update feed lists `minimumSystemVersion` 13.0. https://files.lowtechguys.com/clop/appcast.xml
- Local or upload: local. The site says Clop "doesn't use any cloud services and doesn't send any file data to the internet". https://lowtechguys.com/clop/
  - Crash reports go to Sentry. Licensing uses Paddle, so activation needs a network connection. https://lowtechguys.com/clop/privacy and https://lowtechguys.com/clop/
  - Its "Send securely" feature shares files peer to peer over WebRTC. https://files.lowtechguys.com/clop/changelog.html
- Developer and agent tooling:
  - `clop` CLI, installable with `brew install clop`.
  - MCP server for agents such as Claude Code and Codex (Pro only).
  - Clop SDK, MIT licensed.
  - Sources: https://lowtechguys.com/clop/ and https://files.lowtechguys.com/clop/changelog.html
- Engines: pngquant, jpegoptim, gifsicle, ffmpeg, libvips, gifski and ghostscript. https://lowtechguys.com/clop/
- Licence:
  - The public repository FuzzyIdeas/Clop is GPL-3.0, with 1,856 stars on 2026-10-27. https://api.github.com/repos/FuzzyIdeas/Clop
  - The last code commit there is version 3.5.0 (2026-10-06). On 2026-10-16 a README note was added: "Commits to this repo have been paused ... Work will continue privately." https://github.com/FuzzyIdeas/Clop and https://api.github.com/repos/FuzzyIdeas/Clop/commits
  - So the source of the current 3.6.x releases is not public.
- Latest version: 3.6.3, published 25 October 2026. The DMG is about 105.6 MB. https://files.lowtechguys.com/clop/appcast.xml
- Scope: none of the pages I read mention office documents, ebooks, subtitles or archives. https://lowtechguys.com/clop/
- Unverified: the USD price of Clop Pro. The site shows €15, and the Paddle checkout may convert it.
