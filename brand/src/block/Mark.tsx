import type { CSSProperties } from 'react'
import { IsoBlock, IsoScene, type Material } from './Iso'

/*
 * The mark: a 2×2×2 block of cubes, the front-top cube lifted out and lit.
 * The wheel's aimed wedge, said in blocks: everything else waits, one thing rises.
 */
type Variant = 'color' | 'mono' | 'reverse' | 'flat' | 'icon'

const CELLS: [number, number, number][] = []
for (let z = 0; z < 2; z++) for (let x = 0; x < 2; x++) for (let y = 0; y < 2; y++) CELLS.push([x, y, z])
// Painter's order: back to front, bottom to top.
CELLS.sort((a, b) => a[0] + a[1] + a[2] - (b[0] + b[1] + b[2]) || a[2] - b[2])

const GAP = 0.08
const LIFT = 0.9

export function Mark({ size = 40, variant = 'color', lifted = LIFT, className, style }: {
  size?: number; variant?: Variant; lifted?: number; className?: string; style?: CSSProperties
}) {
  const rest: Material | { top: string; left: string; right: string } =
    variant === 'reverse' ? 'cream'
      : variant === 'mono' ? { top: 'currentColor', left: 'currentColor', right: 'currentColor' }
        : (variant === 'flat' || variant === 'icon') ? { top: '#2C2C33', left: '#1C1C21', right: '#0E0E10' }
          : 'lilac'
  const hot: Material | { top: string; left: string; right: string } =
    variant === 'mono' ? { top: 'currentColor', left: 'currentColor', right: 'currentColor' } : variant === 'icon' ? 'cream' : 'orange'
  const s = 1 - GAP
  return (
    <span className={className} style={{ display: 'inline-block', width: size, height: size * 1.12, lineHeight: 0, ...style }}>
      <IsoScene width={100} height={112} anchor={[0.5, 0.62]} unit={22} title="anyfmt">
        {(ctx) => (
          <g transform="translate(0 -6)" opacity={variant === 'mono' ? 1 : undefined}>
            {CELLS.map(([x, y, z]) => {
              const isHot = x === 1 && y === 1 && z === 1
              return (
                <g key={`${x}${y}${z}`} style={variant === 'mono' ? { opacity: isHot ? 1 : 0.55 } : undefined}>
                  <IsoBlock ctx={ctx} x={x - 1 + GAP / 2 + (isHot ? lifted * 0.42 : 0)} y={y - 1 + GAP / 2 + (isHot ? lifted * 0.42 : 0)} z={z + (isHot ? lifted * 0.62 : 0)} w={s} d={s} h={s}
                            material={isHot ? hot : rest} />
                </g>
              )
            })}
          </g>
        )}
      </IsoScene>
    </span>
  )
}

/** Mark + the name. The name is lowercase Funnel Display, tracked tight. */
export function Wordmark({ size = 24, tone = 'cream', className }: { size?: number; tone?: 'cream' | 'ink'; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.32 }}>
      <Mark size={size * 1.25} variant={tone === 'cream' ? 'color' : 'color'} />
      <span className="bk-display" style={{ fontSize: size, fontWeight: 600, lineHeight: 1, color: tone === 'cream' ? 'var(--bk-cream)' : 'var(--bk-ink)' }}>anyfmt</span>
    </span>
  )
}

/** The macOS app icon: an orange squircle with the mark in ink and a lit cube. */
export function AppIcon({ size = 96, style }: { size?: number; style?: CSSProperties }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.225, display: 'grid', placeItems: 'center',
      background: 'linear-gradient(160deg, #FF8F4D 0%, #FF6B1A 55%, #D9500A 100%)',
      boxShadow: `inset 0 ${Math.max(1, size * 0.012)}px 0 rgba(255,255,255,.35), 0 ${size * 0.05}px ${size * 0.12}px -${size * 0.03}px rgba(58,14,30,.55)`,
      ...style,
    }}>
      <Mark size={size * 0.66} variant="icon" />
    </div>
  )
}
