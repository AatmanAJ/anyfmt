import { Check, ChevronRight, Lock, ShieldCheck } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { CobaltWheel, Hub } from './CobaltWheel'
import { Mark, MenuGlyph, Wordmark } from './Logo'
import { C, FLAME_GRAD } from './tokens'
import { CobaltFile, DoneToast, KeyCap, convertSegs } from './ui'

function Btn({ children, ghost }: { children: ReactNode; ghost?: boolean }) {
  return (
    <span className="inline-flex h-9 items-center gap-1.5 whitespace-nowrap rounded-[10px] px-4 font-anton text-[14px] uppercase leading-none tracking-[0.06em]"
          style={ghost ? { color: C.ice, boxShadow: 'inset 0 0 0 1.5px rgba(233,238,255,.3)' } : { background: C.flame, color: C.midnight, boxShadow: '0 0 18px rgba(255,106,43,.45)' }}>
      {children}
    </span>
  )
}

/** One onboarding window: native chrome, a band panel with the racing number, content on midnight glass. */
function OnbWindow({ step, side, title, children, footer }: { step: number; side?: ReactNode; title: ReactNode; children: ReactNode; footer: ReactNode }) {
  return (
    <div className="overflow-hidden rounded-[22px] font-geist"
         style={{ background: C.midnight, color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14), 0 40px 80px -30px rgba(2,5,22,.9)' }}>
      {/* titlebar */}
      <div className="relative flex h-10 items-center px-4" style={{ background: 'rgba(233,238,255,.03)', borderBottom: '1px solid rgba(233,238,255,.08)' }}>
        <div className="flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}</div>
        <div className="absolute left-1/2 flex -translate-x-1/2 gap-1">
          {Array.from({ length: 6 }).map((_, i) => (
            <span key={i} className="h-1.5 w-6 -skew-x-12 rounded-[1px]" style={{ background: i < step ? C.flame : i === step ? C.ice : 'rgba(233,238,255,.18)' }} />
          ))}
        </div>
        <span className="ml-auto font-mono text-[10px] uppercase tracking-[0.16em] opacity-50">Setup</span>
      </div>
      <div className="grid min-h-[330px] grid-cols-1 sm:grid-cols-[132px_1fr]">
        <div className="relative hidden overflow-hidden sm:block">
          <div className="absolute inset-0 flex">
            {[C.ultra, C.cobalt, C.ultra, '#0E22B8'].map((b, i) => <div key={i} className="flex-1" style={{ background: b }} />)}
          </div>
          <div className="absolute left-3 top-3 font-anton text-[84px] leading-[0.8]" style={{ color: C.ice, transform: 'skewX(-8deg)' }}>{String(step + 1).padStart(2, '0')}</div>
          <div className="absolute bottom-4 left-0 right-0 flex justify-center">{side}</div>
        </div>
        <div className="flex flex-col p-6">
          <div className="font-anton text-[34px] uppercase leading-[0.9]">{title}</div>
          <div className="mt-3 flex-1">{children}</div>
          <div className="mt-5 flex items-center justify-end gap-2">{footer}</div>
        </div>
      </div>
    </div>
  )
}

function Toggle({ on }: { on: boolean }) {
  return (
    <span className="relative inline-block h-[22px] w-[38px] rounded-full transition-colors" style={{ background: on ? C.flame : 'rgba(233,238,255,.18)' }}>
      <span className="absolute top-[2px] size-[18px] rounded-full bg-white shadow" style={{ left: on ? 18 : 2 }} />
    </span>
  )
}

export function Onboarding() {
  return (
    <div className="grid gap-6 lg:grid-cols-2">
      {/* 1 · Welcome */}
      <OnbWindow step={0} side={<Mark size={64} />} title={<>Hey. <span style={{ color: C.flame }}>Let's go fast.</span></>}
        footer={<Btn>Start <ChevronRight size={15} strokeWidth={3} /></Btn>}>
        <div className="flex h-full flex-col justify-between gap-5">
          <p className="max-w-[34ch] text-[14px] leading-relaxed text-[#E9EEFF]/80">Halo lives in your menu bar. Drag a file, press a key, drop it on the wheel. You'll have it in ten seconds.</p>
          <div className="flex items-center gap-3">
            <Wordmark size={54} />
            <span className="rounded-[6px] px-2 py-1 font-mono text-[10px] uppercase tracking-[0.14em]" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.25)' }}>Local · AGPL-3.0</span>
          </div>
        </div>
      </OnbWindow>

      {/* 2 · Accessibility */}
      <OnbWindow step={1} side={<ShieldCheck size={44} strokeWidth={2} />} title="Let Halo see the drag."
        footer={<><Btn ghost>Why?</Btn><Btn>Open System Settings</Btn></>}>
        <p className="max-w-[40ch] text-[14px] leading-relaxed text-[#E9EEFF]/80">macOS asks first. Halo needs Accessibility to notice a drag and the key you press. That's all it looks at.</p>
        <div className="mt-4 overflow-hidden rounded-[12px]" style={{ background: 'rgba(233,238,255,.06)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
          <div className="px-3 py-1.5 font-mono text-[10px] uppercase tracking-[0.14em] opacity-50">Privacy & Security › Accessibility</div>
          {[['Halo', true], ['Terminal', false]].map(([n, on]) => (
            <div key={String(n)} className="flex items-center gap-3 border-t px-3 py-2.5" style={{ borderColor: 'rgba(233,238,255,.08)' }}>
              {n === 'Halo'
                ? <span className="grid size-7 place-items-center rounded-[7px]" style={{ background: C.cobalt }}><Mark size={20} /></span>
                : <span className="grid size-7 place-items-center rounded-[7px] bg-black font-mono text-[10px]">&gt;_</span>}
              <span className="text-[13px] font-medium">{n}</span>
              <span className="ml-auto"><Toggle on={on as boolean} /></span>
            </div>
          ))}
        </div>
        <div className="mt-3 flex items-center gap-2 font-mono text-[11px]" style={{ color: C.flame }}><Check size={14} strokeWidth={3} /> Granted. Nice.</div>
      </OnbWindow>

      {/* 3 · Practice */}
      <OnbWindow step={2} side={<KeyCap sym="⇧" name="shift" size="sm" pressed />} title={<>Try it. <span style={{ color: C.flame }}>Drag this.</span></>}
        footer={<><span className="mr-auto font-mono text-[11px] opacity-60">Lap 1 / 3</span><Btn ghost>Skip</Btn></>}>
        <div className="flex items-center gap-4">
          <div className="-rotate-6"><CobaltFile size={58} name="practice.mov" /></div>
          <div className="relative">
            <CobaltWheel segments={convertSegs} size={184} hoverIndex={0} interactive={false} hubLabel={<Hub top="MOV" size={184} />} labelSize={10} />
          </div>
          <p className="hidden max-w-[16ch] text-[13px] leading-snug text-[#E9EEFF]/75 xl:block">Hold <b>⇧</b> while you drag. Aim at <b style={{ color: C.flame }}>GIF</b>. Let go.</p>
        </div>
      </OnbWindow>

      {/* 4 · Keys */}
      <OnbWindow step={3} side={<span className="font-anton text-[40px] leading-none">⇧⌘⌃</span>} title="Pick your keys."
        footer={<><Btn ghost>Back</Btn><Btn>Lock them in</Btn></>}>
        <div className="flex flex-col gap-2">
          {[['Convert', 0], ['Tools', 1], ['Actions', 2]].map(([w, sel]) => (
            <div key={w} className="flex items-center gap-3 rounded-[12px] px-3 py-2" style={{ background: 'rgba(233,238,255,.05)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.08)' }}>
              <span className="w-[74px] font-anton text-[18px] uppercase leading-none">{w}</span>
              <div className="ml-auto flex gap-1">
                {['⇧', '⌘', '⌃', '⌥'].map((k, i) => (
                  <span key={k} className="grid size-8 place-items-center rounded-[8px] text-[15px] font-semibold"
                        style={i === sel ? { background: C.flame, color: C.midnight } : { background: 'rgba(233,238,255,.08)', color: 'rgba(233,238,255,.7)' }}>{k}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
        <div className="mt-3 font-mono text-[11px] opacity-60">Hold the key mid-drag. The wheel opens under your pointer.</div>
      </OnbWindow>

      {/* 5 · Pro */}
      <OnbWindow step={4} side={<Lock size={40} strokeWidth={2} />} title={<>Local is free. <span style={{ color: C.flame }}>Forever.</span></>}
        footer={<><Btn ghost>Stay local</Btn><Btn>Activate Pro</Btn></>}>
        <div className="grid grid-cols-2 gap-2">
          <div className="rounded-[12px] p-3" style={{ background: 'rgba(233,238,255,.06)', boxShadow: `inset 0 0 0 1.5px ${C.ice}` }}>
            <div className="flex items-center justify-between"><span className="font-anton text-[18px]">LOCAL</span><Check size={15} strokeWidth={3} /></div>
            <div className="mt-1 text-[12px] leading-snug opacity-75">All 793 routes, 26 tools, CLI + MCP.</div>
          </div>
          <div className="rounded-[12px] p-3" style={{ background: FLAME_GRAD, color: C.midnight }}>
            <div className="flex items-center justify-between"><span className="font-anton text-[18px]">PRO</span><span className="font-anton text-[18px]">$4<span className="text-[11px]">/mo</span></span></div>
            <div className="mt-1 text-[12px] font-medium leading-snug">Share links, cloud for huge files, sync presets.</div>
          </div>
        </div>
        <label className="mt-3 block">
          <span className="font-mono text-[10px] uppercase tracking-[0.14em] opacity-60">Licence key</span>
          <span className="mt-1 flex h-9 items-center rounded-[9px] px-3 font-mono text-[12px] text-[#E9EEFF]/40" style={{ background: C.deep, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14)' }}>HALO-XXXX-XXXX-XXXX</span>
        </label>
      </OnbWindow>

      {/* 6 · Done */}
      <OnbWindow step={5} side={<Check size={52} strokeWidth={3} />} title={<>Green light. <span style={{ color: C.flame }}>Go.</span></>}
        footer={<Btn>Finish</Btn>}>
        <p className="text-[14px] leading-relaxed text-[#E9EEFF]/80">Halo is up in the menu bar. Drag anything, anywhere.</p>
        <div className="mt-4 overflow-hidden rounded-[12px]" style={{ background: 'linear-gradient(180deg, #1F3BFF, #0B1A8C)' }}>
          <div className="flex h-7 items-center justify-end gap-3 px-3 text-[11px] font-medium" style={{ background: 'rgba(5,10,46,.55)' }}>
            <span className="opacity-60">Wi-Fi</span>
            <span className={cn('grid h-[20px] place-items-center rounded-[5px] px-1.5')} style={{ background: C.flame, boxShadow: '0 0 12px rgba(255,106,43,.8)' }}><MenuGlyph size={14} color={C.midnight} /></span>
            <span className="opacity-60">9:41</span>
          </div>
          <div className="flex justify-end p-3"><div className="origin-right scale-[.86]"><DoneToast compact title="Setup" /></div></div>
        </div>
      </OnbWindow>
    </div>
  )
}
