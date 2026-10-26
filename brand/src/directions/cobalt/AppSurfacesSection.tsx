import type { ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { FloatShelf, MenuBarMenu, OptionsPanel, ProgressHUD, WheelTrio } from './AppSurfaces'
import { C } from './tokens'
import { Bands, DoneToast, ErrorToast, Eyebrow, RaceNumber } from './ui'

const W = 'mx-auto w-full max-w-[1280px] px-4 sm:px-6 lg:px-10'

function Spot({ label, note, children, className }: { label: string; note?: string; children: ReactNode; className?: string }) {
  return (
    <div className={cn('relative flex flex-col overflow-hidden rounded-[22px]', className)}
         style={{ background: 'linear-gradient(180deg, #13238F 0%, #0B1A8C 100%)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
      <Bands count={6} palette={[C.ultra, '#0D1E9E', C.ultra, '#0A1780']} />
      <div className="relative flex items-center justify-between px-5 pt-4">
        <Eyebrow className="text-[#E9EEFF]/70">{label}</Eyebrow>
        {note && <span className="font-mono text-[10px] text-[#E9EEFF]/50">{note}</span>}
      </div>
      <div className="relative flex flex-1 items-center justify-center px-4 py-10 sm:px-8">{children}</div>
    </div>
  )
}

export function AppSurfaces() {
  return (
    <div className={W}>
      <div id="app" className="scroll-mt-14 pt-24 sm:pt-32">
        <div className="flex items-center gap-4">
          <RaceNumber n="08" size={46} tone="flame" />
          <Eyebrow className="text-[#E9EEFF]/70">App surfaces · real size</Eyebrow>
        </div>
        <h2 className="mt-5 max-w-[16ch] font-anton uppercase leading-[0.86]" style={{ fontSize: 'clamp(54px, 8vw, 128px)' }}>
          The cockpit. <span style={{ color: C.flame }}>Dark cobalt.</span>
        </h2>
        <p className="mt-6 max-w-[58ch] font-geist text-[17px] leading-relaxed text-[#E9EEFF]/80">
          The app wears the brand quietly: deep blue glass, a speedometer rim on the wheel, Anton labels, and exactly one flame thing, the wedge you are aiming at.
          Hover the wheels.
        </p>
      </div>

      <div className="mt-12 overflow-hidden rounded-[26px] px-4 py-14 sm:px-10" style={{ background: `radial-gradient(1000px 500px at 50% 0%, #13238F, ${C.midnight} 70%)`, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
        <div className="mb-10 flex items-center justify-between">
          <Eyebrow className="text-[#E9EEFF]/70">The three wheels · 320pt</Eyebrow>
          <span className="font-mono text-[10px] text-[#E9EEFF]/50">⇧ ⌘ ⌃ held mid-drag</span>
        </div>
        <div className="flex justify-center"><WheelTrio size={320} /></div>
      </div>

      <div className="mt-3 grid gap-3 lg:grid-cols-[1.15fr_1fr]">
        <Spot label="Options panel" note="A size estimate on every chip"><OptionsPanel /></Spot>
        <div className="grid gap-3">
          <Spot label="Progress HUD" note="Speedometer ring · cancel"><ProgressHUD value={0.64} /></Spot>
          <Spot label="Toasts" note="Done / error">
            <div className="flex flex-col items-center gap-3">
              <DoneToast />
              <div className="max-w-full overflow-hidden"><ErrorToast /></div>
            </div>
          </Spot>
        </div>
      </div>

      <div className="mt-3 grid gap-3 lg:grid-cols-2">
        <Spot label="Float shelf" note="Holds files between drags"><FloatShelf /></Spot>
        <Spot label="Menu bar" note="Template glyph · dropdown"><MenuBarMenu /></Spot>
      </div>
    </div>
  )
}
