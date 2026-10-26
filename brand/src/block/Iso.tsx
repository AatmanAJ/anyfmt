import { useId, type ReactNode, type SVGProps } from 'react'

/*
 * Isometric drawing kit. World units: x runs down-right, y runs down-left, z runs up.
 * Screen: sx = (x − y)·cos30, sy = (x + y)·sin30 − z, scaled by `unit` px.
 */
export const COS = Math.cos(Math.PI / 6)
export const SIN = 0.5

export type Faces = { top: string; left: string; right: string }

/** Named materials. Stripes follow each face's plane. */
export const MATERIALS = {
  orange: { top: '#FF8F4D', left: '#FF6B1A', right: '#D9500A' },
  ink: { top: '#3A3A42', left: '#1C1C21', right: '#0E0E10' },
  inkLight: { top: '#4A4A54', left: '#2C2C33', right: '#1C1C21' },
  wine: { top: '#7A2340', left: '#561629', right: '#3A0E1E' },
  lilac: { top: '#D6D3FF', left: '#B8B3FF', right: '#8E87F2' },
  pink: { top: '#FF85BD', left: '#FF4FA0', right: '#D62F7E' },
  cream: { top: '#FFFFFF', left: '#F4F1EC', right: '#DEDAD3' },
  stripePink: { top: 'stripe:pink:top', left: 'stripe:pink:left', right: 'stripe:pink:right' },
  stripeLilac: { top: 'stripe:lilac:top', left: 'stripe:lilac:left', right: 'stripe:lilac:right' },
  stripeOrange: { top: 'stripe:orange:top', left: 'stripe:orange:left', right: 'stripe:orange:right' },
} satisfies Record<string, Faces>
export type Material = keyof typeof MATERIALS

const STRIPES: Record<string, [string, string]> = {
  pink: ['#FF4FA0', '#561629'],
  lilac: ['#B8B3FF', '#2C2C33'],
  orange: ['#FF6B1A', '#561629'],
}
// Plane transforms so stripes lie on each face.
const PLANE: Record<string, string> = {
  top: `matrix(${COS},${SIN},${-COS},${SIN},0,0)`,
  left: `matrix(${COS},${SIN},0,1,0,0)`,
  right: `matrix(${COS},${-SIN},0,1,0,0)`,
}

export function project(x: number, y: number, z: number, unit: number): [number, number] {
  return [(x - y) * COS * unit, (x + y) * SIN * unit - z * unit]
}

type SceneProps = {
  width: number
  height: number
  /** Screen position of the world origin, as a fraction of width/height. */
  anchor?: [number, number]
  unit?: number
  children: (ctx: IsoCtx) => ReactNode
  className?: string
  title?: string
} & Omit<SVGProps<SVGSVGElement>, 'children'>

export type IsoCtx = { unit: number; fill: (spec: string) => string; id: string }

/** An SVG canvas with stripe patterns defined. Draw blocks back to front. */
export function IsoScene({ width, height, anchor = [0.5, 0.62], unit = 40, children, className, title, ...rest }: SceneProps) {
  const id = useId().replace(/:/g, '')
  const fill = (spec: string) => {
    if (!spec.startsWith('stripe:')) return spec
    const [, name, face] = spec.split(':')
    return `url(#${id}-${name}-${face})`
  }
  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" className={className} role={title ? 'img' : undefined} aria-label={title} aria-hidden={title ? undefined : true} style={{ overflow: 'visible', maxWidth: width }} {...rest}>
      <defs>
        {Object.entries(STRIPES).flatMap(([name, [a, b]]) =>
          Object.entries(PLANE).map(([face, m]) => (
            <pattern key={`${name}-${face}`} id={`${id}-${name}-${face}`} patternUnits="userSpaceOnUse" width={unit * 0.5} height={unit * 0.5}
                     patternTransform={`${m} rotate(45)`}>
              <rect width={unit * 0.5} height={unit * 0.5} fill={b} />
              <rect width={unit * 0.25} height={unit * 0.5} fill={a} />
            </pattern>
          )),
        )}
      </defs>
      <g transform={`translate(${width * anchor[0]} ${height * anchor[1]})`}>{children({ unit, fill, id })}</g>
    </svg>
  )
}

type BlockProps = {
  ctx: IsoCtx
  x?: number; y?: number; z?: number
  w?: number; d?: number; h?: number
  material?: Material | Faces
  /** Hairline edges on the faces (looks crisp on dark grounds). */
  edge?: string
  children?: ReactNode
}

/** A box from (x,y,z) with size w×d×h. Only the three visible faces are drawn. */
export function IsoBlock({ ctx, x = 0, y = 0, z = 0, w = 1, d = 1, h = 1, material = 'orange', edge, children }: BlockProps) {
  const f: Faces = typeof material === 'string' ? MATERIALS[material] : material
  const u = ctx.unit
  const p = (a: number, b: number, c: number) => project(a, b, c, u).map((n) => n.toFixed(2)).join(',')
  const top = `M${p(x, y, z + h)} L${p(x + w, y, z + h)} L${p(x + w, y + d, z + h)} L${p(x, y + d, z + h)} Z`
  // Left face: the y+d side (faces down-left). Right face: the x+w side (faces down-right).
  const left = `M${p(x, y + d, z + h)} L${p(x + w, y + d, z + h)} L${p(x + w, y + d, z)} L${p(x, y + d, z)} Z`
  const right = `M${p(x + w, y, z + h)} L${p(x + w, y + d, z + h)} L${p(x + w, y + d, z)} L${p(x + w, y, z)} Z`
  const stroke = edge ? { stroke: edge, strokeWidth: 1, strokeLinejoin: 'round' as const } : {}
  return (
    <g>
      <path d={left} fill={ctx.fill(f.left)} {...stroke} />
      <path d={right} fill={ctx.fill(f.right)} {...stroke} />
      <path d={top} fill={ctx.fill(f.top)} {...stroke} />
      {children}
    </g>
  )
}

/** Puts children (drawn in a flat 0..1 square, units = `size`) onto the top face of a block. */
export function IsoTop({ ctx, x = 0, y = 0, z = 0, size = 1, children }: { ctx: IsoCtx; x?: number; y?: number; z?: number; size?: number; children: ReactNode }) {
  const [ox, oy] = project(x, y, z, ctx.unit)
  const s = ctx.unit
  return <g transform={`translate(${ox} ${oy}) matrix(${COS * s / 100},${SIN * s / 100},${-COS * s / 100},${SIN * s / 100},0,0) scale(${size})`}>{children}</g>
}

/** Text on the right (x+w) face. It reads toward −y, so pass the face's front edge (y + d) as `y`. */
export function IsoRightText({ ctx, x, y, z, children, size = 14, fill = '#0E0E10', weight = 650 }: { ctx: IsoCtx; x: number; y: number; z: number; children: ReactNode; size?: number; fill?: string; weight?: number }) {
  const [ox, oy] = project(x, y, z, ctx.unit)
  return (
    <text transform={`translate(${ox} ${oy}) matrix(${COS},${-SIN},0,1,0,0)`} fontSize={size} fontWeight={weight} fill={fill}
          style={{ fontFamily: '"Funnel Display Variable", sans-serif', letterSpacing: '-0.03em' }}>{children}</text>
  )
}

/** Text on the left (y+d) face, reading left to right along x. */
export function IsoLeftText({ ctx, x, y, z, children, size = 14, fill = '#0E0E10', weight = 650 }: { ctx: IsoCtx; x: number; y: number; z: number; children: ReactNode; size?: number; fill?: string; weight?: number }) {
  const [ox, oy] = project(x, y, z, ctx.unit)
  return (
    <text transform={`translate(${ox} ${oy}) matrix(${COS},${SIN},0,1,0,0)`} fontSize={size} fontWeight={weight} fill={fill}
          style={{ fontFamily: '"Funnel Display Variable", sans-serif', letterSpacing: '-0.03em' }}>{children}</text>
  )
}

/** A chunky isometric keycap with a legend on top. */
export function IsoKeycap({ ctx, x = 0, y = 0, z = 0, legend, sub, material = 'cream', pressed, ink = '#0E0E10' }: {
  ctx: IsoCtx; x?: number; y?: number; z?: number; legend: string; sub?: string; material?: Material; pressed?: boolean; ink?: string
}) {
  const h = pressed ? 0.28 : 0.5
  return (
    <g>
      <IsoBlock ctx={ctx} x={x} y={y} z={z} w={1} d={1} h={0.18} material="ink" />
      <IsoBlock ctx={ctx} x={x + 0.06} y={y + 0.06} z={z + 0.18} w={0.88} d={0.88} h={h - 0.18} material={material} />
      <IsoTop ctx={ctx} x={x + 0.06} y={y + 0.06} z={z + h} size={0.88}>
        <text x="16" y="52" fontSize="40" fontWeight="700" fill={ink} style={{ fontFamily: '"Funnel Display Variable", sans-serif' }}>{legend}</text>
        {sub && <text x="16" y="84" fontSize="15" fontWeight="600" fill={ink} opacity=".6" style={{ fontFamily: '"JetBrains Mono Variable", monospace' }}>{sub}</text>}
      </IsoTop>
    </g>
  )
}
