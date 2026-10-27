/**
 * Comparison pages. Every claim about another product comes from web/research/competitors.md,
 * checked on the date in `checked`, with its source linked on the page. Where a fact couldn't be
 * confirmed it isn't stated. Each page says when the other product is the better choice.
 */
export type Centrepiece = 'routes' | 'clicks' | 'timeline' | 'upload' | 'session' | 'passthrough' | 'terminal' | 'menu'

export interface Competitor {
  slug: string
  name: string
  maker: string
  site: string
  kind: string // one phrase for the hub: "Mac App Store converter"
  title: string // < 60 chars
  h1: string
  description: string // meta, 140–160
  answer: string // the direct answer, quotable
  centrepiece: Centrepiece
  facts: { price: string; platforms: string; processing: string; source: string; scope: string; cli: string; mcp: string; macos: string }
  rows: { label: string; anyfmt: string; them: string }[]
  pickThem: string[]
  pickUs: string[]
  faq: [string, string][]
  sources: { label: string; url: string }[]
}

export const CHECKED = '27 October 2026'

export const ANYFMT_FACTS = {
  price: 'Free to build (AGPL-3.0); Desktop $19 once; Pro from $6 a month',
  platforms: 'macOS 13+, Apple silicon',
  processing: 'On your Mac',
  source: 'Open source, AGPL-3.0',
  scope: '59 formats, 793 tested routes, 26 tools',
  cli: 'Yes, --json everywhere',
  mcp: 'Yes, free, local',
  macos: '13 Ventura',
}

export const COMPETITORS: Competitor[] = [
  {
    slug: 'tangerine', name: 'Tangerine', maker: 'Leap Studio', site: 'https://tangerineformac.com', kind: 'Mac App Store converter',
    title: 'anyfmt vs Tangerine: the open-source alternative',
    h1: 'An open-source Tangerine alternative, with 793 routes to its 275.',
    description: 'anyfmt vs Tangerine for Mac: both open a format wheel when you tap Shift mid-drag. anyfmt is open source, has 793 tested routes to 275, a CLI and an MCP server.',
    answer: 'Tangerine and anyfmt work the same way: drag a file, tap Shift for formats, Command for tools, Control for actions. The differences are underneath: anyfmt is open source, ships 793 tested conversion routes to Tangerine\'s 275, adds a command-line tool and an MCP server for agents, and is 63 MB to Tangerine\'s 97.6 MB. Tangerine is on the Mac App Store and opens Pages and legacy PowerPoint files without extra setup.',
    centrepiece: 'routes',
    facts: { price: 'Free for 20 files, then $24.99 once', platforms: 'macOS 13+, Apple silicon', processing: 'On your Mac', source: 'Closed source', scope: '275 conversion options, 26 tools, 6 actions', cli: 'Not mentioned', mcp: 'Not mentioned', macos: '13 Ventura' },
    rows: [
      { label: 'Gesture', anyfmt: 'Drag, tap ⇧ / ⌘ / ⌃', them: 'Drag, tap ⇧ / ⌘ / ⌃' },
      { label: 'Conversion routes', anyfmt: '793, each run on a real file', them: '275 conversion options' },
      { label: 'Tools and actions', anyfmt: '26 tools, 6 actions', them: '26 tools, 6 actions' },
      { label: 'App size', anyfmt: '63 MB', them: '97.6 MB' },
      { label: 'Price', anyfmt: 'Free to build; $19 for the signed app', them: 'Free for 20 files, then $24.99' },
      { label: 'Source code', anyfmt: 'Open, AGPL-3.0', them: 'Closed' },
      { label: 'Command line and MCP', anyfmt: 'Both, free', them: 'Neither mentioned' },
      { label: 'Pages and legacy PPT', anyfmt: 'Opt-in (needs Pages, or the Office pack)', them: 'Listed as supported' },
      { label: 'Where to get it', anyfmt: 'Direct download, Homebrew, source', them: 'Mac App Store' },
    ],
    pickThem: ['You want it from the Mac App Store, with Apple handling the purchase.', 'You work with Pages files or old .ppt decks every day and don\'t want to switch anything on.'],
    pickUs: ['You want to read the code that touches your files, or build it yourself.', 'You convert across more pairs: 793 routes, including PDF to HTML, ODT and RTF, spreadsheets to JSON, archives to 7z.', 'You script conversions, or let an AI agent run them through MCP.'],
    faq: [
      ['Is anyfmt a Tangerine clone?', 'They share the drag-and-tap gesture, the three-key layout and the counts of tools and actions. anyfmt\'s code is written from scratch and published under AGPL-3.0, and its route table is about three times larger.'],
      ['How much does Tangerine cost?', 'On the US Mac App Store it is free for the first 20 files, then $24.99 once for Tangerine Full Unlock (checked 27 October 2026). Its press kit still lists $29.99.'],
      ['Do both work offline?', 'Yes. Both convert on your Mac. Tangerine\'s privacy policy says it has no server to upload files to; anyfmt only uploads when you use a Pro feature such as a share link.'],
      ['Which Macs do they need?', 'Both need macOS 13 Ventura or later on Apple silicon.'],
    ],
    sources: [
      { label: 'Tangerine on the Mac App Store', url: 'https://apps.apple.com/us/app/tangerine-file-converter/id6813034065?mt=12' },
      { label: 'tangerineformac.com', url: 'https://tangerineformac.com' },
      { label: 'Tangerine press kit', url: 'https://tangerineformac.com/press' },
      { label: 'Tangerine privacy policy', url: 'https://tangerineformac.com/privacy' },
    ],
  },
  {
    slug: 'convt', name: 'convt', maker: 'opencoredev', site: 'https://convt.app', kind: 'Open-source right-click converter',
    title: 'anyfmt vs convt: wheel vs right-click menu',
    h1: 'anyfmt and convt: a wheel mid-drag, or a right-click menu.',
    description: 'anyfmt vs convt: two AGPL file converters. convt adds a right-click menu on Mac, Windows and Linux; anyfmt is a Mac wheel with 793 routes, no sign-in and an MCP server.',
    answer: 'convt and anyfmt are both AGPL-3.0 converters that sell a signed desktop build and a cloud tier. convt runs on macOS, Windows and Linux from a right-click menu, and uses LibreOffice for documents as an optional download. anyfmt is Mac only and works mid-drag from a wheel, with 793 tested routes, its own document writers built in, no sign-in at first run, and a local MCP server.',
    centrepiece: 'clicks',
    facts: { price: 'Desktop $29 once; Pro $12/mo or $96/yr', platforms: 'macOS (Apple silicon), Windows, Linux', processing: 'Local; cloud when you choose it', source: 'Open source, AGPL-3.0', scope: '40 formats on its site (49 in the README)', cli: 'Yes', mcp: 'No; a SKILL.md for agents', macos: 'Not stated' },
    rows: [
      { label: 'How you convert', anyfmt: 'Mid-drag: tap ⇧, drop on a format', them: 'Right-click › Convert with convt › format' },
      { label: 'Platforms', anyfmt: 'macOS 13+', them: 'macOS, Windows, Linux' },
      { label: 'Formats', anyfmt: '59 formats, 793 tested routes', them: '40 formats (site), no route count published' },
      { label: 'Documents', anyfmt: 'Built in (own DOCX, ODT, EPUB, XLSX writers)', them: 'Optional LibreOffice download' },
      { label: 'First run', anyfmt: 'No account', them: 'Sign in or enter a licence key (since 0.4.0)' },
      { label: 'Update checks', anyfmt: 'Off until you turn them on', them: 'Every launch and every 5 hours' },
      { label: 'Agents', anyfmt: 'Local MCP server', them: 'SKILL.md for coding agents' },
      { label: 'Price', anyfmt: '$19 once; Pro $8/mo', them: '$29 once; Pro $12/mo' },
      { label: 'API', anyfmt: '1¢ a conversion (preview)', them: '1¢ a job (domain not live yet)' },
    ],
    pickThem: ['You need the same converter on Windows or Linux.', 'You prefer a right-click menu to a drag gesture.', 'You want folder automations that watch your screenshots folder.'],
    pickUs: ['You\'re on a Mac and want conversions without leaving the drag you\'re already doing.', 'You convert documents, spreadsheets, ebooks, subtitles or archives without installing LibreOffice.', 'You want an MCP server so agents can convert, estimate and list options locally.'],
    faq: [
      ['Are both really open source?', 'Yes. Both are AGPL-3.0, and both sell signed builds and cloud features on top. convt\'s README says ordinary source builds are unrestricted; anyfmt is the same.'],
      ['Which has more formats?', 'convt\'s site lists 40 formats. anyfmt handles 59 formats across 793 tested routes. Counting convt\'s formats page gives about 579 source-to-target pairs, a number convt doesn\'t publish itself.'],
      ['Does either upload my files?', 'Neither does by default. Both upload only for cloud features you choose.'],
      ['Which is cheaper?', 'anyfmt\'s Desktop licence is $19 once against convt\'s $29; Pro is $8 a month against $12. Building either from source is free.'],
    ],
    sources: [
      { label: 'convt.app', url: 'https://convt.app' },
      { label: 'convt formats', url: 'https://convt.app/formats' },
      { label: 'convt terms', url: 'https://convt.app/terms' },
      { label: 'convt privacy', url: 'https://convt.app/privacy' },
      { label: 'convt on GitHub', url: 'https://github.com/opencoredev/convt' },
      { label: 'convt releases', url: 'https://github.com/opencoredev/convt/releases' },
    ],
  },
  {
    slug: 'permute', name: 'Permute', maker: 'Charlie Monroe Software', site: 'https://software.charliemonroe.net/permute/', kind: 'Media converter app',
    title: 'anyfmt vs Permute 4: which Mac converter?',
    h1: 'anyfmt or Permute: a wheel mid-drag, or a media window.',
    description: 'anyfmt vs Permute 4 on Mac: Permute is a window-based media converter for macOS 26. anyfmt converts mid-drag on macOS 13+, adding documents, spreadsheets and archives.',
    answer: 'Permute 4 is a window-based media converter for macOS 26 or later: you drop files on its window and pick a preset, with strong video features such as ProRes, HLS and on-device transcription. anyfmt runs on macOS 13 and later and converts mid-drag from a wheel, covering documents, spreadsheets, ebooks, subtitles and archives as well as media. It is open source; Permute is $14.99.',
    centrepiece: 'timeline',
    facts: { price: '$14.99 (direct or App Store); on Setapp', platforms: 'macOS 26+, Apple silicon', processing: 'On your Mac', source: 'Closed source', scope: 'Video, audio, images, PDF, text', cli: 'Not mentioned', mcp: 'Not mentioned', macos: '26' },
    rows: [
      { label: 'How you convert', anyfmt: 'Mid-drag wheel, anywhere', them: 'Drop on the window, Dock icon or a drop zone' },
      { label: 'macOS', anyfmt: '13 Ventura or later', them: '26 or later (Permute 3 for older Macs)' },
      { label: 'Documents and spreadsheets', anyfmt: 'DOCX, ODT, RTF, EPUB, XLSX, CSV, JSON…', them: 'Not listed' },
      { label: 'Archives and subtitles', anyfmt: 'ZIP, TAR, 7z, RAR in; SRT, VTT', them: 'Not listed' },
      { label: 'Pro video', anyfmt: 'H.264, HEVC, AV1, VP9', them: 'Adds ProRes, HLS, IP-camera repair' },
      { label: 'Camera RAW', anyfmt: 'Not yet', them: 'ARW, CR2, CR3, NEF' },
      { label: 'Transcription', anyfmt: 'Pro (cloud)', them: 'On-device' },
      { label: 'Price', anyfmt: 'Free to build; $19 signed', them: '$14.99 per major version' },
      { label: 'Source', anyfmt: 'Open, AGPL-3.0', them: 'Closed' },
    ],
    pickThem: ['You edit video professionally and need ProRes, HLS or camera RAW.', 'You want on-device transcription and text to speech today.', 'You already use Setapp.'],
    pickUs: ['Your Mac runs macOS 13, 14 or 15.', 'You convert more than media: documents, spreadsheets, ebooks, archives.', 'You want to convert without opening a window, mid-drag, in one motion.'],
    faq: [
      ['Does Permute 4 run on my Mac?', 'Permute 4 needs macOS 26 or later on Apple silicon. For macOS 11 to 15 the developer sells Permute 3, with a free upgrade to 4 later.'],
      ['Is Permute a subscription?', 'No. It\'s $14.99 for a licence that covers one major version, or part of a Setapp subscription.'],
      ['Which is better for video?', 'For professional formats like ProRes and HLS, Permute. For everyday conversions such as MOV to MP4, GIFs and compressing to a size, either works; anyfmt does it mid-drag.'],
    ],
    sources: [
      { label: 'Permute product page', url: 'https://software.charliemonroe.net/permute/' },
      { label: 'Permute 4 on the Mac App Store', url: 'https://apps.apple.com/us/app/permute-4/id6774079417?mt=12' },
      { label: 'Permute release notes', url: 'https://software.charliemonroe.net/trial/permute/v4/rnotes.html' },
      { label: 'Permute on Setapp', url: 'https://setapp.com/apps/permute' },
    ],
  },
  {
    slug: 'cloudconvert', name: 'CloudConvert', maker: 'Lunaweb GmbH', site: 'https://cloudconvert.com', kind: 'Online converter',
    title: 'anyfmt vs CloudConvert: convert without uploading',
    h1: 'Convert files like CloudConvert does, without uploading them.',
    description: 'anyfmt vs CloudConvert and other online converters: CloudConvert uploads your file and gives 10 free conversions a day. anyfmt converts on your Mac with no upload or limit.',
    answer: 'CloudConvert converts files on its servers: you upload, it converts, you download, with 10 free conversions a day and a 1 GB limit on the free tier. anyfmt converts on your Mac, so nothing is uploaded, there is no daily limit, and a large video starts converting immediately. CloudConvert supports more exotic formats, such as CAD and camera RAW, and works from any computer with a browser.',
    centrepiece: 'upload',
    facts: { price: '10 free a day; 1,000 credits from $9/mo or $17 once', platforms: 'Any browser, API', processing: 'Uploaded to its servers', source: 'Closed', scope: '212 formats in 11 categories', cli: 'API', mcp: 'Not mentioned', macos: 'Any (web)' },
    rows: [
      { label: 'Where it converts', anyfmt: 'On your Mac', them: 'On CloudConvert\'s servers' },
      { label: 'Free limit', anyfmt: 'None for anything local', them: '10 conversions a day, 1 GB, 5 min each' },
      { label: 'Big files', anyfmt: 'As big as your disk', them: '1 GB free; no limit when paid' },
      { label: 'Your files', anyfmt: 'Never leave the Mac', them: 'Deleted within 24 hours' },
      { label: 'Formats', anyfmt: '59 formats, 793 routes', them: '212 formats, including CAD and RAW' },
      { label: 'Works on', anyfmt: 'Your Mac', them: 'Any computer with a browser' },
      { label: 'Gesture', anyfmt: 'Drag, tap ⇧, drop', them: 'Open the site, upload, pick, download' },
    ],
    pickThem: ['You\'re not on your own Mac, or not on a Mac at all.', 'You need CAD, camera RAW or another format anyfmt doesn\'t have.', 'You want a hosted API with ISO 27001 certification today.'],
    pickUs: ['The file is private, large, or both.', 'You convert more than ten things a day.', 'You\'d rather not wait for an upload and a download every time.'],
    faq: [
      ['Is CloudConvert safe?', 'CloudConvert says files are deleted after 24 hours at the latest, that it doesn\'t read your files, and that it is ISO 27001 certified. The file still leaves your computer. With anyfmt it doesn\'t.'],
      ['How many free conversions does CloudConvert give?', '10 conversion credits a day on the free tier, with a 1 GB file limit and 5 minutes of processing per conversion (checked 27 October 2026).'],
      ['What about FreeConvert and Zamzar?', 'They work the same way: you upload. FreeConvert\'s free tier allows 1 GB files and 20 conversion minutes a day and deletes files after 8 hours. Zamzar\'s free limit is 50 MB.'],
    ],
    sources: [
      { label: 'CloudConvert pricing', url: 'https://cloudconvert.com/pricing' },
      { label: 'CloudConvert privacy', url: 'https://cloudconvert.com/privacy' },
      { label: 'CloudConvert security', url: 'https://cloudconvert.com/security' },
      { label: 'CloudConvert formats', url: 'https://cloudconvert.com/formats' },
      { label: 'FreeConvert pricing', url: 'https://www.freeconvert.com/pricing' },
      { label: 'Zamzar', url: 'https://www.zamzar.com/' },
    ],
  },
  {
    slug: 'clop', name: 'Clop', maker: 'The low-tech guys', site: 'https://lowtechguys.com/clop/', kind: 'File optimiser',
    title: 'anyfmt vs Clop: converter vs optimiser',
    h1: 'Clop makes files smaller, where anyfmt changes their format.',
    description: 'anyfmt vs Clop on Mac: Clop optimises images, video and PDFs automatically. anyfmt converts between 59 formats mid-drag, with a free CLI and MCP server.',
    answer: 'Clop is an optimiser: it shrinks images on your clipboard, screen recordings and files in watched folders, and converts to a handful of modern formats. anyfmt is a converter: 793 routes between 59 formats, plus compress-to-size tools, all free locally. Clop\'s free version limits most features to 5 per session and keeps its MCP server for Pro; anyfmt\'s CLI and MCP server are free.',
    centrepiece: 'session',
    facts: { price: 'Free with limits; Pro €15 lifetime', platforms: 'macOS 13+ (site says 14+)', processing: 'On your Mac', source: 'GPL-3.0 to 3.5.0; current releases private', scope: 'Images, video, PDF and audio optimisation', cli: 'Yes (5 per session free)', mcp: 'Pro only', macos: '13 (update feed)' },
    rows: [
      { label: 'What it\'s for', anyfmt: 'Converting between formats', them: 'Optimising files automatically' },
      { label: 'Free limits', anyfmt: 'None for anything local', them: '5 per session for most features, 5 files per drop' },
      { label: 'Formats', anyfmt: '59 formats, 793 routes', them: 'Converts to JPEG XL, WebP, AVIF, AV1, WebM, HEVC' },
      { label: 'Documents, ebooks, archives', anyfmt: 'Yes', them: 'Not mentioned' },
      { label: 'Automatic on clipboard and screenshots', anyfmt: 'No', them: 'Yes' },
      { label: 'MCP server', anyfmt: 'Free', them: 'Pro' },
      { label: 'Source', anyfmt: 'AGPL-3.0, public', them: 'Public until 3.5.0; work now continues privately' },
    ],
    pickThem: ['You want screenshots and clipboard images optimised without thinking about it.', 'You want JPEG XL output.', 'You share files peer to peer with Clop\'s send feature.'],
    pickUs: ['You need a different format, not just a smaller file.', 'You don\'t want a per-session limit on local work.', 'You want an agent to convert files through MCP without a paid tier.'],
    faq: [
      ['Can I use both?', 'Yes. They don\'t clash: Clop watches and optimises in the background, and anyfmt waits for you to tap a key mid-drag. If you remap one of them, both can use Option.'],
      ['Is Clop open source?', 'Its repository is GPL-3.0 up to version 3.5.0. A note added on 16 October 2026 says work continues privately, so the current 3.6 releases aren\'t public source.'],
    ],
    sources: [
      { label: 'Clop', url: 'https://lowtechguys.com/clop/' },
      { label: 'Clop changelog', url: 'https://files.lowtechguys.com/clop/changelog.html' },
      { label: 'Clop update feed', url: 'https://files.lowtechguys.com/clop/appcast.xml' },
      { label: 'Clop on GitHub', url: 'https://github.com/FuzzyIdeas/Clop' },
    ],
  },
  {
    slug: 'handbrake', name: 'HandBrake', maker: 'The HandBrake Team', site: 'https://handbrake.fr', kind: 'Open-source video transcoder',
    title: 'anyfmt vs HandBrake for converting video on Mac',
    h1: 'MOV to MP4 without re-encoding, which HandBrake doesn\'t do.',
    description: 'anyfmt vs HandBrake: HandBrake is a free video transcoder that always re-encodes. anyfmt converts MOV to MP4 losslessly when it can, plus images, audio and documents.',
    answer: 'HandBrake is a free, open-source video transcoder with deep encoding controls; its own documentation says it doesn\'t pass video through without re-encoding. anyfmt is a general converter: when a MOV already holds H.264, anyfmt rewraps it as MP4 without re-encoding, in 0.23 seconds for a one-minute 1080p clip in our tests. HandBrake is the better tool for fine-tuned encodes, DVDs and Blu-ray.',
    centrepiece: 'passthrough',
    facts: { price: 'Free', platforms: 'macOS, Windows, Linux', processing: 'On your computer', source: 'Open source, GPL-2.0', scope: 'Video to MP4, MKV, WebM, MOV', cli: 'Yes, separate download', mcp: 'No', macos: '14 supported (13 deprecated)' },
    rows: [
      { label: 'Scope', anyfmt: 'Video, audio, images, PDF, documents and more', them: 'Video only' },
      { label: 'Passthrough (no re-encode)', anyfmt: 'Yes, when the streams allow it', them: 'No, per its docs' },
      { label: 'Join clips', anyfmt: 'Yes, losslessly when compatible', them: 'No, per its docs' },
      { label: 'Encoding controls', anyfmt: 'Quality, size target, codec, resolution', them: 'Extensive: filters, presets, every encoder setting' },
      { label: 'DVD and Blu-ray', anyfmt: 'No', them: 'Yes (without DRM)' },
      { label: 'How you start', anyfmt: 'Drag, tap ⇧, drop', them: 'Open the app, add to queue, start' },
    ],
    pickThem: ['You need precise encoder control, filters and presets.', 'You\'re ripping your own DVDs or Blu-rays.', 'You need the same tool on Windows or Linux.'],
    pickUs: ['You want MOV to MP4 without losing quality or waiting.', 'You also convert photos, audio and documents.', 'You want to trim, join or compress to a size from the same gesture.'],
    faq: [
      ['Why is anyfmt so fast for MOV to MP4?', 'Most MOV files from iPhones and cameras already contain H.264 or HEVC that MP4 can hold as is. anyfmt copies the streams into the new container instead of re-encoding them. In our tests that took 0.23 seconds for a one-minute 1080p clip, against 3.39 seconds for a hardware re-encode.'],
      ['Is HandBrake still free?', 'Yes. HandBrake is free and open source under GPL-2.0. The latest version is 1.11.2.'],
    ],
    sources: [
      { label: 'HandBrake', url: 'https://handbrake.fr/' },
      { label: 'About HandBrake (docs)', url: 'https://handbrake.fr/docs/en/latest/introduction/about.html' },
      { label: 'HandBrake system requirements', url: 'https://handbrake.fr/docs/en/latest/technical/system-requirements.html' },
      { label: 'HandBrake releases', url: 'https://github.com/HandBrake/HandBrake/releases' },
    ],
  },
  {
    slug: 'ffmpeg', name: 'FFmpeg', maker: 'The FFmpeg project', site: 'https://ffmpeg.org', kind: 'Command-line media engine',
    title: 'anyfmt vs FFmpeg: the engine, without the flags',
    h1: 'anyfmt runs FFmpeg for you, so you never write its flags.',
    description: 'anyfmt vs using FFmpeg directly: anyfmt bundles FFmpeg 9.0.2 and picks the right flags for 167 video and audio routes, mid-drag. Its own CLI is there when you want one.',
    answer: 'FFmpeg is the engine behind most video and audio conversion, and anyfmt bundles it: FFmpeg 9.0.2, built without network support. The difference is the interface. With FFmpeg you write the command; with anyfmt you drag, tap Shift and drop, and anyfmt picks codecs, quality and container for you. When something fails, anyfmt shows the exact FFmpeg command it ran.',
    centrepiece: 'terminal',
    facts: { price: 'Free', platforms: 'Every platform, from source', processing: 'On your computer', source: 'LGPL-2.1+ (GPL with some parts)', scope: 'Audio and video, everything', cli: 'It is a CLI', mcp: 'No', macos: 'Any (you build or download it)' },
    rows: [
      { label: 'Interface', anyfmt: 'A wheel mid-drag, plus a CLI', them: 'Command line' },
      { label: 'Choosing flags', anyfmt: 'Done for you, adjustable in options', them: 'You write them' },
      { label: 'Installation', anyfmt: 'Inside the app', them: 'Build it, or use a third-party binary' },
      { label: 'Beyond media', anyfmt: 'Images, PDF, documents, sheets, archives', them: 'Audio and video' },
      { label: 'Network', anyfmt: 'Bundled build has networking disabled', them: 'Can stream and fetch URLs' },
      { label: 'Power', anyfmt: 'The routes we ship', them: 'Anything FFmpeg can do' },
    ],
    pickThem: ['You need a filter graph, streaming, or a codec option anyfmt doesn\'t expose.', 'You\'re building a pipeline on a server, not converting on a Mac.'],
    pickUs: ['You know what you want, not the flags that get you there.', 'You also need images, PDFs and documents.', 'You want scripts with typed options, NDJSON progress and stable exit codes.'],
    faq: [
      ['Does anyfmt use FFmpeg?', 'Yes, for most video and audio routes: FFmpeg 9.0.2 with x264, x265, libvpx, libaom, dav1d, Opus, LAME and more, built from pinned sources with networking turned off. Photos use Apple\'s ImageIO, and documents use anyfmt\'s own writers.'],
      ['Can I see the FFmpeg command anyfmt runs?', 'When a conversion fails, the details start with the exact command line, shell-quoted. `anyfmt convert --dry-run` shows the route and engines before anything runs.'],
    ],
    sources: [
      { label: 'FFmpeg', url: 'https://ffmpeg.org/' },
      { label: 'FFmpeg legal', url: 'https://ffmpeg.org/legal.html' },
      { label: 'FFmpeg download', url: 'https://ffmpeg.org/download.html' },
    ],
  },
  {
    slug: 'macos', name: 'Finder and Preview', maker: 'Apple', site: 'https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/mac', kind: 'Built into macOS',
    title: 'anyfmt vs Finder Convert Image and Preview export',
    h1: 'What Finder and Preview already convert, and what they can\'t.',
    description: 'Finder\'s Convert Image Quick Action and Preview\'s Export cover photos well. Here is what they convert, and what anyfmt adds: video, audio, PDF, documents and options.',
    answer: 'For photos, macOS already has two good converters. Finder\'s Convert Image Quick Action (macOS 12 or later) turns images into JPEG, PNG or HEIF, and Preview\'s File › Export also writes JPEG-2000, OpenEXR, PDF and TIFF. Neither converts video, audio, documents or spreadsheets, and neither writes WebP or AVIF. anyfmt covers those, mid-drag.',
    centrepiece: 'menu',
    facts: { price: 'Free, built in', platforms: 'macOS', processing: 'On your Mac', source: 'Closed', scope: 'Images (and PDF from Preview)', cli: 'sips (images)', mcp: 'No', macos: '12 Monterey for Convert Image' },
    rows: [
      { label: 'Image formats out', anyfmt: 'JPG, PNG, HEIC, WebP, AVIF, TIFF, GIF, BMP, ICO, ICNS, PDF…', them: 'JPEG, PNG, HEIF (Finder); + JPEG-2000, EXR, PDF, TIFF (Preview)' },
      { label: 'Video and audio', anyfmt: 'Yes', them: 'Trim only' },
      { label: 'Documents and spreadsheets', anyfmt: 'Yes', them: 'No' },
      { label: 'Options', anyfmt: 'Quality, size, DPI, metadata and more', them: 'Size and metadata (Finder); quality (Preview)' },
      { label: 'Batch', anyfmt: 'Any multi-file drag', them: 'Yes' },
      { label: 'Steps', anyfmt: 'Drag, tap ⇧, drop', them: 'Right-click › Quick Actions › Convert Image › options' },
    ],
    pickThem: ['You only ever turn HEIC photos into JPEG or PNG, now and then.', 'You don\'t want to install anything.'],
    pickUs: ['You need WebP, AVIF, ICO or ICNS.', 'You convert video, audio, PDFs or documents too.', 'You want it in one motion, without a menu.'],
    faq: [
      ['How do I convert HEIC to JPG on a Mac without an app?', 'Control-click the photo in Finder, choose Quick Actions › Convert Image, pick JPEG and a size. It saves a copy beside the original. This needs macOS 12 Monterey or later.'],
      ['Can Preview convert to WebP?', 'Not in its standard format menu, which lists HEIC, JPEG, JPEG-2000, OpenEXR, PDF, PNG and TIFF. Option-clicking the menu shows a few older formats.'],
    ],
    sources: [
      { label: 'Apple: Quick Actions in the Finder', url: 'https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/mac' },
      { label: 'Apple: Convert image file types in Preview', url: 'https://support.apple.com/guide/preview/convert-image-file-types-prvw1012/mac' },
      { label: 'OSXDaily: Convert Image', url: 'https://osxdaily.com/2023/02/28/convert-images-on-mac-quickly-from-finder/' },
    ],
  },
]

export const COMPETITOR = Object.fromEntries(COMPETITORS.map((c) => [c.slug, c])) as Record<string, Competitor>
