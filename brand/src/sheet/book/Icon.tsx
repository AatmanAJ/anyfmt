import { Folder, Globe, NotebookPen, SquareTerminal, Mail, Music } from 'lucide-react'
import { Pixels } from '../Mark'
import { landscape, wheelArt } from './pixel'
import { Lbl, PX, Section, Sub } from './ui'

/** The app icon at a given point size, with the wheel grid chosen so every cell is a whole pixel. */
function Tile({ size, dark, shown }: { size: number; dark?: boolean; shown?: number }) {
  const d = shown ?? size
  // grid per size: big sizes use the 22 master; small sizes get their own hand-snapped grids.
  const n = size >= 64 ? 22 : size >= 32 ? 20 : 12
  const art = wheelArt(n, 1, 6, 0.27, dark ? 'w' : 'k', 'o')
  const inner = size < 64 ? (n / size) * d : d === size ? Math.floor((d * 0.66) / 22) * 22 : d * 0.62
  return (
    <div className="grid flex-none place-items-center" style={{
      width: d, height: d, borderRadius: d * 0.225, background: dark ? '#000' : '#fff',
      boxShadow: `inset 0 0 0 ${Math.max(1, d / 128)}px ${dark ? '#2A2A2A' : '#C5D3E8'}`,
    }}>
      <Pixels rows={art} palette={PX} px={inner / n} style={{ width: inner, height: inner }} />
    </div>
  )
}

const SIZES: [number, number][] = [[1024, 240], [512, 168], [256, 112], [128, 80], [64, 64], [32, 32], [16, 16]]

function MenuGlyph({ n, dark, zoom = 1 }: { n: number; dark?: boolean; zoom?: number }) {
  return <Pixels rows={wheelArt(n, 1, 6, 0.27, dark ? 'w' : 'k', '.')} palette={PX} px={zoom} style={{ width: n * zoom, height: n * zoom }} />
}

function MenuBar({ dark }: { dark?: boolean }) {
  return (
    <div className="flex h-[26px] items-center justify-end gap-4 rounded-[4px] px-3 text-[13px] font-[500]" style={{ background: dark ? '#1E1E1E' : '#EEF1F5', color: dark ? '#fff' : '#000' }}>
      <span className="opacity-80">Wi-Fi</span>
      <span className="grid size-[22px] place-items-center rounded-[4px]" style={{ background: dark ? 'rgba(255,255,255,.18)' : 'rgba(0,0,0,.1)' }}><MenuGlyph n={16} dark={dark} /></span>
      <span className="shb-num opacity-80">Mon 26 Oct 09:41</span>
    </div>
  )
}

/** Generic neighbours for the Dock: plain shapes, nobody’s real icon. */
function Neighbour({ i }: { i: number }) {
  const sets = [
    { bg: '#E2E9F3', fg: '#000', I: Folder }, { bg: '#fff', fg: '#000', I: Globe }, { bg: '#FFFDE6', fg: '#000', I: NotebookPen },
    { bg: '#111', fg: '#fff', I: SquareTerminal }, { bg: '#C4EDFF', fg: '#000', I: Mail }, { bg: '#F8FAFC', fg: '#000', I: Music },
  ]
  const s = sets[i % sets.length]
  return <div className="grid size-[56px] place-items-center rounded-[13px] md:size-[64px] md:rounded-[14px]" style={{ background: s.bg, color: s.fg, boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.12)' }}><s.I size={28} strokeWidth={1.5} /></div>
}

const WALL = landscape(140, 44, { cursor: false, files: true })

export function IconSection() {
  return (
    <Section id="icon" n={2} label="App icon" title={<>A white tile, <span className="sh-hl">one wedge</span> lit.</>}
      lede="Paper-white squircle, hairline edge, the pixel wheel in ink. A dark variant for dark Docks. The menu-bar glyph is a template: ink only, the lit wedge knocked out.">
      <Sub n="2.1" title="Light and dark, 1024 to 16" note="Large sizes scale the 22-cell master. 32 uses a 20-cell grid and 16 a 12-cell grid, so each cell is a whole pixel.">
        {[false, true].map((dark) => (
          <div key={String(dark)} className={`mb-4 overflow-x-auto rounded-[4px] p-6 md:p-8 ${dark ? 'bg-black' : 'bg-[var(--sh-lavender)]'}`}>
            <div className="flex min-w-max items-end gap-6 md:gap-8">
              {SIZES.map(([s, shown]) => (
                <div key={s} className="flex flex-col items-start gap-3">
                  <Tile size={s} shown={shown} dark={dark} />
                  <span className={`shb-lbl ${dark ? 'text-[#9A9794]' : 'text-[var(--sh-graphite)]'}`}>{s}{shown !== s ? ` · at ${Math.round((shown / s) * 100)}%` : ''}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </Sub>

      <Sub n="2.2" title="Menu-bar template glyph" note="macOS tints template images, so the glyph is pure ink with the lit wedge knocked out. Drawn per size, never scaled.">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-[4px] p-6 shb-hair">
            <div className="flex items-end gap-10">
              {[16, 18, 22].map((n) => (
                <div key={n} className="flex flex-col items-start gap-3">
                  <MenuGlyph n={n} zoom={6} />
                  <div className="flex items-center gap-3"><MenuGlyph n={n} /><Lbl>{n} px</Lbl></div>
                </div>
              ))}
            </div>
          </div>
          <div className="flex flex-col justify-center gap-4 rounded-[4px] bg-[var(--sh-slate)] p-6">
            <MenuBar /><MenuBar dark />
            <Lbl>In place · 16 px glyph in a 22 px hit area</Lbl>
          </div>
        </div>
      </Sub>

      <Sub n="2.3" title="In the Dock">
        <figure>
          <div className="relative overflow-hidden rounded-[4px] bg-[var(--sh-sky)] sh-dots">
            <Pixels rows={WALL} palette={PX} px={9} style={{ width: '100%', display: 'block', opacity: 0.95 }} />
            <div className="absolute inset-x-0 bottom-3 flex justify-center px-3 md:bottom-5">
              <div className="flex items-end gap-2 rounded-[20px] px-2 pb-2 pt-2 md:gap-3 md:px-3" style={{ background: 'rgba(255,255,255,.62)', backdropFilter: 'blur(14px)', boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.14)' }}>
                {[0, 1, 2].map((i) => <div key={i} className={i === 2 ? 'hidden sm:block' : ''}><Neighbour i={i} /></div>)}
                <div className="relative flex flex-col items-center">
                  <span className="shb-lbl absolute -top-9 hidden whitespace-nowrap rounded-[4px] bg-black px-2 py-1 text-[11px] text-white md:block">anyfmt</span>
                  <div className="hidden md:block"><Tile size={64} /></div>
                  <div className="md:hidden"><Tile size={56} /></div>
                  <span className="absolute -bottom-[6px] size-[4px] rounded-full bg-black" />
                </div>
                {[3, 4, 5].map((i) => <div key={i} className={i === 5 ? 'hidden sm:block' : ''}><Neighbour i={i} /></div>)}
              </div>
            </div>
          </div>
          <figcaption className="mt-3"><Lbl>Fig. 3 · Neighbours are generic stand-ins, drawn in CSS</Lbl></figcaption>
        </figure>
      </Sub>
    </Section>
  )
}
