import { motion } from 'motion/react'
import { ChevronDown } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { AppIcon, Led, Mark, MenuGlyph } from './Mark'
import { SignalFile } from './SignalDemo'
import { SignalWheel } from './SignalWheel'
import { C, vibrancy, wheels } from './tokens'
import { Label } from './ui'

/** An onboarding window: dark vibrancy, 22 px radius, a dot progress meter in the title bar. */
function Win({ step, title, body, visual, primary, secondary, className }: {
  step: number; title: ReactNode; body: ReactNode; visual: ReactNode; primary: string; secondary?: string; className?: string
}) {
  return (
    <div className={cn('relative flex flex-col overflow-hidden rounded-[22px] font-geist', className)} style={{ ...vibrancy, background: 'rgba(16,16,18,.86)', color: C.bone }}>
      <div className="flex h-11 items-center justify-between px-4">
        <div className="flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c, opacity: 0.9 }} />)}</div>
        <div className="flex items-center gap-1.5" aria-label={`Step ${step} of 6`}>
          {Array.from({ length: 6 }, (_, i) => (
            <span key={i} className="rounded-full" style={{ width: i + 1 === step ? 14 : 5, height: 5, background: i + 1 === step ? C.solar : i + 1 < step ? C.ash : C.graphite2, boxShadow: i + 1 === step ? '0 0 8px rgba(215,255,58,.6)' : 'none' }} />
          ))}
        </div>
        <Label dim>{String(step).padStart(2, '0')} / 06</Label>
      </div>
      <div className="relative mx-3 grid h-[208px] place-items-center overflow-hidden rounded-[14px]" style={{ background: 'radial-gradient(80% 90% at 50% 0%, #17171A, #0A0A0B)', boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
        <div className="pointer-events-none absolute inset-0" style={{ backgroundImage: 'radial-gradient(circle, rgba(237,237,230,.07) 1px, transparent 1.4px)', backgroundSize: '12px 12px' }} />
        <div className="relative">{visual}</div>
      </div>
      <div className="flex flex-1 flex-col px-6 pb-5 pt-5">
        <h4 className="font-serif text-[30px] leading-[1.02] tracking-[-0.02em]">{title}</h4>
        <p className="mt-2 max-w-[44ch] text-[13.5px] leading-[1.55]" style={{ color: C.ash }}>{body}</p>
        <div className="mt-auto flex items-center justify-end gap-2 pt-5">
          {secondary && <span className="rounded-full px-4 py-2 text-[13px]" style={{ color: C.bone, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>{secondary}</span>}
          <span className="rounded-full px-4 py-2 text-[13px] font-semibold" style={{ background: C.solar, color: C.void, boxShadow: '0 0 20px -6px rgba(215,255,58,.6)' }}>{primary}</span>
        </div>
      </div>
    </div>
  )
}

function Toggle({ on }: { on: boolean }) {
  return (
    <span className="relative inline-block h-[22px] w-[38px] rounded-full transition-colors" style={{ background: on ? C.solar : C.graphite2 }}>
      <motion.span className="absolute top-[2px] size-[18px] rounded-full shadow" style={{ background: on ? C.void : C.bone }} animate={{ left: on ? 18 : 2 }} transition={{ type: 'spring', stiffness: 600, damping: 32 }} />
    </span>
  )
}

function Select({ k, v }: { k: string; v: string }) {
  return (
    <span className="flex items-center gap-2 rounded-[7px] px-2.5 py-1.5 text-[12px]" style={{ background: C.carbon2, boxShadow: `inset 0 0 0 0.5px rgba(255,255,255,.12)` }}>
      <span>{k}</span><span style={{ color: C.ash }}>{v}</span><ChevronDown size={12} style={{ color: C.ash }} />
    </span>
  )
}

export function Onboarding() {
  const [granted, setGranted] = useState(false)
  return (
    <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
      <Win step={1} title={<>Welcome to <i>Halo.</i></>} body="Drag a file. Press a key. Drop on the wheel. Setup takes under a minute." primary="Begin"
        visual={<div className="flex flex-col items-center gap-4"><Mark size={104} animate /><Label>v1 · local · AGPL-3.0</Label></div>} />

      <Win step={2} title={<>Let Halo <i>see the drag.</i></>} secondary="Later" primary={granted ? 'Continue' : 'Open Settings'}
        body="macOS asks for Accessibility so Halo can notice a drag and a key press. Nothing is recorded or sent."
        visual={
          <button type="button" onClick={() => setGranted((g) => !g)} className="flex w-[290px] max-w-[calc(100vw-96px)] flex-col gap-3 text-left outline-none">
            <div className="flex items-center gap-3 rounded-[12px] px-3 py-2.5" style={{ background: C.carbon2, boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,.1)' }}>
              <AppIcon size={34} />
              <div className="flex-1"><div className="text-[13px] font-medium">Halo</div><div className="text-[11px]" style={{ color: C.ash }}>Accessibility</div></div>
              <Toggle on={granted} />
            </div>
            <span className="flex items-center gap-2 pl-1 font-mono text-[10px] uppercase tracking-[0.16em]" style={{ color: granted ? C.solar : C.ash }}>
              <Led size={5} on blink={!granted} color={granted ? C.solar : '#FEBC2E'} /> {granted ? 'Granted · listening' : 'Waiting for access · tap to grant'}
            </span>
          </button>
        } />

      <Win step={3} title={<>Try it. <i>Drag this file.</i></>} secondary="Skip" primary="Next"
        body="Hold it, press ⇧, and drop on JPG. The real wheel, on a practice file."
        visual={
          <div className="flex items-center gap-3">
            <div className="flex flex-col items-center gap-2"><SignalFile ext="PNG" name="practice.png" size={40} /></div>
            <svg width="30" height="12" aria-hidden><path d="M0 6h24" stroke={C.graphite2} strokeDasharray="3 4" /><path d="M22 2l5 4-5 4" fill="none" stroke={C.ash} /></svg>
            <div className="relative">
              <SignalWheel segments={wheels[0].segs.slice(0, 6).map((s, i) => (i === 0 ? { ...s, label: 'JPG', sub: undefined } : { ...s, sub: undefined }))} size={156} hoverIndex={0} interactive={false} channels={false}
                hub={<span className="font-geist text-[17px]" style={{ color: C.solar }}>⇧</span>} />
            </div>
          </div>
        } />

      <Win step={4} title={<>Pick <i>your keys.</i></>} primary="Next" secondary="Back"
        body="The defaults suit most hands. Change them any time in Settings."
        visual={
          <div className="flex w-[300px] max-w-[calc(100vw-96px)] flex-col gap-1.5">
            {wheels.map((w, i) => (
              <div key={w.wheel} className="flex items-center justify-between gap-3 rounded-[10px] px-2.5 py-2" style={{ background: i === 0 ? 'rgba(215,255,58,.07)' : 'transparent', boxShadow: i === 0 ? 'inset 0 0 0 1px rgba(215,255,58,.35)' : `inset 0 0 0 1px ${C.graphite}` }}>
                <span className="flex items-center gap-2.5"><Led size={5} on={i === 0} /><span className="font-serif text-[20px] leading-none">{w.wheel}</span></span>
                <Select k={w.key} v={w.name} />
              </div>
            ))}
          </div>
        } />

      <Win step={5} title={<>Local is everything. <i>Pro is optional.</i></>} primary="Continue free" secondary="Add licence"
        body="Every conversion, tool and action is free and open source. Pro adds cloud extras for $4 a month."
        visual={
          <div className="grid w-[300px] max-w-[calc(100vw-96px)] grid-cols-2 gap-2">
            {[['Local', 'Free', true], ['Pro', '$4/mo', false]].map(([n, p, on]) => (
              <div key={n as string} className="flex flex-col gap-3 rounded-[12px] p-3" style={{ background: on ? 'rgba(215,255,58,.07)' : C.carbon2, boxShadow: `inset 0 0 0 1px ${on ? 'rgba(215,255,58,.4)' : C.graphite}` }}>
                <span className="flex items-center gap-1.5"><Led size={5} on={on as boolean} /><Label style={{ color: C.bone }}>{n as string}</Label></span>
                <span className="font-serif text-[32px] leading-none">{p as string}</span>
                <span className="font-mono text-[9.5px] uppercase tracking-[0.12em]" style={{ color: C.ash }}>{on ? 'Everything local' : 'Cloud extras'}</span>
              </div>
            ))}
          </div>
        } />

      <Win step={6} title={<>Ready. <i>793 routes armed.</i></>} primary="Finish"
        body="Halo lives in the menu bar. Drag any file to start. Press Esc mid-drag to cancel."
        visual={
          <div className="flex w-[300px] max-w-[calc(100vw-96px)] flex-col items-end gap-2">
            <div className="flex h-[24px] w-full items-center justify-end gap-3 rounded-[6px] px-2.5 text-[11.5px]" style={{ background: 'rgba(30,30,33,.9)' }}>
              <span className="grid h-[20px] w-[28px] place-items-center rounded-[5px]" style={{ background: 'rgba(215,255,58,.22)', boxShadow: '0 0 14px rgba(215,255,58,.35)', color: C.solar }}><MenuGlyph size={15} /></span>
              <span className="font-medium tabular-nums">Mon 9:41</span>
            </div>
            <span className="relative mr-[30px] rounded-[8px] px-2.5 py-1.5 font-mono text-[10px] uppercase tracking-[0.14em]" style={{ background: C.solar, color: C.void }}>
              Halo lives here
              <span className="absolute -top-1 left-1/2 size-2 -translate-x-1/2 rotate-45" style={{ background: C.solar }} />
            </span>
          </div>
        } />
    </div>
  )
}
