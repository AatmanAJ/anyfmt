/*
 * The hero's pixel landscape: the wheel rising like a sun (its hub is the sun's yellow core, one wedge
 * lit orange) over rolling hills, with a village of file icons on the slopes. Generated, not hand-drawn,
 * so it can be any width. Characters map to the palette below; '.' is sky (the mist shows through).
 */
export const SCENE_PALETTE: Record<string, string> = {
  k: '#000000', // ink
  g: '#2FB36B', // hill green
  y: '#FFD23F', // sun yellow
  o: '#FF4500', // the lit wedge, file badges
  w: '#FFFFFF', // file paper, clouds
}

export const SCENE_W = 260
export const SCENE_H = 72
/** The sun's centre, in cells. The landing aligns the window mockup against these. */
export const SUN = { x: 80, y: 47 }

const TAU = Math.PI * 2

export function buildScene(): string[] {
  const W = SCENE_W, H = SCENE_H
  const g: string[][] = Array.from({ length: H }, () => Array(W).fill('.'))
  const set = (x: number, y: number, c: string) => { if (x >= 0 && x < W && y >= 0 && y < H) g[y][x] = c }

  // Clouds: flat white pixel slabs.
  const cloud = (x: number, y: number, w: number) => {
    for (let i = 0; i < w; i++) set(x + i, y, 'w')
    for (let i = 2; i < w - 3; i++) set(x + i, y - 1, 'w')
    for (let i = 4; i < w - 7; i++) set(x + i, y - 2, 'w')
  }
  cloud(14, 14, 16); cloud(132, 9, 22); cloud(200, 20, 14); cloud(46, 6, 10); cloud(232, 8, 12)

  // Rays: short yellow dashes around the wheel, every 15 degrees.
  for (let k = 0; k < 24; k++) {
    const a = (k / 24) * TAU
    const len = k % 2 ? 2 : 4
    for (let r = 35; r < 35 + len; r++) set(Math.round(SUN.x + r * Math.sin(a)), Math.round(SUN.y - r * Math.cos(a) * 0.98), 'y')
  }

  // The wheel-sun: six wedges with gaps, a yellow hub, wedge 1 lit orange.
  const r0 = 12.5, r1 = 31, hubR = 10
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dx = x - SUN.x, dy = y - SUN.y, d = Math.hypot(dx, dy)
    if (d <= hubR) { set(x, y, 'y'); continue }
    if (d <= hubR + 1.2) continue
    if (d < r0 || d > r1) continue
    let a = Math.atan2(dx, -dy) + Math.PI / 6
    a = ((a % TAU) + TAU) % TAU
    const span = TAU / 6, into = a % span
    if (Math.min(into, span - into) * d < 1.6) continue
    set(x, y, Math.floor(a / span) === 1 ? 'o' : 'k')
  }

  // Hills: a far ridge in solid green with a black crest, a near ridge dithered toward black.
  const far = (x: number) => Math.round(50 + 4 * Math.sin(x / 15) + 2 * Math.sin(x / 6.5 + 1))
  const near = (x: number) => Math.round(59 + 3 * Math.sin(x / 10 + 2) + 1.5 * Math.sin(x / 4.3))
  for (let x = 0; x < W; x++) {
    const f = far(x), n = near(x)
    for (let y = f; y < H; y++) set(x, y, y === f ? 'k' : 'g')
    for (let y = n; y < H; y++) {
      const depth = y - n
      const c = depth === 0 ? 'k' : depth < 3 ? ((x + y) % 2 ? 'g' : 'k') : depth < 5 ? ((x + y) % 4 === 0 ? 'g' : 'k') : 'k'
      set(x, y, c)
    }
  }

  // File icons standing on the slopes, like houses. 9 x 11 cells, folded corner, a badge stripe.
  const file = (x: number, base: number, badge: string, tall = 11) => {
    const top = base - tall
    for (let yy = 0; yy < tall; yy++) for (let xx = 0; xx < 9; xx++) {
      const corner = xx >= 6 && yy <= xx - 6 // the folded-off corner
      if (corner) continue
      const edge = xx === 0 || xx === 8 || yy === tall - 1 || yy === 0 || (xx - 6 === yy - 0 && xx >= 6)
      let c = edge ? 'k' : 'w'
      if (xx === 6 && yy >= 0 && yy <= 2) c = 'k'
      if (yy === 2 && xx >= 6) c = 'k'
      if (!edge && yy >= tall - 4 && yy <= tall - 3 && xx >= 1 && xx <= 5) c = badge
      if (!edge && (yy === 4 || yy === 6) && xx >= 2 && xx <= (yy === 6 ? 4 : 6)) c = 'k'
      set(x + xx, top + yy, c)
    }
  }
  const onFar = (x: number, badge: string) => file(x, Math.min(...[0, 1, 2, 3, 4, 5, 6, 7, 8].map((i) => far(x + i))) + 1, badge)
  const onNear = (x: number, badge: string) => file(x, Math.min(...[0, 1, 2, 3, 4, 5, 6, 7, 8].map((i) => near(x + i))) + 1, badge, 12)
  onFar(28, 'o'); onFar(118, 'y'); onFar(156, 'k'); onFar(184, 'o'); onFar(214, 'y'); onFar(4, 'k'); onFar(244, 'k')
  onNear(50, 'k'); onNear(104, 'o'); onNear(140, 'y'); onNear(198, 'k'); onNear(232, 'o'); onNear(14, 'y')

  return g.map((r) => r.join(''))
}
