import { BatteryFull, Search, Settings, Wifi } from 'lucide-react'
import type { ReactNode } from 'react'
import { AppIcon } from '../Mark'
import { C, Caption, Scaled, Section, Sub, Tile } from './ui'

/** The 2D menu-bar template glyph: four squares, the top-right one stepped up and out. One colour only. */
export function Glyph({ size = 18, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill={color} aria-label="anyfmt" role="img" style={{ display: 'block' }}>
      <rect x="1" y="10.5" width="6.5" height="6.5" rx="1" />
      <rect x="9" y="10.5" width="6.5" height="6.5" rx="1" />
      <rect x="1" y="2.5" width="6.5" height="6.5" rx="1" />
      <rect x="10.5" y="1" width="6.5" height="6.5" rx="1" />
    </svg>
  )
}

function PixelGrid() {
  const s = 16, n = 18
  return (
    <svg viewBox={`0 0 ${n * s} ${n * s}`} width="100%" style={{ maxWidth: 360 }} aria-label="The 18px glyph on its pixel grid" role="img">
      <rect width={n * s} height={n * s} fill={C.cream} />
      <g transform={`scale(${s})`}>
        <rect x="1" y="10.5" width="6.5" height="6.5" rx="1" fill={C.ink} />
        <rect x="9" y="10.5" width="6.5" height="6.5" rx="1" fill={C.ink} />
        <rect x="1" y="2.5" width="6.5" height="6.5" rx="1" fill={C.ink} />
        <rect x="9" y="2.5" width="6.5" height="6.5" rx="1" fill="none" stroke={C.orange} strokeWidth={0.12} strokeDasharray=".3 .25" />
        <rect x="10.5" y="1" width="6.5" height="6.5" rx="1" fill={C.orange} />
      </g>
      <g stroke="rgba(14,14,16,.14)" strokeWidth={1}>
        {Array.from({ length: n + 1 }, (_, i) => <g key={i}><line x1={i * s} y1={0} x2={i * s} y2={n * s} /><line x1={0} y1={i * s} x2={n * s} y2={i * s} /></g>)}
      </g>
    </svg>
  )
}

function MenuBar({ dark, size }: { dark: boolean; size: number }) {
  const fg = dark ? '#FFFFFF' : '#0E0E10'
  return (
    <div className="flex h-[30px] items-center justify-end gap-[14px] rounded-[6px] px-3 text-[13px] font-[560]"
         style={{ background: dark ? '#242428' : '#E9E6E0', color: fg }}>
      <span className="grid place-items-center rounded-[4px] px-1 py-[3px]" style={{ background: dark ? 'rgba(255,255,255,.18)' : 'rgba(0,0,0,.1)' }}><Glyph size={size} /></span>
      <Wifi size={15} strokeWidth={2.2} />
      <BatteryFull size={18} strokeWidth={1.8} />
      <Search size={14} strokeWidth={2.4} />
      <span className="whitespace-nowrap">Mon 26 Oct 9:41</span>
    </div>
  )
}

/** Generic neighbour icons, drawn flat in CSS so nothing borrows anyone's real icon. */
function Neighbour({ kind, size = 64 }: { kind: 'folder' | 'chat' | 'notes' | 'cal' | 'gear' | 'term' | 'music'; size?: number }) {
  const r = size * 0.225
  const base = { width: size, height: size, borderRadius: r, position: 'relative' as const, overflow: 'hidden' as const, boxShadow: '0 4px 10px -4px rgba(0,0,0,.45)' }
  const k = size / 64
  const body: Record<string, ReactNode> = {
    folder: (<div style={{ ...base, background: '#5B8DEF' }}>
      <div style={{ position: 'absolute', left: 12 * k, top: 18 * k, width: 18 * k, height: 8 * k, borderRadius: 3 * k, background: '#DCE7FF' }} />
      <div style={{ position: 'absolute', left: 12 * k, top: 22 * k, width: 40 * k, height: 26 * k, borderRadius: 4 * k, background: '#F4F7FF' }} /></div>),
    chat: (<div style={{ ...base, background: '#3FBF6A' }}>
      <div style={{ position: 'absolute', left: 13 * k, top: 15 * k, width: 38 * k, height: 28 * k, borderRadius: 14 * k, background: '#fff' }} />
      <div style={{ position: 'absolute', left: 16 * k, top: 38 * k, width: 10 * k, height: 10 * k, background: '#fff', transform: 'skewX(-30deg)' }} /></div>),
    notes: (<div style={{ ...base, background: '#FFFDF4' }}>
      <div style={{ position: 'absolute', inset: `0 0 auto 0`, height: 16 * k, background: '#F6C443' }} />
      {[26, 34, 42, 50].map((y) => <div key={y} style={{ position: 'absolute', left: 10 * k, right: 10 * k, top: y * k, height: 1.6 * k, background: '#D8D3C4' }} />)}</div>),
    cal: (<div style={{ ...base, background: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ fontSize: 10 * k, fontWeight: 700, color: '#E5484D', marginTop: 7 * k, letterSpacing: '.05em' }}>OCT</div>
      <div style={{ fontSize: 30 * k, fontWeight: 400, color: '#111', lineHeight: 1 }}>26</div></div>),
    gear: (<div style={{ ...base, background: '#8E8E96', display: 'grid', placeItems: 'center' }}><Settings size={40 * k} color="#2B2B30" strokeWidth={1.6} /></div>),
    term: (<div style={{ ...base, background: '#1E1E22', border: `${1.5 * k}px solid #3A3A42` }}>
      <span style={{ position: 'absolute', left: 10 * k, top: 10 * k, fontFamily: 'JetBrains Mono Variable, monospace', fontSize: 13 * k, color: '#E6E6E6', fontWeight: 700 }}>&gt;_</span></div>),
    music: (<div style={{ ...base, background: '#F2545B', display: 'grid', placeItems: 'center' }}>
      <div style={{ width: 26 * k, height: 26 * k, borderRadius: '50%', border: `${5 * k}px solid #fff` }} /></div>),
  }
  return <>{body[kind]}</>
}

export function IconSection() {
  const big = [[1024, 220], [512, 160], [256, 112]] as const
  const real = [128, 64, 32, 16]
  return (
    <Section id="icon" num="03" title="App icon" accent="." intro="An orange squircle carrying the mark in ink, with a cream core. On the menu bar it becomes a one-colour 2D glyph.">
      <Sub n="3.1">Sizes</Sub>
      <Tile bg={C.wine} label="1024 → 16, macOS squircle" fg={C.cream} className="px-5 pb-6 pt-14 md:px-8">
        <div className="flex flex-wrap items-end gap-x-8 gap-y-6">
          {big.map(([n, s]) => (
            <figure key={n} className="flex flex-col items-start gap-3">
              <div className="hidden md:block"><AppIcon size={s} /></div>
              <div className="md:hidden"><AppIcon size={Math.round(s * 0.55)} /></div>
              <figcaption className="bk-mono text-[11px] text-[#F4F1EC]/60">{n}px <span className="opacity-60">· shown {Math.round(s / n * 100)}%</span></figcaption>
            </figure>
          ))}
          {real.map((n) => (
            <figure key={n} className="flex flex-col items-start gap-3">
              <AppIcon size={n} />
              <figcaption className="bk-mono text-[11px] text-[#F4F1EC]/60">{n}px</figcaption>
            </figure>
          ))}
        </div>
      </Tile>
      <Caption label="Built from the mark">
        Squircle at 22.5% corner radius, orange with a one-step top light. The mark sits at 66% of the tile so the lifted core never
        touches the edge. Below 32px, the resting cubes merge into one ink shape and the cream core carries the read.
      </Caption>

      <Sub n="3.2">Menu-bar glyph</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.cream} fg={C.ink} label="18px template on its pixel grid" className="grid place-items-center p-8 pt-14 md:col-span-5">
          <PixelGrid />
          <p className="bk-mono mt-4 text-center text-[11px] leading-[1.6] opacity-70">Four squares, 1.5px gaps. The top-right one steps up and out by 1.5px.</p>
        </Tile>
        <Tile bg={C.ink2} label="In the bar" fg={C.cream} className="flex flex-col justify-center gap-5 p-5 pt-14 md:col-span-7 md:p-8 md:pt-14">
          {[16, 18, 22].map((s) => (
            <div key={s} className="grid gap-2 md:grid-cols-[52px_1fr_1fr] md:items-center">
              <span className="bk-mono text-[11px] text-[#8A8790]">{s}px</span>
              <MenuBar dark={false} size={s} />
              <MenuBar dark size={s} />
            </div>
          ))}
          <div className="flex items-center gap-6 pt-2">
            {[16, 18, 22].map((s) => <div key={s} className="grid size-14 place-items-center rounded-[6px] bg-[#0E0E10] text-[#F4F1EC]"><Glyph size={s} /></div>)}
            {[16, 18, 22].map((s) => <div key={s} className="grid size-14 place-items-center rounded-[6px] bg-[#F4F1EC] text-[#0E0E10]"><Glyph size={s} /></div>)}
          </div>
        </Tile>
      </div>
      <Caption label="A template image">
        The menu bar wants one colour with alpha, so the isometric mark flattens to a front view. The lift becomes a 1.5px step up and to
        the right. Ship it as a template PDF so macOS tints it for light, dark and highlighted states.
      </Caption>

      <Sub n="3.3">In the Dock</Sub>
      <Tile bg={C.lilac} className="relative overflow-hidden">
        <div className="absolute inset-0 grid grid-cols-6 grid-rows-3 gap-0 opacity-90" aria-hidden>
          {[C.lilac, C.lilacLo, C.lilac, C.wine2, C.lilac, C.lilacLo, C.lilacLo, C.lilac, C.wine, C.lilac, C.lilacLo, C.lilac, C.lilac, C.wine2, C.lilac, C.lilacLo, C.lilac, C.wine].map((c, i) => <div key={i} style={{ background: c }} />)}
        </div>
        <div className="relative px-3 pb-6 pt-40 md:pt-64">
          <Scaled w={760} h={128} max={1}>
            <div className="mx-auto flex w-[760px] items-end justify-center">
              <div className="flex items-end gap-3 rounded-[24px] border border-white/40 bg-white/35 px-3 pb-2.5 pt-3 backdrop-blur-md">
                {(['folder', 'chat', 'notes', 'cal'] as const).map((k) => <Neighbour key={k} kind={k} />)}
                <div className="flex flex-col items-center gap-1">
                  <div className="bk-mono mb-1 rounded-[5px] bg-[#0E0E10]/85 px-2 py-1 text-[11px] text-[#F4F1EC]">anyfmt</div>
                  <div className="-translate-y-2"><AppIcon size={64} /></div>
                  <span className="-mt-1.5 size-1 rounded-full bg-[#0E0E10]" />
                </div>
                {(['music', 'gear', 'term'] as const).map((k) => <Neighbour key={k} kind={k} />)}
              </div>
            </div>
          </Scaled>
        </div>
      </Tile>
      <Caption label="Holds its own">
        Next to the usual blue folders and green bubbles, the orange squircle with a lifted cream cube is easy to find. Neighbour icons here
        are generic stand-ins drawn in CSS.
      </Caption>
    </Section>
  )
}
