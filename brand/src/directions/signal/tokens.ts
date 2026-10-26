import { product } from '../../shared/product'
import type { WheelSegment, WheelSkin } from '../../shared/Wheel'
import { meta } from './meta'

/** Signal palette. One accent, used like a lit LED. */
export const C = {
  void: '#050506',
  carbon: '#111113',
  carbon2: '#18181B',
  carbon3: '#202024',
  graphite: '#2A2A2E',
  graphite2: '#3A3A3F',
  ash: '#8E8E88',
  ash2: '#5E5E5A',
  bone: '#EDEDE6',
  solar: '#D7FF3A',
  solarDim: '#9DBA2A',
  clip: '#FF5B3A',
} as const

/** Semantic tokens, written once as CSS variables on every Signal root. */
export const TOKENS: { name: string; value: string; use: string }[] = [
  { name: '--sg-bg', value: C.void, use: 'Page and window canvas' },
  { name: '--sg-surface', value: C.carbon, use: 'Panels, wedges at rest' },
  { name: '--sg-raised', value: C.carbon2, use: 'Hover rows, chips' },
  { name: '--sg-line', value: C.graphite, use: 'Hairlines, 1 px only' },
  { name: '--sg-line-strong', value: C.graphite2, use: 'Keycap edges, dividers on carbon' },
  { name: '--sg-text', value: C.bone, use: 'Primary text' },
  { name: '--sg-text-2', value: C.ash, use: 'Secondary text, labels' },
  { name: '--sg-text-3', value: C.ash2, use: 'Disabled, decoration only' },
  { name: '--sg-live', value: C.solar, use: 'The lit wedge, selection, primary CTA' },
  { name: '--sg-live-ink', value: C.void, use: 'Text on the lit colour' },
  { name: '--sg-clip', value: C.clip, use: 'Errors only. Never decoration' },
]

export const cssVars = Object.fromEntries(TOKENS.map((t) => [t.name, t.value])) as Record<string, string>

/** Skin for the shared Wheel (the hub card uses it). */
export const skin: WheelSkin = meta.skin

const seg = (label: string, sub?: string): WheelSegment => ({ id: label, label, sub })

export const convertSegs: WheelSegment[] = [
  seg('GIF', '15 fps'), seg('MP4', 'H.264'), seg('WEBM', 'VP9'), seg('MOV', 'ProRes'),
  seg('M4V'), seg('MKV'), seg('MP3', 'audio'), seg('PNG', 'frame'),
]
export const toolSegs: WheelSegment[] = product.tools.map((t) => seg(t))
export const actionSegs: WheelSegment[] = product.actions.map((t) => seg(t))

export const wheels = [
  { key: '⇧', name: 'Shift', wheel: 'Convert', segs: convertSegs, blurb: product.keys[0].blurb },
  { key: '⌘', name: 'Command', wheel: 'Tools', segs: toolSegs, blurb: product.keys[1].blurb },
  { key: '⌃', name: 'Control', wheel: 'Actions', segs: actionSegs, blurb: product.keys[2].blurb },
] as const

/** Display type helpers. */
export const serif = 'font-serif tracking-[-0.02em]'
export const mono = 'font-mono uppercase tracking-[0.16em]'

/** Dark macOS vibrancy material. */
export const vibrancy = {
  background: 'rgba(22,22,25,0.72)',
  backdropFilter: 'blur(28px) saturate(160%)',
  WebkitBackdropFilter: 'blur(28px) saturate(160%)',
  boxShadow: `inset 0 0.5px 0 rgba(255,255,255,.14), inset 0 0 0 0.5px rgba(255,255,255,.07), 0 0 0 0.5px rgba(0,0,0,.8), 0 24px 60px -18px rgba(0,0,0,.85)`,
} as const

/** WCAG contrast ratio between two hex colours. */
export function contrast(a: string, b: string) {
  const lum = (hex: string) => {
    const n = parseInt(hex.slice(1), 16)
    const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
      const s = v / 255
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
    })
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
  }
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x)
  return (l1 + 0.05) / (l2 + 0.05)
}
