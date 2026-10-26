import { motion, useReducedMotion } from 'motion/react'
import { ChevronRight, Pin, X } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { CobaltWheel, Hub } from './CobaltWheel'
import { MenuGlyph, Mark } from './Logo'
import { C } from './tokens'
import { CobaltFile, Eyebrow, KeyCap, actionSegs, convertSegs, toolSegs } from './ui'

/** Midnight glass panel used by every app surface. */
export function Glass({ children, className, style, radius = 22 }: { children: ReactNode; className?: string; style?: React.CSSProperties; radius?: number }) {
  return (
    <div className={cn('relative font-geist backdrop-blur-2xl', className)}
         style={{
           borderRadius: radius, color: C.ice,
           background: 'linear-gradient(180deg, rgba(19,35,143,.78) 0%, rgba(5,10,46,.94) 46%)',
           boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14), inset 0 1px 0 rgba(233,238,255,.22), 0 30px 70px -20px rgba(2,5,22,.85)',
           ...style,
         }}>
      {children}
    </div>
  )
}

export function WheelTrio({ size = 320 }: { size?: number }) {
  const items = [
    { k: '⇧', name: 'shift', title: 'CONVERT', segs: convertSegs, hover: 0, hub: <Hub top="MOV" bottom="clip.mov" size={size} /> },
    { k: '⌘', name: 'command', title: 'TOOLS', segs: toolSegs, hover: 1, hub: <Hub top="MOV" bottom="8 tools" size={size} /> },
    { k: '⌃', name: 'control', title: 'ACTIONS', segs: actionSegs, hover: 1, hub: <Hub top="MOV" bottom="6 actions" size={size} /> },
  ]
  return (
    <div className="grid gap-10 lg:grid-cols-3">
      {items.map((it) => (
        <div key={it.title} className="flex flex-col items-center gap-6">
          <CobaltWheel segments={it.segs} size={size} hoverIndex={it.hover} hubLabel={it.hub} interactive />
          <div className="flex items-center gap-3">
            <KeyCap sym={it.k} name={it.name} size="sm" />
            <span className="font-anton text-[28px] leading-none tracking-[0.01em]" style={{ color: C.ice }}>{it.title}</span>
          </div>
        </div>
      ))}
    </div>
  )
}

const FPS = [
  { v: '10', size: '1.1 MB' }, { v: '15', size: '1.6 MB' }, { v: '24', size: '2.5 MB' }, { v: '30', size: '3.1 MB' },
]
const WIDTHS = [{ v: '480', size: '≈ 0.8 MB' }, { v: '720', size: '≈ 1.6 MB' }, { v: '1080', size: '≈ 3.4 MB' }]

function Chip({ on, label, sub, onClick }: { on: boolean; label: string; sub?: string; onClick?: () => void }) {
  return (
    <button type="button" onClick={onClick}
      className="relative flex min-w-0 flex-1 flex-col items-start gap-1 rounded-[12px] px-3 py-2 text-left transition-[background,box-shadow] duration-150"
      style={on
        ? { background: C.ice, color: C.midnight, boxShadow: `inset 0 0 0 2px ${C.flame}` }
        : { background: 'rgba(31,59,255,.22)', color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14)' }}>
      <span className="font-anton text-[20px] leading-none">{label}</span>
      {sub && <span className="whitespace-nowrap font-mono text-[9px] font-semibold opacity-80 sm:text-[10px]">{sub}</span>}
    </button>
  )
}

export function OptionsPanel() {
  const [fps, setFps] = useState(1)
  const [w, setW] = useState(1)
  return (
    <Glass className="w-full max-w-[400px] p-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <span className="font-anton text-[22px] leading-none">MOV <span style={{ color: C.flame }}>→</span> GIF</span>
        </div>
        <span className="rounded-full px-2 py-1 font-mono text-[10px] uppercase tracking-[0.14em]" style={{ background: 'rgba(233,238,255,.08)' }}>clip.mov · 0:08</span>
      </div>
      <div className="mt-4">
        <Eyebrow className="mb-2 opacity-60">Frame rate · fps</Eyebrow>
        <div className="flex gap-1.5">
          {FPS.map((f, i) => <Chip key={f.v} on={fps === i} label={f.v} sub={`≈ ${f.size}`} onClick={() => setFps(i)} />)}
        </div>
      </div>
      <div className="mt-3">
        <Eyebrow className="mb-2 opacity-60">Width · px</Eyebrow>
        <div className="flex gap-1.5">
          {WIDTHS.map((f, i) => <Chip key={f.v} on={w === i} label={f.v} sub={f.size} onClick={() => setW(i)} />)}
        </div>
      </div>
      <div className="mt-4 flex items-center justify-between gap-3 border-t pt-3" style={{ borderColor: 'rgba(233,238,255,.12)' }}>
        <div className="font-mono text-[11px] opacity-70">Estimate <span className="font-semibold" style={{ color: C.ice }}>{FPS[fps].size}</span> · refining</div>
        <div className="flex items-center gap-2">
          <span className="font-mono text-[10px] opacity-50">Save as preset</span>
          <span className="rounded-full px-4 py-2 font-anton text-[15px] leading-none tracking-[0.04em]" style={{ background: C.flame, color: C.midnight }}>CONVERT</span>
        </div>
      </div>
    </Glass>
  )
}

/** Speedometer gauge: 270° arc, ticks, a needle. */
export function Gauge({ value, size = 56 }: { value: number; size?: number }) {
  const r = size / 2 - 5, c = size / 2
  const start = -135, sweep = 270
  const pt = (deg: number, rr: number) => {
    const a = (deg * Math.PI) / 180
    return [c + rr * Math.sin(a), c - rr * Math.cos(a)]
  }
  const arcPath = (d0: number, d1: number) => {
    const [x0, y0] = pt(d0, r), [x1, y1] = pt(d1, r)
    return `M${x0},${y0} A${r},${r} 0 ${d1 - d0 > 180 ? 1 : 0} 1 ${x1},${y1}`
  }
  const end = start + sweep * value
  const [nx, ny] = pt(end, r - 7)
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
      <path d={arcPath(start, start + sweep)} fill="none" stroke="rgba(233,238,255,.16)" strokeWidth="4" strokeLinecap="butt" />
      <path d={arcPath(start, Math.max(start + 0.1, end))} fill="none" stroke={C.flame} strokeWidth="4" style={{ filter: 'drop-shadow(0 0 4px rgba(255,106,43,.9))' }} />
      {Array.from({ length: 10 }).map((_, i) => {
        const d = start + (sweep / 9) * i
        const [x0, y0] = pt(d, r - 6), [x1, y1] = pt(d, r - 3)
        return <line key={i} x1={x0} y1={y0} x2={x1} y2={y1} stroke={C.ice} strokeOpacity=".5" strokeWidth="1" />
      })}
      <line x1={c} y1={c} x2={nx} y2={ny} stroke={C.ice} strokeWidth="2" strokeLinecap="round" />
      <circle cx={c} cy={c} r="3" fill={C.flame} />
    </svg>
  )
}

export function ProgressHUD({ value: fixed }: { value?: number }) {
  const reduce = useReducedMotion()
  const [v, setV] = useState(fixed ?? 0.64)
  useEffect(() => {
    if (fixed !== undefined || isShot || reduce) return
    const id = setInterval(() => setV((x) => (x >= 1 ? 0.05 : Math.min(1, x + 0.02))), 80)
    return () => clearInterval(id)
  }, [fixed, reduce])
  return (
    <div className="flex items-center gap-3 rounded-full py-1.5 pl-1.5 pr-2 font-geist backdrop-blur-2xl"
         style={{ background: 'rgba(5,10,46,.94)', color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14), 0 24px 50px -14px rgba(2,5,22,.85)' }}>
      <span className="relative grid place-items-center rounded-full" style={{ background: C.deep }}>
        <Gauge value={v} size={52} />
      </span>
      <div className="min-w-0">
        <div className="flex items-baseline gap-2">
          <span className="font-anton text-[22px] leading-none tabular-nums">{Math.round(v * 100)}<span className="text-[14px] opacity-60">%</span></span>
          <span className="font-mono text-[10px] uppercase tracking-[0.14em] opacity-60">MOV → GIF</span>
        </div>
        <div className="mt-1 max-w-[150px] truncate text-[12px] opacity-80">clip.mov</div>
      </div>
      <button type="button" aria-label="Cancel" className="ml-1 grid size-8 place-items-center rounded-full transition-colors hover:bg-white/15" style={{ background: 'rgba(233,238,255,.08)' }}>
        <X size={14} strokeWidth={2.6} />
      </button>
    </div>
  )
}

export function FloatShelf() {
  const files = [
    { ext: 'GIF', name: 'clip.gif' }, { ext: 'JPG', name: 'IMG_2041.jpg' }, { ext: 'PDF', name: 'brief.pdf' },
  ]
  return (
    <Glass className="w-[300px] max-w-full p-3" radius={26}>
      <div className="flex items-center justify-between px-1">
        <div className="flex items-center gap-2">
          <span className="font-anton text-[18px] leading-none">FLOAT</span>
          <span className="grid h-5 min-w-5 place-items-center rounded-full px-1 font-anton text-[12px] leading-none" style={{ background: C.flame, color: C.midnight }}>3</span>
        </div>
        <div className="flex items-center gap-1.5 opacity-60"><Pin size={13} /><X size={14} /></div>
      </div>
      <div className="mt-3 flex items-end justify-center gap-1 rounded-[18px] px-2 pb-3 pt-4" style={{ background: 'rgba(2,5,22,.55)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.08)' }}>
        {files.map((f, i) => (
          <motion.div key={f.name} whileHover={{ y: -6, rotate: 0 }} style={{ rotate: (i - 1) * 6 }} className="cursor-grab">
            <CobaltFile ext={f.ext} name={f.name} size={52} thumb={i === 0} />
          </motion.div>
        ))}
      </div>
      <div className="mt-2.5 flex items-center justify-between px-1 font-mono text-[10px] uppercase tracking-[0.14em] opacity-60">
        <span>Drag out to drop</span><span>⌃ Float</span>
      </div>
    </Glass>
  )
}

export function MenuBarMenu() {
  const rows: (null | { l: string; r?: string; hot?: boolean; chev?: boolean })[] = [
    { l: 'Open Float shelf', r: '3 files', hot: true }, { l: 'Presets', chev: true }, { l: 'Recent', chev: true }, null,
    { l: 'Practice the wheel' }, { l: 'Keys: ⇧ Convert  ⌘ Tools  ⌃ Actions' }, null,
    { l: 'Settings…', r: '⌘,' }, { l: 'Check for updates' }, { l: 'Quit Halo', r: '⌘Q' },
  ]
  return (
    <div className="w-full max-w-[340px] font-geist">
      {/* menu bar strip */}
      <div className="flex h-7 items-center justify-end gap-4 rounded-t-[10px] px-3 text-[12px] font-medium" style={{ background: 'rgba(10,14,40,.9)', color: C.ice }}>
        <span className="opacity-60">Wi-Fi</span>
        <span className="grid h-[22px] place-items-center rounded-[5px] px-1.5" style={{ background: 'rgba(233,238,255,.18)' }}><MenuGlyph size={16} color={C.ice} /></span>
        <span className="opacity-60">Mon 9:41</span>
      </div>
      <div className="ml-auto mr-6 mt-1 w-[272px] rounded-[12px] p-1.5 text-[13px] backdrop-blur-2xl"
           style={{ background: 'rgba(5,10,46,.94)', color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14), 0 24px 50px -14px rgba(2,5,22,.85)' }}>
        <div className="flex items-center gap-2.5 px-2.5 pb-2 pt-1.5">
          <Mark size={22} />
          <div>
            <div className="font-anton text-[15px] leading-none">HALO</div>
            <div className="mt-0.5 font-mono text-[9.5px] uppercase tracking-[0.14em] opacity-60">Local · ready</div>
          </div>
          <span className="ml-auto size-2 rounded-full" style={{ background: C.flame, boxShadow: '0 0 8px rgba(255,106,43,.9)' }} />
        </div>
        {rows.map((r, i) => r === null
          ? <div key={i} className="mx-2 my-1 h-px" style={{ background: 'rgba(233,238,255,.12)' }} />
          : (
            <div key={i} className="flex items-center justify-between rounded-[7px] px-2.5 py-[5px]"
                 style={r.hot ? { background: C.cobalt } : undefined}>
              <span className={cn(i === 5 && 'font-mono text-[11px] opacity-60')}>{r.l}</span>
              <span className="flex items-center gap-1 text-[12px] opacity-60">{r.r}{r.chev && <ChevronRight size={13} />}</span>
            </div>
          ))}
      </div>
    </div>
  )
}
