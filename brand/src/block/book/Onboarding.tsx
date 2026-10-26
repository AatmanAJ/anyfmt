import { Check } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { IsoBlock, IsoKeycap, IsoScene } from '../Iso'
import { Mark } from '../Mark'
import { BlockWheel } from '../BlockWheel'
import { isShot } from '../../shared/kit'
import { MarkCubes } from './isoBits'
import { C, Caption, Lights, Scaled, Section, Tile } from './ui'

const W = 700, H = 460

function Win({ step, title, art, artBg, children, foot }: { step: number; title: string; art: ReactNode; artBg: string; children: ReactNode; foot: ReactNode }) {
  return (
    <div className="flex flex-col overflow-hidden rounded-[12px] bg-[#1C1C21] text-[#F4F1EC] shadow-[0_30px_60px_-30px_rgba(0,0,0,.8)] ring-1 ring-[#2C2C33]" style={{ width: W, height: H }}>
      <div className="relative flex h-[38px] shrink-0 items-center px-3.5">
        <Lights />
        <span className="absolute inset-x-0 text-center text-[12.5px] font-[600] text-[#F4F1EC]/60">{title}</span>
      </div>
      <div className="flex min-h-0 flex-1">
        <div className="relative m-2 mt-0 grid w-[236px] shrink-0 place-items-center overflow-hidden rounded-[8px]" style={{ background: artBg }}>{art}</div>
        <div className="flex min-w-0 flex-1 flex-col px-6 pb-5 pt-3">
          <div className="mb-5 flex gap-1">
            {Array.from({ length: 7 }, (_, i) => <span key={i} className="h-[5px] flex-1 rounded-[1px]" style={{ background: i < step ? C.orange : i === step ? C.cream : C.ink3 }} />)}
          </div>
          <div className="min-h-0 flex-1">{children}</div>
          <div className="flex items-center justify-end gap-3">{foot}</div>
        </div>
      </div>
    </div>
  )
}

const H1 = ({ children }: { children: ReactNode }) => <h4 className="bk-display mb-2 text-[34px] font-[650] leading-[.98]">{children}</h4>
const P = ({ children }: { children: ReactNode }) => <p className="text-[14.5px] leading-[1.5] text-[#F4F1EC]/70">{children}</p>
const Btn = ({ kind = 'orange', children, onClick }: { kind?: 'orange' | 'line' | 'ink'; children: ReactNode; onClick?: () => void }) => (
  <button onClick={onClick} className={`bk-btn bk-btn-${kind} !h-[38px] !px-4 !text-[14px]`} style={kind === 'ink' ? { background: C.cream, color: C.ink } : undefined}>{children}</button>
)
const Step = ({ n }: { n: number }) => <span className="bk-mono mr-auto text-[11px] uppercase tracking-[.08em] text-[#8A8790]">Step {n} of 7</span>

function Welcome() {
  return (
    <Win step={0} title="Welcome to anyfmt" artBg={C.orange} art={<Mark size={170} variant="icon" />}
      foot={<><Step n={1} /><Btn>Set it up</Btn></>}>
      <H1>Hi. This is <span className="text-[#FF6B1A]">anyfmt.</span></H1>
      <P>Drag any file, press a key, drop it on what you want. It lives in your menu bar and runs entirely on your Mac.</P>
      <div className="mt-5 flex flex-col gap-2 text-[14px]">
        {[['⇧', 'Convert', '793 routes'], ['⌘', 'Tools', '26 tools'], ['⌃', 'Actions', 'AirDrop, Float, Copy…']].map(([k, n, s]) => (
          <div key={k} className="flex items-center gap-3"><span className="bk-tag !h-[24px] !w-[28px] justify-center !p-0 !text-[14px]" style={{ background: C.ink3, color: C.orange }}>{k}</span><b className="w-[70px] font-[620]">{n}</b><span className="text-[#F4F1EC]/55">{s}</span></div>
        ))}
      </div>
      <p className="bk-mono mt-5 text-[11px] text-[#8A8790]">Takes about a minute. You can change everything later.</p>
    </Win>
  )
}

function TryIt() {
  const [open, setOpen] = useState(isShot)
  useEffect(() => {
    const d = (e: KeyboardEvent) => e.key === 'Shift' && setOpen(true), u = (e: KeyboardEvent) => e.key === 'Shift' && !isShot && setOpen(false)
    window.addEventListener('keydown', d); window.addEventListener('keyup', u)
    return () => { window.removeEventListener('keydown', d); window.removeEventListener('keyup', u) }
  }, [])
  return (
    <Win step={1} title="Try it" artBg={C.ink}
      art={
        <div className="relative grid size-full place-items-center bkb-dots">
          <div className="relative">
            <div className="grid h-[86px] w-[70px] place-items-center rounded-[6px] bg-[#F4F1EC] text-[#0E0E10] shadow-[4px_4px_0_#FF6B1A]">
              <span className="bk-mono rounded-[3px] bg-[#0E0E10] px-1.5 py-0.5 text-[10px] font-[700] text-[#F4F1EC]">MOV</span>
            </div>
            <span className="bk-mono absolute -bottom-6 left-0 text-[10px] text-[#8A8790]">sample.mov</span>
          </div>
          {open && (
            <div className="absolute inset-0 grid place-items-center">
              <BlockWheel size={200} active={0} wedges={['GIF', 'MP4', 'WEBM', 'MP3', 'PNG', 'M4V'].map((l) => ({ id: l, label: l }))} hub={<span className="bk-display text-[15px] font-[700]">MOV</span>} />
            </div>
          )}
        </div>
      }
      foot={<><Step n={2} /><Btn kind="line">Skip</Btn><Btn>{open ? 'Nice. Next' : 'Next'}</Btn></>}>
      <H1>Drag the sample. <span className="text-[#FF6B1A]">Press ⇧.</span></H1>
      <P>Pick up sample.mov on the left. While you're holding it, press Shift. A wheel of formats opens around your pointer. Drop it on GIF.</P>
      <div className="mt-5 rounded-[8px] bg-[#0E0E10] p-3 ring-1 ring-inset ring-[#2C2C33]">
        <div className="bk-mono flex items-center gap-2 text-[12px]">
          <span className={`size-2 rounded-full ${open ? 'bg-[#FF6B1A]' : 'bg-[#2C2C33]'}`} />
          {open ? 'Wheel open · aiming at GIF' : 'Waiting for ⇧…'}
        </div>
      </div>
      <p className="bk-mono mt-3 text-[11px] text-[#8A8790]">On this page, holding Shift opens it too.</p>
    </Win>
  )
}

function Permissions() {
  const [g, setG] = useState<Record<string, boolean>>(isShot ? { notif: true } : {})
  const rows = [
    ['notif', 'Notifications', 'Tells you when a long conversion finishes.'],
    ['disk', 'Full Disk Access', 'Lets anyfmt save into protected folders like Mail Downloads.'],
    ['auto', 'Automation · Finder', 'Lets "Reveal" select the new file in Finder.'],
  ]
  return (
    <Win step={2} title="Permissions" artBg={C.lilac}
      art={<div className="bk-display px-5 text-center text-[#0E0E10]"><div className="text-[120px] font-[700] leading-[.8]">0</div><div className="mt-2 text-[20px] font-[620] leading-[1.05]">permissions needed for the core</div></div>}
      foot={<><Step n={3} /><Btn>Continue</Btn></>}>
      <H1>Nothing to grant. <span className="text-[#B8B3FF]">Really.</span></H1>
      <P>Converting, tools and actions all work without any permissions. These extras are optional.</P>
      <div className="mt-4 flex flex-col gap-2">
        {rows.map(([id, t, why]) => (
          <div key={id} className="flex items-center gap-3 rounded-[8px] bg-[#0E0E10] px-3 py-2.5 ring-1 ring-inset ring-[#2C2C33]">
            <div className="min-w-0 flex-1"><div className="text-[14px] font-[620]">{t}</div><div className="truncate text-[12.5px] text-[#F4F1EC]/55">{why}</div></div>
            {g[id]
              ? <span className="bk-tag !h-[30px]" style={{ background: C.lilac, color: C.ink }}><Check size={13} strokeWidth={3} />Granted</span>
              : <button onClick={() => setG((s) => ({ ...s, [id]: true }))} className="bk-btn bk-btn-line !h-[30px] !px-2.5 !text-[12px]">Open System Settings</button>}
          </div>
        ))}
      </div>
    </Win>
  )
}

function Keys() {
  const opts = ['⇧', '⌥', '⌘', '⌃', 'fn']
  const [pick, setPick] = useState<Record<string, string>>({ Convert: '⇧', Tools: '⌘', Actions: '⌃' })
  return (
    <Win step={3} title="Pick your keys" artBg={C.orange}
      art={
        <div className="w-full px-2">
          <IsoScene width={240} height={260} unit={70} anchor={[0.5, 0.5]}>
            {(ctx) => (<>
              <IsoKeycap ctx={ctx} x={-1.55} y={-0.5} legend={pick.Convert} material="cream" pressed />
              <IsoKeycap ctx={ctx} x={-0.45} y={-0.5} legend={pick.Tools} material="lilac" />
              <IsoKeycap ctx={ctx} x={0.65} y={-0.5} legend={pick.Actions} material="inkLight" ink={C.cream} />
            </>)}
          </IsoScene>
        </div>
      }
      foot={<><Step n={4} /><Btn kind="line">Use defaults</Btn><Btn>Continue</Btn></>}>
      <H1>Pick your <span className="text-[#FF6B1A]">keys.</span></H1>
      <P>Press one of these while dragging to open a wheel. Each wheel needs its own key.</P>
      <div className="mt-4 flex flex-col gap-2.5">
        {Object.keys(pick).map((w) => (
          <div key={w} className="flex items-center gap-3">
            <span className="w-[68px] text-[14px] font-[620]">{w}</span>
            <div className="flex gap-1.5">
              {opts.map((o) => {
                const on = pick[w] === o
                const taken = !on && Object.values(pick).includes(o)
                return (
                  <button key={o} disabled={taken} onClick={() => setPick((p) => ({ ...p, [w]: o }))}
                    className="grid h-[34px] w-[40px] place-items-center rounded-[5px] text-[15px] font-[650] disabled:opacity-30"
                    style={{ background: on ? C.orange : C.ink, color: on ? C.ink : C.cream, boxShadow: on ? `2px 2px 0 ${C.wine2}` : `inset 0 0 0 1px ${C.ink3}` }}>{o}</button>
                )
              })}
            </div>
          </div>
        ))}
      </div>
    </Win>
  )
}

function Toggle({ on, onClick }: { on: boolean; onClick: () => void }) {
  return (
    <button role="switch" aria-checked={on} onClick={onClick} className="relative h-[26px] w-[46px] shrink-0 rounded-[5px] transition-colors" style={{ background: on ? C.orange : C.ink3 }}>
      <span className="absolute top-[3px] size-[20px] rounded-[3px] bg-[#F4F1EC] transition-[left]" style={{ left: on ? 23 : 3, boxShadow: `2px 2px 0 ${on ? C.wine2 : C.ink}` }} />
    </button>
  )
}

function Launch() {
  const [t, setT] = useState({ login: true, auto: true, beta: false })
  const rows: [keyof typeof t, string, string][] = [
    ['login', 'Open at login', 'So the wheel is there the first time you drag.'],
    ['auto', 'Install updates automatically', 'Small, signed updates. We check once a day.'],
    ['beta', 'Get beta updates', 'New routes and tools earlier. Rougher edges.'],
  ]
  return (
    <Win step={4} title="Login and updates" artBg={C.wine}
      art={
        <IsoScene width={220} height={240} unit={44} anchor={[0.5, 0.66]}>
          {(ctx) => (<>
            <IsoBlock ctx={ctx} x={-1.5} y={-1.5} z={0} w={3} d={3} h={0.5} material="stripePink" />
            <IsoBlock ctx={ctx} x={-1} y={-1} z={0.5} w={2} d={2} h={0.5} material="pink" />
            <IsoBlock ctx={ctx} x={-0.5} y={-0.5} z={1} w={1} d={1} h={1.1} material="orange" />
          </>)}
        </IsoScene>
      }
      foot={<><Step n={5} /><Btn>Continue</Btn></>}>
      <H1>Always <span className="text-[#FF4FA0]">ready.</span></H1>
      <P>anyfmt is tiny in the menu bar and does nothing until you press a key.</P>
      <div className="mt-4 flex flex-col divide-y divide-[#2C2C33] rounded-[8px] bg-[#0E0E10] ring-1 ring-inset ring-[#2C2C33]">
        {rows.map(([k, title, sub]) => (
          <div key={k} className="flex items-center gap-3 px-3 py-2.5">
            <div className="flex-1"><div className="text-[14px] font-[620]">{title}</div><div className="text-[12.5px] text-[#F4F1EC]/55">{sub}</div></div>
            <Toggle on={t[k]} onClick={() => setT((s) => ({ ...s, [k]: !s[k] }))} />
          </div>
        ))}
      </div>
    </Win>
  )
}

function Pro() {
  return (
    <Win step={5} title="anyfmt Pro" artBg={C.pink}
      art={<div className="px-5 text-[#0E0E10]"><div className="bk-display text-[64px] font-[700] leading-[.85]">$4</div><div className="bk-mono mt-1 text-[11px] uppercase">a month · optional</div><div className="bk-display mt-5 text-[20px] font-[620] leading-[1.05]">Everything local stays free.</div></div>}
      foot={<><Step n={6} /><Btn kind="line">Activate</Btn><Btn>Skip, use it free</Btn></>}>
      <H1>Got a <span className="text-[#FF4FA0]">Pro key?</span></H1>
      <P>Pro adds the things that need a server: share links, cloud conversions for huge files, transcribe, upscale, preset sync.</P>
      <label className="mt-5 block">
        <span className="bk-mono mb-1.5 block text-[11px] uppercase tracking-[.08em] text-[#8A8790]">Licence key</span>
        <span className="flex h-[42px] items-center rounded-[6px] bg-[#0E0E10] px-3 ring-1 ring-inset ring-[#2C2C33]">
          <span className="bk-mono text-[14px] text-[#F4F1EC]">ANYFMT1-</span><span className="bk-mono text-[14px] text-[#F4F1EC]/30">XXXX-XXXX-XXXX</span>
          <span className="ml-0.5 h-[18px] w-[2px] bg-[#FF6B1A]" />
        </span>
      </label>
      <p className="mt-3 text-[13px] text-[#F4F1EC]/55">No key? Skip. You can add one any time in Settings.</p>
    </Win>
  )
}

function Done() {
  return (
    <Win step={7} title="All set" artBg={C.cream}
      art={
        <IsoScene width={220} height={240} unit={48} anchor={[0.5, 0.62]}>
          {(ctx) => <MarkCubes ctx={ctx} x={-1} y={-1} z={0} rest="ink" hot="orange" lift={1.1} />}
        </IsoScene>
      }
      foot={<Btn>Start using anyfmt</Btn>}>
      <H1>You're <span className="text-[#FF6B1A]">set.</span></H1>
      <P>anyfmt is in your menu bar. Drag anything off your Desktop and press a key.</P>
      <div className="mt-5 grid grid-cols-3 gap-2">
        {[['⇧', 'Convert'], ['⌘', 'Tools'], ['⌃', 'Actions']].map(([k, n]) => (
          <div key={k} className="rounded-[8px] bg-[#0E0E10] p-3 ring-1 ring-inset ring-[#2C2C33]">
            <div className="bk-display text-[30px] font-[650] leading-none text-[#FF6B1A]">{k}</div>
            <div className="mt-1 text-[13px] font-[600]">{n}</div>
          </div>
        ))}
      </div>
    </Win>
  )
}

const WINDOWS = [
  ['01 Welcome', Welcome, C.orange], ['02 Try it', TryIt, C.ink2], ['03 Permissions', Permissions, C.lilac], ['04 Keys', Keys, C.wine],
  ['05 Login + updates', Launch, C.ink2], ['06 Pro, optional', Pro, C.orange], ['07 Done', Done, C.lilac],
] as const

export function Onboarding() {
  return (
    <Section id="onboarding" num="09" title="Onboarding" accent="." intro="Seven short windows. Each one has a colour panel on the left that carries the idea and a plain column on the right that carries the words.">
      <div className="grid gap-2 md:grid-cols-2">
        {WINDOWS.map(([label, Win, bg], i) => (
          <Tile key={label} bg={bg === C.ink2 ? '' : bg} label={label} fg={bg === C.lilac || bg === C.orange ? C.ink : C.cream}
            className={`px-3 pb-6 pt-14 md:px-6 ${i === 6 ? 'md:col-span-2' : ''} ${bg === C.ink2 ? 'bkb-dots' : ''}`}
            style={bg === C.ink2 ? { backgroundColor: C.ink2 } : undefined}>
            <div className={i === 6 ? 'mx-auto max-w-[700px]' : ''}>
              <Scaled w={W} h={H}><Win /></Scaled>
            </div>
          </Tile>
        ))}
      </div>
      <Caption label="One idea per window">
        The core needs no permissions, so we say so first and make every extra optional with a one-line reason. "Open System Settings"
        flips to Granted when it comes back. On the Pro step, Skip is the primary button: free is the default, not the fallback.
      </Caption>
    </Section>
  )
}
