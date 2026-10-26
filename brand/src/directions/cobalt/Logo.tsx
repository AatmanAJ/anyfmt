import { useId, type CSSProperties } from 'react'
import { C } from './tokens'

/** Annular sector, clock angles in degrees (0 = 12 o'clock, clockwise). */
export function arc(cx: number, cy: number, r0: number, r1: number, a0d: number, a1d: number) {
  const a0 = (a0d * Math.PI) / 180, a1 = (a1d * Math.PI) / 180
  const p = (r: number, a: number) => `${(cx + r * Math.sin(a)).toFixed(2)},${(cy - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${p(r1, a0)} A${r1},${r1} 0 ${large} 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 ${large} 0 ${p(r0, a0)} Z`
}

// The mark: a slanted ring (the wheel) with one wedge knocked out and lifted (the hit).
const RING = arc(50, 50, 25, 41, 72, 378)
const NOTCH_MID = 45
const LIFT = 7
const NOTCH = arc(50 + LIFT * Math.sin((NOTCH_MID * Math.PI) / 180), 50 - LIFT * Math.cos((NOTCH_MID * Math.PI) / 180), 25, 41, 26, 64)

export function Mark({
  size = 64, ring = C.ice, notch = C.flame, slant = true, glow = false, className, style, title = 'Halo',
}: { size?: number; ring?: string; notch?: string; slant?: boolean; glow?: boolean; className?: string; style?: CSSProperties; title?: string }) {
  const id = useId().replace(/:/g, '')
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} style={{ overflow: 'visible', ...style }} role="img" aria-label={title}>
      {glow && (
        <defs>
          <filter id={`g${id}`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4" /></filter>
        </defs>
      )}
      <g transform={slant ? 'translate(50 50) skewX(-12) translate(-50 -50)' : undefined}>
        <path d={RING} fill={ring} />
        {glow && <path d={NOTCH} fill={notch} filter={`url(#g${id})`} opacity=".9" />}
        <path d={NOTCH} fill={notch} />
      </g>
    </svg>
  )
}

/** Speed lines that trail the mark in the motion lockup. */
export function SpeedLines({ color = C.ice, size = 64 }: { color?: string; size?: number }) {
  return (
    <svg width={size * 0.5} height={size} viewBox="0 0 50 100" aria-hidden>
      <g transform="skewX(-12)" fill={color}>
        <rect x="18" y="34" width="34" height="6" />
        <rect x="6" y="47" width="46" height="6" />
        <rect x="26" y="60" width="26" height="6" />
      </g>
    </svg>
  )
}

/** HALO in Anton, slanted, with the flame cut. */
export function Wordmark({ size = 48, color = C.ice, cut = C.flame, className }: { size?: number; color?: string; cut?: string | null; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'flex-end', lineHeight: 0.8, fontFamily: '"Anton", Impact, sans-serif', fontSize: size, color, letterSpacing: '-0.005em', transform: 'skewX(-8deg)' }}>
      HALO
      {cut && <span aria-hidden style={{ display: 'inline-block', width: size * 0.16, height: size * 0.16, marginLeft: size * 0.06, marginBottom: size * 0.005, background: cut, transform: 'skewX(-12deg)' }} />}
    </span>
  )
}

export function Lockup({ size = 32, color = C.ice, notch = C.flame, className }: { size?: number; color?: string; notch?: string; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.28 }}>
      <Mark size={size * 1.2} ring={color} notch={notch} />
      <Wordmark size={size} color={color} cut={notch} />
    </span>
  )
}

/** Continuous-corner (superellipse) squircle path, macOS-ish. */
export function squircle(s: number, n = 5) {
  const pts: string[] = []
  const r = s / 2
  for (let i = 0; i <= 72; i++) {
    const t = (i / 72) * Math.PI * 2
    const c = Math.cos(t), si = Math.sin(t)
    const x = r + r * Math.sign(c) * Math.pow(Math.abs(c), 2 / n)
    const y = r + r * Math.sign(si) * Math.pow(Math.abs(si), 2 / n)
    pts.push(`${x.toFixed(2)},${y.toFixed(2)}`)
  }
  return `M${pts.join(' L')} Z`
}

/** The 1024 app icon, drawn at any size. */
export function AppIcon({ size = 180 }: { size?: number }) {
  const id = useId().replace(/:/g, '')
  const S = 1024, inset = 100, body = S - inset * 2
  const sq = squircle(body)
  const bands = [C.ultra, C.cobalt, '#2A46FF', C.cobalt, C.ultra]
  return (
    <svg width={size} height={size} viewBox={`0 0 ${S} ${S}`} role="img" aria-label="Halo app icon">
      <defs>
        <clipPath id={`c${id}`}><path d={sq} transform={`translate(${inset} ${inset})`} /></clipPath>
        <linearGradient id={`s${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity=".07" /><stop offset=".22" stopColor="#fff" stopOpacity="0" />
          <stop offset=".22" stopColor={C.deep} stopOpacity="0" /><stop offset="1" stopColor={C.deep} stopOpacity=".5" />
        </linearGradient>
        <filter id={`d${id}`} x="-20%" y="-20%" width="140%" height="150%" colorInterpolationFilters="sRGB"><feDropShadow dx="0" dy="22" stdDeviation="22" floodColor="#000" floodOpacity=".45" /></filter>
        <filter id={`gl${id}`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3.5" /></filter>
      </defs>
      <g filter={`url(#d${id})`}>
        <g clipPath={`url(#c${id})`}>
          {bands.map((b, i) => <rect key={i} x={inset + (body / 5) * i - 1} y={inset} width={body / 5 + 2} height={body} fill={b} />)}
          <rect x={inset} y={inset} width={body} height={body} fill={`url(#s${id})`} />
          {/* racing number plate stripe */}
          <rect x={inset} y={inset + body * 0.83} width={body} height={body * 0.03} fill={C.flame} opacity=".95" />
          <g transform={`translate(${S / 2 - 265} ${S / 2 - 290}) scale(5.3)`}>
            <g transform="translate(50 50) skewX(-12) translate(-50 -50)">
              <path d={RING} fill={C.ice} />
              <path d={NOTCH} fill={C.flame} opacity=".8" filter={`url(#gl${id})`} />
              <path d={NOTCH} fill={C.flame} />
            </g>
          </g>
        </g>
        <path d={sq} transform={`translate(${inset} ${inset})`} fill="none" stroke="#fff" strokeOpacity=".18" strokeWidth="3" />
      </g>
    </svg>
  )
}

/** Monochrome template glyph for the menu bar (no slant at this size: crisper on pixels). */
export function MenuGlyph({ size = 18, color = '#000' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" aria-label="Halo menu bar icon">
      <path d={arc(50, 50, 27, 44, 72, 378)} fill={color} />
      <path d={arc(56, 44, 27, 44, 28, 62)} fill={color} />
    </svg>
  )
}
