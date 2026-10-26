import type { CSSProperties } from 'react'
import { cn } from '../../shared/cn'
import { sector } from './GridWheel'
import { C } from './ui'

const TAU = Math.PI * 2

/**
 * The mark: a ring cut into six wedges. One is vermilion — the one you drop on.
 * Built on a 100-unit square: outer r 48, inner r 20, gap 6. The red wedge sits at 2 o'clock.
 */
export function Mark({
  size = 48, ink = C.ink, accent = C.red, hot = 1, className, style, gap = 6, inner = 20, template,
}: {
  size?: number; ink?: string; accent?: string; hot?: number | null; className?: string; style?: CSSProperties
  gap?: number; inner?: number; template?: boolean
}) {
  const n = 6, step = TAU / n
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} style={style} role="img" aria-label="Halo">
      {Array.from({ length: n }).map((_, i) => {
        const a0 = -step / 2 + i * step
        if (template && i === hot) return null
        return <path key={i} d={sector(50, 50, inner, 48, a0, a0 + step, gap)} fill={i === hot && !template ? accent : ink} />
      })}
    </svg>
  )
}

export function Wordmark({ className, style, color = C.ink }: { className?: string; style?: CSSProperties; color?: string }) {
  return (
    <span className={cn('font-grotesk font-semibold leading-none tracking-[-0.065em]', className)} style={{ color, ...style }}>
      Halo
    </span>
  )
}

/** Horizontal lockup. Mark height = cap height × 1.4; space between = one wedge gap × 4. */
export function Lockup({ h = 28, color = C.ink, accent = C.red, className }: { h?: number; color?: string; accent?: string; className?: string }) {
  return (
    <span className={cn('inline-flex items-center', className)} style={{ gap: h * 0.3 }}>
      <Mark size={h} ink={color} accent={accent} />
      <Wordmark color={color} style={{ fontSize: h * 1.04, marginTop: -h * 0.04 }} />
    </span>
  )
}

/** macOS app icon (1024 grid: 824 body, 185 corner radius, continuous corners approximated). */
export function AppIcon({ size = 160, dark, className }: { size?: number; dark?: boolean; className?: string }) {
  const bg = dark ? C.ink : C.sheet
  const line = dark ? '#262624' : C.rule
  const wedge = dark ? C.sheet : C.sheet
  const disc = dark ? '#000' : C.ink
  const n = 6, step = TAU / n
  const id = dark ? 'gi-d' : 'gi-l'
  return (
    <svg width={size} height={size} viewBox="0 0 1024 1024" className={className} role="img" aria-label="Halo app icon">
      <defs>
        <clipPath id={`${id}-c`}><path d={squircle(100, 100, 824, 185)} /></clipPath>
        <filter id={`${id}-s`} x="-20%" y="-20%" width="140%" height="150%">
          <feDropShadow dx="0" dy="14" stdDeviation="16" floodColor="#000" floodOpacity={dark ? 0.45 : 0.22} />
        </filter>
      </defs>
      <path d={squircle(100, 100, 824, 185)} fill={bg} filter={`url(#${id}-s)`} />
      <g clipPath={`url(#${id}-c)`}>
        {Array.from({ length: 12 }).map((_, i) => (
          <line key={i} x1={100 + (824 / 12) * i} x2={100 + (824 / 12) * i} y1={100} y2={924} stroke={line} strokeWidth="2" />
        ))}
        <circle cx="512" cy="512" r="318" fill={disc} />
        {Array.from({ length: n }).map((_, i) => {
          const a0 = -step / 2 + i * step
          return <path key={i} d={sector(512, 512, 118, 300, a0, a0 + step, 18)} fill={i === 1 ? C.red : wedge} />
        })}
        <circle cx="512" cy="512" r="76" fill="none" stroke={dark ? '#2A2A28' : '#2C2C2A'} strokeWidth="3" />
        <text x="156" y="880" fill={dark ? '#6A6A64' : C.ink2} style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 40, fontWeight: 600, letterSpacing: 3 }}>HALO</text>
        <text x="868" y="880" textAnchor="end" fill={dark ? '#6A6A64' : C.ink2} style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 40, fontWeight: 600 }}>01</text>
      </g>
      <path d={squircle(100, 100, 824, 185)} fill="none" stroke={dark ? '#2A2A28' : 'rgba(0,0,0,.08)'} strokeWidth="2" />
    </svg>
  )
}

/** Rounded rect with continuous-ish corners (cubic handles at 0.62 of the radius, closer to Apple's shape than arcs). */
export function squircle(x: number, y: number, s: number, r: number) {
  const k = r * 0.38
  const R = x + s, B = y + s
  return [
    `M${x + r},${y}`, `H${R - r}`, `C${R - k},${y} ${R},${y + k} ${R},${y + r}`,
    `V${B - r}`, `C${R},${B - k} ${R - k},${B} ${R - r},${B}`,
    `H${x + r}`, `C${x + k},${B} ${x},${B - k} ${x},${B - r}`,
    `V${y + r}`, `C${x},${y + k} ${x + k},${y} ${x + r},${y}`, 'Z',
  ].join(' ')
}

/** Menu-bar template: monochrome; the red wedge becomes the gap. */
export function MenuGlyph({ size = 16, color = '#000' }: { size?: number; color?: string }) {
  return <Mark size={size} ink={color} template gap={10} inner={16} />
}
