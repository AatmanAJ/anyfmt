import type { Wedge } from '../SheetWheel'

export const NAV = [
  { label: 'How it works', href: '#demo' },
  { label: 'Features', href: '#features' },
  { label: 'Agents', href: '#agents' },
  { label: 'Pricing', href: '#pricing' },
  { label: 'FAQ', href: '#faq' },
]

/** What a .mov can become, as the Shift wheel shows it. GIF sits at 12 o'clock. */
export const convertVideo: Wedge[] = ['GIF', 'MP4', 'WEBM', 'MP3', 'PNG', 'M4V'].map((l) => ({ id: l, label: l, sub: `clip.${l.toLowerCase()}` }))

export const convertImage: Wedge[] = ['JPG', 'PNG', 'WEBP', 'AVIF', 'PDF', 'TIFF'].map((l) => ({ id: l, label: l, sub: `photo.${l.toLowerCase()}` }))

export const toolWedges: Wedge[] = ['Compress', 'Crop', 'Trim', 'Redact', 'Annotate', 'Metadata'].map((l) => ({ id: l, label: l, sub: 'new copy' }))

export const actionWedges: Wedge[] = [
  { id: 'airdrop', label: 'AirDrop' },
  { id: 'float', label: 'Float', sub: 'shelf' },
  { id: 'copy', label: 'Copy' },
  { id: 'move', label: 'Move', sub: 'recent' },
  { id: 'path', label: 'Copy Path' },
  { id: 'term', label: 'Terminal' },
]

/** The strip band: formats we read and write, grouped by kind. No company names. */
export const STRIP = [
  ['HEIC', 'image'], ['MOV', 'video'], ['PDF', 'document'], ['WAV', 'audio'], ['WEBP', 'image'], ['MKV', 'video'],
  ['DOCX', 'document'], ['FLAC', 'audio'], ['AVIF', 'image'], ['EPUB', 'ebook'], ['SVG', 'vector'], ['ZIP', 'archive'],
] as const
