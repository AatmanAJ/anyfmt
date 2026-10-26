import { useId, type CSSProperties } from 'react'

/*
 * The mark: four quarter wedges of the wheel, each ending in an arrowhead that
 * tucks into the notch of the next. A wheel and a convert cycle at once.
 * Drawn on a 100×100 box, centre 50,50.
 */
const C = 50, R0 = 17, R1 = 45, HEAD = 15, GAP = 7

function pt(r: number, deg: number) {
  const a = (deg * Math.PI) / 180
  return `${(C + r * Math.sin(a)).toFixed(2)},${(C - r * Math.cos(a)).toFixed(2)}`
}

/** One petal starting at clock angle `a0` (degrees). */
export function petalPath(a0: number) {
  const a1 = a0 + 90 - GAP
  const rm = (R0 + R1) / 2
  return [
    `M${pt(R1, a0)}`,
    `A${R1},${R1} 0 0 1 ${pt(R1, a1 - HEAD)}`,
    `L${pt(rm, a1)}`,
    `L${pt(R0, a1 - HEAD)}`,
    `A${R0},${R0} 0 0 0 ${pt(R0, a0)}`,
    `L${pt(rm, a0 + HEAD * 0.9)}`,
    'Z',
  ].join(' ')
}

const PETALS = [0, 90, 180, 270].map((a) => petalPath(a + GAP / 2 - 45))

type MarkProps = { size?: number; variant?: 'flat' | 'gloss' | 'mono' | 'white'; className?: string; style?: CSSProperties; spin?: boolean }

/** The anyfmt mark. `gloss` is the 3D sweet version for icons and hero moments. */
export function Mark({ size = 32, variant = 'flat', className, style, spin }: MarkProps) {
  const id = useId().replace(/:/g, '')
  const round = { strokeLinejoin: 'round' as const, strokeWidth: 5 }
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} style={{ ...style, overflow: 'visible' }} aria-label="anyfmt" role="img">
      <defs>
        <linearGradient id={`${id}t`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FFB273" />
          <stop offset=".55" stopColor="#F08A3A" />
          <stop offset="1" stopColor="#D8601F" />
        </linearGradient>
        <linearGradient id={`${id}h`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".85" />
          <stop offset=".45" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <linearGradient id={`${id}f`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#F59248" />
          <stop offset="1" stopColor="#D35A1C" />
        </linearGradient>
      </defs>
      <g style={spin ? { transformOrigin: '50px 50px', animation: 'af-spin 14s linear infinite' } : undefined}>
        {PETALS.map((d, i) => {
          if (variant === 'mono') return <path key={i} d={d} fill="currentColor" stroke="currentColor" {...round} />
          if (variant === 'white') return <path key={i} d={d} fill="#fff" stroke="#fff" {...round} />
          if (variant === 'flat') return <path key={i} d={d} fill={`url(#${id}f)`} stroke={`url(#${id}f)`} {...round} />
          return (
            <g key={i}>
              {/* extrusion */}
              <path d={d} transform="translate(0 3.2)" fill="#A9400F" stroke="#A9400F" {...round} />
              <path d={d} transform="translate(0 1.6)" fill="#C4511A" stroke="#C4511A" {...round} />
              {/* face */}
              <path d={d} fill={`url(#${id}t)`} stroke={`url(#${id}t)`} {...round} />
              {/* top light */}
              <path d={d} fill={`url(#${id}h)`} stroke="none" opacity=".9" />
              <path d={d} fill="none" stroke="#FFE2C8" strokeOpacity=".7" strokeWidth={1} strokeLinejoin="round" transform="translate(0 -.4)" />
            </g>
          )
        })}
      </g>
    </svg>
  )
}

/** Mark + name. */
export function Wordmark({ size = 22, tone = 'ink', className }: { size?: number; tone?: 'ink' | 'white'; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.36 }}>
      <Mark size={size * 1.1} variant={tone === 'white' ? 'white' : 'flat'} />
      <span style={{ fontSize: size, fontWeight: 650, letterSpacing: '-0.035em', lineHeight: 1, color: tone === 'white' ? '#fff' : 'var(--af-ink)' }}>
        anyfmt
      </span>
    </span>
  )
}

/** The macOS app icon: a white squircle with the glossy mark. */
export function AppIcon({ size = 96, className, style }: { size?: number; className?: string; style?: CSSProperties }) {
  return (
    <div className={className} style={{
      width: size, height: size, borderRadius: size * 0.225,
      background: 'linear-gradient(180deg, #FFFFFF 0%, #F2F0ED 100%)',
      boxShadow: `inset 0 ${size * 0.01}px 0 #fff, inset 0 -${size * 0.03}px ${size * 0.06}px rgba(17,17,17,.06), 0 ${size * 0.06}px ${size * 0.16}px -${size * 0.04}px rgba(90,30,0,.35), 0 0 0 ${Math.max(0.5, size * 0.006)}px rgba(17,17,17,.08)`,
      display: 'grid', placeItems: 'center', ...style,
    }}>
      <Mark size={size * 0.64} variant="gloss" />
    </div>
  )
}

/** A thick clear-glass tile holding the glossy mark (the hero object). */
export function GlassTile({ size = 280, className, style }: { size?: number; className?: string; style?: CSSProperties }) {
  return (
    <div className={className} style={{ width: size, height: size, position: 'relative', ...style }}>
      {/* body */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: size * 0.3,
        background: 'linear-gradient(160deg, rgba(255,255,255,.75) 0%, rgba(255,255,255,.28) 45%, rgba(255,255,255,.5) 100%)',
        boxShadow: `inset 0 ${size * 0.012}px ${size * 0.01}px rgba(255,255,255,.95), inset 0 -${size * 0.04}px ${size * 0.08}px rgba(255,180,120,.45), inset ${size * 0.03}px 0 ${size * 0.06}px rgba(255,255,255,.4), 0 ${size * 0.1}px ${size * 0.2}px -${size * 0.06}px rgba(120,35,0,.55)`,
        backdropFilter: 'blur(18px) saturate(1.4)', WebkitBackdropFilter: 'blur(18px) saturate(1.4)',
        transform: 'rotate(-4deg)',
      }} />
      {/* rim */}
      <div style={{ position: 'absolute', inset: size * 0.035, borderRadius: size * 0.27, boxShadow: 'inset 0 0 0 1.5px rgba(255,255,255,.65)', transform: 'rotate(-4deg)' }} />
      {/* specular */}
      <div style={{ position: 'absolute', left: '12%', top: '7%', width: '46%', height: '16%', borderRadius: 999, background: 'linear-gradient(180deg, rgba(255,255,255,.9), rgba(255,255,255,0))', filter: 'blur(2px)', transform: 'rotate(-14deg)' }} />
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
        <Mark size={size * 0.62} variant="gloss" />
      </div>
    </div>
  )
}
