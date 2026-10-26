// The app itself, wearing Aura: wheels, options, HUD, Float shelf, menu-bar menu, toasts.
import {
  AlertCircle, BatteryFull, ChevronRight, Clock, Layers, Pause, Repeat, Search, Settings, Sparkles, Wifi, X,
} from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { AuraWheel } from './AuraWheel'
import { DoneToast } from './Demo'
import { Fit, Glow, Grain, MenuGlyph, Mark, PaperFile, WHEELS } from './ui'

/* ------------------------------------------------------------------ desktop backdrop */

export function Desktop({ children, className, glow = true }: { children: ReactNode; className?: string; glow?: boolean }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[32px]', className)}
         style={{ background: 'linear-gradient(160deg,#F7EEE2 0%,#F3E4D6 40%,#E9E3F4 100%)', boxShadow: '0 0 0 1px rgba(30,27,24,.06) inset' }}>
      {glow && <Glow className="left-[10%] top-[-20%] h-[120%] w-[80%]" intensity={0.75} />}
      <Grain />
      <div className="relative flex h-full flex-col">{children}</div>
    </div>
  )
}

/* ------------------------------------------------------------------ wheels */

export function WheelTrio({ size = 340 }: { size?: number }) {
  const hovers = [0, 1, 0]
  return (
    <div className="grid grid-cols-1 gap-10 md:grid-cols-3">
      {WHEELS.map((w, i) => (
        <div key={w.wheel} className="flex flex-col items-center gap-6">
          <Fit width={size + 60} height={size + 60}>
            <div className="grid h-full w-full place-items-center">
              <AuraWheel segments={w.segs} size={size} tone={w.tone}
                interactive
                hubLabel={<span className="aura-serif text-[14px] italic text-[#5B524A]">{w.wheel}</span>}
                hubSub={<span className="mt-0.5 text-[11px] font-semibold">{i === 0 ? 'clip.mov' : i === 1 ? 'shot.png' : '3 files'}</span>}
                {...(isShot ? { hoverIndex: hovers[i] } : {})} />
            </div>
          </Fit>
          <div className="text-center">
            <div className="flex items-center justify-center gap-2 text-[13px] font-semibold text-[#1E1B18]">
              <kbd className="rounded-md bg-white px-1.5 py-0.5 font-sans text-[13px] shadow-[0_0_0_.5px_rgba(90,60,30,.25),0_2px_0_#E2D4C2]">{w.key}</kbd>
              {w.name} · {w.wheel}
            </div>
            <p className="mt-1 text-[13.5px] text-[#5B524A]">{w.blurb}</p>
          </div>
        </div>
      ))}
    </div>
  )
}

/* ------------------------------------------------------------------ options panel */

const FPS = [{ v: 10, mb: 1.1 }, { v: 15, mb: 1.6 }, { v: 24, mb: 2.5 }, { v: 30, mb: 3.1 }]
const WIDTHS = [{ v: '480', k: 0.55 }, { v: '720', k: 1 }, { v: 'Original', k: 1.9 }]

export function OptionsPanel() {
  const [fps, setFps] = useState(1)
  const [w, setW] = useState(1)
  const [loop, setLoop] = useState(true)
  const est = (FPS[fps].mb * WIDTHS[w].k).toFixed(1)
  return (
    <div className="aura-frost w-[340px] rounded-[26px] p-4">
      <div className="flex items-center gap-3">
        <PaperFile ext="GIF" size={30} />
        <div className="min-w-0 flex-1">
          <div className="text-[14px] font-semibold text-[#1E1B18]">Make a GIF</div>
          <div className="truncate text-[12px] text-[#5B524A]">from clip.mov · 0:08 · 1920×1080</div>
        </div>
        <div className="text-right">
          <div className="aura-serif text-[22px] leading-none text-[#1E1B18] tabular-nums">{est}<span className="ml-0.5 text-[12px] text-[#5B524A]">MB</span></div>
          <div className="text-[10.5px] text-[#8A7F74]">estimate</div>
        </div>
      </div>

      <div className="mt-4 text-[11px] font-semibold uppercase tracking-[0.12em] text-[#8A7F74]">Frame rate</div>
      <div className="mt-2 grid grid-cols-4 gap-1.5">
        {FPS.map((f, i) => (
          <Chip key={f.v} on={fps === i} onClick={() => setFps(i)}>
            <span className="text-[14px] font-semibold">{f.v}<span className="ml-0.5 text-[10px] font-medium opacity-70">fps</span></span>
            <span className="text-[10.5px] tabular-nums opacity-70">{(f.mb * WIDTHS[w].k).toFixed(1)} MB</span>
          </Chip>
        ))}
      </div>

      <div className="mt-3.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-[#8A7F74]">Width</div>
      <div className="mt-2 grid grid-cols-3 gap-1.5">
        {WIDTHS.map((x, i) => (
          <Chip key={x.v} on={w === i} onClick={() => setW(i)}>
            <span className="text-[13px] font-semibold">{x.v}{x.v !== 'Original' && <span className="ml-0.5 text-[10px] opacity-70">px</span>}</span>
            <span className="text-[10.5px] tabular-nums opacity-70">{(FPS[fps].mb * x.k).toFixed(1)} MB</span>
          </Chip>
        ))}
      </div>

      <button type="button" onClick={() => setLoop(!loop)} className="mt-3.5 flex w-full items-center justify-between rounded-[14px] bg-white/60 px-3 py-2.5 text-[13px] font-medium text-[#1E1B18] shadow-[0_0_0_.5px_rgba(90,60,30,.14)]">
        <span className="flex items-center gap-2"><Repeat size={14} className="text-[#5B524A]" /> Loop forever</span>
        <span className={cn('relative h-[22px] w-[38px] rounded-full transition-colors', loop ? 'bg-[#FFA868]' : 'bg-[#E2D7C8]')}
              style={{ boxShadow: loop ? '0 0 12px rgba(255,160,100,.6)' : undefined }}>
          <span className={cn('absolute top-[2px] size-[18px] rounded-full bg-white shadow transition-all', loop ? 'left-[18px]' : 'left-[2px]')} />
        </span>
      </button>

      <div className="mt-4 flex items-center justify-between">
        <span className="text-[11.5px] text-[#8A7F74]">Save as preset</span>
        <span className="aura-btn aura-btn-ink px-4 py-2 text-[13px]">Make GIF <kbd className="rounded bg-white/15 px-1 text-[11px] font-medium">↵</kbd></span>
      </div>
    </div>
  )
}

function Chip({ on, children, onClick }: { on: boolean; children: ReactNode; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={on}
      className={cn('flex flex-col items-center gap-0.5 rounded-[14px] px-1 py-2 text-[#1E1B18] transition-all duration-200', on ? '' : 'hover:bg-white/80')}
      style={on
        ? { background: 'linear-gradient(180deg,#FFE9D6,#FFCBA2)', boxShadow: '0 0 0 1px rgba(255,150,90,.55), 0 6px 16px -6px rgba(255,140,80,.6)' }
        : { background: 'rgba(255,255,255,.55)', boxShadow: '0 0 0 .5px rgba(90,60,30,.16)' }}>
      {children}
    </button>
  )
}

/* ------------------------------------------------------------------ progress HUD */

export function ProgressHUD({ value: fixed }: { value?: number }) {
  const [v, setV] = useState(fixed ?? 0.62)
  useEffect(() => {
    if (isShot || fixed !== undefined) return
    const id = setInterval(() => setV((x) => (x >= 1 ? 0.05 : Math.min(1, x + 0.012))), 60)
    return () => clearInterval(id)
  }, [fixed])
  const r = 15, c = 2 * Math.PI * r
  return (
    <div className="aura-frost flex w-[380px] items-center gap-3 rounded-full py-2 pl-2 pr-2.5">
      <div className="relative grid size-11 place-items-center">
        <div className="absolute inset-0 rounded-full bg-[#FFB27A]/30 blur-md" />
        <svg width="44" height="44" viewBox="0 0 44 44" className="relative -rotate-90">
          <circle cx="22" cy="22" r={r} fill="#fff" stroke="#EFE5D8" strokeWidth="4" />
          <circle cx="22" cy="22" r={r} fill="none" stroke="url(#hudg)" strokeWidth="4" strokeLinecap="round"
                  strokeDasharray={c} strokeDashoffset={c * (1 - v)} style={{ transition: 'stroke-dashoffset .1s linear' }} />
          <defs><linearGradient id="hudg" x1="0" x2="1"><stop offset="0" stopColor="#9DB4FF" /><stop offset="1" stopColor="#FF9858" /></linearGradient></defs>
        </svg>
        <span className="absolute text-[10px] font-bold tabular-nums text-[#1E1B18]">{Math.round(v * 100)}</span>
      </div>
      <div className="min-w-0 flex-1 leading-tight">
        <div className="truncate text-[13.5px] font-semibold text-[#1E1B18]">clip.mov <span className="font-normal text-[#8A7F74]">→</span> clip.gif</div>
        <div className="text-[11.5px] text-[#5B524A]">Converting · about {Math.max(1, Math.round((1 - v) * 8))} s left</div>
      </div>
      <button type="button" aria-label="Cancel" className="grid size-8 place-items-center rounded-full bg-[#1E1B18]/[.06] text-[#5B524A] transition hover:bg-[#1E1B18]/10 hover:text-[#1E1B18]">
        <X size={15} strokeWidth={2.2} />
      </button>
    </div>
  )
}

/* ------------------------------------------------------------------ float shelf */

export function FloatShelf() {
  const files = [
    { ext: 'PDF', name: 'lease.pdf', rot: -6 },
    { ext: 'PNG', name: 'hero@2x.png', rot: 4 },
    { ext: 'GIF', name: 'clip.gif', rot: -1 },
  ]
  return (
    <div className="aura-frost w-[236px] rounded-[28px] p-3">
      <div className="flex items-center justify-between px-1.5 pt-0.5">
        <span className="flex items-center gap-1.5 text-[13px] font-semibold text-[#1E1B18]"><Layers size={14} /> Float</span>
        <span className="rounded-full bg-[#1E1B18]/[.06] px-2 py-0.5 text-[11px] font-semibold text-[#5B524A]">3 files</span>
      </div>
      <div className="relative mt-3 grid h-[150px] place-items-center rounded-[20px]"
           style={{ background: 'radial-gradient(circle at 50% 60%, rgba(255,178,122,.35), rgba(255,255,255,.4) 70%)', boxShadow: '0 0 0 .5px rgba(90,60,30,.12) inset' }}>
        {files.map((f, i) => (
          <div key={f.name} className="absolute" style={{ transform: `translate(${(i - 1) * 44}px, ${i === 1 ? -6 : 4}px) rotate(${f.rot}deg)`, zIndex: i === 2 ? 3 : 1 }}>
            <PaperFile ext={f.ext} size={46} />
          </div>
        ))}
      </div>
      <div className="mt-2.5 space-y-1">
        {files.slice().reverse().map((f) => (
          <div key={f.name} className="flex items-center justify-between rounded-[12px] px-2 py-1.5 text-[12.5px] text-[#1E1B18] hover:bg-white/70">
            <span className="truncate font-medium">{f.name}</span>
            <span className="text-[11px] text-[#8A7F74]">{f.ext}</span>
          </div>
        ))}
      </div>
      <div className="mt-2 border-t border-[#1E1B18]/[.07] px-1.5 pt-2.5 text-[11.5px] text-[#5B524A]">Drag them out together, or one at a time.</div>
    </div>
  )
}

/* ------------------------------------------------------------------ menu bar */

export function MenuBarScene() {
  return (
    <div className="relative h-[430px] w-[620px]">
      <div className="absolute inset-x-0 top-0 flex h-[30px] items-center justify-between rounded-t-[22px] px-4 text-[13px] text-[#1E1B18]"
           style={{ background: 'rgba(255,251,245,.6)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', boxShadow: '0 .5px 0 rgba(90,60,30,.15)' }}>
        <div className="flex items-center gap-4 font-semibold"><span>Finder</span><span className="font-normal">File</span><span className="font-normal">Edit</span><span className="font-normal">View</span></div>
        <div className="flex items-center gap-3.5">
          <span className="grid h-[22px] w-[30px] place-items-center rounded-[6px] bg-[#1E1B18]/[.12]"><MenuGlyph size={16} /></span>
          <Wifi size={15} /><BatteryFull size={17} /><Search size={14} />
          <span className="tabular-nums">Mon 26 Oct 9:41</span>
        </div>
      </div>
      <div className="aura-frost absolute right-[150px] top-[36px] w-[290px] rounded-[16px] p-1.5 text-[13px] text-[#1E1B18]">
        <div className="flex items-center gap-2.5 rounded-[11px] px-2.5 py-2.5"
             style={{ background: 'radial-gradient(circle at 15% 50%, rgba(255,178,122,.35), transparent 70%)' }}>
          <Mark size={26} />
          <div className="flex-1 leading-tight">
            <div className="font-semibold">anyfmt is ready</div>
            <div className="text-[11.5px] text-[#5B524A]">Hold a file, then ⇧ ⌘ or ⌃</div>
          </div>
          <span className="relative flex size-2.5"><span className="aura-pulse-ring absolute inset-0 rounded-full bg-[#7BC88A]" /><span className="relative size-2.5 rounded-full bg-[#5DB06E]" /></span>
        </div>
        <Sep />
        <div className="px-2.5 pb-1 pt-1.5 text-[11px] font-semibold text-[#8A7F74]">Recent</div>
        <MenuRow icon={<Ext e="GIF" />} label="clip.gif" right="2.4 MB" />
        <MenuRow icon={<Ext e="PNG" />} label="receipt.png" right="from PDF" />
        <MenuRow icon={<Ext e="JPG" />} label="IMG_2041.jpg" right="from HEIC" />
        <Sep />
        <MenuRow icon={<Layers size={14} />} label="Show Float shelf" right={<ChevronRight size={13} />} hot />
        <MenuRow icon={<Sparkles size={14} />} label="Presets" right={<ChevronRight size={13} />} />
        <MenuRow icon={<Clock size={14} />} label="History" />
        <MenuRow icon={<Pause size={14} />} label="Pause for an hour" />
        <Sep />
        <MenuRow icon={<Settings size={14} />} label="Settings…" right="⌘," />
        <MenuRow label="Quit anyfmt" right="⌘Q" />
      </div>
    </div>
  )
}
function Ext({ e }: { e: string }) {
  return <span className="grid h-[18px] w-[16px] place-items-center rounded-[3px] bg-white text-[6.5px] font-bold text-[#1E1B18] shadow-[0_0_0_.5px_rgba(90,60,30,.3),0_1px_2px_rgba(90,60,30,.15)]">{e}</span>
}
function Sep() { return <div className="mx-2.5 my-1 h-px bg-[#1E1B18]/[.08]" /> }
function MenuRow({ icon, label, right, hot }: { icon?: ReactNode; label: string; right?: ReactNode; hot?: boolean }) {
  return (
    <div className={cn('flex items-center gap-2.5 rounded-[8px] px-2.5 py-[5px]', hot ? 'bg-gradient-to-r from-[#FFC9A0] to-[#FFB27A] text-[#1E1B18] shadow-[0_0_14px_rgba(255,160,100,.45)]' : 'hover:bg-white/70')}>
      <span className="grid w-4 place-items-center text-[#5B524A]">{icon}</span>
      <span className="flex-1 truncate">{label}</span>
      {right && <span className={cn('text-[12px]', hot ? 'text-[#1E1B18]/70' : 'text-[#8A7F74]')}>{right}</span>}
    </div>
  )
}

/* ------------------------------------------------------------------ toasts */

export function ErrorToast() {
  return (
    <div className="aura-frost flex w-max max-w-[500px] items-center gap-3 rounded-full py-2 pl-2 pr-2">
      <span className="grid size-9 shrink-0 place-items-center rounded-full bg-gradient-to-br from-[#FFE1D6] to-[#F7A08A] text-[#7A2A12] shadow-[0_0_16px_rgba(240,130,100,.45)]">
        <AlertCircle size={17} strokeWidth={2.4} />
      </span>
      <span className="flex min-w-0 flex-col leading-tight">
        <span className="text-[13.5px] font-semibold text-[#1E1B18]">clip.mov moved before we finished</span>
        <span className="text-[11.5px] text-[#5B524A]">Nothing was touched. Drop it again and we’ll pick up.</span>
      </span>
      <span className="ml-1 shrink-0 rounded-full bg-[#1E1B18] px-3 py-1.5 text-[11.5px] font-semibold text-[#FFF8F0]">Try again</span>
    </div>
  )
}

export { DoneToast }

/** The whole "App surfaces" board for the brand book. */
export function AppBoard() {
  const w = WHEELS[0]
  return (
    <div className="space-y-10">
      <Desktop className="px-6 py-14 md:px-12">
        <WheelTrio />
      </Desktop>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1.25fr_1fr]">
        <Desktop className="p-6 md:p-10">
          <Label>Options, after you hover GIF</Label>
          <Fit width={720} height={420} className="my-auto">
            <div className="flex h-full items-center gap-6">
              <AuraWheel segments={w.segs} size={340} tone="apricot" hoverIndex={0} interactive={false}
                hubLabel={<span className="aura-serif text-[14px] italic text-[#5B524A]">Convert</span>}
                hubSub={<span className="mt-0.5 text-[11px] font-semibold">clip.mov</span>} />
              <OptionsPanel />
            </div>
          </Fit>
        </Desktop>
        <Desktop className="flex flex-col p-6 md:p-10">
          <Label>Float shelf</Label>
          <div className="grid flex-1 place-items-center py-4"><FloatShelf /></div>
        </Desktop>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_1.1fr]">
        <Desktop className="p-6 md:p-10">
          <Label>Progress, toasts</Label>
          <Fit width={500} height={250} max={1.15} className="my-auto">
            <div className="flex h-full flex-col items-start justify-center gap-5">
              <ProgressHUD />
              <DoneToast name="clip.gif" meta="2.4 MB · saved next to clip.mov" />
              <ErrorToast />
            </div>
          </Fit>
        </Desktop>
        <Desktop className="p-4 md:p-6">
          <Label className="px-2 pt-2">Menu bar</Label>
          <Fit width={620} height={430}><MenuBarScene /></Fit>
        </Desktop>
      </div>
    </div>
  )
}

function Label({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('mb-4 text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]', className)}>{children}</div>
}
