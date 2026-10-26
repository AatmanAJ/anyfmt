import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Check, FolderSearch, Keyboard } from 'lucide-react'
import { Mark, Pixels } from '../Mark'
import { SheetWheel } from '../SheetWheel'
import { isShot } from '../../shared/kit'
import { fileArt, landscape } from './pixel'
import { Key, Lbl, PX, Section, Sub, Win } from './ui'
import { CONVERT } from './wheels'

function Step({ n, title, children, foot, primary = 'Continue', back = true, wide }: {
  n: number; title: ReactNode; children: ReactNode; foot?: ReactNode; primary?: ReactNode; back?: boolean; wide?: boolean
}) {
  return (
    <Win title="Welcome to anyfmt" className={wide ? 'md:col-span-2' : ''}>
      <div className="flex min-h-[440px] flex-col p-6 md:p-8">
        <div className="flex items-center justify-between">
          <span className="shb-lbl text-[var(--sh-graphite)]">{n} / 7</span>
          <span className="flex gap-1">{Array.from({ length: 7 }, (_, i) => <i key={i} className={`block h-[3px] w-4 rounded-full ${i < n ? 'bg-black' : 'bg-[var(--shb-line)]'}`} />)}</span>
        </div>
        <h3 className="sh-display mt-5 text-[30px] md:text-[34px]">{title}</h3>
        <div className="mt-4 flex-1">{children}</div>
        <div className="mt-6 flex items-center justify-between gap-3 border-t border-[var(--shb-line)] pt-4">
          <span className="text-[13px] text-[var(--sh-graphite)]">{foot}</span>
          <div className="flex flex-none gap-2">
            {back && <button className="sh-btn sh-btn-ghost !h-8 !px-4 !text-[14px]">Back</button>}
            {primary && <button className="sh-btn sh-btn-ink !h-8 !px-4 !text-[14px]">{primary}</button>}
          </div>
        </div>
      </div>
    </Win>
  )
}

/** Try it: drag the sample file, press Shift, drop on a wedge. */
function TryIt() {
  const box = useRef<HTMLDivElement>(null)
  const [phase, setPhase] = useState<'idle' | 'drag' | 'wheel' | 'done'>(isShot ? 'wheel' : 'idle')
  const [pos, setPos] = useState({ x: 0.5, y: 0.5 })
  const [at, setAt] = useState({ x: 0.5, y: 0.5 })
  const [aim, setAim] = useState<number | null>(isShot ? 0 : null)
  const [picked, setPicked] = useState<string | null>(null)
  const S = 210

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'Shift' && phase === 'drag') { setAt(pos); setPhase('wheel') }
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [phase, pos])

  const rel = (e: React.PointerEvent) => {
    const r = box.current!.getBoundingClientRect()
    return { x: (e.clientX - r.left) / r.width, y: (e.clientY - r.top) / r.height, r }
  }
  const move = (e: React.PointerEvent) => {
    if (phase !== 'drag' && phase !== 'wheel') return
    const p = rel(e)
    setPos({ x: p.x, y: p.y })
    if (phase === 'wheel') {
      const dx = (p.x - at.x) * p.r.width, dy = (p.y - at.y) * p.r.height, d = Math.hypot(dx, dy)
      if (d < S * 0.17) { setAim(null); return }
      let a = Math.atan2(dx, -dy) + Math.PI / 6
      a = ((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
      setAim(Math.floor(a / (Math.PI / 3)) % 6)
    }
  }
  const up = () => {
    if (phase === 'wheel' && aim !== null) { setPicked(CONVERT[aim].label); setPhase('done') } else if (phase !== 'done') setPhase('idle')
    setAim(null)
  }
  const demo = () => {
    setAt({ x: 0.5, y: 0.5 }); setPos({ x: 0.5, y: 0.5 }); setPhase('wheel'); setAim(0)
    setTimeout(() => { setPicked('GIF'); setPhase('done'); setAim(null) }, 1100)
  }
  const reset = () => { setPhase('idle'); setPicked(null); setPos({ x: 0.5, y: 0.5 }) }

  const dragging = phase === 'drag' || phase === 'wheel'
  return (
    <div>
      <div ref={box} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
        className="sh-dots relative h-[250px] select-none overflow-hidden rounded-[6px] bg-[var(--sh-mist)]" style={{ touchAction: 'none' }}>
        {phase === 'wheel' && (
          <div className="pointer-events-none absolute" style={{ left: `${at.x * 100}%`, top: `${at.y * 100}%`, transform: 'translate(-50%,-50%)' }}>
            <SheetWheel wedges={CONVERT} size={S} active={aim} />
          </div>
        )}
        {phase !== 'done' && (
          <div onPointerDown={(e) => { try { (e.currentTarget.parentElement as HTMLElement).setPointerCapture(e.pointerId) } catch { /* synthetic pointer */ } setPhase('drag'); const p = rel(e); setPos({ x: p.x, y: p.y }) }}
            className={`absolute flex flex-col items-center gap-1 ${dragging ? 'cursor-grabbing' : 'cursor-grab'}`}
            style={{ left: `${pos.x * 100}%`, top: `${pos.y * 100}%`, transform: 'translate(-50%,-50%)', zIndex: 2 }}>
            <Pixels rows={fileArt('MOV', 'k', 'w')} palette={PX} px={3} />
            {phase === 'idle' && <span className="sh-code rounded-[3px] bg-white px-1.5 text-[11px]">sample.mov</span>}
          </div>
        )}
        {phase === 'done' && (
          <div className="absolute inset-0 grid place-items-center">
            <div className="flex items-center gap-3 rounded-[8px] bg-white p-3 pr-4 shb-hair-ink">
              <Pixels rows={fileArt(picked === 'WEBM' ? 'MP4' : (picked ?? 'GIF'), 'o')} palette={PX} px={2} />
              <div><div className="text-[14px] font-[600]">Converted to {picked}</div><div className="text-[12px] text-[var(--sh-graphite)]">sample.{(picked ?? 'gif').toLowerCase()} · on your Desktop</div></div>
            </div>
          </div>
        )}
        <div className="pointer-events-none absolute bottom-2 left-3 flex items-center gap-2">
          <span className="shb-lbl text-[11px]">{phase === 'idle' ? 'Hold the file' : phase === 'drag' ? 'Now press' : phase === 'wheel' ? 'Drop on a format' : 'Done'}</span>
          {phase === 'drag' && <Key size={20}>⇧</Key>}
        </div>
      </div>
      <div className="mt-3 flex gap-3 text-[13px]">
        {phase === 'done' ? <button className="sh-link" onClick={reset}>Try again</button> : <button className="sh-link" onClick={demo}>No trackpad handy? Show me</button>}
      </div>
    </div>
  )
}

function Perm({ icon, title, body }: { icon: ReactNode; title: string; body: string }) {
  const [ok, setOk] = useState(false)
  return (
    <div className="flex flex-col gap-3 border-t border-[var(--shb-line)] py-4 sm:flex-row sm:items-start">
      <span className="mt-[2px]">{icon}</span>
      <div className="flex-1"><div className="text-[15px] font-[600]">{title} <span className="shb-lbl ml-1 text-[11px] text-[var(--sh-graphite)]">optional</span></div><p className="text-[13px] text-[var(--sh-graphite)]">{body}</p></div>
      {ok
        ? <span className="inline-flex h-8 flex-none items-center gap-1.5 px-2 text-[14px] font-[500]"><Check size={16} />Granted</span>
        : <button onClick={() => setOk(true)} className="sh-btn sh-btn-ghost !h-8 flex-none !px-4 !text-[14px]">Open System Settings</button>}
    </div>
  )
}

function Toggle({ on: init, label, body }: { on: boolean; label: string; body: string }) {
  const [on, setOn] = useState(init)
  return (
    <div className="flex items-start gap-4 border-t border-[var(--shb-line)] py-4">
      <div className="flex-1"><div className="text-[15px] font-[600]">{label}</div><p className="text-[13px] text-[var(--sh-graphite)]">{body}</p></div>
      <button role="switch" aria-checked={on} aria-label={label} onClick={() => setOn(!on)} className="shb-toggle mt-1" style={{ background: on ? '#000' : '#C5D3E8' }} />
    </div>
  )
}

function Licence() {
  const [v, setV] = useState('')
  return (
    <div>
      <p className="text-[15px] text-[var(--sh-graphite)]">Everything you’ve seen is free and stays free. Pro adds the parts that need a server: share links, cloud conversions for huge files, transcription and upscaling. $4 a month.</p>
      <label className="mt-5 block">
        <span className="shb-lbl text-[11px]">Licence key</span>
        <input value={v} onChange={(e) => setV(e.target.value)} placeholder="ANYFMT1-01GQP-8K5F1-…" spellCheck={false}
          className="sh-code mt-2 h-10 w-full rounded-[4px] bg-white px-3 text-[14px] outline-none shb-hair focus:shadow-[inset_0_0_0_1px_#000]" />
      </label>
      <div className="mt-3 flex flex-wrap items-center gap-3">
        <button disabled={!v.startsWith('ANYFMT1-')} className="sh-btn sh-btn-ghost !h-8 !px-4 !text-[14px] disabled:opacity-40">Activate</button>
        <span className="text-[13px] text-[var(--sh-graphite)]">Keys are checked on your Mac, offline.</span>
      </div>
    </div>
  )
}

export function Onboarding() {
  return (
    <Section id="onboarding" n={9} label="Onboarding" title={<>Seven windows, <span className="sh-hl">about a minute.</span></>}
      lede="The first run teaches the one gesture by doing it, asks only for optional permissions, and makes skipping Pro the easy choice. Every window works; try step 2.">
      <Sub n="9.1" title="The flow" note="Windows are 520 wide, the same chrome as the app. Back is always a ghost pill; the way forward is always the black one.">
        <div className="grid gap-4 md:grid-cols-2">
          <Step n={1} back={false} primary="Get started" title={<>Convert any file <span className="sh-hl">mid-drag.</span></>} foot="anyfmt lives in your menu bar.">
            <div className="sh-dots grid h-[200px] place-items-center overflow-hidden rounded-[6px] bg-[var(--sh-sky)]">
              <Pixels rows={landscape(92, 36, { cursor: false, files: true })} palette={PX} px={5} style={{ width: '100%' }} />
            </div>
            <p className="mt-4 text-[15px] text-[var(--sh-graphite)]">Drag a file, press a key, and a wheel of everything it can become opens around your pointer. Drop on one. That’s the whole app.</p>
          </Step>

          <Step n={2} title="Try it: drag the file, press Shift." foot="Nothing is saved; this is a sample.">
            <TryIt />
          </Step>

          <Step n={3} title="Two optional extras." foot="Skip both: every drag still works. These only add the Finder Return shortcut.">
            <Perm icon={<Keyboard size={18} strokeWidth={1.5} />} title="Accessibility + Input Monitoring" body="Lets you select a file in Finder and press Return to open the wheel, no drag needed. anyfmt only watches for Return; it never reads what you type." />
            <Perm icon={<FolderSearch size={18} strokeWidth={1.5} />} title="Automation for Finder" body="Lets anyfmt read which file is selected in Finder when you press Return." />
          </Step>

          <Step n={4} title="Three keys, three wheels." foot="Change them later in Settings → Keys.">
            {[['⇧', 'Shift', 'Convert', 'Every format the file can become.'], ['⌘', 'Command', 'Tools', 'Crop, trim, compress, redact, annotate.'], ['⌃', 'Control', 'Actions', 'AirDrop, Float, Copy, Move, Path, Terminal.']].map(([k, n, w, d]) => (
              <div key={n} className="flex items-center gap-4 border-t border-[var(--shb-line)] py-3">
                <Key size={40}>{k}</Key>
                <div className="flex-1"><div className="text-[15px] font-[600]">{w} <span className="font-[400] text-[var(--sh-graphite)]">· {n}</span></div><div className="text-[13px] text-[var(--sh-graphite)]">{d}</div></div>
              </div>
            ))}
          </Step>

          <Step n={5} title="Start at login, stay up to date." foot="You can change both in Settings → General.">
            <Toggle on label="Open at login" body="anyfmt sits in the menu bar and uses no CPU until you drag." />
            <Toggle on={false} label="Check for updates" body="One request a day to anyfmt.app for a signed update feed. Leave it off for zero network calls." />
          </Step>

          <Step n={6} primary={null} title="Pro, if you want it." foot="You can add a key any time in Settings → Pro.">
            <Licence />
            <div className="mt-6 flex flex-col gap-2 sm:flex-row">
              <button className="sh-btn sh-btn-ink justify-center">Skip, keep it free</button>
              <a className="sh-link self-center text-[14px]" href="#onboarding">What’s in Pro?</a>
            </div>
          </Step>

          <Step n={7} back={false} primary="Done" wide title={<>You’re set. <span className="sh-hl">Go drag something.</span></>} foot="Find anyfmt in the menu bar, top right.">
            <div className="grid items-center gap-6 md:grid-cols-[1fr_auto]">
              <ul className="grid gap-2 text-[15px]">
                {['Shift opens Convert, Command opens Tools, Control opens Actions.', 'Converted files land next to the original.', 'Everything ran on this Mac. Nothing was uploaded.'].map((t) => (
                  <li key={t} className="flex gap-2"><Check size={16} className="mt-[3px] flex-none" />{t}</li>
                ))}
              </ul>
              <div className="flex items-center gap-4 rounded-[6px] bg-[var(--sh-lavender)] p-5">
                <Mark size={88} />
                <div className="sh-code text-[13px] leading-[1.6]">793 routes<br />26 tools<br />0 network calls</div>
              </div>
            </div>
          </Step>
        </div>
      </Sub>
      <div className="mt-4"><Lbl>Steps 3, 5 and 6 are live: grant, toggle, paste a key.</Lbl></div>
    </Section>
  )
}
