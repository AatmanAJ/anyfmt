import { useId } from 'react'
import { cn } from '../../shared/cn'
import { P } from './theme'

/** Colour stops around the ring, clockwise from 12 o'clock. */
const STOPS = ['#FF6B8B', '#FF8FA8', '#E7A2E6', '#B9A7FF', '#9DB8FF', '#7FD9F0', '#5EE7DF', '#8FD1F4', '#B9A7FF', '#D9A1E0', '#FF6B8B']

function hexToRgb(h: string) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255] }
function mix(a: string, b: string, t: number) {
  const A = hexToRgb(a), B = hexToRgb(b)
  return `rgb(${A.map((v, i) => Math.round(v + (B[i] - v) * t)).join(',')})`
}
function colourAt(t: number) {
  const x = t * (STOPS.length - 1), i = Math.min(STOPS.length - 2, Math.floor(x))
  return mix(STOPS[i], STOPS[i + 1], x - i)
}

/** An SVG ring with a true conic-style iridescence (built from short arcs). */
function IridescentRing({ cx, cy, r, w, segs = 72, rot = -20 }: { cx: number; cy: number; r: number; w: number; segs?: number; rot?: number }) {
  const out = []
  for (let k = 0; k < segs; k++) {
    const a0 = ((k / segs) * 360 + rot) * Math.PI / 180, a1 = (((k + 1.15) / segs) * 360 + rot) * Math.PI / 180
    const p = (a: number) => `${(cx + r * Math.sin(a)).toFixed(3)} ${(cy - r * Math.cos(a)).toFixed(3)}`
    out.push(<path key={k} d={`M${p(a0)} A${r} ${r} 0 0 1 ${p(a1)}`} stroke={colourAt(k / segs)} strokeWidth={w} fill="none" />)
  }
  return <g>{out}</g>
}

/** The Prism mark: a glass halo that catches light. */
export function PrismMark({ size = 40, className, title = 'Halo' }: { size?: number; className?: string; title?: string }) {
  const id = useId().replace(/:/g, '')
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} role="img" aria-label={title}>
      <defs>
        <linearGradient id={`g${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".75" />
          <stop offset=".45" stopColor="#fff" stopOpacity=".05" />
          <stop offset="1" stopColor="#1C1530" stopOpacity=".14" />
        </linearGradient>
        <radialGradient id={`s${id}`} cx=".5" cy=".5" r=".5">
          <stop offset="0" stopColor="#fff" stopOpacity="1" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <IridescentRing cx={50} cy={50} r={33} w={17} />
      {/* glass body: light from above, depth below */}
      <circle cx="50" cy="50" r="33" fill="none" stroke={`url(#g${id})`} strokeWidth="17" />
      {/* crisp edges */}
      <circle cx="50" cy="50" r="41.5" fill="none" stroke="#fff" strokeOpacity=".7" strokeWidth=".8" />
      <circle cx="50" cy="50" r="24.5" fill="none" stroke="#1C1530" strokeOpacity=".12" strokeWidth=".8" />
      {/* specular highlight */}
      <path d="M24.5 33.5 A31 31 0 0 1 43 20.2" stroke="#fff" strokeWidth="4.2" strokeLinecap="round" fill="none" opacity=".95" />
      <circle cx="73.5" cy="72" r="2.6" fill={`url(#s${id})`} />
    </svg>
  )
}

/** Monochrome template glyph for the menu bar: a ring with a glint. Uses currentColor. */
export function MenuGlyph({ size = 18, className }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" className={className} aria-hidden>
      <path d="M13.95 5.2 A6.2 6.2 0 1 1 11.6 3.35" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" />
      <circle cx="13.9" cy="3.6" r="1.55" fill="currentColor" />
    </svg>
  )
}

/** Wordmark: lowercase "halo" in Inter Display, tight. */
export function Wordmark({ className, size = 28, iris }: { className?: string; size?: number; iris?: boolean }) {
  return (
    <span className={cn('p-display font-semibold leading-none', iris && 'p-iris-text', className)}
          style={{ fontSize: size, letterSpacing: '-0.055em' }}>halo</span>
  )
}

export function Lockup({ size = 28, className, dark, iris }: { size?: number; className?: string; dark?: boolean; iris?: boolean }) {
  return (
    <span className={cn('inline-flex items-center', className)} style={{ gap: size * 0.32, color: dark ? '#fff' : P.plum }}>
      <PrismMark size={size * 1.18} />
      <Wordmark size={size} iris={iris} />
    </span>
  )
}

/** macOS app icon (1024 grid, Big Sur rounded square with the standard 100 px inset). */
export function AppIcon({ size = 160, dark, className }: { size?: number; dark?: boolean; className?: string }) {
  const id = useId().replace(/:/g, '')
  const box = { x: 100, y: 100, width: 824, height: 824, rx: 186 }
  const pool = (cx: string, cy: string, c: string, o: number, key: string) => (
    <radialGradient key={key} id={`${key}${id}`} cx={cx} cy={cy} r=".6">
      <stop offset="0" stopColor={c} stopOpacity={o} /><stop offset="1" stopColor={c} stopOpacity="0" />
    </radialGradient>
  )
  return (
    <svg width={size} height={size} viewBox="0 0 1024 1024" className={className} role="img" aria-label="Halo app icon">
      <defs>
        <linearGradient id={`bg${id}`} x1="0" y1="0" x2="1" y2="1">
          {dark ? (<><stop offset="0" stopColor="#2A1F48" /><stop offset="1" stopColor="#0E0A1A" /></>)
                : (<><stop offset="0" stopColor="#FFFFFF" /><stop offset=".55" stopColor="#F5F1FC" /><stop offset="1" stopColor="#E7E0F8" /></>)}
        </linearGradient>
        {pool('.18', '.12', P.coral, dark ? 0.55 : 0.42, 'pa')}
        {pool('.9', '.25', P.aqua, dark ? 0.35 : 0.45, 'pb')}
        {pool('.5', '1', dark ? P.iris : P.lilac, dark ? 0.75 : 0.6, 'pc')}
        <linearGradient id={`hi${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity={dark ? 0.12 : 0.6} /><stop offset=".45" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <filter id={`sh${id}`} filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feDropShadow dx="0" dy="20" stdDeviation="20" floodColor="#1C1530" floodOpacity=".3" /></filter>
        <filter id={`rs${id}`} filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feDropShadow dx="0" dy="24" stdDeviation="24" floodColor={dark ? '#000' : '#5B3FD6'} floodOpacity={dark ? 0.6 : 0.3} /></filter>
        <linearGradient id={`gl${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity={dark ? 0.3 : 0.8} /><stop offset=".5" stopColor="#fff" stopOpacity="0" /><stop offset="1" stopColor="#1C1530" stopOpacity=".12" />
        </linearGradient>
      </defs>
      <rect {...box} fill={`url(#bg${id})`} filter={`url(#sh${id})`} />
      <rect {...box} fill={`url(#pa${id})`} />
      <rect {...box} fill={`url(#pb${id})`} />
      <rect {...box} fill={`url(#pc${id})`} />
      <g filter={`url(#rs${id})`}>
        <g transform="translate(512 512) scale(5.4) translate(-50 -50)">
          <IridescentRing cx={50} cy={50} r={33} w={17} segs={96} />
        </g>
      </g>
      <g transform="translate(512 512) scale(5.4) translate(-50 -50)">
        <circle cx="50" cy="50" r="33" fill="none" stroke={`url(#gl${id})`} strokeWidth="17" />
        <circle cx="50" cy="50" r="41.5" fill="none" stroke="#fff" strokeOpacity=".8" strokeWidth=".5" />
        <path d="M24.5 33.5 A31 31 0 0 1 43 20.2" stroke="#fff" strokeWidth="4" strokeLinecap="round" fill="none" opacity=".95" />
      </g>
      <rect {...box} fill={`url(#hi${id})`} />
      <rect x="101" y="101" width="822" height="822" rx="185" fill="none" stroke={dark ? '#fff' : '#1C1530'} strokeOpacity={dark ? 0.14 : 0.07} strokeWidth="2" />
    </svg>
  )
}
