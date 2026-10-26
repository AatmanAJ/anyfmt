import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { ChevronRight, Search, Wifi, X } from 'lucide-react'
import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'
import { Led, MenuGlyph } from './Mark'
import { DoneToast, SignalFile } from './SignalDemo'
import { FileHub, SignalWheel } from './SignalWheel'
import { C, vibrancy, wheels } from './tokens'
import { Label } from './ui'

/** A dark desktop to set glass on: graphite dot grid, one solar glow. */
export function Desktop({ children, className, style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[20px]', className)}
      style={{
        background: `radial-gradient(60% 50% at 75% 20%, rgba(215,255,58,.10), transparent 70%), radial-gradient(50% 60% at 10% 90%, rgba(120,120,130,.12), transparent 70%), linear-gradient(180deg, #0B0B0D, #060607)`,
        boxShadow: `inset 0 0 0 1px ${C.graphite}`,
        ...style,
      }}>
      <div className="pointer-events-none absolute inset-0 opacity-70" style={{ backgroundImage: 'radial-gradient(circle, rgba(237,237,230,.09) 1px, transparent 1.5px)', backgroundSize: '14px 14px' }} />
      <div className="relative">{children}</div>
    </div>
  )
}

/* ───────────────────────────── Options panel ───────────────────────────── */

const FPS = [10, 15, 24, 30] as const
const FPS_MB = { 10: 1.9, 15: 2.8, 24: 4.4, 30: 5.6 } as const
const WIDTHS = [480, 720, 1080] as const
const W_K = { 480: 0.48, 720: 1, 1080: 2.2 } as const

function Chip({ on, onClick, top, bottom, refining }: { on: boolean; onClick: () => void; top: string; bottom: string; refining?: boolean }) {
  return (
    <button type="button" onClick={onClick}
      className="relative flex min-w-0 flex-1 flex-col items-start gap-1.5 rounded-[9px] px-2.5 py-2 text-left outline-none transition-[background,box-shadow] duration-150 focus-visible:ring-2 focus-visible:ring-[#D7FF3A]"
      style={on
        ? { background: C.solar, color: C.void, boxShadow: '0 0 24px -8px rgba(215,255,58,.7)' }
        : { background: 'rgba(255,255,255,.045)', color: C.bone, boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,.1)' }}>
      <span className="font-geist text-[14px] font-semibold leading-none tabular-nums">{top}</span>
      <span className="flex items-center gap-1 font-mono text-[9.5px] leading-none tracking-[0.04em] tabular-nums" style={{ color: on ? 'rgba(5,5,6,.66)' : C.ash }}>
        {refining && <span className="inline-block size-1 rounded-full" style={{ background: on ? C.void : C.solar, opacity: 0.7 }} />}
        {bottom}
      </span>
    </button>
  )
}

export function OptionsPanel({ className }: { className?: string }) {
  const [fps, setFps] = useState<(typeof FPS)[number]>(15)
  const [w, setW] = useState<(typeof WIDTHS)[number]>(720)
  const [loop, setLoop] = useState(true)
  const [refining, setRefining] = useState(false)
  useEffect(() => {
    if (isShot) return
    setRefining(true)
    const t = setTimeout(() => setRefining(false), 650)
    return () => clearTimeout(t)
  }, [fps, w])
  const mb = (f: number, ww: number) => (FPS_MB[f as keyof typeof FPS_MB] * W_K[ww as keyof typeof W_K]).toFixed(1) + ' MB'
  return (
    <div className={cn('w-[312px] max-w-full rounded-[16px] p-3.5 font-geist', className)} style={{ ...vibrancy, color: C.bone }}>
      <div className="flex items-center justify-between px-0.5">
        <div className="flex items-center gap-2">
          <span className="rounded-[4px] px-1.5 py-[3px] font-mono text-[9px] font-bold leading-none tracking-[0.12em]" style={{ background: C.solar, color: C.void }}>GIF</span>
          <span className="text-[13px] font-medium">clip.mov</span>
          <span className="text-[12px]" style={{ color: C.ash }}>→ clip.gif</span>
        </div>
        <Label dim>⌥ opts</Label>
      </div>
      <div className="mt-3.5 h-px" style={{ background: 'rgba(255,255,255,.07)' }} />
      <div className="mt-3 flex items-center justify-between px-0.5"><Label>Frame rate</Label><Label dim>fps</Label></div>
      <div className="mt-2 flex gap-1.5">
        {FPS.map((f) => <Chip key={f} on={fps === f} onClick={() => setFps(f)} top={String(f)} bottom={mb(f, w)} refining={refining && fps !== f} />)}
      </div>
      <div className="mt-3.5 flex items-center justify-between px-0.5"><Label>Width</Label><Label dim>px</Label></div>
      <div className="mt-2 flex gap-1.5">
        {WIDTHS.map((ww) => <Chip key={ww} on={w === ww} onClick={() => setW(ww)} top={String(ww)} bottom={mb(fps, ww)} refining={refining && w !== ww} />)}
      </div>
      <button type="button" onClick={() => setLoop((v) => !v)} className="mt-3.5 flex w-full items-center justify-between rounded-[9px] px-2.5 py-2 text-left outline-none focus-visible:ring-2 focus-visible:ring-[#D7FF3A]" style={{ background: 'rgba(255,255,255,.035)' }}>
        <span className="text-[13px]">Loop forever</span>
        <span className="relative h-[18px] w-[30px] rounded-full transition-colors" style={{ background: loop ? C.solar : C.graphite2 }}>
          <motion.span className="absolute top-[2px] size-[14px] rounded-full" style={{ background: loop ? C.void : C.bone }} animate={{ left: loop ? 14 : 2 }} transition={{ type: 'spring', stiffness: 600, damping: 32 }} />
        </span>
      </button>
      <div className="mt-3.5 flex items-center justify-between gap-3 rounded-[10px] px-3 py-2.5" style={{ background: 'rgba(0,0,0,.35)', boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,.06)' }}>
        <div className="flex flex-col gap-1">
          <span className="font-mono text-[18px] font-medium leading-none tabular-nums" style={{ color: C.bone }}>≈ {mb(fps, w)}</span>
          <span className="flex items-center gap-1.5 font-mono text-[9.5px] uppercase tracking-[0.14em]" style={{ color: C.ash }}>
            <Led size={4} blink={refining} on /> {refining ? 'Refining' : 'Measured'}
          </span>
        </div>
        <span className="rounded-full px-3.5 py-2 font-mono text-[11px] font-semibold uppercase tracking-[0.14em]" style={{ background: C.solar, color: C.void }}>Convert ↵</span>
      </div>
    </div>
  )
}

/* ───────────────────────────── Progress HUD ───────────────────────────── */

export function ProgressHUD({ className, fixed }: { className?: string; fixed?: number }) {
  const reduce = useReducedMotion()
  const [p, setP] = useState(fixed ?? 0.62)
  useEffect(() => {
    if (isShot || reduce || fixed != null) return
    const id = setInterval(() => setP((v) => (v >= 1 ? 0 : Math.min(1, v + 0.012))), 60)
    return () => clearInterval(id)
  }, [reduce, fixed])
  const N = 24
  const lit = Math.round(p * N)
  const left = Math.max(0, (1 - p) * 2.9)
  return (
    <div className={cn('flex w-[340px] max-w-full items-center gap-3 rounded-full py-2 pl-2 pr-2.5 font-geist', className)} style={{ ...vibrancy, color: C.bone }}>
      <div className="relative grid size-11 shrink-0 place-items-center rounded-full" style={{ background: 'rgba(0,0,0,.4)' }}>
        <svg width="44" height="44" viewBox="0 0 44 44" className="absolute inset-0" aria-hidden>
          {Array.from({ length: N }, (_, i) => {
            const a = (i / N) * Math.PI * 2
            const on = i < lit
            return <circle key={i} cx={22 + 17 * Math.sin(a)} cy={22 - 17 * Math.cos(a)} r={on ? 1.6 : 1.2} fill={on ? C.solar : '#3A3A3F'} />
          })}
        </svg>
        <span className="font-mono text-[10px] font-semibold tabular-nums">{Math.round(p * 100)}</span>
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <span className="truncate text-[13px] font-medium">clip.mov <span style={{ color: C.ash }}>→</span> GIF</span>
        <span className="truncate font-mono text-[10px] uppercase tracking-[0.12em] tabular-nums" style={{ color: C.ash }}>
          {p >= 1 ? 'Done' : `Encoding · ${left.toFixed(1)} s left`}
        </span>
      </div>
      <button type="button" aria-label="Cancel" className="grid size-7 shrink-0 place-items-center rounded-full transition-colors hover:bg-white/15" style={{ background: 'rgba(255,255,255,.08)' }}>
        <X size={13} strokeWidth={2.4} />
      </button>
    </div>
  )
}

/* ───────────────────────────── Float shelf ───────────────────────────── */

export function FloatShelf({ className }: { className?: string }) {
  const files = [
    { ext: 'GIF', name: 'clip.gif' }, { ext: 'PDF', name: 'scan.pdf' }, { ext: 'JPG', name: 'IMG_2041.jpg' },
  ]
  return (
    <div className={cn('w-[300px] max-w-full rounded-[22px] p-3 font-geist', className)} style={{ ...vibrancy, color: C.bone }}>
      <div className="flex items-center justify-between px-1.5 pt-0.5">
        <div className="flex items-center gap-2"><Led size={5} /><Label style={{ color: C.bone }}>Float</Label><Label dim>3 held</Label></div>
        <button type="button" aria-label="Close shelf" className="grid size-5 place-items-center rounded-full" style={{ background: 'rgba(255,255,255,.08)' }}><X size={10} strokeWidth={2.6} /></button>
      </div>
      <div className="mt-3 grid grid-cols-3 gap-1.5 rounded-[16px] p-2.5" style={{ background: 'rgba(0,0,0,.32)', boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,.06)' }}>
        {files.map((f, i) => (
          <div key={f.name} className="group flex flex-col items-center gap-1.5 rounded-[10px] py-2 transition-colors hover:bg-white/[.06]" style={i === 0 ? { background: 'rgba(215,255,58,.08)', boxShadow: 'inset 0 0 0 1px rgba(215,255,58,.35)' } : undefined}>
            <SignalFile ext={f.ext} name="" size={40} lit={i === 0} />
            <span className="max-w-full truncate px-1 text-[10.5px]" style={{ color: i === 0 ? C.bone : C.ash }}>{f.name}</span>
          </div>
        ))}
      </div>
      <div className="mt-2.5 flex items-center justify-between px-1.5 pb-0.5">
        <span className="font-mono text-[10px] uppercase tracking-[0.14em]" style={{ color: C.ash }}>Drag out all</span>
        <span className="font-mono text-[10px] uppercase tracking-[0.14em]" style={{ color: C.ash2 }}>Clear</span>
      </div>
    </div>
  )
}

/* ───────────────────────────── Menu bar ───────────────────────────── */

type Row = { k: string; label: ReactNode; right?: ReactNode; sub?: boolean } | 'sep' | { head: string }

export function MenuBarMenu({ className }: { className?: string }) {
  const [hot, setHot] = useState<string | null>('float')
  const rows: Row[] = [
    { head: 'Recent' },
    { k: 'r1', label: <span className="flex items-center gap-2"><span className="font-mono text-[9px] font-bold" style={{ color: C.solar }}>GIF</span>clip.gif</span>, right: <span className="font-mono text-[11px]">2 m</span> },
    { k: 'r2', label: <span className="flex items-center gap-2"><span className="font-mono text-[9px] font-bold" style={{ color: C.solar }}>PDF</span>scan.pdf</span>, right: <span className="font-mono text-[11px]">14 m</span> },
    'sep',
    { k: 'float', label: 'Float shelf', right: '⌥⌘F' },
    { k: 'presets', label: 'Presets', right: <ChevronRight size={13} />, sub: true },
    { k: 'keys', label: 'Keys…' },
    'sep',
    { k: 'pause', label: 'Pause for 1 hour' },
    { k: 'settings', label: 'Settings…', right: '⌘,' },
    { k: 'quit', label: 'Quit anyfmt', right: '⌘Q' },
  ]
  return (
    <div className={cn('w-[340px] max-w-full font-geist text-[13px]', className)}>
      {/* Menu bar strip */}
      <div className="flex h-[26px] items-center justify-end gap-3.5 rounded-t-[10px] px-3 text-[12.5px]" style={{ background: 'rgba(18,18,20,.7)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', color: C.bone }}>
        <span className="grid h-[22px] w-[30px] place-items-center rounded-[5px]" style={{ background: 'rgba(255,255,255,.18)' }}><MenuGlyph size={16} /></span>
        <Wifi size={14} strokeWidth={2.2} />
        <Search size={13} strokeWidth={2.4} />
        <span className="font-medium tabular-nums">Mon 9:41</span>
      </div>
      <div className="ml-auto mr-1 mt-1 w-[260px] sm:mr-[96px] max-w-[calc(100%-8px)] rounded-[11px] p-[5px]" style={{ ...vibrancy, color: C.bone }}>
        <div className="flex items-center justify-between px-2.5 pb-2 pt-1.5">
          <div className="flex items-center gap-2"><Led size={6} /><span className="font-semibold">anyfmt</span></div>
          <span className="font-mono text-[10px] uppercase tracking-[0.12em]" style={{ color: C.ash }}>Ready · local</span>
        </div>
        {rows.map((r, i) => {
          if (r === 'sep') return <div key={i} className="mx-2.5 my-[5px] h-px" style={{ background: 'rgba(255,255,255,.09)' }} />
          if ('head' in r) return <div key={i} className="px-2.5 pb-1 pt-0.5 text-[11px] font-semibold" style={{ color: C.ash2 }}>{r.head}</div>
          const on = hot === r.k
          return (
            <div key={r.k} onPointerEnter={() => setHot(r.k)} className="flex h-[24px] cursor-default items-center justify-between rounded-[5px] px-2.5"
              style={{ background: on ? C.solar : 'transparent', color: on ? C.void : C.bone }}>
              <span>{r.label}</span>
              {r.right && <span style={{ color: on ? 'rgba(5,5,6,.7)' : C.ash }}>{r.right}</span>}
            </div>
          )
        })}
      </div>
    </div>
  )
}

/* ───────────────────────────── Toasts ───────────────────────────── */

export function ErrorToast({ className }: { className?: string }) {
  return (
    <div className={cn('flex items-center gap-3 rounded-[20px] py-2 pl-3 pr-2 font-geist text-[13px] sm:whitespace-nowrap sm:rounded-full', className)} style={{ ...vibrancy, color: C.bone }}>
      <Led size={7} color={C.clip} />
      <span className="shrink-0 font-medium">scan.heic</span>
      <span className="min-w-0 text-[12px] leading-snug" style={{ color: C.ash }}>Locked by Preview. Close it, then retry.</span>
      <span className="shrink-0 rounded-full px-2.5 py-1 font-mono text-[10px] font-semibold uppercase tracking-[0.12em]" style={{ boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>Retry</span>
    </div>
  )
}

export { DoneToast }

/* ───────────────────────────── Wheels at size ───────────────────────────── */

export function WheelTrio({ size = 320 }: { size?: number }) {
  const rest = [0, 2, 1]
  const [hot, setHot] = useState<(number | null)[]>([null, null, null])
  return (
    <div className="grid justify-items-center gap-12 xl:grid-cols-3 xl:gap-8">
      {wheels.map((w, i) => (
        <div key={w.wheel} className="flex flex-col items-center gap-5">
          <SignalWheel segments={w.segs} size={size} restIndex={rest[i]} onHover={(v) => setHot((h) => h.map((x, j) => (j === i ? v : x)))}
            hub={<FileHub stem={i === 0 ? 'clip' : i === 1 ? 'photo' : 'deck'} ext={i === 0 ? 'MOV' : i === 1 ? 'HEIC' : 'PDF'} size={size} />} />
          <div className="flex w-full items-center justify-between" style={{ maxWidth: size }}>
            <span className="flex items-center gap-2.5">
              <span className="grid size-7 place-items-center rounded-[7px] font-geist text-[14px]" style={{ background: C.carbon2, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>{w.key}</span>
              <span className="font-serif text-[26px] leading-none">{w.wheel}</span>
            </span>
            <Label>{w.segs.length} wedges</Label>
          </div>
          <AnimatePresence mode="wait">
            <motion.span key={String(hot[i])} initial={isShot ? false : { opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="-mt-3 h-4 font-mono text-[10.5px] uppercase tracking-[0.16em]" style={{ color: C.solar }}>
              {`● ${w.segs[hot[i] ?? rest[i]].label}`}
            </motion.span>
          </AnimatePresence>
        </div>
      ))}
    </div>
  )
}
