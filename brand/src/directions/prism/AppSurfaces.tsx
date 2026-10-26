import { animate, motion, useMotionValue, useReducedMotion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Check, ChevronRight, CircleAlert, FolderOpen, Pause, Settings, Sparkles, X } from 'lucide-react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { MenuGlyph, PrismMark } from './Logo'
import { P, glass } from './theme'

/* ---------- small atoms ---------- */

const THUMBS: Record<string, string> = {
  MOV: `linear-gradient(140deg, #FFB199, ${P.coral} 45%, #7C4DFF)`,
  GIF: `linear-gradient(140deg, ${P.lilac}, #FF9DB3)`,
  HEIC: `linear-gradient(160deg, #9EE6FF, #5EE7DF 40%, #2F8F86)`,
  JPG: `linear-gradient(160deg, #FFE1A8, #FF9DB3 60%, #B9A7FF)`,
  PDF: `linear-gradient(180deg, #fff, #F1EDFA)`,
  WAV: `linear-gradient(140deg, #CFC4FF, #8F7BFF)`,
  PNG: `linear-gradient(140deg, #B5F5EF, #8FC9FF)`,
}

/** A file tile: rounded paper with a little picture and a format tag. */
export function FileTile({ ext = 'MOV', size = 56, className, name }: { ext?: string; size?: number; className?: string; name?: string }) {
  const doc = ext === 'PDF'
  return (
    <div className={cn('flex flex-col items-center', className)} style={{ width: size * 1.3 }}>
      <div className="relative" style={{ width: size, height: size * 1.22 }}>
        <div className="absolute inset-0 overflow-hidden rounded-[22%_32%_22%_22%/18%_26%_18%_18%] bg-white"
             style={{ boxShadow: '0 1px 0 rgba(255,255,255,.9) inset, 0 0 0 .5px rgba(28,21,48,.12), 0 10px 24px -10px rgba(44,30,90,.45)' }}>
          <div className="absolute inset-[9%] rounded-[16%]" style={{ background: THUMBS[ext] ?? THUMBS.PNG }}>
            {doc && [22, 34, 46, 58].map((y) => <div key={y} className="absolute left-[14%] h-[5%] rounded-full bg-[#1C1530]/12" style={{ top: `${y}%`, width: y === 58 ? '44%' : '72%' }} />)}
            {!doc && <div className="absolute bottom-[14%] left-[14%] size-[22%] rounded-full bg-white/70 blur-[1px]" />}
          </div>
        </div>
        <span className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 rounded-full px-1.5 py-[2px] font-mono text-[8.5px] font-semibold tracking-wide text-white"
              style={{ background: P.plum, boxShadow: '0 4px 10px -4px rgba(28,21,48,.6)' }}>{ext}</span>
      </div>
      {name && <span className="mt-3 max-w-full truncate rounded-[5px] px-1 text-[11px] font-medium text-current">{name}</span>}
    </div>
  )
}

/** An option chip: a choice with a size estimate. */
export function Chip({ label, est, on, dark, onClick }: { label: string; est?: string; on?: boolean; dark?: boolean; onClick?: () => void }) {
  return (
    <button onClick={onClick} type="button"
      className={cn('p-focus relative flex min-w-0 flex-1 flex-col items-center justify-center rounded-[14px] px-2 py-2 transition-all duration-200',
                    on ? 'text-[#1C1530]' : dark ? 'text-white/85 hover:bg-white/10' : 'text-[#1C1530] hover:bg-white')}
      style={on
        ? { background: `linear-gradient(140deg, ${P.coral}, ${P.lilac} 55%, #7FD9F0)`, boxShadow: '0 8px 20px -8px rgba(255,107,139,.6), inset 0 1px 0 rgba(255,255,255,.5)' }
        : dark ? { background: 'rgba(255,255,255,.06)', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.08)' }
               : { background: 'rgba(255,255,255,.6)', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.9), 0 1px 2px rgba(28,21,48,.06)' }}>
      <span className="text-[14px] font-semibold tracking-[-0.02em]">{label}</span>
      {est && <span className={cn('font-mono text-[10px] tabular-nums', on ? 'text-[#1C1530]/75' : 'opacity-55')}>{est}</span>}
    </button>
  )
}

function Toggle({ on, dark }: { on?: boolean; dark?: boolean }) {
  return (
    <span className="relative inline-block h-[22px] w-[38px] shrink-0 rounded-full transition-colors"
          style={{ background: on ? `linear-gradient(120deg, ${P.coral}, ${P.lilac})` : dark ? 'rgba(255,255,255,.15)' : 'rgba(28,21,48,.12)' }}>
      <span className="absolute top-[2px] size-[18px] rounded-full bg-white shadow-[0_2px_5px_rgba(28,21,48,.3)]" style={{ left: on ? 18 : 2 }} />
    </span>
  )
}

/* ---------- options panel ---------- */

const FPS = [
  { v: '10', est: '2.6 MB' }, { v: '15', est: '4.1 MB' }, { v: '24', est: '6.3 MB' }, { v: '30', est: '7.9 MB' },
]
const WIDTHS = [{ v: '480', est: '1.9 MB' }, { v: '720', est: '4.1 MB' }, { v: '1080', est: '9.2 MB' }]

export function OptionsPanel({ dark, className }: { dark?: boolean; className?: string }) {
  const [fps, setFps] = useState(1)
  const [w, setW] = useState(1)
  const fg = dark ? 'text-white' : 'text-[#1C1530]'
  const sub = dark ? 'text-white/55' : 'text-[#5E5677]'
  return (
    <div className={cn('w-[320px] max-w-full rounded-[26px] p-4', fg, className)} style={dark ? glass.dark : glass.light}>
      <div className="flex items-center gap-3">
        <FileTile ext="MOV" size={30} />
        <div className="min-w-0 flex-1">
          <div className="text-[14px] font-semibold tracking-[-0.02em]">clip.mov → GIF</div>
          <div className={cn('text-[12px]', sub)}>0:08 · 1080p · 18.4 MB</div>
        </div>
        <span className={cn('rounded-full px-2 py-0.5 font-mono text-[10px]', dark ? 'bg-white/10 text-white/70' : 'bg-white/80 text-[#5E5677]')}>⌥ options</span>
      </div>
      <div className={cn('mb-2 mt-4 flex items-baseline justify-between text-[11px] font-medium uppercase tracking-[.08em]', sub)}>
        <span>Frame rate</span><span className="normal-case tracking-normal">fps</span>
      </div>
      <div className="flex gap-1.5">
        {FPS.map((f, i) => <Chip key={f.v} label={f.v} est={f.est} on={i === fps} dark={dark} onClick={() => setFps(i)} />)}
      </div>
      <div className={cn('mb-2 mt-4 flex items-baseline justify-between text-[11px] font-medium uppercase tracking-[.08em]', sub)}>
        <span>Width</span><span className="normal-case tracking-normal">px</span>
      </div>
      <div className="flex gap-1.5">
        {WIDTHS.map((f, i) => <Chip key={f.v} label={f.v} est={f.est} on={i === w} dark={dark} onClick={() => setW(i)} />)}
      </div>
      <div className={cn('mt-4 flex items-center justify-between rounded-[14px] px-3 py-2.5 text-[13px]', dark ? 'bg-white/5' : 'bg-white/55')}>
        <span>Loop forever</span><Toggle on dark={dark} />
      </div>
      <div className="mt-4 flex items-center justify-between">
        <div className="leading-tight">
          <div className={cn('text-[11px]', sub)}>Estimated</div>
          <div className="text-[18px] font-semibold tabular-nums tracking-[-0.03em]">
            {['2.6', '4.1', '6.3', '7.9'][fps]} <span className="text-[13px] font-medium opacity-60">MB</span>
          </div>
        </div>
        <button type="button" className="p-focus inline-flex h-10 items-center gap-1.5 rounded-full px-5 text-[13.5px] font-semibold text-white"
                style={{ background: P.plum, boxShadow: '0 10px 24px -10px rgba(107,78,255,.7), inset 0 1px 0 rgba(255,255,255,.18)' }}>
          Make GIF <span className="opacity-60">↩</span>
        </button>
      </div>
    </div>
  )
}

/* ---------- progress HUD ---------- */

export function ProgressRing({ value, size = 40, stroke = 3.5, dark }: { value: number; size?: number; stroke?: number; dark?: boolean }) {
  const r = (size - stroke) / 2, c = 2 * Math.PI * r
  const gid = `pr${size}${dark ? 'd' : 'l'}`
  return (
    <svg width={size} height={size} className="-rotate-90" aria-hidden>
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={P.coral} /><stop offset=".5" stopColor={P.lilac} /><stop offset="1" stopColor={P.aqua} />
        </linearGradient>
      </defs>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={dark ? 'rgba(255,255,255,.12)' : 'rgba(28,21,48,.08)'} strokeWidth={stroke} />
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={`url(#${gid})`} strokeWidth={stroke} strokeLinecap="round"
              strokeDasharray={c} strokeDashoffset={c * (1 - value)} />
    </svg>
  )
}

export function ProgressHUD({ dark, value: fixed, className, live = true }: { dark?: boolean; value?: number; className?: string; live?: boolean }) {
  const reduce = useReducedMotion()
  const mv = useMotionValue(fixed ?? 0.62)
  const [v, setV] = useState(fixed ?? 0.62)
  useEffect(() => {
    if (!live || isShot || reduce || fixed !== undefined) return
    const c = animate(mv, [0.04, 1], { duration: 4.2, ease: 'easeInOut', repeat: Infinity, repeatDelay: 0.8, onUpdate: setV })
    return () => c.stop()
  }, [live, reduce, fixed, mv])
  const pct = Math.round(v * 100)
  const left = Math.max(0, Math.round((1 - v) * 8))
  return (
    <div className={cn('flex w-[360px] max-w-full items-center gap-3 rounded-full py-2 pl-2 pr-2.5', dark ? 'text-white' : 'text-[#1C1530]', className)}
         style={dark ? glass.dark : glass.light}>
      <div className="relative grid size-11 shrink-0 place-items-center">
        <div className="absolute"><ProgressRing value={v} size={44} dark={dark} /></div>
        <div className="size-7 overflow-hidden rounded-full" style={{ background: THUMBS.MOV }} />
      </div>
      <div className="min-w-0 flex-1 leading-tight">
        <div className="truncate text-[13.5px] font-semibold tracking-[-0.015em]">Making clip.gif</div>
        <div className={cn('truncate font-mono text-[11px] tabular-nums', dark ? 'text-white/55' : 'text-[#5E5677]')}>
          {pct}% · {pct >= 100 ? 'done' : `${left} s left`} · 15 fps
        </div>
      </div>
      <button type="button" aria-label="Cancel" className={cn('p-focus grid size-8 shrink-0 place-items-center rounded-full transition-colors', dark ? 'bg-white/10 hover:bg-white/20' : 'bg-[#1C1530]/[.06] hover:bg-[#1C1530]/10')}>
        <X size={14} strokeWidth={2.4} />
      </button>
    </div>
  )
}

/* ---------- toasts ---------- */

export function Toast({ kind = 'done', dark, className, title, body, action }: {
  kind?: 'done' | 'error'; dark?: boolean; className?: string; title?: string; body?: string; action?: string
}) {
  const ok = kind === 'done'
  return (
    <div className={cn('flex w-[340px] max-w-full items-center gap-3 rounded-[22px] p-2.5 pr-3', dark ? 'text-white' : 'text-[#1C1530]', className)}
         style={dark ? glass.dark : glass.light}>
      <div className="relative grid size-10 shrink-0 place-items-center rounded-full text-white"
           style={{ background: ok ? `linear-gradient(140deg, ${P.aqua}, #3CC9B2)` : `linear-gradient(140deg, #FF8FA3, ${P.danger})`,
                    boxShadow: ok ? '0 6px 16px -6px rgba(47,191,155,.8), inset 0 1px 0 rgba(255,255,255,.5)' : '0 6px 16px -6px rgba(229,72,106,.8), inset 0 1px 0 rgba(255,255,255,.45)' }}>
        {ok ? <Check size={18} strokeWidth={3} /> : <CircleAlert size={18} strokeWidth={2.5} />}
      </div>
      <div className="min-w-0 flex-1 leading-tight">
        <div className="text-[13.5px] font-semibold tracking-[-0.015em]">{title ?? (ok ? 'clip.gif is ready' : 'That one slipped')}</div>
        <div className={cn('mt-0.5 text-[12px]', dark ? 'text-white/60' : 'text-[#5E5677]')}>
          {body ?? (ok ? '4.1 MB · saved next to clip.mov' : 'The file is locked by another app. Close it and drop again.')}
        </div>
      </div>
      <button type="button" className={cn('p-focus shrink-0 rounded-full px-3 py-1.5 text-[12px] font-semibold', dark ? 'bg-white/10 hover:bg-white/15' : 'bg-white hover:bg-white/80 shadow-[0_1px_2px_rgba(28,21,48,.1)]')}>
        {action ?? (ok ? 'Show' : 'Retry')}
      </button>
    </div>
  )
}

/* ---------- Float shelf ---------- */

export function FloatShelf({ dark, className, empty }: { dark?: boolean; className?: string; empty?: boolean }) {
  const files: [string, string][] = [['HEIC', 'beach.heic'], ['PDF', 'Invoice 214.pdf'], ['GIF', 'clip.gif'], ['WAV', 'take-3.wav']]
  const sub = dark ? 'text-white/60' : 'text-[#5E5677]'
  return (
    <div className={cn('relative w-[148px] rounded-[36px] px-3 pb-4 pt-3', dark ? 'text-white' : 'text-[#1C1530]', className)} style={dark ? glass.dark : glass.light}>
      <div className="flex items-center justify-between px-0.5">
        <button type="button" aria-label="Close shelf" className={cn('grid size-6 place-items-center rounded-full', dark ? 'bg-white/10' : 'bg-[#1C1530]/[.07]')}><X size={11} strokeWidth={2.6} /></button>
        <span className={cn('text-[11px] font-semibold', sub)}>Float</span>
      </div>
      {empty ? (
        <div className="flex flex-col items-center px-1 pb-2 pt-6 text-center">
          <div className={cn('grid size-[72px] place-items-center rounded-[22px] border-[1.5px] border-dashed', dark ? 'border-white/25' : 'border-[#B9A7FF]')}>
            <MenuGlyph size={20} className={dark ? 'text-white/70' : 'text-[#6B4EFF]'} />
          </div>
          <div className="mt-4 text-[12.5px] font-semibold">Nothing here yet</div>
          <div className={cn('mt-1 text-[11px] leading-[1.45]', sub)}>Hold ⌃ mid-drag and drop on Float. Files wait here.</div>
        </div>
      ) : (
        <>
          <div className="relative mx-auto mt-3 h-[92px] w-[110px]">
            {([['HEIC', -20, -10], ['PDF', 20, 9], ['GIF', 0, -2]] as const).map(([e, x, r], k) => (
              <div key={e} className="absolute left-1/2 top-0" style={{ transform: `translateX(calc(-50% + ${x}px)) rotate(${r}deg)`, zIndex: k }}>
                <FileTile ext={e} size={50} />
              </div>
            ))}
            <span className="absolute right-0 top-[-4px] z-10 grid h-5 min-w-5 place-items-center rounded-full px-1.5 text-[10px] font-bold text-white"
                  style={{ background: P.plum, boxShadow: `0 0 0 2px ${dark ? '#2a2144' : '#fff'}, 0 4px 10px -3px rgba(28,21,48,.5)` }}>4</span>
          </div>
          <div className={cn('mt-3 text-center text-[11px] font-medium', sub)}>4 files · drag out</div>
          <div className={cn('my-3 h-px', dark ? 'bg-white/10' : 'bg-[#1C1530]/[.07]')} />
          <ul className="m-0 list-none space-y-1 p-0">
            {files.map(([e, n]) => (
              <li key={n} className={cn('flex items-center gap-2 rounded-[12px] px-1.5 py-1', dark ? 'hover:bg-white/10' : 'hover:bg-white/70')}>
                <span className="size-5 shrink-0 rounded-[6px]" style={{ background: THUMBS[e], boxShadow: 'inset 0 0 0 .5px rgba(28,21,48,.15)' }} />
                <span className="min-w-0 truncate text-[11.5px] font-medium">{n}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  )
}

/* ---------- menu-bar menu ---------- */

function MenuRow({ children, right, dark, hot, icon }: { children: ReactNode; right?: ReactNode; dark?: boolean; hot?: boolean; icon?: ReactNode }) {
  return (
    <div className={cn('flex items-center gap-2.5 rounded-[9px] px-2.5 py-[6px] text-[13px]', hot && 'font-medium text-[#1C1530]')}
         style={hot ? { background: `linear-gradient(120deg, ${P.coral}, ${P.lilac} 60%, #8FD1F4)` } : undefined}>
      {icon && <span className={cn('grid w-4 place-items-center', !hot && (dark ? 'text-white/60' : 'text-[#5E5677]'))}>{icon}</span>}
      <span className="flex-1 truncate">{children}</span>
      {right && <span className={cn('font-mono text-[11.5px]', hot ? 'text-[#1C1530]/70' : dark ? 'text-white/45' : 'text-[#8E87A6]')}>{right}</span>}
    </div>
  )
}

export function MenuBarMenu({ dark, className }: { dark?: boolean; className?: string }) {
  const sep = <div className={cn('mx-2.5 my-1.5 h-px', dark ? 'bg-white/10' : 'bg-[#1C1530]/[.08]')} />
  const sub = dark ? 'text-white/50' : 'text-[#8E87A6]'
  return (
    <div className={cn('w-[300px] max-w-full', dark ? 'text-white' : 'text-[#1C1530]', className)}>
      {/* menu bar strip */}
      <div className={cn('flex h-7 items-center justify-end gap-4 rounded-[10px] px-3 text-[12px] font-medium', dark ? 'bg-black/35 text-white/90' : 'bg-white/45 text-[#1C1530]/85')}
           style={{ backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)' }}>
        <span className="opacity-70">100%</span>
        <span className="grid h-[22px] w-[30px] place-items-center rounded-[6px]" style={{ background: dark ? 'rgba(255,255,255,.18)' : 'rgba(28,21,48,.1)' }}>
          <MenuGlyph size={15} />
        </span>
        <span className="tabular-nums">Mon 9:41</span>
      </div>
      <div className="mt-1.5 rounded-[16px] p-1.5" style={dark ? glass.dark : glass.light}>
        <div className="flex items-center gap-3 px-2.5 pb-2.5 pt-2">
          <PrismMark size={30} />
          <div className="leading-tight">
            <div className="text-[13.5px] font-semibold tracking-[-0.015em]">anyfmt is ready</div>
            <div className={cn('flex items-center gap-1.5 text-[11.5px]', sub)}>
              <span className="size-1.5 rounded-full" style={{ background: P.success, boxShadow: `0 0 6px ${P.success}` }} />
              Local · 0 network calls
            </div>
          </div>
        </div>
        <div className={cn('mx-1 mb-1.5 grid grid-cols-3 gap-1 rounded-[12px] p-1 text-center text-[11px]', dark ? 'bg-white/5' : 'bg-white/55')}>
          {[['⇧', 'Convert'], ['⌘', 'Tools'], ['⌃', 'Actions']].map(([k, l]) => (
            <div key={l} className="rounded-[9px] py-1.5">
              <div className="text-[15px] leading-none">{k}</div>
              <div className={cn('mt-1', sub)}>{l}</div>
            </div>
          ))}
        </div>
        <div className={cn('px-2.5 pb-1 pt-1.5 text-[11px] font-medium', sub)}>Recent</div>
        <MenuRow dark={dark} icon={<span className="size-3.5 rounded-[4px]" style={{ background: THUMBS.GIF }} />} right="2m">clip.mov → GIF</MenuRow>
        <MenuRow dark={dark} hot icon={<span className="size-3.5 rounded-[4px]" style={{ background: THUMBS.JPG }} />} right="14m">beach.heic → JPG</MenuRow>
        <MenuRow dark={dark} icon={<span className="size-3.5 rounded-[4px]" style={{ background: THUMBS.PDF, boxShadow: 'inset 0 0 0 .5px rgba(28,21,48,.2)' }} />} right="1h">Invoice 214 · Redact</MenuRow>
        {sep}
        <MenuRow dark={dark} icon={<FolderOpen size={14} />} right="⌘O">Open Float shelf</MenuRow>
        <MenuRow dark={dark} icon={<Sparkles size={14} />} right={<ChevronRight size={13} />}>Presets</MenuRow>
        <MenuRow dark={dark} icon={<Pause size={14} />} right="⌥⌘P">Pause anyfmt</MenuRow>
        {sep}
        <MenuRow dark={dark} icon={<Settings size={14} />} right="⌘,">Settings…</MenuRow>
        <MenuRow dark={dark} right="⌘Q">Quit anyfmt</MenuRow>
      </div>
    </div>
  )
}

/* ---------- a tiny spinning ring used for "working" states ---------- */
export function Busy({ size = 18 }: { size?: number }) {
  const r = useMotionValue(0)
  useEffect(() => { if (isShot) return; const c = animate(r, 360, { duration: 1, repeat: Infinity, ease: 'linear' }); return () => c.stop() }, [r])
  return <motion.span className="inline-block rounded-full" style={{ width: size, height: size, rotate: r, background: `conic-gradient(${P.coral}, ${P.lilac}, ${P.aqua}, transparent)`, WebkitMask: 'radial-gradient(farthest-side, transparent 60%, #000 62%)', mask: 'radial-gradient(farthest-side, transparent 60%, #000 62%)' }} />
}
