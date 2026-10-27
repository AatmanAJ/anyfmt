/**
 * The anyfmt icon: the wordmark, cut down to its first letter and its full stop. A white "a" and
 * the ember dot on an ink squircle, so the icon and the name are one mark.
 */
import { GLYPH_A, GLYPH_DOT } from '../data/glyphs'

const squircle = (() => {
  // superellipse, n = 5, the shape macOS uses for app icons, 824 px inside a 1024 canvas
  const c = 512, r = 412, n = 5, pts: string[] = []
  for (let i = 0; i < 360; i += 3) {
    const t = (i * Math.PI) / 180, ct = Math.cos(t), st = Math.sin(t)
    pts.push(`${(c + r * Math.sign(ct) * Math.abs(ct) ** (2 / n)).toFixed(1)},${(c + r * Math.sign(st) * Math.abs(st) ** (2 / n)).toFixed(1)}`)
  }
  return `M${pts.join('L')}Z`
})()

// "a." set as in the wordmark (tracking −0.04em), sized to 0.52 of the canvas and centred on its ink
const TRACK = -40
const DOT_X = GLYPH_A.adv + TRACK
const INK = { x0: 23.5, x1: DOT_X + 145.3, y0: -12.6, y1: 541.7 }
const S = 532 / (INK.x1 - INK.x0)
const X0 = 512 - ((INK.x1 - INK.x0) * S) / 2 - INK.x0 * S
const Y0 = 524 + ((INK.y1 + INK.y0) / 2) * S

export function AppIcon({ size = 128, className = '', uid = 'ai', tone = 'ink' }: { size?: number; className?: string; uid?: string; tone?: 'ink' | 'paper' }) {
  const paper = tone === 'paper'
  return (
    <svg width={size} height={size} viewBox="0 0 1024 1024" className={className} role="img" aria-label="anyfmt app icon">
      <defs>
        <linearGradient id={`${uid}-body`} x1="0" y1="0" x2="0" y2="1">
          {paper ? <><stop offset="0" stopColor="#FFFFFF" /><stop offset="1" stopColor="#ECEAE6" /></> : <><stop offset="0" stopColor="#222222" /><stop offset="0.55" stopColor="#0E0E0E" /><stop offset="1" stopColor="#050505" /></>}
        </linearGradient>
        <radialGradient id={`${uid}-dot`} cx="0.35" cy="0.3" r="0.8">
          <stop offset="0" stopColor="#FF7A3D" /><stop offset="0.55" stopColor="#FF4A14" /><stop offset="1" stopColor="#E02A00" />
        </radialGradient>
      </defs>
      <path d={squircle} fill={`url(#${uid}-body)`} />
      <path d={squircle} fill="none" stroke={paper ? 'rgba(0,0,0,.08)' : 'rgba(255,255,255,.09)'} strokeWidth="5" />
      <g transform={`translate(${X0.toFixed(1)} ${Y0.toFixed(1)}) scale(${S.toFixed(4)} ${(-S).toFixed(4)})`}>
        <path d={GLYPH_A.d} fill={paper ? '#0A0A0A' : '#FFFFFF'} />
        <path d={GLYPH_DOT.d} transform={`translate(${DOT_X} 0)`} fill={`url(#${uid}-dot)`} />
      </g>
    </svg>
  )
}

/** The menu bar glyph: the same "a." as a single-colour template image, 18 pt like the system's own. */
export function MenuBarGlyph({ size = 16, className = '' }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 -560 600 600" className={className} aria-hidden>
      <g transform="scale(1 -1)" fill="currentColor">
        <path d={GLYPH_A.d} />
        <path d={GLYPH_DOT.d} transform={`translate(${GLYPH_A.adv - 40} 0)`} />
      </g>
    </svg>
  )
}
