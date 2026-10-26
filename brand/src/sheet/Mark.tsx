import type { CSSProperties } from 'react'

/*
 * The mark: the wheel drawn in pixels. Six wedges on a 22×22 grid, one lit orange:
 * the wedge you aim at. Pixels because the brand's imagery is digital-native.
 */
const N = 22

type Cell = { x: number; y: number; wedge: number }

function wheelCells(n = N, wedges = 6): Cell[] {
  const c = (n - 1) / 2
  const r1 = n / 2 - 0.15, r0 = n * 0.27
  const out: Cell[] = []
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const dx = x - c, dy = y - c, d = Math.hypot(dx, dy)
    if (d > r1 || d < r0) continue
    let a = Math.atan2(dx, -dy) + Math.PI / wedges // clock angle, wedge 0 centred at 12
    a = ((a % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI)
    const span = (2 * Math.PI) / wedges
    const into = a % span
    // Gap: drop cells within ~0.6 px of a wedge boundary at their radius.
    if (Math.min(into, span - into) * d < 0.85) continue
    out.push({ x, y, wedge: Math.floor(a / span) })
  }
  return out
}

const CELLS = wheelCells()

export function Mark({ size = 32, hot = 1, ink = '#000000', accent = '#FF4500', className, style }: {
  size?: number; hot?: number | null; ink?: string; accent?: string; className?: string; style?: CSSProperties
}) {
  return (
    <svg width={size} height={size} viewBox={`0 0 ${N} ${N}`} shapeRendering="crispEdges" className={className} style={style} role="img" aria-label="anyfmt">
      {CELLS.map((c) => <rect key={`${c.x}-${c.y}`} x={c.x} y={c.y} width={1} height={1} fill={c.wedge === hot ? accent : ink} />)}
    </svg>
  )
}

/** "any" plus "fmt" in the orange highlight box: the brand's signature move, in the name itself. */
export function Wordmark({ size = 22, mark = true, className }: { size?: number; mark?: boolean; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.4, color: 'var(--sh-ink)' }}>
      {mark && <Mark size={size * 1.15} />}
      <span className="sh-display" style={{ fontSize: size, lineHeight: 1, letterSpacing: '-0.04em', fontWeight: 500 }}>
        any<span className="sh-hl" style={{ marginLeft: '0.03em' }}>fmt</span>
      </span>
    </span>
  )
}

/** App icon: a paper-white squircle, hairline edge, the pixel wheel in ink with the orange wedge. */
export function AppIcon({ size = 96, dark, style }: { size?: number; dark?: boolean; style?: CSSProperties }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.225, display: 'grid', placeItems: 'center',
      background: dark ? '#000' : '#fff', boxShadow: `inset 0 0 0 ${Math.max(1, size / 96)}px ${dark ? '#222' : '#E2E9F3'}`, ...style,
    }}>
      <Mark size={size * 0.62} ink={dark ? '#fff' : '#000'} />
    </div>
  )
}

/** Renders a pixel grid from rows of characters, each mapped to a colour ('.' is empty). */
export function Pixels({ rows, palette, px = 8, className, style }: {
  rows: string[]; palette: Record<string, string>; px?: number; className?: string; style?: CSSProperties
}) {
  const w = Math.max(...rows.map((r) => r.length)), h = rows.length
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width={w * px} height={h * px} shapeRendering="crispEdges" className={className} style={{ maxWidth: '100%', height: 'auto', ...style }} aria-hidden>
      {rows.flatMap((r, y) => [...r].map((ch, x) => (ch === '.' || !palette[ch] ? null : <rect key={`${x}-${y}`} x={x} y={y} width={1.02} height={1.02} fill={palette[ch]} />)))}
    </svg>
  )
}
