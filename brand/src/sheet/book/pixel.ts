/*
 * The pixel-art system, as code. Every illustration is a grid of characters; each character is a palette
 * slot (see PX in ui.tsx). Generators keep the pieces consistent: same file silhouette, same 3×5 font,
 * same wheel geometry as the mark.
 */

type Grid = string[][]
const grid = (w: number, h: number, fill = '.'): Grid => Array.from({ length: h }, () => Array(w).fill(fill))
const rows = (g: Grid) => g.map((r) => r.join(''))
const put = (g: Grid, x: number, y: number, ch: string) => { if (y >= 0 && y < g.length && x >= 0 && x < g[0].length) g[y][x] = ch }
function stamp(g: Grid, art: string[], ox: number, oy: number) {
  art.forEach((r, y) => [...r].forEach((ch, x) => { if (ch !== '.') put(g, ox + x, oy + y, ch) }))
}

/** A 3×5 pixel font: just the letters our format names need. */
const FONT: Record<string, string[]> = {
  A: ['.k.', 'k.k', 'kkk', 'k.k', 'k.k'], B: ['kk.', 'k.k', 'kk.', 'k.k', 'kk.'], C: ['kkk', 'k..', 'k..', 'k..', 'kkk'],
  D: ['kk.', 'k.k', 'k.k', 'k.k', 'kk.'], E: ['kkk', 'k..', 'kk.', 'k..', 'kkk'], F: ['kkk', 'k..', 'kk.', 'k..', 'k..'],
  G: ['kkk', 'k..', 'k.k', 'k.k', 'kkk'], H: ['k.k', 'k.k', 'kkk', 'k.k', 'k.k'], I: ['kkk', '.k.', '.k.', '.k.', 'kkk'],
  J: ['..k', '..k', '..k', 'k.k', 'kkk'], M: ['k.k', 'kkk', 'kkk', 'k.k', 'k.k'], N: ['kk.', 'k.k', 'k.k', 'k.k', 'k.k'],
  O: ['kkk', 'k.k', 'k.k', 'k.k', 'kkk'], P: ['kkk', 'k.k', 'kkk', 'k..', 'k..'], V: ['k.k', 'k.k', 'k.k', 'k.k', '.k.'],
  W: ['k.k', 'k.k', 'kkk', 'kkk', 'k.k'], X: ['k.k', 'k.k', '.k.', 'k.k', 'k.k'], '3': ['kkk', '..k', '.kk', '..k', 'kkk'],
  '4': ['k.k', 'k.k', 'kkk', '..k', '..k'], Z: ['kkk', '..k', '.k.', 'k..', 'kkk'], T: ['kkk', '.k.', '.k.', '.k.', '.k.'],
}
function text(g: Grid, s: string, ox: number, oy: number, ch: string) {
  [...s].forEach((l, i) => (FONT[l] ?? []).forEach((r, y) => [...r].forEach((c, x) => { if (c === 'k') put(g, ox + i * 4 + x, oy + y, ch) })))
}

/** The file sprite: 17×21, folded corner, a coloured band with the extension in the pixel font. */
export function fileArt(ext: string, band = 'o', ink = 'k'): string[] {
  const W = 17, H = 21, F = 5, fx = W - 1 - F
  const g = grid(W, H)
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (y < F && x > fx + y) continue
    const edge = x === 0 || y === H - 1 || (y === 0 && x <= fx) || (x === W - 1 && y >= F) || (y < F && x === fx + y)
    if (edge) { g[y][x] = 'k'; continue }
    if (y <= F && x >= fx) g[y][x] = (x === fx || y === F) ? 'k' : 'm'
    else g[y][x] = 'w'
  }
  for (let y = 11; y <= 17; y++) for (let x = 1; x < W - 1; x++) g[y][x] = band
  const tw = ext.length * 4 - 1
  text(g, ext, Math.floor((W - tw) / 2), 12, ink)
  // two text lines above the band
  for (let x = 3; x < 10; x++) put(g, x, 6, 'm')
  for (let x = 3; x < 13; x++) put(g, x, 8, 'm')
  return rows(g)
}

/** The arrow pointer, 12×17. */
export const CURSOR = [
  'k...........', 'kk..........', 'kwk.........', 'kwwk........', 'kwwwk.......', 'kwwwwk......', 'kwwwwwk.....',
  'kwwwwwwk....', 'kwwwwwwwk...', 'kwwwwwwwwk..', 'kwwwwwkkkkk.', 'kwwkwwk.....', 'kwk.kwwk....', 'kk..kwwk....',
  'k....kwwk...', '.....kwwk...', '......kk....',
]

/** Wheel cells, same maths as the mark, at any grid size. */
export function wheelArt(n: number, hot: number | null = 1, wedges = 6, inner = 0.27, ink = 'k', accent = 'o', hub?: string): string[] {
  const g = grid(n, n)
  const c = (n - 1) / 2, r1 = n / 2 - 0.15, r0 = n * inner
  const span = (2 * Math.PI) / wedges
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const dx = x - c, dy = y - c, d = Math.hypot(dx, dy)
    if (hub && d < r0 - n * 0.06) { g[y][x] = hub; continue }
    if (d > r1 || d < r0) continue
    let a = Math.atan2(dx, -dy) + Math.PI / wedges
    a = ((a % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI)
    const into = a % span
    if (Math.min(into, span - into) * d < 0.85 * (n / 22) ** 0.5) continue
    g[y][x] = Math.floor(a / span) === hot ? accent : ink
  }
  return rows(g)
}

/** The cover scene: the wheel rising like a sun over green hills, file icons standing in the fields. */
export function landscape(W = 120, H = 60, opts: { cursor?: boolean; files?: boolean } = {}): string[] {
  const { cursor = true, files = true } = opts
  const g = grid(W, H)
  const hillA = (x: number) => Math.round(H * 0.64 + 3.2 * Math.sin(x / 9) + 2 * Math.sin(x / 4.1 + 2))
  const hillB = (x: number) => Math.round(H * 0.8 + 2.2 * Math.sin(x / 11 + 1.3) + 1.2 * Math.sin(x / 5.3))
  // Sun: the wheel, rising behind the far hills.
  let S = Math.round(Math.min(H * 0.74, W * 0.4)); if (S % 2) S++
  const sx = Math.round(W / 2 - S / 2), sy = Math.round(H * 0.1)
  stamp(g, wheelArt(S, 1, 6, 0.27), sx, sy)
  // Rays: short orange dashes around the sun's upper half.
  const cx = sx + S / 2 - 0.5, cy = sy + S / 2 - 0.5, rr = S / 2 + 2
  for (let i = -3; i <= 3; i++) {
    const a = (i / 3) * (Math.PI * 0.4)
    for (let t = 0; t < 3; t++) put(g, Math.round(cx + (rr + t) * Math.sin(a)), Math.round(cy - (rr + t) * Math.cos(a)), 'o')
  }
  // Clouds, kept clear of the sun.
  const cloud = ['..wwww....', '.wwwwwww..', 'wwwwwwwwww', '.kkkkkkkk.']
  const right = sx + S + 4
  if (W - right > 14) stamp(g, cloud, right + 2, Math.round(H * 0.12))
  if (sx > 16) stamp(g, ['.www..', 'wwwwww', '.kkkk.'], Math.max(2, sx - 12), Math.round(H * 0.08))
  // Far hills (forest), near hills (green) with a yellow field band, dithered edges.
  for (let x = 0; x < W; x++) {
    const h1 = hillA(x), h2 = hillB(x)
    for (let y = h1; y < H; y++) g[y][x] = 'G'
    if ((x + h1) % 2 === 0) put(g, x, h1 - 1, 'G')
    for (let y = h2; y < H; y++) {
      const dy = y - h2
      g[y][x] = dy === 0 ? 'k' : dy >= 3 && dy <= 4 ? 'y' : dy === 5 && x % 2 ? 'y' : 'g'
    }
  }
  if (files) {
    // Files standing in the field, two each side of the sun.
    const slots = [2, 21, W - 38, W - 19]
    const icons: [string, string, string][] = [['GIF', 'o', 'k'], ['PNG', 'y', 'k'], ['MP4', 'o', 'k'], ['PDF', 'y', 'k']]
    slots.forEach((x, i) => {
      const base = Math.min(hillB(x + 3), hillB(x + 13))
      stamp(g, fileArt(...icons[i]), x, base - 19)
    })
  }
  if (cursor) {
    // A pointer carrying a small file across the sky, top left, with a dotted trail.
    const mini = MINI
    const px = Math.round(W * 0.2), py = Math.round(H * 0.08)
    stamp(g, mini, px, py)
    stamp(g, CURSOR, px + 4, py + 4)
    for (let i = 1; i <= 5; i++) put(g, px - i * 3, py + 6 + i, 'k')
  }
  return rows(g)
}

/** A small file, 7×9, for wheel hubs and pointers. */
export const MINI = ['kkkkk..', 'kwwwkk.', 'kwwwkwk', 'kwwwwwk', 'koooook', 'koooook', 'kwwwwwk', 'kkkkkkk']

/** The wheel with a small file sitting in its hole. */
export function hubWheel(n = 32): string[] {
  const g = wheelArt(n).map((r) => [...r])
  const ox = Math.round(n / 2 - 3.5), oy = Math.round(n / 2 - 4)
  stamp(g, MINI, ox, oy)
  return rows(g)
}

/** Mid-drag: the wheel open around the pointer, the file in its hub, a dotted trail from where it came. */
export function dragArt(): string[] {
  const W = 66, H = 40, n = 34
  const g = grid(W, H)
  const wx = W - n - 2, wy = 2
  stamp(g, hubWheel(n), wx, wy)
  // pointer resting on the hub, aiming up-right at the lit wedge
  stamp(g, CURSOR, wx + n / 2 + 1, wy + n / 2 + 1)
  // an empty dotted slot where the file was, and the trail
  stamp(g, ['k.k.k.k', '.......', 'k.....k', '.......', 'k.....k', '.......', 'k.k.k.k'], 2, 30)
  for (let i = 1; i <= 7; i++) put(g, 10 + i * 3, 33 - Math.round(i * 1.6), 'k')
  return rows(g)
}

/** A keycap with a pixel Shift arrow. */
export function keyArt(): string[] {
  const g = grid(20, 20)
  for (let y = 0; y < 20; y++) for (let x = 0; x < 20; x++) {
    const edge = x === 0 || x === 19 || y === 0 || y >= 18
    const corner = (x === 0 || x === 19) && (y === 0 || y === 19)
    if (corner) continue
    g[y][x] = edge ? 'k' : y === 17 ? 'm' : 'w'
  }
  const arrow = ['....k....', '...kwk...', '..kwwwk..', '.kwwwwwk.', 'kkkwwwkkk', '..kwwwk..', '..kwwwk..', '..kkkkk..']
  stamp(g, arrow.map((r) => r.replace(/w/g, 'o')), 5, 4)
  return rows(g)
}

/** The Float shelf: a tray with three files waiting. */
export function shelfArt(): string[] {
  const g = grid(62, 26)
  stamp(g, fileArt('JPG', 'y', 'k'), 3, 0)
  stamp(g, fileArt('MP3', 'g', 'w'), 22, 0)
  stamp(g, fileArt('ZIP', 'o', 'w'), 41, 0)
  for (let x = 0; x < 62; x++) { put(g, x, 21, 'k'); for (let y = 22; y < 25; y++) put(g, x, y, x === 0 || x === 61 ? 'k' : 'm'); put(g, x, 25, 'k') }
  for (let x = 3; x < 59; x += 2) put(g, x, 23, 'w')
  return rows(g)
}
