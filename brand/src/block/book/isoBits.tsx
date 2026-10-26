import { IsoBlock, project, type Faces, type IsoCtx, type Material } from '../Iso'

/** The mark's eight cubes drawn inside a larger scene. Origin is the grid's back corner. */
export function MarkCubes({ ctx, x = 0, y = 0, z = 0, s = 1, rest = 'lilac', hot = 'orange', lift = 0.9, gap = 0.08, edge }: {
  ctx: IsoCtx; x?: number; y?: number; z?: number; s?: number; rest?: Material | Faces; hot?: Material | Faces; lift?: number; gap?: number; edge?: string
}) {
  const cells: [number, number, number][] = []
  for (let k = 0; k < 2; k++) for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) cells.push([i, j, k])
  cells.sort((a, b) => a[0] + a[1] + a[2] - (b[0] + b[1] + b[2]) || a[2] - b[2])
  const c = 1 - gap
  return (
    <g>
      {cells.map(([i, j, k]) => {
        const isHot = i === 1 && j === 1 && k === 1
        const L = isHot ? lift : 0
        return (
          <IsoBlock key={`${i}${j}${k}`} ctx={ctx}
            x={x + (i + gap / 2 + L * 0.42) * s} y={y + (j + gap / 2 + L * 0.42) * s} z={z + (k + L * 0.62) * s}
            w={c * s} d={c * s} h={c * s} material={isHot ? hot : rest} edge={edge} />
        )
      })}
    </g>
  )
}

/** An isometric triangular lattice: lines along x, along y, and verticals. */
export function IsoLattice({ ctx, n = 6, stroke = 'rgba(14,14,16,.14)', z = 0, verticals = true, width = 0.75 }: {
  ctx: IsoCtx; n?: number; stroke?: string; z?: number; verticals?: boolean; width?: number
}) {
  const u = ctx.unit
  const P = (a: number, b: number, c = z) => project(a, b, c, u)
  const lines: [number, number, number, number][] = []
  for (let i = -n; i <= n; i++) {
    const [a1, b1] = P(i, -n), [a2, b2] = P(i, n); lines.push([a1, b1, a2, b2])
    const [c1, d1] = P(-n, i), [c2, d2] = P(n, i); lines.push([c1, d1, c2, d2])
  }
  const verts: [number, number, number, number][] = []
  if (verticals) for (let i = -n; i <= n; i++) for (let j = -n; j <= n; j++) {
    if ((i + j) % 2 !== 0) continue
    const [a, b] = P(i, j), [, d] = P(i, j, z + 3); verts.push([a, b, a, d])
  }
  return (
    <g stroke={stroke} strokeWidth={width} fill="none">
      {lines.map(([a, b, c, d], i) => <line key={i} x1={a} y1={b} x2={c} y2={d} />)}
      {verts.map(([a, b, c, d], i) => <line key={`v${i}`} x1={a} y1={b} x2={c} y2={d} opacity={0.5} />)}
    </g>
  )
}

/** Outline of a box (all 9 visible edges), optionally dashed. */
export function IsoWire({ ctx, x = 0, y = 0, z = 0, w = 1, d = 1, h = 1, stroke = '#0E0E10', dash, width = 1.2 }: {
  ctx: IsoCtx; x?: number; y?: number; z?: number; w?: number; d?: number; h?: number; stroke?: string; dash?: string; width?: number
}) {
  const p = (a: number, b: number, c: number) => project(a, b, c, ctx.unit).map((n) => n.toFixed(2)).join(',')
  const T = [p(x, y, z + h), p(x + w, y, z + h), p(x + w, y + d, z + h), p(x, y + d, z + h)]
  const path = `M${T.join(' L')} Z M${p(x + w, y, z + h)} L${p(x + w, y, z)} L${p(x + w, y + d, z)} L${p(x, y + d, z)} L${p(x, y + d, z + h)} M${p(x + w, y + d, z + h)} L${p(x + w, y + d, z)}`
  return <path d={path} fill="none" stroke={stroke} strokeWidth={width} strokeDasharray={dash} strokeLinejoin="round" />
}

/** A screen-space point for annotations. */
export const pt = (ctx: IsoCtx, x: number, y: number, z: number) => project(x, y, z, ctx.unit)
