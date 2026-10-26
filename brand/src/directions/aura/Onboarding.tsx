// Onboarding: six stadium-shaped windows, each with a round "porthole" illustration on the left.
import { ArrowUpRight, Check, Cloud, Link2, Lock, Mic, RefreshCw } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { AuraWheel } from './AuraWheel'
import { AuraKey, Fit, Glow, Grain, HandArrow, Mark, MenuGlyph, PaperFile, Sticky, convertSegs } from './ui'

const W = 800, H = 320

function Stadium({ step, art, children }: { step: number; art: ReactNode; children: ReactNode }) {
  return (
    <div className="aura-frost relative overflow-hidden rounded-full" style={{ width: W, height: H }}>
      {/* porthole */}
      <div className="absolute left-[18px] top-[18px] grid size-[284px] place-items-center overflow-hidden rounded-full"
           style={{ background: 'radial-gradient(circle at 50% 40%, #FFFDF9, #F6ECDF)', boxShadow: '0 0 0 .5px rgba(90,60,30,.14) inset, 0 10px 30px -10px rgba(150,80,30,.25) inset' }}>
        <Glow className="inset-[-10%]" intensity={0.55} />
        <div className="relative">{art}</div>
      </div>
      {/* window controls */}
      <div className="absolute left-[336px] top-[30px] flex gap-[7px]">
        {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-[11px] rounded-full" style={{ background: c, boxShadow: '0 0 0 .5px rgba(0,0,0,.15) inset' }} />)}
      </div>
      <div className="absolute right-[120px] top-[27px] flex gap-1.5" aria-label={`Step ${step} of 6`}>
        {Array.from({ length: 6 }, (_, i) => (
          <span key={i} className={cn('h-[6px] rounded-full transition-all', i + 1 === step ? 'w-5 bg-[#FFA868] shadow-[0_0_8px_rgba(255,160,100,.7)]' : i + 1 < step ? 'w-[6px] bg-[#1E1B18]/40' : 'w-[6px] bg-[#1E1B18]/12')} />
        ))}
      </div>
      <div className="absolute bottom-[34px] left-[336px] right-[110px] top-[62px] flex flex-col">{children}</div>
    </div>
  )
}

function Title({ children }: { children: ReactNode }) {
  return <h4 className="aura-display text-[38px] leading-[1] text-[#1E1B18]">{children}</h4>
}
function Body({ children }: { children: ReactNode }) {
  return <p className="mt-3 max-w-[340px] text-[13.5px] leading-[1.5] text-[#5B524A]">{children}</p>
}
function Buttons({ children }: { children: ReactNode }) {
  return <div className="mt-auto flex items-center gap-2.5">{children}</div>
}
const Primary = ({ children }: { children: ReactNode }) => <span className="aura-btn aura-btn-ink px-4 py-2 text-[13px]">{children}</span>
const Soft = ({ children }: { children: ReactNode }) => <span className="aura-btn aura-btn-soft px-4 py-2 text-[13px]">{children}</span>

export const SCREENS: { name: string; node: ReactNode }[] = [
  {
    name: 'Welcome',
    node: (
      <Stadium step={1} art={<div className="relative grid place-items-center"><div className="absolute size-[170px] rounded-full bg-[#FFB27A]/40 blur-2xl" /><Mark size={132} /></div>}>
        <Title>Hello. Let’s make files <em>easier</em> to move.</Title>
        <Body>anyfmt lives in your menu bar and only wakes up when you drag something. Setup takes about two minutes.</Body>
        <Buttons><Primary>Get started</Primary><span className="text-[12px] text-[#8A7F74]">Free and open source</span></Buttons>
      </Stadium>
    ),
  },
  {
    name: 'Permission',
    node: (
      <Stadium step={2} art={
        <div className="w-[210px] rounded-[18px] bg-white p-3 shadow-[0_14px_30px_-12px_rgba(120,70,30,.35)]">
          <div className="mb-2 flex items-center gap-1.5 text-[10px] font-semibold text-[#8A7F74]"><Lock size={10} /> Privacy & Security › Accessibility</div>
          {[{ n: 'anyfmt', on: true }, { n: 'Terminal', on: false }].map((r) => (
            <div key={r.n} className={cn('flex items-center gap-2 rounded-[10px] px-2 py-1.5', r.on && 'bg-[#FFF3E8]')}>
              {r.on ? <Mark size={18} /> : <span className="size-[18px] rounded-[5px] bg-[#2B2724]" />}
              <span className="flex-1 text-[12px] font-medium text-[#1E1B18]">{r.n}</span>
              <span className={cn('relative h-[16px] w-[28px] rounded-full', r.on ? 'bg-[#FFA868] shadow-[0_0_10px_rgba(255,160,100,.7)]' : 'bg-[#E2D7C8]')}>
                <span className={cn('absolute top-[2px] size-[12px] rounded-full bg-white', r.on ? 'left-[14px]' : 'left-[2px]')} />
              </span>
            </div>
          ))}
        </div>
      }>
        <Title>One permission, and <em>why</em>.</Title>
        <Body>Accessibility lets anyfmt notice ⇧ ⌘ ⌃ while you drag. It doesn’t read your screen or your typing, and nothing leaves your Mac.</Body>
        <Buttons>
          <Primary>Open System Settings <ArrowUpRight size={14} /></Primary>
          <span className="flex items-center gap-2 text-[12px] text-[#5B524A]"><span className="relative flex size-2"><span className="aura-pulse-ring absolute inset-0 rounded-full bg-[#FFA868]" /><span className="relative size-2 rounded-full bg-[#FF9858]" /></span>Waiting for the switch…</span>
        </Buttons>
      </Stadium>
    ),
  },
  {
    name: 'Practice',
    node: (
      <Stadium step={3} art={
        <div className="relative grid size-[220px] place-items-center">
          <div className="absolute inset-[18px] rounded-full border-2 border-dashed border-[#FF9858]/60" />
          <div className="aura-float"><PaperFile ext="HEIC" name="practice.heic" size={58} /></div>
          <span className="aura-hand absolute left-[22px] top-[36px] -rotate-6 text-[15px] text-[#B04E1B]">pick me up</span>
          <HandArrow className="absolute left-[34px] top-[54px] rotate-[6deg] scale-75" color="#B04E1B" />
        </div>
      }>
        <Title>Try it: drag <em>this</em> file.</Title>
        <Body>Pick it up, hold <b className="font-semibold text-[#1E1B18]">⇧ Shift</b>, and drop it on <b className="font-semibold text-[#1E1B18]">JPG</b>. It’s a practice copy, so nothing on your Mac changes.</Body>
        <Buttons><Soft>Skip practice</Soft><span className="text-[12px] text-[#8A7F74]">Most people get it first try.</span></Buttons>
      </Stadium>
    ),
  },
  {
    name: 'Your keys',
    node: (
      <Stadium step={4} art={
        <div className="relative grid size-[230px] place-items-center">
          <div className="scale-[.9]"><AuraWheel segments={convertSegs} size={190} hoverIndex={2} interactive={false} halo={false} labelSize={9.5}
            hubLabel={<span className="font-sans text-[15px] font-semibold text-[#1E1B18]">⇧</span>} /></div>
        </div>
      }>
        <Title>Pick your <em>keys</em>.</Title>
        <div className="mt-2.5 space-y-1">
          {[{ k: '⇧', n: 'Shift', w: 'Convert' }, { k: '⌘', n: 'Command', w: 'Tools' }, { k: '⌃', n: 'Control', w: 'Actions' }].map((r, i) => (
            <div key={r.w} className="flex items-center gap-3 rounded-[12px] bg-white/60 py-[3px] pl-[3px] pr-2.5 shadow-[0_0_0_.5px_rgba(90,60,30,.12)]">
              <AuraKey symbol={r.k} size="xs" active={i === 0} />
              <span className="flex-1 text-[13px] font-semibold text-[#1E1B18]">{r.w}</span>
              <span className="rounded-full bg-[#1E1B18]/[.06] px-2.5 py-1 text-[11.5px] font-medium text-[#5B524A]">{r.n} ▾</span>
            </div>
          ))}
        </div>
        <Buttons><Primary>These are good</Primary><span className="text-[12px] text-[#8A7F74]">Change them any time</span></Buttons>
      </Stadium>
    ),
  },
  {
    name: 'Pro, if you like',
    node: (
      <Stadium step={5} art={
        <div className="grid gap-2">
          {[{ i: Link2, t: 'Share links' }, { i: Cloud, t: 'Cloud for huge files' }, { i: Mic, t: 'Transcribe' }, { i: RefreshCw, t: 'Synced presets' }].map(({ i: I, t }, n) => (
            <div key={t} className="flex items-center gap-2 rounded-full bg-white px-3 py-1.5 text-[12px] font-medium text-[#1E1B18] shadow-[0_8px_18px_-10px_rgba(120,70,30,.4)]"
                 style={{ transform: `translateX(${[0, 14, -8, 8][n]}px)` }}>
              <I size={13} className="text-[#B04E1B]" />{t}
            </div>
          ))}
        </div>
      }>
        <Title>Everything local is <em>free</em>. Forever.</Title>
        <Body>Pro adds share links, cloud conversions for huge files, transcription and preset sync. $4 a month, whenever you want it. Or never.</Body>
        <Buttons><Primary>Maybe later</Primary><Soft>Try Pro</Soft></Buttons>
      </Stadium>
    ),
  },
  {
    name: 'Done',
    node: (
      <Stadium step={6} art={
        <div className="relative w-[230px]">
          <div className="flex h-[30px] items-center justify-end gap-3 rounded-[10px] bg-white/80 px-3 text-[#1E1B18] shadow-[0_8px_20px_-10px_rgba(120,70,30,.35)]">
            <span className="h-1.5 w-8 rounded bg-[#1E1B18]/15" /><span className="h-1.5 w-5 rounded bg-[#1E1B18]/15" />
            <span className="relative grid h-[22px] w-[28px] place-items-center rounded-[6px] bg-[#FFB27A]/50 shadow-[0_0_16px_rgba(255,160,100,.8)]"><MenuGlyph size={15} /></span>
            <span className="text-[10px] font-medium tabular-nums">9:41</span>
          </div>
          <HandArrow className="absolute right-[2px] top-[34px] -rotate-[100deg]" color="#B04E1B" />
          <span className="aura-hand absolute right-[64px] top-[84px] -rotate-3 text-[16px] text-[#B04E1B]">it lives here</span>
        </div>
      }>
        <Title>You’re set. anyfmt is <em>up there</em>.</Title>
        <Body>Look for the little ring in your menu bar. Drag anything, press a key, drop. That’s the whole trick.</Body>
        <Buttons><Primary><Check size={14} strokeWidth={2.6} /> Start using anyfmt</Primary></Buttons>
      </Stadium>
    ),
  },
]

export function OnboardingBoard() {
  return (
    <div className="relative overflow-hidden rounded-[36px] px-4 py-12 md:px-10 md:py-16"
         style={{ background: 'linear-gradient(170deg,#F8EEE2,#F2E2D2 45%,#E7E4F6)' }}>
      <Glow className="left-[-10%] top-[5%] h-[50%] w-[70%]" intensity={0.8} />
      <Glow className="bottom-[0%] right-[-15%] h-[55%] w-[70%]" intensity={0.6} />
      <Grain />
      <div className="relative mx-auto grid max-w-[1080px] gap-y-10 md:gap-y-14">
        {SCREENS.map((s, i) => (
          <figure key={s.name} className={cn('m-0 w-full max-w-[860px]', i % 2 ? 'justify-self-end' : 'justify-self-start')}>
            <figcaption className="mb-4 flex items-baseline gap-3 px-2">
              <span className="aura-serif text-[15px] italic text-[#B04E1B]">0{i + 1}</span>
              <span className="text-[13px] font-semibold text-[#1E1B18]">{s.name}</span>
            </figcaption>
            <Fit width={W + 40} height={H + 40}><div className="p-5">{s.node}</div></Fit>
          </figure>
        ))}
      </div>
      <Sticky className="absolute right-10 top-24 hidden xl:block" rotate={4}>Every window is a pill. Every porthole shows the one thing that step is about.</Sticky>
      <Sticky className="absolute bottom-40 left-10 hidden xl:block" rotate={-3}>One clear button per step. The quiet one is always allowed.</Sticky>
    </div>
  )
}
