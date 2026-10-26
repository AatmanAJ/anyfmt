import type { ReactNode } from 'react'
import { ArrowLeft, Check, ChevronDown, Lock, MousePointer2 } from 'lucide-react'
import { cn } from '../../shared/cn'
import { FileTile } from './AppSurfaces'
import { MenuGlyph, PrismMark, Wordmark } from './Logo'
import { Hub, PrismWheel, SEG } from './PrismWheel'
import { FormatRing, IRIS, Mesh, P, Scaled, glass } from './theme'

export const OB_W = 680
export const OB_H = 400

/** A stadium-shaped onboarding window, the way anyfmt's setup actually looks. */
function Stadium({ children, step, iris, dark, label }: { children: ReactNode; step: number; iris?: boolean; dark?: boolean; label: string }) {
  return (
    <figure className="m-0">
      <Scaled w={OB_W} h={OB_H}>
        <div className={cn('relative h-full w-full overflow-hidden', dark ? 'text-white' : 'text-[#1C1530]')}
             style={{
               borderRadius: 200,
               background: iris ? '#F3EEFB' : dark ? `linear-gradient(180deg, #221A38, ${P.night})` : 'linear-gradient(180deg, #FFFFFF, #F7F4FC)',
               boxShadow: dark
                 ? 'inset 0 1px 0 rgba(255,255,255,.14), inset 0 0 0 1px rgba(255,255,255,.07), 0 40px 80px -30px rgba(0,0,0,.6)'
                 : 'inset 0 1.5px 0 #fff, inset 0 0 0 1px rgba(255,255,255,.8), 0 0 0 .5px rgba(28,21,48,.1), 0 40px 80px -36px rgba(44,30,90,.45), 0 10px 30px -18px rgba(44,30,90,.25)',
             }}>
          {iris && <Mesh intensity={1.5} />}
          {dark && <Mesh dark intensity={0.7} />}
          <div className="absolute left-[92px] top-[46px] z-20 flex gap-[7px]">
            {['#FF5F57', '#FEBC2E', dark ? 'rgba(255,255,255,.2)' : 'rgba(28,21,48,.14)'].map((c, i) => <span key={i} className="size-3 rounded-full" style={{ background: c, boxShadow: 'inset 0 0 0 .5px rgba(0,0,0,.12)' }} />)}
          </div>
          <div className="relative h-full w-full">{children}</div>
          <div className="absolute bottom-[30px] left-1/2 flex -translate-x-1/2 gap-1.5">
            {Array.from({ length: 6 }, (_, i) => (
              <span key={i} className="h-1.5 rounded-full transition-all"
                    style={{ width: i === step ? 18 : 6, background: i === step ? IRIS : dark ? 'rgba(255,255,255,.2)' : 'rgba(28,21,48,.14)' }} />
            ))}
          </div>
        </div>
      </Scaled>
      <figcaption className="mt-4 flex items-center justify-center gap-2 text-[12.5px] text-[#5E5677]">
        <span className="font-mono text-[11px] text-[#8E87A6]">0{step + 1}</span>{label}
      </figcaption>
    </figure>
  )
}

function Right({ children, back = true, dark }: { children: ReactNode; back?: boolean; dark?: boolean }) {
  return (
    <div className="absolute left-[370px] top-1/2 w-[236px] -translate-y-1/2">
      {back && <div className={cn('mb-3 inline-flex items-center gap-1 text-[11.5px] font-medium', dark ? 'text-white/50' : 'text-[#8E87A6]')}><ArrowLeft size={12} /> Back</div>}
      {children}
    </div>
  )
}
const H = ({ children }: { children: ReactNode }) => <h4 className="p-display m-0 text-[27px] font-semibold leading-[1.05]">{children}</h4>
const Body = ({ children, dark }: { children: ReactNode; dark?: boolean }) => <p className={cn('mb-0 mt-2.5 text-[13px] leading-[1.5]', dark ? 'text-white/65' : 'text-[#5E5677]')}>{children}</p>
function Btn({ children, ghost, dark }: { children: ReactNode; ghost?: boolean; dark?: boolean }) {
  if (ghost) return <span className={cn('inline-flex h-9 items-center px-3 text-[13px] font-medium', dark ? 'text-white/60' : 'text-[#5E5677]')}>{children}</span>
  return (
    <span className="relative inline-flex h-9 items-center rounded-full px-5 text-[13px] font-semibold text-white"
          style={{ background: P.plum, boxShadow: '0 10px 22px -10px rgba(107,78,255,.75), inset 0 1px 0 rgba(255,255,255,.18)' }}>
      <span aria-hidden className="absolute -inset-px rounded-full" style={{ padding: 1, background: IRIS, WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)', WebkitMaskComposite: 'xor', maskComposite: 'exclude' }} />
      <span className="relative">{children}</span>
    </span>
  )
}
function Kc({ k, label, dark }: { k: string; label: string; dark?: boolean }) {
  return (
    <span className={cn('inline-flex h-[34px] min-w-[52px] flex-col items-start justify-between rounded-[9px] px-2 py-1 align-middle', dark ? 'text-white' : 'text-[#1C1530]')}
          style={dark ? { background: 'rgba(255,255,255,.1)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.15), 0 2px 0 rgba(0,0,0,.4)' }
                      : { background: 'linear-gradient(180deg,#fff,#F3F0FA)', boxShadow: 'inset 0 1px 0 #fff, 0 0 0 .5px rgba(28,21,48,.15), 0 2px 0 rgba(28,21,48,.12)' }}>
      <span className="text-[13px] leading-none">{k}</span><span className="text-[8.5px] font-medium leading-none opacity-60">{label}</span>
    </span>
  )
}

/* 1 */
function Welcome() {
  return (
    <Stadium step={0} iris label="Welcome">
      <div className="flex h-full flex-col items-center justify-center text-center">
        <div className="relative grid place-items-center">
          <FormatRing size={128} thickness={1.5} className="opacity-80" />
          <PrismMark size={92} />
        </div>
        <div className="mt-5 text-[13px] font-medium text-[#3A3152]">Welcome to</div>
        <Wordmark size={64} className="mt-0.5" />
        <span className="mt-5 inline-flex h-10 items-center rounded-full bg-white px-6 text-[13.5px] font-semibold shadow-[0_12px_30px_-12px_rgba(44,30,90,.5)]">Let’s begin</span>
      </div>
    </Stadium>
  )
}

/* 2 */
function Permission() {
  return (
    <Stadium step={1} label="Accessibility, asked once and explained">
      <div className="absolute left-[96px] top-1/2 w-[238px] -translate-y-1/2">
        <div className="rounded-[18px] p-3" style={{ background: '#F4F1FA', boxShadow: 'inset 0 0 0 .5px rgba(28,21,48,.08)' }}>
          <div className="mb-2 flex items-center gap-1.5 text-[10.5px] font-medium text-[#8E87A6]"><Lock size={10} /> Privacy & Security › Accessibility</div>
          {[['Terminal', false, '#2B2B2B'], ['anyfmt', true, ''], ['Raycast', true, '#FF5C5C']].map(([n, on, c]) => (
            <div key={n as string} className={cn('flex items-center gap-2.5 rounded-[10px] px-2 py-1.5', n === 'anyfmt' && 'bg-white shadow-[0_6px_16px_-8px_rgba(44,30,90,.35)]')}>
              {n === 'anyfmt' ? <PrismMark size={20} /> : <span className="size-5 rounded-[5px]" style={{ background: c as string }} />}
              <span className="flex-1 text-[12px] font-medium">{n}</span>
              <span className="relative h-[16px] w-[28px] rounded-full" style={{ background: on ? (n === 'anyfmt' ? `linear-gradient(120deg, ${P.coral}, ${P.lilac})` : '#34C759') : 'rgba(28,21,48,.15)' }}>
                <span className="absolute top-[2px] size-[12px] rounded-full bg-white shadow" style={{ left: on ? 14 : 2 }} />
              </span>
            </div>
          ))}
        </div>
        <MousePointer2 size={20} className="absolute -bottom-3 right-6 fill-white text-[#1C1530]" strokeWidth={1.6} />
      </div>
      <Right>
        <H>Let anyfmt feel your drags</H>
        <Body>anyfmt listens for ⇧ ⌘ ⌃ only while a file is mid-drag. Never your typing, never your screen.</Body>
        <div className="mt-5 flex items-center gap-1"><Btn>Open Settings</Btn><Btn ghost>Why?</Btn></div>
      </Right>
    </Stadium>
  )
}

/* 3 */
function TryIt() {
  return (
    <Stadium step={2} label="Practice drag, right in the window">
      <div className="absolute left-[78px] top-1/2 grid size-[250px] -translate-y-1/2 place-items-center">
        <PrismWheel segments={SEG.convert} size={230} hoverIndex={0} interactive={false} hubLabel={<Hub size="18 MB" small />} />
        <div className="absolute left-[164px] top-[30px] z-10 rotate-[8deg]"><FileTile ext="MOV" size={30} /></div>
      </div>
      <Right>
        <H>Try it: drag this file</H>
        <ol className="mb-0 mt-4 list-none space-y-2.5 p-0 text-[13px] font-medium">
          <li className="flex items-center gap-2.5"><span className="grid size-5 place-items-center rounded-full bg-[#1C1530] text-[10px] text-white"><Check size={11} strokeWidth={3} /></span>Pick up <span className="font-mono text-[12px]">try-me.mov</span></li>
          <li className="flex items-center gap-2.5"><span className="grid size-5 place-items-center rounded-full text-[10px] font-semibold text-white" style={{ background: IRIS }}>2</span>Tap <Kc k="⇧" label="shift" /></li>
          <li className="flex items-center gap-2.5 text-[#8E87A6]"><span className="grid size-5 place-items-center rounded-full bg-[#1C1530]/10 text-[10px] font-semibold">3</span>Drop on GIF</li>
        </ol>
        <div className="mt-5"><Btn>Continue</Btn></div>
      </Right>
    </Stadium>
  )
}

/* 4 */
function Keys() {
  const rows = [['⇧', 'shift', 'Convert'], ['⌘', 'command', 'Tools'], ['⌃', 'control', 'Actions']]
  return (
    <Stadium step={3} label="Pick your keys">
      <div className="absolute left-[86px] top-1/2 grid size-[250px] -translate-y-1/2 place-items-center">
        <PrismWheel segments={SEG.tools} size={236} hoverIndex={6} interactive={false} hubLabel={<Hub size="2.4 MB" small />} />
      </div>
      <Right>
        <H>Pick your keys</H>
        <Body>Defaults feel right for most people. Change them any time in Settings.</Body>
        <div className="mt-3.5 space-y-1.5">
          {rows.map(([k, l, w], i) => (
            <div key={w} className={cn('flex items-center gap-2.5 rounded-[12px] px-2 py-1.5', i === 1 ? 'bg-white shadow-[0_6px_16px_-8px_rgba(44,30,90,.35)]' : 'bg-[#1C1530]/[.035]')}>
              <Kc k={k} label={l} />
              <span className="flex-1 text-[12.5px] font-semibold">{w}</span>
              <ChevronDown size={13} className="text-[#8E87A6]" />
            </div>
          ))}
        </div>
      </Right>
    </Stadium>
  )
}

/* 5 */
function Pro() {
  return (
    <Stadium step={4} label="Pro, optional and honest">
      <div className="absolute left-[100px] top-1/2 w-[226px] -translate-y-1/2">
        <div className="relative overflow-hidden rounded-[22px] p-4" style={{ background: `linear-gradient(150deg, #FFE3EA, #EDE6FF 50%, #DDF8F6)`, boxShadow: 'inset 0 1px 0 #fff, 0 16px 34px -18px rgba(44,30,90,.5)' }}>
          <div className="flex items-baseline justify-between">
            <span className="text-[13px] font-semibold">anyfmt Pro</span>
            <span className="text-[22px] font-semibold tracking-[-0.04em]">$4<span className="text-[11px] font-medium text-[#5E5677]">/mo</span></span>
          </div>
          <ul className="mb-0 mt-3 list-none space-y-1.5 p-0 text-[11.5px] text-[#3A3152]">
            {['Share links with expiry', 'Cloud conversions for huge files', 'Transcribe, upscale, HQ cut-outs', 'Sync presets across Macs'].map((t) => (
              <li key={t} className="flex items-center gap-2"><Check size={12} strokeWidth={3} className="text-[#6B4EFF]" />{t}</li>
            ))}
          </ul>
        </div>
      </div>
      <Right>
        <H>Everything local is free. Forever.</H>
        <Body>Pro adds a few cloud extras. Skip it and nothing gets locked.</Body>
        <div className="mt-5 flex items-center gap-1"><Btn>Try Pro</Btn><Btn ghost>Not now</Btn></div>
      </Right>
    </Stadium>
  )
}

/* 6 */
function Done() {
  return (
    <Stadium step={5} dark label="Done, in Plum night">
      <div className="absolute left-[96px] top-1/2 w-[236px] -translate-y-1/2">
        <div className="flex h-7 items-center justify-end gap-3 rounded-[9px] bg-black/30 px-2.5 text-[11px] text-white/85">
          <span className="opacity-60">100%</span>
          <span className="relative grid h-[20px] w-[28px] place-items-center rounded-[6px] bg-white/20"><MenuGlyph size={14} />
            <span className="absolute -inset-1 rounded-[8px]" style={{ boxShadow: `0 0 0 1.5px ${P.lilac}, 0 0 16px ${P.lilac}` }} />
          </span>
          <span>9:41</span>
        </div>
        <div className="ml-auto mr-[46px] mt-1 h-5 w-px bg-gradient-to-b from-[#B9A7FF] to-transparent" />
        <div className="rounded-[16px] p-3" style={glass.dark}>
          <div className="flex items-center justify-between gap-3">
            <div className="leading-tight">
              <div className="text-[12.5px] font-semibold">Open at login</div>
              <div className="text-[10.5px] text-white/50">Ready whenever your Mac is</div>
            </div>
            <span className="relative h-[20px] w-[34px] rounded-full" style={{ background: `linear-gradient(120deg, ${P.coral}, ${P.lilac})` }}><span className="absolute left-[16px] top-[2px] size-4 rounded-full bg-white" /></span>
          </div>
        </div>
      </div>
      <Right dark>
        <H>You’re all set</H>
        <Body dark>anyfmt lives in your menu bar. Drag any file, tap a key, and enjoy the magic.</Body>
        <div className="mt-5"><span className="inline-flex h-9 items-center rounded-full bg-white px-6 text-[13px] font-semibold text-[#1C1530]">Done</span></div>
      </Right>
    </Stadium>
  )
}

export function Onboarding() {
  return (
    <div className="grid gap-x-8 gap-y-12 lg:grid-cols-2">
      <Welcome /><Permission /><TryIt /><Keys /><Pro /><Done />
    </div>
  )
}
