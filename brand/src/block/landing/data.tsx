import {
  Clapperboard, Copy, Crop, Eraser, FileText, Film, FolderInput, Image, Link, Minimize2, Music, Paintbrush, PanelTop, PenLine, Radio,
  Scissors, SquareTerminal, Tags,
} from 'lucide-react'
import type { ReactNode } from 'react'
import type { Wedge } from '../BlockWheel'
import { product } from '../../shared/product'

/* Copy and wheel data for the Block landing. Facts come from shared/product.ts; only the voice is ours. */

export const DOMAIN = 'anyfmt.app'

const ICON: Record<string, ReactNode> = {
  GIF: <Clapperboard size={15} strokeWidth={2.2} />,
  MP4: <Film size={15} strokeWidth={2.2} />,
  WEBM: <Film size={15} strokeWidth={2.2} />,
  M4V: <Film size={15} strokeWidth={2.2} />,
  MKV: <Film size={15} strokeWidth={2.2} />,
  MP3: <Music size={15} strokeWidth={2.2} />,
  PNG: <Image size={15} strokeWidth={2.2} />,
  JPG: <Image size={15} strokeWidth={2.2} />,
  WEBP: <Image size={15} strokeWidth={2.2} />,
  AVIF: <Image size={15} strokeWidth={2.2} />,
  TIFF: <Image size={15} strokeWidth={2.2} />,
  PDF: <FileText size={15} strokeWidth={2.2} />,
  Compress: <Minimize2 size={15} strokeWidth={2.2} />,
  Crop: <Crop size={15} strokeWidth={2.2} />,
  Edit: <Paintbrush size={15} strokeWidth={2.2} />,
  Annotate: <PenLine size={15} strokeWidth={2.2} />,
  'Add BG': <Eraser size={15} strokeWidth={2.2} />,
  Redact: <Tags size={15} strokeWidth={2.2} />,
  Metadata: <Tags size={15} strokeWidth={2.2} />,
  Trim: <Scissors size={15} strokeWidth={2.2} />,
  AirDrop: <Radio size={15} strokeWidth={2.2} />,
  Float: <PanelTop size={15} strokeWidth={2.2} />,
  Copy: <Copy size={15} strokeWidth={2.2} />,
  Move: <FolderInput size={15} strokeWidth={2.2} />,
  'Copy Path': <Link size={15} strokeWidth={2.2} />,
  Terminal: <SquareTerminal size={15} strokeWidth={2.2} />,
}

const w = (label: string, sub?: string, icon = true): Wedge => ({ id: label, label, sub, icon: icon ? ICON[label] : undefined })

/** The hero clip: sizes are the same illustrative numbers the app's own mockups use. */
export const heroWedges: Wedge[] = [w('GIF', '4.1 MB'), w('MP4', '1.8 MB'), w('WEBM', '1.2 MB'), w('M4V', '1.9 MB'), w('MP3', 'audio'), w('PNG', 'frame')]

export const convertVideo: Wedge[] = product.formatsVideo.filter((f) => f !== 'MOV').map((f) => w(f))
export const convertImage: Wedge[] = product.formatsImage.filter((f) => f !== 'HEIC').map((f) => w(f))
export const toolWedges: Wedge[] = product.tools.slice(0, 6).map((t) => w(t))
export const actionWedges: Wedge[] = product.actions.map((a) => w(a))

export const KEYS = [
  { ...product.keys[0], code: 'Shift', wedges: heroWedges.map((x) => ({ ...x, sub: undefined })), hub: 'MOV' },
  { ...product.keys[1], code: 'Meta', wedges: toolWedges, hub: 'MOV' },
  { ...product.keys[2], code: 'Control', wedges: actionWedges, hub: 'MOV' },
] as const

export const faqs = [
  { q: 'Does anything leave my Mac?', a: 'No. Every conversion, tool and action runs locally. anyfmt makes zero network calls unless you switch on a Pro cloud feature yourself. No account, no upload, no telemetry.' },
  { q: 'Is it really free?', a: 'Yes, forever. Every local feature is free and the code is open source under the AGPL-3.0. Pro is optional and only adds things that need a server, like share links and cloud conversions for huge files.' },
  { q: 'Will it overwrite my original?', a: 'Never. Every result is saved as a new file next to the original, so the file you dragged is untouched.' },
  { q: 'Which Macs does it run on?', a: 'Macs with Apple silicon running macOS 13 Ventura or later.' },
  { q: 'Why does it ask for permissions?', a: 'To open the wheel, anyfmt has to notice a drag and a key press anywhere on your Mac. macOS asks you to allow that once. You can switch it off in System Settings at any time.' },
  { q: 'Can my scripts and agents use it?', a: 'Yes. anyfmt ships a real command line tool with JSON and NDJSON progress, plus an MCP server, so Claude and other agents can convert files on your Mac, locally.' },
]

export const NAV = [
  { href: '#keys', label: 'How it works' },
  { href: '#play', label: 'Try it' },
  { href: '#features', label: 'Features' },
  { href: '#agents', label: 'Agents' },
  { href: '#pricing', label: 'Pricing' },
  { href: '#faq', label: 'FAQ' },
]
