import type { ReactNode } from 'react'
import { Pixels } from '../Mark'
import { dragArt, fileArt, hubWheel, keyArt, landscape, shelfArt, wheelArt } from './pixel'
import { DoDont, Lbl, PX, Section, Sub } from './ui'

const FILES: [string, string, string][] = [['GIF', 'o', 'k'], ['PNG', 'y', 'k'], ['MP4', 'k', 'w'], ['PDF', 'o', 'k'], ['MP3', 'g', 'k'], ['WAV', 'y', 'k']]

function halftone(w: number, h: number) {
  const dots: ReactNode[] = []
  const s = 10
  for (let y = 0; y < h; y += s) for (let x = 0; x < w; x += s) {
    const t = x / w
    dots.push(<circle key={`${x}-${y}`} cx={x + s / 2} cy={y + s / 2} r={0.6 + t * 4.4 * (0.75 + 0.25 * Math.sin(y / 23))} fill="#000" />)
  }
  return dots
}

const EXAMPLES: { title: string; note: string; bg: string; art: string[]; px: number; dots?: boolean }[] = [
  { title: 'The wheel', note: '32-cell wheel, same rules as the mark', bg: 'var(--sh-sky)', art: hubWheel(32), px: 7, dots: true },
  { title: 'Sunrise', note: '96 × 40 scene: wheel, hills, files', bg: 'var(--sh-sky)', art: landscape(96, 40, { cursor: false, files: true }), px: 6, dots: true },
  { title: 'Mid-drag', note: 'Pointer, file, the wheel opening', bg: 'var(--sh-lavender)', art: dragArt(), px: 5 },
  { title: 'Shift', note: 'The key that opens Convert', bg: 'var(--sh-cream)', art: keyArt(), px: 9 },
  { title: 'Float shelf', note: 'Files waiting between drags', bg: 'var(--sh-slate)', art: shelfArt(), px: 5 },
]

export function Imagery() {
  return (
    <Section id="imagery" n={6} label="Imagery" title={<>Files are data, so <span className="sh-hl">we draw in pixels.</span></>}
      lede="No photos and no 3D. Illustrations are pixel art in eight inks, on a pale tint, often over halftone dots. The terminal caret is the only thing that moves on its own.">
      <Sub n="6.1" title="Grids" note="Art is drawn at 1× and scaled by whole numbers only. A cell is never anti-aliased and never rotated.">
        <div className="grid gap-4 md:grid-cols-3">
          {[
            ['Sprite', '17 × 21 cells', 'Files, keys, small objects. Shown at 4×–8×.', <Pixels key="a" rows={fileArt('GIF', 'o')} palette={PX} px={6} />],
            ['Mark and wheel', '22 or 32 cells', 'The wheel at any size uses the mark’s maths.', <Pixels key="b" rows={wheelArt(22)} palette={PX} px={5} />],
            ['Scene', '64–140 cells wide', 'Heroes and covers. Shown at 5×–10×.', <Pixels key="c" rows={landscape(40, 22, { cursor: false, files: false })} palette={PX} px={4} />],
          ].map(([t, g, d, el], i) => (
            <div key={i} className="rounded-[4px] p-5 shb-hair">
              <div className="grid h-[140px] place-items-center rounded-[4px] bg-[var(--sh-slate)]">{el}</div>
              <div className="mt-4 flex items-baseline justify-between"><span className="text-[15px] font-[600]">{t as string}</span><span className="shb-num text-[12px] text-[var(--sh-graphite)]">{g as string}</span></div>
              <p className="mt-1 text-[14px] text-[var(--sh-graphite)]">{d as string}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-12">
          <div className="overflow-x-auto rounded-[4px] bg-[var(--sh-sky)] p-5 md:col-span-7">
            <Lbl className="!text-black">Art is text · pixel.ts</Lbl>
            <pre className="sh-code mt-3 text-[12px] leading-[1.35] md:text-[13px]">{`// k ink · w paper · o signal · y yellow
// g green · G forest · m mist · s sky
fileArt('GIF', 'o') =>
${fileArt('GIF', 'o').slice(0, 9).map((r) => `  '${r}'`).join('\n')}
  …`}</pre>
          </div>
          <div className="grid grid-cols-4 gap-px overflow-hidden rounded-[4px] bg-[var(--shb-line)] md:col-span-5">
            {Object.entries({ k: PX.k, w: PX.w, o: PX.o, y: PX.y, g: PX.g, G: PX.G, m: PX.m, s: PX.s }).map(([ch, hex]) => (
              <div key={ch} className="flex flex-col items-start gap-2 bg-white p-3">
                <i className="block size-8" style={{ background: hex, boxShadow: hex === '#FFFFFF' ? 'inset 0 0 0 1px #D3D9E2' : undefined }} />
                <span className="shb-num text-[12px]">{ch} · {hex}</span>
              </div>
            ))}
          </div>
        </div>
      </Sub>

      <Sub n="6.2" title="Examples" note="Every piece is about the product: files, the wheel, the drag. Nothing decorative for its own sake.">
        <div className="rounded-[4px] bg-[var(--sh-lavender)] p-5 md:p-8">
          <div className="flex flex-wrap items-end justify-center gap-5 md:justify-between">
            {FILES.map(([e, b, k]) => <Pixels key={e} rows={fileArt(e, b, k)} palette={PX} px={6} />)}
          </div>
          <div className="mt-4 flex justify-between"><Lbl className="!text-black">File icons</Lbl><Lbl>17 × 21 · 3 × 5 pixel font · band in signal, yellow, green or ink</Lbl></div>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-3">
          {EXAMPLES.map((x, i) => (
            <figure key={x.title} className={i === 1 ? 'md:col-span-2' : ''}>
              <div className={`grid h-[260px] place-items-center overflow-hidden rounded-[4px] p-4 ${x.dots ? 'sh-dots' : ''}`} style={{ background: x.bg }}>
                <Pixels rows={x.art} palette={PX} px={x.px} style={{ maxHeight: 228, width: 'auto' }} />
              </div>
              <figcaption className="mt-3 flex justify-between gap-3"><span className="whitespace-nowrap text-[15px] font-[600]">{x.title}</span><Lbl className="text-right">{x.note}</Lbl></figcaption>
            </figure>
          ))}
        </div>
      </Sub>

      <Sub n="6.3" title="Halftone and the caret" note="Dots are texture, not information: 1 px dots on a 10 px grid at 14% ink. The caret blinks once a second and stops for reduced motion.">
        <div className="grid gap-4 md:grid-cols-3">
          <figure>
            <div className="sh-dots h-[200px] rounded-[4px] bg-[var(--sh-mist)]" />
            <figcaption className="mt-3"><Lbl>Wash · 10 px grid · 14%</Lbl></figcaption>
          </figure>
          <figure>
            <div className="h-[200px] overflow-hidden rounded-[4px] bg-[var(--sh-sky)]">
              <svg viewBox="0 0 360 200" preserveAspectRatio="xMidYMid slice" className="h-full w-full" aria-hidden>{halftone(360, 200)}</svg>
            </div>
            <figcaption className="mt-3"><Lbl>Ramp · for section breaks and covers</Lbl></figcaption>
          </figure>
          <figure>
            <div className="flex h-[200px] flex-col justify-between rounded-[4px] bg-[var(--sh-sky)] p-5">
              <Lbl className="!text-black">zsh · ~/Desktop</Lbl>
              <div className="sh-code text-[15px] leading-[1.7]">
                <div><span className="text-[var(--sh-graphite)]">$</span> anyfmt convert clip.mov --to gif</div>
                <div className="text-[var(--sh-graphite)]">✓ clip.gif · 3.8 MB · 1.9 s</div>
                <div><span className="text-[var(--sh-graphite)]">$</span> <span className="sh-caret" /></div>
              </div>
            </div>
            <figcaption className="mt-3"><Lbl>The caret · 0.55em block, steps(1)</Lbl></figcaption>
          </figure>
        </div>
        <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-4">
          <DoDont ok note="Whole-number scale, hard edges."><Pixels rows={fileArt('PNG', 'y')} palette={PX} px={5} /></DoDont>
          <DoDont ok={false} note="Smoothed or blurred pixels."><Pixels rows={fileArt('PNG', 'y')} palette={PX} px={5} style={{ filter: 'blur(1.2px)' }} /></DoDont>
          <DoDont ok={false} note="Photos, or 3D renders."><div className="h-[100px] w-[140px] rounded-[6px]" style={{ background: 'radial-gradient(circle at 35% 30%, #fff, #9aa6b8 45%, #3a4250)' }} /></DoDont>
          <DoDont ok={false} note="Colours from outside the eight."><Pixels rows={fileArt('PNG', 'y')} palette={{ ...PX, y: '#B26BFF', m: '#F5C2E7' }} px={5} /></DoDont>
        </div>
      </Sub>
    </Section>
  )
}
