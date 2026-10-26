// Facts about the product every direction must stay true to. Directions change
// the look and the voice, never these. Numbers are from the real app (docs/).

export const product = {
  name: 'Halo',
  oneLiner: 'Convert, edit and share any file in the middle of a drag.',
  how: 'Drag a file in Finder. Press a key. A wheel of everything that file can become opens around your pointer. Drop.',
  platform: 'macOS 13+ · Apple silicon',
  licence: 'Open source (AGPL-3.0). Every local feature free, forever.',
  stats: [
    { value: '793', label: 'conversion routes, every one tested' },
    { value: '26', label: 'tools: crop, trim, compress, redact…' },
    { value: '0', label: 'network calls unless you ask' },
    { value: '43 ms', label: 'key press to wheel on screen' },
  ],
  keys: [
    { key: '⇧', name: 'Shift', wheel: 'Convert', blurb: 'Every format the file can become.' },
    { key: '⌘', name: 'Command', wheel: 'Tools', blurb: 'Crop, trim, compress, redact, annotate.' },
    { key: '⌃', name: 'Control', wheel: 'Actions', blurb: 'AirDrop, Float, Copy, Move, Path, Terminal.' },
  ],
  formatsVideo: ['GIF', 'MP4', 'WEBM', 'MOV', 'M4V', 'MKV', 'MP3', 'PNG'],
  formatsImage: ['JPG', 'PNG', 'WEBP', 'HEIC', 'AVIF', 'TIFF', 'PDF', 'GIF'],
  tools: ['Compress', 'Crop', 'Edit', 'Annotate', 'Add BG', 'Redact', 'Metadata', 'Trim'],
  actions: ['AirDrop', 'Float', 'Copy', 'Move', 'Copy Path', 'Terminal'],
  conversions: [
    'HEIC → JPG', 'MOV → GIF', 'PDF → PNG', 'WAV → MP3', 'PNG → WEBP', 'MP4 → WEBM', 'DOCX → PDF', 'SVG → PNG',
    'AVIF → JPG', 'FLAC → M4A', 'MKV → MP4', 'TIFF → PDF', 'EPUB → PDF', 'ZIP ← Folder', 'MD → DOCX', 'JPG → AVIF',
  ],
  features: [
    { title: 'Convert', body: '793 routes across images, video, audio, documents, ebooks and archives. Multi-hop routes picked for quality.' },
    { title: 'Tools', body: 'Crop, trim, compress to a size, redact, annotate, add a background, read QR codes. Each saves a new copy.' },
    { title: 'Actions', body: 'AirDrop, a Float shelf that holds files between drags, copy path, open in Terminal, move to recent folders.' },
    { title: 'Presets', body: 'Your GIF at 15 fps, your JPG at 80 %. One chip on the wheel, synced if you want.' },
    { title: 'Agents', body: 'A real CLI with JSON and NDJSON progress, plus an MCP server. Claude can convert your files, locally.' },
    { title: 'Private', body: 'Everything runs on your Mac. No account, no upload, no telemetry. Pro cloud is opt-in.' },
  ],
  pricing: [
    { name: 'Local', price: 'Free', period: 'forever', points: ['All 793 conversions', 'All 26 tools and 6 actions', 'CLI + MCP server', 'Open source'] },
    { name: 'Pro', price: '$4', period: '/month', points: ['Share links with expiry', 'Cloud conversions for huge files', 'Transcribe, upscale, HQ cut-outs', 'Sync presets across Macs'] },
  ],
} as const

export type Product = typeof product
