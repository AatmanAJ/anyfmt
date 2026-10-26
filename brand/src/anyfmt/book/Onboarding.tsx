import { BatteryFull, Check, Eye, Keyboard, MousePointer2, RotateCcw, Settings, Wifi } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { AnyWheel, type Wedge } from '../AnyWheel'
import { convertWedges } from '../copy'
import { FileTile } from '../Demo'
import { Streaks } from '../Landing'
import { AppIcon, GlassTile, Mark } from '../Mark'
import { Fit, Section, useTick } from './kit'

const W = 600, H = 520, STEPS = 7

export function Lights() {
  return (
    <div className="flex gap-2">
      {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c, boxShadow: 'inset 0 0 0 .5px rgba(0,0,0,.18)' }} />)}
    </div>
  )
}

function Win({ step, children, footer }: { step: number; children: ReactNode; footer: ReactNode }) {
  return (
    <div className="flex flex-col overflow-hidden rounded-[18px] bg-white text-[#111]"
      style={{ width: W, height: H, boxShadow: '0 0 0 1px rgba(17,17,17,.12), 0 1px 0 rgba(255,255,255,.8) inset, 0 40px 80px -30px rgba(90,30,0,.45), 0 12px 24px -12px rgba(17,17,17,.2)' }}>
      <div className="relative flex h-[46px] shrink-0 items-center px-4">
        <Lights />
        <span className="absolute left-1/2 -translate-x-1/2 text-[13px] font-semibold text-[#55524F]">Welcome to anyfmt</span>
      </div>
      <div className="relative flex min-h-0 flex-1 flex-col px-8 pb-5 pt-2">{children}</div>
      <div className="flex h-[64px] shrink-0 items-center justify-between border-t border-[#EEECE9] bg-[#FBFBFA] px-6">
        <div className="flex items-center gap-1.5" aria-label={`Step ${step} of ${STEPS}`}>
          {Array.from({ length: STEPS }, (_, i) => (
            <span key={i} className="h-1.5 rounded-full transition-all" style={{ width: i + 1 === step ? 18 : 6, background: i + 1 === step ? '#EA7C25' : i + 1 < step ? '#F2B98B' : '#DAD7D3' }} />
          ))}
        </div>
        <div className="flex items-center gap-2.5">{footer}</div>
      </div>
    </div>
  )
}

const Btn = ({ children, kind = 'primary', onClick }: { children: ReactNode; kind?: 'primary' | 'light' | 'dark'; onClick?: () => void }) => (
  <button type="button" onClick={onClick} className={`af-btn af-btn-${kind} !h-9 !rounded-[10px] !px-4 !text-[13.5px]`}>{children}</button>
)

function Head({ title, sub, small }: { title: ReactNode; sub: ReactNode; small?: boolean }) {
  return (
    <div>
      <h3 className={`${small ? 'text-[30px]' : 'text-[34px]'} font-semibold leading-[0.98] tracking-[-0.05em]`}>{title}</h3>
      <p className={`${small ? 'mt-2' : 'mt-2.5'} max-w-[470px] text-[14.5px] leading-relaxed text-[#55524F]`}>{sub}</p>
    </div>
  )
}

/* 1 · Welcome */
function Welcome() {
  const [aim, setAim] = useState(0)
  useTick(1100, () => setAim((a) => (a + 1) % convertWedges.length))
  return (
    <Win step={1} footer={<Btn>Continue</Btn>}>
      <div className="grid h-full grid-cols-[1fr_250px] items-center gap-6">
        <div className="flex flex-col gap-6">
          <AppIcon size={60} />
          <Head title={<>Any file.<br />Any format.</>} sub="Drag a file, press Shift and drop it on the format you want. Everything runs on this Mac. Local features are free, with no account." />
          <div className="flex flex-wrap gap-1.5 text-[12px] text-[#55524F]">
            {['Free and open source', 'No account', 'No upload'].map((t) => <span key={t} className="rounded-full bg-[#F3F2F0] px-2.5 py-1 ring-1 ring-[#E7E5E2]">{t}</span>)}
          </div>
        </div>
        <div className="af-stage relative grid h-[330px] place-items-center overflow-hidden rounded-[18px]">
          <Streaks className="inset-0 h-full w-full" />
          <AnyWheel wedges={convertWedges} size={214} tone="stage" active={aim} hub={<span className="text-[11px] font-semibold text-[#111]">MOV</span>} />
          <span className="absolute bottom-3 rounded-full bg-white/20 px-2.5 py-0.5 text-[11px] font-medium ring-1 ring-white/35">Convert wheel</span>
        </div>
      </div>
    </Win>
  )
}

/* 2 · Try it: a real drag. Hold the tile, press Shift, aim, let go. */
const IMG: Wedge[] = product.formatsImage.filter((f) => f !== 'HEIC').slice(0, 6).map((f) => ({ id: f, label: f }))
function TryIt() {
  const box = useRef<HTMLDivElement>(null)
  const START = { x: 92, y: 128 }
  const [pos, setPos] = useState(isShot ? { x: 342, y: 46 } : START)
  const [phase, setPhase] = useState<'idle' | 'drag' | 'wheel' | 'pick' | 'done'>(isShot ? 'wheel' : 'idle')
  const [at, setAt] = useState(isShot ? { x: 250, y: 140 } : START)
  const [aim, setAim] = useState<number | null>(isShot ? 0 : null)
  const [made, setMade] = useState('')
  const R = 100
  const local = (e: { clientX: number; clientY: number }) => {
    const r = box.current!.getBoundingClientRect(), s = r.width / box.current!.offsetWidth
    return { x: (e.clientX - r.left) / s, y: (e.clientY - r.top) / s }
  }
  const aimAt = (p: { x: number; y: number }, c: { x: number; y: number }) => {
    const dx = p.x - c.x, dy = p.y - c.y
    if (Math.hypot(dx, dy) < R * 0.37) return null
    const step = (Math.PI * 2) / IMG.length
    let a = Math.atan2(dx, -dy) + step / 2
    a = ((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
    return Math.floor(a / step)
  }
  const openAt = (p: { x: number; y: number }) => {
    const c = { x: Math.min(Math.max(p.x, R + 6), 536 - R - 6), y: Math.min(Math.max(p.y, R + 6), 256 - R - 6) }
    setAt(c)
  }
  useEffect(() => {
    if (isShot) return
    const down = (e: KeyboardEvent) => {
      if (e.key !== 'Shift') return
      setPhase((ph) => { if (ph === 'drag') { openAt(posRef.current); return 'wheel' } return ph })
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [])
  const posRef = useRef(pos)
  posRef.current = pos
  const finish = (i: number) => { setMade(`Sample.${IMG[i].label.toLowerCase()}`); setPhase('done') }
  const reset = () => { setPhase('idle'); setPos(START); setAim(null) }
  const wheelOpen = phase === 'wheel' || phase === 'pick'
  return (
    <Win step={2} footer={<><Btn kind="light">Back</Btn><Btn>Continue</Btn></>}>
      <Head title="Try it." sub={<>Drag the sample file, and press <b className="font-semibold text-[#111]">Shift</b> while you hold it. Aim at a format and let go.</>} />
      <div ref={box} className="af-well relative mt-5 h-[256px] w-[536px] touch-none select-none overflow-hidden"
        onPointerMove={(e) => {
          if (phase !== 'drag' && phase !== 'wheel') return
          const p = local(e); setPos(p)
          if (phase === 'wheel') setAim(aimAt(p, at))
        }}
        onPointerUp={() => {
          if (phase === 'wheel' && aim != null) finish(aim)
          else if (phase === 'drag' || phase === 'wheel') reset()
        }}>
        <div className="absolute inset-0 opacity-60" style={{ background: 'radial-gradient(70% 80% at 80% 100%, #FCE6D2, transparent 70%)' }} />
        {wheelOpen && (
          <div className="absolute" style={{ left: at.x - R, top: at.y - R }}>
            <AnyWheel wedges={IMG} size={R * 2} active={phase === 'pick' ? undefined : aim}
              onPick={(_, i) => finish(i)} hub={<span className="text-[10px] font-semibold text-[#111]">HEIC</span>} />
          </div>
        )}
        {phase !== 'done' && (
          <div className="absolute z-10 cursor-grab active:cursor-grabbing" style={{ left: pos.x - 32, top: pos.y - 48, transform: phase === 'idle' ? undefined : 'rotate(-5deg) scale(.86)', transition: phase === 'idle' ? 'left .3s, top .3s' : undefined, pointerEvents: wheelOpen && phase === 'pick' ? 'none' : undefined }}
            onPointerDown={(e) => { if (phase !== 'idle') return; (e.currentTarget.parentElement as HTMLElement).setPointerCapture(e.pointerId); setPhase('drag') }}>
            <FileTile name="Sample.heic" ext="HEIC" />
          </div>
        )}
        {phase === 'done' && (
          <div className="absolute inset-0 grid place-items-center">
            <div className="flex items-center gap-3 rounded-[14px] bg-white p-3 pr-4 shadow-[0_0_0_1px_rgba(17,17,17,.07),0_14px_30px_-16px_rgba(90,30,0,.45)]">
              <span className="grid size-8 place-items-center rounded-full bg-[#E9F7EF] text-[#1F9D55]"><Check size={16} strokeWidth={3} /></span>
              <div className="text-[13px] leading-snug"><div className="font-semibold">{made} is ready</div><div className="text-[#55524F]">That’s the whole app.</div></div>
              <button type="button" onClick={reset} className="ml-2 grid size-7 place-items-center rounded-full bg-[#F3F2F0] text-[#55524F]" aria-label="Try again"><RotateCcw size={13} /></button>
            </div>
          </div>
        )}
        <div className="absolute bottom-3 right-3 z-20 flex items-center gap-2">
          <span className="rounded-full bg-white/80 px-2.5 py-1 text-[11px] font-medium text-[#55524F] shadow-[0_0_0_1px_#E7E5E2]">
            {phase === 'idle' ? 'Hold the file…' : phase === 'drag' ? '…now press Shift' : wheelOpen ? (aim != null ? `Let go on ${IMG[aim].label}` : 'Aim at a format') : 'Done'}
          </span>
          <button type="button" aria-label="Press Shift" onClick={() => { if (phase === 'idle') { openAt(pos); setPhase('pick') } }}
            className="af-key !h-12 !w-12 !rounded-[11px] !p-[6px_8px]"
            style={wheelOpen || phase === 'drag' ? { boxShadow: 'inset 0 1px 0 #fff, inset 0 -1px 0 #E2E0DC, 0 0 0 1.5px #E5701E', transform: 'translateY(2px)' } : undefined}>
            <span className="text-[15px] leading-none" style={{ color: wheelOpen ? '#E5701E' : '#111' }}>⇧</span>
            <span className="text-[8.5px] font-medium text-[#8C8884]">shift</span>
          </button>
        </div>
      </div>
    </Win>
  )
}

/* 3 · Permission coach */
const PERMS = [
  { icon: <Eye size={15} />, name: 'Accessibility', why: 'Lets anyfmt catch Return in Finder before Finder starts renaming the file.' },
  { icon: <Keyboard size={15} />, name: 'Input Monitoring', why: 'Lets anyfmt notice Return while Finder is in front. Other keys pass through untouched.' },
  { icon: <MousePointer2 size={15} />, name: 'Automation for Finder', why: 'Lets anyfmt ask Finder which files are selected. Nothing else is read.' },
]
export function Toggle({ on, onClick, label }: { on: boolean; onClick?: () => void; label: string }) {
  return <button type="button" role="switch" aria-checked={on} aria-label={label} onClick={onClick} className="afb-toggle" data-on={on} />
}
function Permissions() {
  const [shortcut, setShortcut] = useState(true)
  const [granted, setGranted] = useState([true, false, false])
  const [waiting, setWaiting] = useState<number | null>(null)
  const grant = (i: number) => {
    setWaiting(i)
    setTimeout(() => { setGranted((g) => g.map((v, j) => (j === i ? true : v))); setWaiting(null) }, 1400)
  }
  return (
    <Win step={3} footer={<><Btn kind="light">Back</Btn><Btn>Continue</Btn></>}>
      <Head small title="No permissions needed." sub="The wheel works without any special access. There’s nothing to approve." />
      <div className="mt-3.5 overflow-hidden rounded-[14px] bg-white shadow-[0_0_0_1px_#E7E5E2,0_8px_20px_-14px_rgba(17,17,17,.2)]">
        <div className="flex items-center gap-4 px-4 py-2.5">
          <div className="min-w-0 flex-1 text-[13px] leading-snug">
            <div className="font-semibold">Optional: press Return in Finder to open the wheel</div>
            <div className="text-[#55524F]">Select files and press Return instead of dragging. This one extra needs the permissions below.</div>
          </div>
          <Toggle on={shortcut} onClick={() => setShortcut(!shortcut)} label="Finder Return shortcut" />
        </div>
        {shortcut && PERMS.map((p, i) => (
          <div key={p.name} className="flex items-center gap-3 border-t border-[#EEECE9] bg-[#FCFCFB] px-4 py-2">
            <span className="grid size-7 shrink-0 place-items-center rounded-[8px] bg-[#FFF3E6] text-[#B4570F]">{p.icon}</span>
            <div className="min-w-0 flex-1 text-[12px] leading-[1.3]"><div className="font-semibold">{p.name}</div><div className="text-[#55524F]">{p.why}</div></div>
            {granted[i]
              ? <span className="af-pill-status !h-7 shrink-0 !bg-[#E9F7EF] !px-2.5 !text-[12px] !text-[#1F7A45] !shadow-[inset_0_0_0_1px_#BFE6CF]">Granted <Check size={12} strokeWidth={3} /></span>
              : <button type="button" onClick={() => grant(i)} className="af-btn af-btn-light !h-7 shrink-0 !gap-1.5 !rounded-[8px] !px-2.5 !text-[12px]">
                  {waiting === i ? <span className="afb-pulse">Waiting for you…</span> : <><Settings size={12} />Open System Settings</>}
                </button>}
          </div>
        ))}
      </div>
      <p className="mt-auto pt-2 text-[12px] leading-snug text-[#8C8884]">Prefer no permissions at all? Right-click files › Services › Open in anyfmt Wheel does the same.</p>
    </Win>
  )
}

/* 4 · Pick your keys */
const SYMBOL: Record<string, [string, string]> = { Shift: ['⇧', 'shift'], Meta: ['⌘', 'command'], Control: ['⌃', 'control'], Alt: ['⌥', 'option'] }
function Keys() {
  const DEF = ['Shift', 'Meta', 'Control']
  const [keys, setKeys] = useState(DEF)
  const [rec, setRec] = useState<number | null>(null)
  useEffect(() => {
    if (rec === null) return
    const down = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setRec(null); return }
      if (!(e.key in SYMBOL)) return
      e.preventDefault()
      setKeys((ks) => {
        const next = [...ks], clash = next.indexOf(e.key)
        if (clash >= 0) next[clash] = next[rec]
        next[rec] = e.key
        return next
      })
      setRec(null)
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [rec])
  const rows = [['Convert', 'Every format the file can become.'], ['Tools', 'Crop, trim, compress, redact, annotate.'], ['Actions', 'AirDrop, Float, Copy, Move, Path, Terminal.']]
  return (
    <Win step={4} footer={<><Btn kind="light" onClick={() => setKeys(DEF)}><RotateCcw size={13} />Reset</Btn><Btn>Continue</Btn></>}>
      <Head title="Pick your keys." sub="Hold one while you drag to open its wheel. Click a key to change it, then press the one you want." />
      <div className="mt-5 flex flex-col gap-2.5">
        {rows.map(([n, b], i) => {
          const [sym, lab] = SYMBOL[keys[i]]
          const on = rec === i
          return (
            <div key={n} className="flex items-center gap-4 rounded-[14px] bg-white px-4 py-3 shadow-[0_0_0_1px_#E7E5E2]">
              <div className="min-w-0 flex-1">
                <div className="text-[16px] font-semibold tracking-[-0.02em]">{n}</div>
                <div className="text-[13px] text-[#55524F]">{b}</div>
              </div>
              {on && <span className="afb-pulse text-[12px] font-medium text-[#B4570F]">Press a modifier…</span>}
              <button type="button" onClick={() => setRec(on ? null : i)} aria-label={`${n} key: ${lab}. Click to change`} className="rounded-[14px] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#111]">
                <span className="af-key !h-[56px] !w-[64px]" style={on ? { boxShadow: 'inset 0 1px 0 #fff, inset 0 -1px 0 #E2E0DC, 0 0 0 2px #E5701E, 0 0 0 6px rgba(234,124,37,.18)', transform: 'translateY(2px)' } : undefined}>
                  <span className="text-[18px] leading-none" style={{ color: on ? '#E5701E' : '#111' }}>{sym}</span>
                  <span className="text-[10px] font-medium text-[#8C8884]">{lab}</span>
                </span>
              </button>
            </div>
          )
        })}
      </div>
      <p className="mt-auto text-[12px] text-[#8C8884]">Tap Option mid-drag to lock the wedge you are on.</p>
    </Win>
  )
}

/* 5 · Launch at login, updates */
function Launch() {
  const [login, setLogin] = useState(true)
  const [updates, setUpdates] = useState(false)
  return (
    <Win step={5} footer={<><Btn kind="light">Back</Btn><Btn>Continue</Btn></>}>
      <Head title={<>Ready when<br />you drag.</>} sub="anyfmt lives in the menu bar, with no Dock icon and no window. Start it with your Mac so the wheel is always there." />
      <div className="mt-6 overflow-hidden rounded-[14px] bg-white shadow-[0_0_0_1px_#E7E5E2,0_8px_20px_-14px_rgba(17,17,17,.2)]">
        <div className="flex items-center gap-4 px-4 py-3.5">
          <div className="flex-1 text-[13px] leading-snug"><div className="font-semibold">Open anyfmt at login</div><div className="text-[#55524F]">Adds anyfmt to System Settings › General › Login Items.</div></div>
          <Toggle on={login} onClick={() => setLogin(!login)} label="Open at login" />
        </div>
        <div className="flex items-center gap-4 border-t border-[#EEECE9] px-4 py-3.5">
          <div className="flex-1 text-[13px] leading-snug"><div className="font-semibold">Check for updates automatically</div><div className="text-[#55524F]">Once a day, asks anyfmt.app for the latest version number. Nothing about you or your files is sent.</div></div>
          <Toggle on={updates} onClick={() => setUpdates(!updates)} label="Check for updates" />
        </div>
      </div>
      <p className="mt-auto text-[12px] leading-snug text-[#8C8884]">Updates are off unless you turn them on. anyfmt never connects to the internet unless you ask it to.</p>
    </Win>
  )
}

/* 6 · Optional Pro licence */
const SAMPLE_KEY = 'ANYFMT1-01GQP-8K5F1-R24EK-7Q4KM-H58HG-2'
function Pro() {
  const [key, setKey] = useState(isShot ? SAMPLE_KEY : '')
  const valid = /^ANYFMT1-[0-9A-HJKMNP-TV-Z]{5}(-[0-9A-HJKMNP-TV-Z]{1,5}){3,}$/i.test(key.trim())
  const bad = key.trim().length > 6 && !valid
  return (
    <Win step={6} footer={<><Btn kind="light">Skip for now</Btn><Btn>{valid ? 'Activate and continue' : 'Continue without Pro'}</Btn></>}>
      <Head title={<>Got a<br />Pro key?</>} sub="Optional. Pro adds cloud features like share links and cloud conversions. Nothing local ever needs a key, so skipping changes nothing." />
      <label className="mt-6 block text-[12px] font-semibold text-[#55524F]" htmlFor="bk-key">Licence key</label>
      <div className={`mt-1.5 flex h-11 items-center gap-2 rounded-[12px] bg-white pl-3.5 pr-1.5 ${valid ? 'shadow-[0_0_0_1.5px_#1F9D55,0_0_0_5px_rgba(31,157,85,.12)]' : bad ? 'shadow-[0_0_0_1.5px_#BB3F14]' : 'shadow-[inset_0_1px_2px_rgba(17,17,17,.08),0_0_0_1px_#D9D6D2]'}`}>
        <input id="bk-key" value={key} onChange={(e) => setKey(e.target.value)} placeholder="ANYFMT1-…" spellCheck={false}
          className="af-mono min-w-0 flex-1 bg-transparent text-[13px] tracking-[-0.02em] text-[#111] outline-none placeholder:text-[#8C8884]" />
        {!key && <button type="button" onClick={() => setKey(SAMPLE_KEY)} className="af-btn af-btn-light !h-8 !rounded-[8px] !px-2.5 !text-[12px]">Paste</button>}
      </div>
      <div className="mt-2 min-h-[36px] text-[12.5px] leading-snug">
        {valid && <div className="flex items-start gap-2 text-[#1F7A45]"><span className="mt-[1px] grid size-4 shrink-0 place-items-center rounded-full bg-[#1F9D55] text-white"><Check size={10} strokeWidth={3.5} /></span><span><b className="font-semibold">Pro licence, valid until 26 October 2027.</b> Checked on this Mac, offline. Nothing was sent.</span></div>}
        {bad && <div className="text-[#BB3F14]">That doesn’t look like an anyfmt key. Keys start with ANYFMT1- and come from your receipt email.</div>}
        {!key && <div className="text-[#8C8884]">The key is verified on this Mac with a signature check. It never needs the internet.</div>}
      </div>
      <p className="mt-auto text-[12px] text-[#8C8884]">You can do this later in Settings › Account.</p>
    </Win>
  )
}

/* 7 · Done */
function Done() {
  return (
    <Win step={7} footer={<Btn>Start using anyfmt</Btn>}>
      <div className="af-stage relative -mx-8 -mt-2 grid h-[236px] place-items-center overflow-hidden">
        <Streaks className="inset-0 h-full w-full" />
        <div className="absolute inset-x-0 top-0 flex h-7 items-center justify-end gap-3 bg-white/25 px-4 text-[11.5px] font-medium text-[#111] backdrop-blur">
          <span className="grid h-[20px] place-items-center rounded-[5px] bg-black/10 px-1"><Mark size={14} variant="mono" /></span><Wifi size={13} /><BatteryFull size={16} /><span>Mon 9:41</span>
        </div>
        <span className="absolute right-[92px] top-9 rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#111] shadow-[0_6px_14px_-6px_rgba(90,30,0,.5)]">anyfmt lives up here</span>
        <div className="mt-6"><GlassTile size={128} /></div>
      </div>
      <div className="flex flex-1 items-center justify-between gap-6 pt-2">
        <Head title="You’re set." sub="anyfmt is in your menu bar. Drag any file and press a key." />
        <div className="flex shrink-0 gap-2 pb-1">
          {product.keys.map((k) => (
            <div key={k.key} className="flex flex-col items-center gap-1.5">
              <span className="af-key !h-12 !w-12 !rounded-[11px] !items-center !justify-center !p-0 !text-[17px]">{k.key}</span>
              <span className="text-[11px] font-medium text-[#55524F]">{k.wheel}</span>
            </div>
          ))}
        </div>
      </div>
    </Win>
  )
}

const SCREENS: { n: string; name: string; note: string; el: ReactNode }[] = [
  { n: '1', name: 'Welcome', note: 'The promise, and a live wheel.', el: <Welcome /> },
  { n: '2', name: 'Try it', note: 'A real drag: hold the file, press Shift, let go.', el: <TryIt /> },
  { n: '3', name: 'Permissions', note: 'None needed. One optional extra explains its own.', el: <Permissions /> },
  { n: '4', name: 'Your keys', note: 'Click a keycap, press the modifier you want.', el: <Keys /> },
  { n: '5', name: 'Login and updates', note: 'Launch at login on. Updates opt-in.', el: <Launch /> },
  { n: '6', name: 'Pro, optional', note: 'Paste a key, verified offline. Skipping changes nothing.', el: <Pro /> },
  { n: '7', name: 'Done', note: 'The three keys, once more.', el: <Done /> },
]

export function Onboarding() {
  return (
    <Section id="onboarding" n="08" eyebrow="Onboarding" title={<>Seven calm screens.<br /><span className="text-[#8C8884]">One real drag.</span></>}
      intro="First launch opens a small window that teaches the gesture by doing it. Nothing is required: no account, no permission, no key. Every screen below works; try them.">
      <div className="grid gap-x-6 gap-y-12 lg:grid-cols-2">
        {SCREENS.map((s, i) => (
          <div key={s.n} className={`flex min-w-0 flex-col gap-4 ${i === SCREENS.length - 1 ? 'lg:col-span-2 lg:mx-auto lg:w-[600px]' : ''}`}>
            <div className="flex flex-wrap items-baseline gap-x-3 gap-y-0.5">
              <span className="af-mono text-[12px] text-[#EA7C25]">{s.n.padStart(2, '0')}</span>
              <span className="whitespace-nowrap text-[16px] font-semibold tracking-[-0.02em]">{s.name}</span>
              <span className="text-[13px] text-[#8C8884] max-sm:basis-full">{s.note}</span>
            </div>
            <div className="rounded-[26px] p-3 sm:p-5" style={{ background: 'radial-gradient(80% 70% at 30% 20%, #FFE3C8 0%, transparent 60%), linear-gradient(160deg,#FBEBDD,#F6D3B2 60%,#F0B587)' }}>
              <Fit w={W} h={H}>{s.el}</Fit>
            </div>
          </div>
        ))}
      </div>
    </Section>
  )
}
