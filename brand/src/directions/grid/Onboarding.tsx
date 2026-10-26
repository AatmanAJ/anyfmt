import { Check } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { GridWheel, SETS } from './GridWheel'
import { Lockup, Mark, MenuGlyph } from './Logo'
import { GridDemo, GridWindow } from './Surfaces'
import { Arrow, Btn, C, Mono, SwissKey } from './ui'

function Steps({ at }: { at: number }) {
  return (
    <div className="flex gap-1" aria-label={`Step ${at + 1} of 6`}>
      {Array.from({ length: 6 }).map((_, i) => (
        <span key={i} className="h-1.5 w-5" style={{ background: i === at ? C.red : i < at ? C.ink : C.rule }} />
      ))}
    </div>
  )
}

function Screen({ at, title, children, foot, className }: { at: number; title: string; children: ReactNode; foot: ReactNode; className?: string }) {
  return (
    <GridWindow title={title} step={`${String(at + 1).padStart(2, '0')} / 06`} className={cn('flex flex-col', className)}>
      <div className="relative flex-1 px-6 pb-4 pt-6 md:px-8">{children}</div>
      <div className="flex items-center justify-between gap-3 border-t border-[#E4E4DF] px-6 py-3.5 md:px-8">
        <Steps at={at} />
        <div className="flex items-center gap-2">{foot}</div>
      </div>
    </GridWindow>
  )
}

const H = ({ children }: { children: ReactNode }) => (
  <h3 className="font-grotesk text-[40px] font-semibold leading-[0.88] tracking-[-0.055em] md:text-[48px]">{children}</h3>
)
const P = ({ children }: { children: ReactNode }) => <p className="mt-3 max-w-[38ch] text-[14px] leading-snug text-[#5C5C56]">{children}</p>

export function Onboarding() {
  const [keys, setKeys] = useState(['⇧', '⌘', '⌃'])
  const pool = ['⇧', '⌘', '⌃', '⌥']
  const cycle = (i: number) => setKeys((k) => {
    const next = pool[(pool.indexOf(k[i]) + 1) % pool.length]
    const out = [...k]
    const j = out.indexOf(next)
    if (j >= 0) out[j] = out[i]
    out[i] = next
    return out
  })
  const names: Record<string, string> = { '⇧': 'Shift', '⌘': 'Command', '⌃': 'Control', '⌥': 'Option' }
  const [plan, setPlan] = useState(0)

  return (
    <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
      {/* 01 Welcome */}
      <Screen at={0} title="Welcome" className="min-h-[440px]" foot={<Btn size="sm">Begin <Arrow /></Btn>}>
        <div className="flex h-full flex-col">
          <div className="flex items-start justify-between">
            <Mark size={72} />
            <Mono className="text-[#5C5C56]">v1.0</Mono>
          </div>
          <div className="mt-auto pt-10">
            <h3 className="font-grotesk text-[64px] font-semibold leading-[0.82] tracking-[-0.065em] md:text-[80px]">Halo.</h3>
            <P>A wheel for every file. Three keys, one drag. Setup takes five steps.</P>
            <div className="mt-6 grid grid-cols-3 border-t border-[#D6D6D0] font-mono text-[10px] uppercase tracking-[0.08em]">
              {['⇧ Convert', '⌘ Tools', '⌃ Actions'].map((t, i) => (
                <span key={t} className={cn('py-2', i > 0 && 'border-l border-[#D6D6D0] pl-3')}>{t}</span>
              ))}
            </div>
          </div>
        </div>
      </Screen>

      {/* 02 Accessibility */}
      <Screen at={1} title="Permission" className="min-h-[440px]"
        foot={<><Mono className="mr-2 hidden items-center gap-2 text-[#5C5C56] sm:flex"><span className="size-1.5 animate-pulse bg-[#FF3D2E]" />Waiting</Mono><Btn size="sm">Open Settings <Arrow /></Btn></>}>
        <H>Allow<br />Accessibility.</H>
        <P>Halo reads which modifier key you press while you drag. Nothing else. No screen recording, no keystroke log.</P>
        <div className="relative mt-6 rounded-[8px] border border-[#D6D6D0] bg-[#F4F4F1] p-1">
          <div className="px-2.5 pb-1.5 pt-1 font-sans text-[11px] font-semibold text-[#5C5C56]">Privacy &amp; Security › Accessibility</div>
          {[['Finder', false], ['Halo', true], ['Terminal', false]].map(([n, me]) => (
            <div key={n as string} className={cn('flex items-center justify-between rounded-[5px] px-2.5 py-2 font-sans text-[13px]', me && 'bg-white outline outline-1 outline-[#0B0B0B]')}>
              <span className="flex items-center gap-2.5">
                {me ? <Mark size={18} /> : <span className="size-[18px] rounded-[4px] bg-[#D6D6D0]" />}
                <span className={me ? 'font-semibold' : 'text-[#5C5C56]'}>{n as string}</span>
              </span>
              <span className={cn('relative h-[18px] w-[32px] rounded-full transition-colors', me ? 'bg-[#0B0B0B]' : 'bg-[#D6D6D0]')}>
                <span className={cn('absolute top-[2px] size-[14px] rounded-full bg-white', me ? 'left-[16px]' : 'left-[2px]')} />
              </span>
            </div>
          ))}
        </div>
        <div className="mt-3 flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.08em]">
          <span className="block h-px w-6 bg-[#FF3D2E]" /> Turn on Halo
        </div>
      </Screen>

      {/* 03 Practice */}
      <Screen at={2} title="Practice" className="min-h-[480px]" foot={<><button type="button" className="px-2 font-sans text-[12px] text-[#5C5C56] hover:text-[#0B0B0B]">Skip</button><Btn size="sm" kind="ghost">Next <Arrow /></Btn></>}>
        <div className="grid grid-cols-1 items-center gap-6 sm:grid-cols-[1fr_auto]">
          <div>
            <H>Try it.<br />Drag this file.</H>
            <P>Pick up clip.mov. Hold ⇧ Shift. Let go on GIF.</P>
            <ol className="mt-5 space-y-0 border-t border-[#D6D6D0] font-mono text-[11px]">
              {['Drag clip.mov', 'Hold ⇧ Shift', 'Release on GIF'].map((t, i) => (
                <li key={t} className="flex items-center justify-between border-b border-[#D6D6D0] py-2">
                  <span><span className="mr-3 text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</span>{t}</span>
                  {i < 2 ? <Check size={13} strokeWidth={2.6} /> : <span className="size-2 bg-[#FF3D2E]" />}
                </li>
              ))}
            </ol>
          </div>
          <div className="flex justify-center rounded-[8px] border border-dashed border-[#BDBDB6] bg-[#F4F4F1] p-5">
            <GridDemo segments={SETS.convert} target={0} sweep={[1, 0]} size={220} hub="clip.mov" hubSub="8 FORMATS"
              ext="MOV" name="clip.mov" keySym="⇧" keyName="Shift" result="clip.gif" resultMeta="DONE · YOUR FIRST DROP" />
          </div>
        </div>
      </Screen>

      {/* 04 Keys */}
      <Screen at={3} title="Keys" className="min-h-[480px]" foot={<><button type="button" onClick={() => setKeys(['⇧', '⌘', '⌃'])} className="px-2 font-sans text-[12px] text-[#5C5C56] hover:text-[#0B0B0B]">Reset</button><Btn size="sm">Next <Arrow /></Btn></>}>
        <H>Pick your keys.</H>
        <P>One modifier per wheel. Click a key to change it. The defaults work for most people.</P>
        <div className="mt-6 border-t border-[#0B0B0B]">
          {['Convert', 'Tools', 'Actions'].map((w, i) => (
            <div key={w} className="grid grid-cols-[28px_1fr_auto] items-center gap-3 border-b border-[#D6D6D0] py-3">
              <span className="font-mono text-[11px] text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</span>
              <div>
                <div className="font-grotesk text-[22px] font-semibold leading-none tracking-[-0.03em]">{w}</div>
                <div className="mt-1 font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">Hold {names[keys[i]]} while dragging</div>
              </div>
              <SwissKey symbol={keys[i]} name={names[keys[i]]} size={50} onClick={() => cycle(i)} pressed={i === 0} />
            </div>
          ))}
        </div>
      </Screen>

      {/* 05 Pro */}
      <Screen at={4} title="Licence" className="min-h-[460px]" foot={<><button type="button" onClick={() => setPlan(0)} className="whitespace-nowrap px-2 font-sans text-[12px] text-[#5C5C56] hover:text-[#0B0B0B]">Stay on Local</button><Btn size="sm" kind={plan === 1 ? 'primary' : 'ghost'}>{plan === 1 ? 'Activate' : 'Next'} <Arrow /></Btn></>}>
        <H>Local or Pro.</H>
        <P>Everything on your Mac is free. Pro is optional and adds server features.</P>
        <div className="mt-5 grid grid-cols-2 gap-2">
          {[['Local', 'Free', 'forever'], ['Pro', '$4', '/month']].map(([n, p, per], i) => (
            <button key={n} type="button" onClick={() => setPlan(i)} aria-pressed={plan === i}
              className={cn('relative border p-3 text-left transition-colors', plan === i ? 'border-[#0B0B0B] bg-[#0B0B0B] text-[#F4F4F1]' : 'border-[#D6D6D0] hover:border-[#0B0B0B]')}>
              {plan === i && <span className="absolute right-2 top-2 size-2 bg-[#FF3D2E]" />}
              <Mono className="opacity-70">{n}</Mono>
              <div className="mt-3 font-grotesk text-[34px] font-semibold leading-none tracking-[-0.05em]">{p}<span className="ml-1 font-mono text-[11px] font-medium opacity-60">{per}</span></div>
            </button>
          ))}
        </div>
        <label className="mt-4 block">
          <Mono className="text-[10px] text-[#5C5C56]">Licence key</Mono>
          <div className={cn('mt-1.5 flex h-10 items-center border px-3 font-mono text-[13px] tracking-[0.08em]', plan === 1 ? 'border-[#0B0B0B]' : 'border-[#D6D6D0] text-[#BDBDB6]')}>
            HALO-····-····-····
            {plan === 1 && <span className="ml-0.5 inline-block h-4 w-[2px] animate-pulse bg-[#FF3D2E]" />}
          </div>
        </label>
      </Screen>

      {/* 06 Done */}
      <Screen at={5} title="Ready" className="min-h-[460px]" foot={<Btn size="sm">Start dragging <Arrow /></Btn>}>
        <div className="flex items-start justify-between">
          <span className="grid size-14 place-items-center bg-[#0B0B0B] text-[#F4F4F1]"><Check size={26} strokeWidth={2.6} /></span>
          <Mono className="text-[#5C5C56]">Setup 6 / 6</Mono>
        </div>
        <div className="mt-8"><H>Ready.</H></div>
        <P>Halo lives in your menu bar. Drag any file and press a key.</P>
        <div className="relative mt-8">
          <div className="flex h-7 items-center justify-end gap-4 rounded-[6px] border border-[#D6D6D0] bg-[#F4F4F1] px-3 font-sans text-[12px] font-medium">
            <span className="text-[#5C5C56]">Wi-Fi</span>
            <span className="relative grid h-[22px] w-7 place-items-center">
              <MenuGlyph size={16} color="#0B0B0B" />
              <span className="absolute -inset-1.5 rounded-full border-[1.5px] border-[#FF3D2E]" />
            </span>
            <span className="tabular-nums">09:41</span>
          </div>
          <div className="mr-[76px] mt-2 flex justify-end">
            <div className="flex flex-col items-end">
              <span className="h-6 w-px bg-[#FF3D2E]" />
              <Mono className="mt-1">Halo is here</Mono>
            </div>
          </div>
        </div>
        <div className="mt-6 flex items-center gap-4">
          <GridWheel segments={SETS.actions} size={92} active={1} interactive={false} showIndex={false} labelScale={0} />
          <div className="font-mono text-[11px] leading-relaxed text-[#5C5C56]">⇧ CONVERT<br />⌘ TOOLS<br />⌃ ACTIONS</div>
          <div className="ml-auto hidden sm:block"><Lockup h={18} /></div>
        </div>
      </Screen>
    </div>
  )
}
