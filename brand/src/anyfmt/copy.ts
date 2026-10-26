// anyfmt copy. Numbers come from the real app (see ../shared/product.ts); only the name and voice change here.
import { product } from '../shared/product'

export const brand = {
  name: 'anyfmt',
  domain: 'anyfmt.app',
  platform: product.platform,
}

export const convertWedges = [
  { id: 'gif', label: 'GIF', sub: '4.1 MB' },
  { id: 'mp4', label: 'MP4', sub: '1.8 MB' },
  { id: 'webm', label: 'WEBM', sub: '1.2 MB' },
  { id: 'm4v', label: 'M4V', sub: '1.9 MB' },
  { id: 'mp3', label: 'MP3', sub: 'audio' },
  { id: 'png', label: 'PNG', sub: 'frame' },
] as const

export const toolWedges = product.tools.slice(0, 6).map((t) => ({ id: t, label: t }))
export const actionWedges = product.actions.map((a) => ({ id: a, label: a }))

export const stats = product.stats
export const pricing = product.pricing

export const faqs = [
  { q: 'Is anyfmt really free?', a: 'Yes. Every conversion, tool and action runs on your Mac and is free forever. The code is open source under the AGPL. Pro is optional and only adds things that need a server, like share links and cloud conversions for huge files.' },
  { q: 'Does it upload my files?', a: 'No. anyfmt makes zero network calls unless you turn on a Pro cloud feature yourself. There is no account and no telemetry.' },
  { q: 'Will it touch my original file?', a: 'Never. Every result is saved as a new file next to the original, so you can always go back.' },
  { q: 'Which Macs does it run on?', a: 'Macs with Apple silicon running macOS 13 Ventura or later.' },
  { q: 'Why does it ask for permission on first launch?', a: 'anyfmt needs to notice a drag and a key press anywhere on your Mac. macOS asks you to allow that once, and you can turn it off in System Settings at any time.' },
  { q: 'Can my scripts or AI agent use it?', a: 'Yes. anyfmt ships a real command line tool with JSON and NDJSON progress, plus an MCP server, so Claude and other agents can convert files on your Mac.' },
]
