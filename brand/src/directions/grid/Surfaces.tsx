import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { Check, X } from 'lucide-react'
import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { GridWheel, type Seg } from './GridWheel'
import { MenuGlyph } from './Logo'
import { C, EASE, FileTile, Mono, SwissKey } from './ui'

const panel = 'rounded-[10px] border border-[#D6D6D0] bg-white text-[#0B0B0B] shadow-[0_1px_0_rgba(0,0,0,.04),0_24px_48px_-24px_rgba(0,0,0,.28)]'

/* ───────────────────────── Options panel ───────────────────────── */

const FPS = [10, 15, 24, 30] as const
const WIDTHS = [480, 720, 1080] as const
const mb = (fps: number, w: number) => 1.8 * (fps / 15) * Math.pow(w / 720, 2) * 0.92 + 0.12

export function OptionsPanel({ className }: { className?: string }) {
  const [fps, setFps] = useState<number>(15)
  const [w, setW] = useState<number>(720)
  const [loop, setLoop] = useState(true)
  const est = mb(fps, w)
  return (
    <div className={cn(panel, 'w-full max-w-[380px] overflow-hidden', className)} role="dialog" aria-label="GIF options">
      <div className="flex items-center justify-between border-b border-[#D6D6D0] px-4 py-3">
        <div className="flex items-baseline gap-3">
          <span className="font-mono text-[11px] font-semibold text-[#5C5C56]">01</span>
          <span className="font-grotesk text-[22px] font-semibold leading-none tracking-[-0.04em]">GIF</span>
        </div>
        <span className="font-mono text-[11px] text-[#5C5C56]">clip.mov · 6.2 s</span>
      </div>
      <div className="space-y-4 px-4 py-4">
        <Row label="Frame rate">
          <div className="grid grid-cols-4 gap-1.5">
            {FPS.map((f) => (
              <Chip key={f} on={fps === f} onClick={() => setFps(f)} main={`${f}`} unit="fps" sub={`${mb(f, w).toFixed(1)} MB`} />
            ))}
          </div>
        </Row>
        <Row label="Width">
          <div className="grid grid-cols-3 gap-1.5">
            {WIDTHS.map((x) => (
              <Chip key={x} on={w === x} onClick={() => setW(x)} main={`${x}`} unit="px" sub={`${mb(fps, x).toFixed(1)} MB`} />
            ))}
          </div>
        </Row>
        <Row label="Loop">
          <div className="grid grid-cols-2 gap-1.5">
            <Chip on={loop} onClick={() => setLoop(true)} main="Forever" />
            <Chip on={!loop} onClick={() => setLoop(false)} main="Once" />
          </div>
        </Row>
      </div>
      <div className="flex items-center justify-between gap-3 border-t border-[#D6D6D0] bg-[#F4F4F1] px-4 py-3">
        <div className="font-mono text-[11px] leading-tight">
          <div className="text-[#5C5C56]">ESTIMATE</div>
          <div className="mt-1 text-[15px] font-semibold tabular-nums">≈ {est.toFixed(1)} MB</div>
        </div>
        <button type="button" className="flex h-9 items-center gap-2 bg-[#0B0B0B] px-4 font-grotesk text-[14px] font-medium text-[#F4F4F1] transition-colors hover:bg-[#FF3D2E] hover:text-[#0B0B0B]">
          Convert <span className="font-mono text-[12px] opacity-70">⏎</span>
        </button>
      </div>
    </div>
  )
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <Mono className="mb-2 block text-[10px] text-[#5C5C56]">{label}</Mono>
      {children}
    </div>
  )
}

function Chip({ on, onClick, main, unit, sub }: { on: boolean; onClick: () => void; main: string; unit?: string; sub?: string }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={on}
      className={cn('relative flex flex-col items-start gap-1 rounded-[4px] border px-2.5 py-2 text-left transition-colors duration-75',
        on ? 'border-[#0B0B0B] bg-[#0B0B0B] text-[#F4F4F1]' : 'border-[#D6D6D0] bg-white hover:border-[#0B0B0B]')}>
      {on && <span className="absolute right-1.5 top-1.5 size-1.5 bg-[#FF3D2E]" />}
      <span className="font-grotesk text-[15px] font-semibold leading-none tracking-[-0.02em]">
        {main}{unit && <span className="ml-0.5 font-mono text-[10px] font-medium opacity-60">{unit}</span>}
      </span>
      {sub && <span className={cn('font-mono text-[10px] leading-none tabular-nums', on ? 'text-[#BDBDB6]' : 'text-[#5C5C56]')}>{sub}</span>}
    </button>
  )
}

/* ───────────────────────── Progress HUD ───────────────────────── */

export function ProgressHUD({ className, fixed }: { className?: string; fixed?: number }) {
  const reduce = useReducedMotion()
  const [p, setP] = useState(fixed ?? 0.62)
  useEffect(() => {
    if (isShot || reduce || fixed !== undefined) return
    const id = setInterval(() => setP((x) => (x >= 1 ? 0 : Math.min(1, x + 0.02))), 90)
    return () => clearInterval(id)
  }, [reduce, fixed])
  const R = 15, L = 2 * Math.PI * R
  const total = 2.3
  return (
    <div className={cn('flex w-full max-w-[440px] items-center gap-3 rounded-[12px] bg-[#0B0B0B] p-2.5 pr-3 text-[#F4F4F1] shadow-[0_24px_48px_-20px_rgba(0,0,0,.5)]', className)}
      role="progressbar" aria-valuenow={Math.round(p * 100)} aria-valuemin={0} aria-valuemax={100} aria-label="Converting clip.mov">
      <div className="relative grid size-11 shrink-0 place-items-center">
        <svg width="44" height="44" viewBox="0 0 40 40" className="absolute inset-0 -rotate-90" aria-hidden>
          <circle cx="20" cy="20" r={R} fill="none" stroke="#2A2A28" strokeWidth="3.5" />
          <circle cx="20" cy="20" r={R} fill="none" stroke={C.red} strokeWidth="3.5" strokeDasharray={L} strokeDashoffset={L * (1 - p)} />
        </svg>
        <span className="font-mono text-[10px] font-semibold tabular-nums">{Math.round(p * 100)}</span>
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate font-grotesk text-[14px] font-medium tracking-[-0.01em]">clip.mov <span className="text-[#8E8E87]">→</span> clip.gif</div>
        <div className="mt-1 font-mono text-[10px] tabular-nums text-[#A9A9A2]">
          {(p * total).toFixed(1)} of {total} MB · {Math.max(0, Math.ceil((1 - p) * 8))} s left
        </div>
      </div>
      <button type="button" aria-label="Cancel" className="grid size-8 shrink-0 place-items-center rounded-[6px] border border-[#3A3A38] text-[#F4F4F1] transition-colors hover:border-[#FF3D2E] hover:bg-[#FF3D2E] hover:text-[#0B0B0B]">
        <X size={14} strokeWidth={2.2} />
      </button>
    </div>
  )
}

/* ───────────────────────── Float shelf ───────────────────────── */

export function FloatShelf({ className }: { className?: string }) {
  const files = [
    { ext: 'GIF', name: 'clip.gif' }, { ext: 'JPG', name: 'photo.jpg' }, { ext: 'PDF', name: 'report.pdf' },
  ]
  const [held, setHeld] = useState(files)
  return (
    <div className={cn(panel, 'w-full max-w-[360px]', className)} aria-label="Float shelf">
      <div className="flex items-center justify-between border-b border-[#D6D6D0] px-3.5 py-2.5">
        <div className="flex items-center gap-2">
          <span className="block size-2 bg-[#FF3D2E]" />
          <Mono className="text-[10px]">Float</Mono>
          <span className="font-mono text-[10px] text-[#5C5C56]">{String(held.length).padStart(2, '0')}</span>
        </div>
        <button type="button" onClick={() => setHeld(held.length ? [] : files)} className="font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56] hover:text-[#0B0B0B]">
          {held.length ? 'Clear' : 'Restore'}
        </button>
      </div>
      <div className="grid min-h-[118px] grid-cols-3 gap-0">
        {held.length ? held.map((f, i) => (
          <div key={f.name} className={cn('group relative flex flex-col items-center justify-center gap-1 py-3 transition-colors hover:bg-[#F4F4F1]', i > 0 && 'border-l border-[#D6D6D0]')}>
            <span className="absolute left-2 top-2 font-mono text-[9px] text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</span>
            <FileTile ext={f.ext} name={f.name} size={40} />
          </div>
        )) : (
          <div className="col-span-3 grid place-items-center px-6 text-center font-sans text-[13px] text-[#5C5C56]">Float is empty. Drag a file here to hold it.</div>
        )}
      </div>
      <div className="border-t border-[#D6D6D0] px-3.5 py-2 font-mono text-[10px] text-[#5C5C56]">Drag out to drop anywhere · ⌃ wheel → Float</div>
    </div>
  )
}

/* ───────────────────────── Menu bar + menu ───────────────────────── */

export function MenuBarMenu({ className }: { className?: string }) {
  const items: ({ t: string; k?: string; dim?: boolean } | 'sep' | { head: string })[] = [
    { head: 'Recent' },
    { t: 'clip.gif', k: '2.4 MB' }, { t: 'photo.jpg', k: '880 KB' }, { t: 'report-redacted.pdf', k: '1.1 MB' },
    'sep',
    { t: 'Open Float shelf', k: '⌥⌘F' }, { t: 'Presets…' }, { t: 'Settings…', k: '⌘,' },
    'sep',
    { t: 'Pause anyfmt' }, { t: 'Quit anyfmt', k: '⌘Q' },
  ]
  return (
    <div className={cn('w-full max-w-[400px]', className)}>
      <div className="flex h-7 items-center justify-end gap-4 rounded-t-[8px] border border-b-0 border-[#D6D6D0] bg-white/90 px-3 font-sans text-[12px] font-medium text-[#0B0B0B]">
        <span className="opacity-60">Wi-Fi</span>
        <span className="grid h-[22px] w-7 place-items-center rounded-[4px] bg-[#0B0B0B]/10"><MenuGlyph size={16} color="#0B0B0B" /></span>
        <span className="tabular-nums">Mon 26 Oct 09:41</span>
      </div>
      <div className="relative">
        <div className="ml-auto mr-[96px] mt-1 w-[260px] max-w-[calc(100%-8px)] rounded-[8px] border border-[#D6D6D0] bg-white p-1 font-sans text-[13px] text-[#0B0B0B] shadow-[0_18px_40px_-16px_rgba(0,0,0,.3)] max-[420px]:mr-1">
          <div className="flex items-center justify-between px-2.5 py-2">
            <span className="font-grotesk text-[14px] font-semibold tracking-[-0.02em]">anyfmt 1.0</span>
            <span className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-[0.08em]"><span className="size-1.5 bg-[#0B0B0B]" />Ready</span>
          </div>
          <div className="mx-2 mb-1 h-px bg-[#D6D6D0]" />
          {items.map((it, i) => it === 'sep' ? <div key={i} className="mx-2 my-1 h-px bg-[#D6D6D0]" /> : 'head' in it ? (
            <div key={i} className="px-2.5 pb-1 pt-1.5 font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">{it.head}</div>
          ) : (
            <div key={i} className={cn('flex cursor-default items-center justify-between rounded-[4px] px-2.5 py-[5px]', i === 4 + 1 ? 'bg-[#0B0B0B] text-[#F4F4F1]' : 'hover:bg-[#0B0B0B] hover:text-[#F4F4F1]')}>
              <span>{it.t}</span>{it.k && <span className="font-mono text-[11px] opacity-60">{it.k}</span>}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

/* ───────────────────────── Toasts ───────────────────────── */

export function DoneToast({ className, file = 'clip.gif', meta = '2.4 MB · 15 FPS · 0.9 S' }: { className?: string; file?: string; meta?: string }) {
  return (
    <div className={cn(panel, 'flex w-full max-w-[360px] items-center gap-3 p-2.5 pr-3', className)} role="status">
      <span className="grid size-9 shrink-0 place-items-center rounded-[6px] bg-[#0B0B0B] text-[#F4F4F1]"><Check size={16} strokeWidth={2.6} /></span>
      <div className="min-w-0 flex-1">
        <div className="truncate font-grotesk text-[14px] font-semibold tracking-[-0.02em]">Saved {file}</div>
        <div className="mt-0.5 font-mono text-[10px] tracking-[0.04em] text-[#5C5C56]">{meta}</div>
      </div>
      <div className="flex shrink-0 gap-1 font-sans text-[12px] font-medium">
        <button type="button" className="rounded-[4px] px-2 py-1 hover:bg-[#F4F4F1]">Reveal</button>
        <button type="button" className="rounded-[4px] px-2 py-1 text-[#5C5C56] hover:bg-[#F4F4F1]">Undo</button>
      </div>
    </div>
  )
}

export function ErrorToast({ className }: { className?: string }) {
  return (
    <div className={cn(panel, 'flex w-full max-w-[360px] items-start gap-3 p-2.5 pr-3', className)} role="alert">
      <span className="grid size-9 shrink-0 place-items-center rounded-[6px] bg-[#FF3D2E] font-grotesk text-[18px] font-bold text-[#0B0B0B]">!</span>
      <div className="min-w-0 flex-1">
        <div className="font-grotesk text-[14px] font-semibold tracking-[-0.02em]">Can't convert locked.pdf</div>
        <div className="mt-0.5 font-sans text-[12px] leading-snug text-[#5C5C56]">It's password-protected. Unlock it, then drop again.</div>
      </div>
      <button type="button" className="shrink-0 rounded-[4px] px-2 py-1 font-sans text-[12px] font-medium hover:bg-[#F4F4F1]">Details</button>
    </div>
  )
}

/* ───────────────────────── macOS window, Grid style ───────────────────────── */

export function GridWindow({ children, className, title, step, style }: { children: ReactNode; className?: string; title?: string; step?: string; style?: CSSProperties }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[12px] border border-[#CFCFC8] bg-white text-[#0B0B0B] shadow-[0_1px_0_rgba(0,0,0,.05),0_40px_70px_-40px_rgba(0,0,0,.45)]', className)} style={style}>
      <div className="flex h-10 items-center justify-between border-b border-[#E4E4DF] px-3.5">
        <div className="flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}</div>
        {title && <Mono className="text-[10px] text-[#5C5C56]">{title}</Mono>}
        <span className="font-mono text-[10px] font-semibold text-[#5C5C56]">{step ?? ''}</span>
      </div>
      {children}
    </div>
  )
}

/* ───────────────────────── Hero demo: drag → key → wheel → drop ───────────────────────── */

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: [Phase, number][] = [['idle', 900], ['drag', 650], ['key', 360], ['open', 380], ['aim', 1500], ['drop', 360], ['done', 2100]]

export function GridDemo({
  segments, target, sweep, size = 380, hub, hubSub, ext, name, keySym, keyName, result, resultMeta, className,
}: {
  segments: readonly Seg[]; target: number; sweep?: number[]; size?: number; hub?: string; hubSub?: string
  ext: string; name: string; keySym: string; keyName: string; result: string; resultMeta: string; className?: string
}) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [aim, setAim] = useState<number | null>(isShot ? target : null)
  const phase = SCRIPT[step][0]
  const path = sweep ?? [target]

  useEffect(() => {
    if (isShot) return
    const t = setTimeout(() => setStep((s) => (s + 1) % SCRIPT.length), SCRIPT[step][1])
    return () => clearTimeout(t)
  }, [step])

  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(path[0])
    const id = setInterval(() => { i = Math.min(i + 1, path.length - 1); setAim(path[i]) }, SCRIPT[4][1] / path.length)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const n = segments.length
  const a = aim != null ? ((aim + 0.5) / n) * Math.PI * 2 - Math.PI / n : 0
  const rr = size * 0.45
  const px = aim != null ? rr * Math.sin(a) : phase === 'drag' ? -26 : 0
  const py = aim != null ? -rr * Math.cos(a) : phase === 'drag' ? 14 : 0
  const pressed = phase === 'key' || phase === 'open' || phase === 'aim'

  return (
    <div className={cn('relative', className)} style={{ width: size, height: size }}>
      <GridWheel segments={segments} size={size} interactive={false} active={phase === 'drop' ? target : aim} open={open} hub={hub} hubSub={hubSub} />
      <motion.div className="pointer-events-none absolute left-1/2 top-1/2 z-10 -ml-[28px] -mt-[40px]"
        initial={false} animate={{ x: reduce ? 0 : px, y: reduce ? 0 : py, opacity: phase === 'drop' || phase === 'done' ? 0 : 1, scale: phase === 'drop' ? 0.5 : 1 }}
        transition={{ duration: 0.32, ease: EASE }}>
        <div className={cn(phase !== 'idle' && 'rotate-[-3deg]')}><FileTile ext={ext} size={52} /></div>
        <svg className="absolute -bottom-2 -right-3" width="22" height="22" viewBox="0 0 24 24" aria-hidden>
          <path d="M5 3l14 8-6 1.6L10 19z" fill={C.ink} stroke={C.white} strokeWidth="1.4" strokeLinejoin="round" />
        </svg>
      </motion.div>
      <div className="absolute -bottom-2 -right-2 z-20">
        <SwissKey symbol={keySym} name={keyName} pressed={pressed} size={58} />
      </div>
      <div className="absolute -left-1 top-0 z-20 font-mono text-[10px] uppercase tracking-[0.08em] text-[#0B0B0B]">
        <span className="bg-[#F4F4F1] px-1">{name}</span>
      </div>
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute left-1/2 top-1/2 z-30 -translate-x-1/2 -translate-y-1/2"
            initial={{ clipPath: 'inset(0 100% 0 0)' }} animate={{ clipPath: 'inset(0 0% 0 0)' }} exit={{ clipPath: 'inset(0 0 0 100%)' }}
            transition={{ duration: 0.28, ease: EASE }}>
            <DoneToast file={result} meta={resultMeta} className="w-[300px]" />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
