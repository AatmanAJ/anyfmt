import {
  BatteryFull, ChevronDown, ChevronRight, Copy, FolderOpen, GripHorizontal, Info, Keyboard, Layers, Pin, Settings, SlidersHorizontal, User, Wifi, X,
} from 'lucide-react'
import { useState, type CSSProperties, type ReactNode } from 'react'
import { AppIcon, Mark } from '../Mark'
import { Fit, Section, Sub } from './kit'
import { Lights, Toggle } from './Onboarding'
import { FPS, SizeChip, WIDTHS } from './System'

type T = { dark: boolean; panel: string; card: string; text: string; sub: string; mute: string; line: string; ring: string; hover: string }
const LIGHT: T = { dark: false, panel: 'rgba(250,250,249,.94)', card: '#FFFFFF', text: '#111111', sub: '#55524F', mute: '#8C8884', line: 'rgba(17,17,17,.08)', ring: '0 0 0 1px rgba(17,17,17,.1), 0 24px 50px -20px rgba(90,30,0,.4)', hover: 'rgba(17,17,17,.05)' }
const DARK: T = { dark: true, panel: 'rgba(26,26,26,.96)', card: '#1F1F1F', text: '#FFFFFF', sub: 'rgba(255,255,255,.66)', mute: 'rgba(255,255,255,.42)', line: 'rgba(255,255,255,.08)', ring: '0 0 0 1px rgba(255,255,255,.1), 0 0 0 1.5px #000, 0 30px 60px -20px rgba(0,0,0,.8)', hover: 'rgba(255,255,255,.06)' }

const hot: CSSProperties = { background: 'linear-gradient(180deg,#F59248,#E5701E)', color: '#fff', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.35)' }

function Backdrop({ t, children, className, label = true }: { t: T; children: ReactNode; className?: string; label?: boolean }) {
  return (
    <div className={`relative flex min-w-0 items-center justify-center overflow-hidden rounded-[22px] px-4 pb-8 pt-12 sm:px-8 ${t.dark ? 'afb-dark' : ''} ${className ?? ''}`}
      style={{ background: t.dark
        ? 'radial-gradient(70% 60% at 85% 0%, rgba(234,124,37,.28) 0%, transparent 60%), linear-gradient(170deg,#1C1C1C,#0A0A0A)'
        : 'radial-gradient(80% 70% at 30% 20%, #FFE3C8 0%, transparent 60%), linear-gradient(160deg,#FBEBDD,#F6D3B2 60%,#F0B587)' }}>
      {label && <span className={`absolute left-4 top-4 rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${t.dark ? 'bg-white/10 text-white/70' : 'bg-white/70 text-[#55524F]'}`}>{t.dark ? 'Dark' : 'Light'}</span>}
      {children}
    </div>
  )
}

function Pair({ children, className }: { children: (t: T) => ReactNode; className?: string }) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {[LIGHT, DARK].map((t) => <Backdrop key={String(t.dark)} t={t} className={className}>{children(t)}</Backdrop>)}
    </div>
  )
}

/* menu-bar dropdown */
function MenuDropdown({ t }: { t: T }) {
  const items: ([string, string?] | null)[] = [['Convert last file…', '⌘L'], ['Open Float shelf', '⌘F'], null, ['Presets'], ['Recent conversions'], null, ['Pro Licence & Account…'], ['Settings…', '⌘,'], ['Quit anyfmt', '⌘Q']]
  return (
    <div className="w-[300px]">
      <div className="flex h-7 items-center justify-end gap-3 rounded-[8px] px-3 text-[12px] font-medium" style={{ background: t.dark ? 'rgba(255,255,255,.08)' : 'rgba(255,255,255,.55)', color: t.text }}>
        <span className="grid h-[22px] place-items-center rounded-[5px] px-1" style={{ background: t.dark ? 'rgba(255,255,255,.2)' : 'rgba(17,17,17,.1)' }}><Mark size={15} variant="mono" style={{ color: t.text }} /></span>
        <Wifi size={13} /><BatteryFull size={16} /><span>Mon 9:41</span>
      </div>
      <div className="ml-auto mt-1.5 w-[270px] rounded-[14px] p-1.5 text-[13.5px] backdrop-blur-xl" style={{ background: t.panel, color: t.text, boxShadow: t.ring }}>
        <div className="flex items-center gap-2.5 px-2.5 py-2">
          <AppIcon size={30} />
          <div className="leading-tight"><div className="font-semibold">anyfmt</div><div className="text-[12px]" style={{ color: t.mute }}>Ready · drag any file</div></div>
          <span className="ml-auto size-2 rounded-full bg-[#1F9D55] shadow-[0_0_0_3px_rgba(31,157,85,.18)]" />
        </div>
        <div className="mx-1 my-1 h-px" style={{ background: t.line }} />
        {items.map((it, i) => it === null ? <div key={i} className="mx-1 my-1 h-px" style={{ background: t.line }} /> : (
          <div key={i} className="flex items-center rounded-[8px] px-2.5 py-[5px]" style={i === 0 ? hot : undefined}>
            <span>{it[0]}</span>
            {it[1] && <span className="af-mono ml-auto text-[11.5px]" style={{ color: i === 0 ? 'rgba(255,255,255,.8)' : t.mute }}>{it[1]}</span>}
            {!it[1] && (it[0] === 'Presets' || it[0] === 'Recent conversions') && <ChevronRight size={14} className="ml-auto" style={{ color: t.mute }} />}
          </div>
        ))}
      </div>
    </div>
  )
}

/* progress HUD + toasts */
export function Hud({ t }: { t: T }) {
  return (
    <div className="flex items-center gap-3 rounded-full py-2 pl-2 pr-2.5 backdrop-blur-xl" style={{ background: t.panel, color: t.text, boxShadow: t.ring }}>
      <svg width="36" height="36" viewBox="0 0 36 36" aria-hidden>
        <circle cx="18" cy="18" r="14.5" fill="none" stroke={t.dark ? 'rgba(255,255,255,.14)' : 'rgba(17,17,17,.08)'} strokeWidth="3.5" />
        <circle cx="18" cy="18" r="14.5" fill="none" stroke="#EA7C25" strokeWidth="3.5" strokeLinecap="round" strokeDasharray="91.1" strokeDashoffset="31.9" transform="rotate(-90 18 18)" />
        <text x="18" y="21.5" textAnchor="middle" fontSize="9.5" fontWeight="700" fill={t.text} fontFamily="Inter Tight Variable, sans-serif">65</text>
      </svg>
      <div className="min-w-0 text-[13px] leading-tight">
        <div className="font-semibold">clip.mov → GIF</div>
        <div className="af-mono text-[11px]" style={{ color: t.mute }}>65% · about 3 s left</div>
      </div>
      <button type="button" aria-label="Cancel" className="ml-3 grid size-7 place-items-center rounded-full" style={{ background: t.hover, color: t.sub }}><X size={14} /></button>
    </div>
  )
}

function Toast({ t, err }: { t: T; err?: boolean }) {
  const mini = (label: ReactNode, primary?: boolean) => (
    <span className={`af-btn ${primary ? 'af-btn-primary' : t.dark ? 'af-btn-dark' : 'af-btn-light'} !h-7 !gap-1.5 !rounded-[8px] !px-2.5 !text-[12px]`}>{label}</span>
  )
  return (
    <div className="flex w-[360px] items-start gap-3 rounded-[16px] p-3 pr-3.5 backdrop-blur-xl" style={{ background: t.panel, color: t.text, boxShadow: t.ring }}>
      {err
        ? <span className="grid size-9 shrink-0 place-items-center rounded-[10px] text-[15px] font-bold" style={{ background: t.dark ? 'rgba(187,63,20,.25)' : '#FDECE6', color: t.dark ? '#FF9466' : '#BB3F14' }}>!</span>
        : <AppIcon size={36} />}
      <div className="min-w-0 flex-1 text-[13px] leading-snug">
        <div className="flex items-baseline justify-between gap-2"><span className="font-semibold">{err ? 'Couldn’t convert clip.mkv' : 'clip.gif is ready'}</span><span className="text-[11px]" style={{ color: t.mute }}>now</span></div>
        <div style={{ color: t.sub }}>{err ? 'It uses a video codec anyfmt can’t read yet. Try MP4 instead, or send us the details.' : '4.1 MB · saved next to clip.mov'}</div>
        <div className="mt-2.5 flex gap-2">
          {err ? <>{mini(<><Copy size={12} />Copy details</>)}{mini('Dismiss')}</> : <>{mini(<><FolderOpen size={12} />Show in Finder</>)}{mini('Open')}</>}
        </div>
      </div>
    </div>
  )
}

/* Float shelf */
function Thumb({ kind }: { kind: 'photo' | 'video' | 'pdf' }) {
  if (kind === 'pdf') return (
    <div className="relative h-[84px] w-[66px] rounded-[6px] bg-white p-2 shadow-[0_0_0_1px_rgba(17,17,17,.08),0_8px_16px_-8px_rgba(0,0,0,.4)]">
      {[0, 1, 2, 3, 4].map((i) => <div key={i} className="mb-1.5 h-[3px] rounded-full bg-[#111]/10" style={{ width: i === 4 ? '55%' : '100%' }} />)}
      <span className="absolute bottom-1.5 left-1/2 -translate-x-1/2 rounded-[3px] bg-[#BB3F14] px-1 text-[8px] font-bold text-white">PDF</span>
    </div>
  )
  return (
    <div className="relative h-[84px] w-[66px] overflow-hidden rounded-[6px] shadow-[0_0_0_1px_rgba(17,17,17,.08),0_8px_16px_-8px_rgba(0,0,0,.4)]"
      style={{ background: kind === 'photo' ? 'linear-gradient(180deg,#9CC3E6 0%,#F4C9A0 55%,#5E7F5A 56%,#3F5E3E 100%)' : 'linear-gradient(160deg,#FFC08A,#EA7C25 55%,#8E2E0B)' }}>
      {kind === 'photo' && <span className="absolute right-2 top-2 size-3 rounded-full bg-[#FFE7B5]" />}
      {kind === 'video' && <span className="af-mono absolute bottom-1 right-1 rounded-[3px] bg-black/45 px-1 text-[8px] text-white">0:12</span>}
    </div>
  )
}
function Shelf({ t }: { t: T }) {
  const files: { k: 'photo' | 'video' | 'pdf'; n: string; s: string }[] = [
    { k: 'photo', n: 'IMG_0412.jpg', s: '2.4 MB' }, { k: 'video', n: 'clip.gif', s: '4.1 MB' }, { k: 'pdf', n: 'report.pdf', s: '860 KB' },
  ]
  return (
    <div className="w-[330px] rounded-[20px] p-2 backdrop-blur-xl" style={{ background: t.panel, color: t.text, boxShadow: t.ring }}>
      <div className="flex items-center gap-2 px-2 pb-2 pt-1">
        <Pin size={14} className="text-[#EA7C25]" /><span className="text-[13px] font-semibold">Float</span><span className="text-[12px]" style={{ color: t.mute }}>3 files</span>
        <GripHorizontal size={16} className="mx-auto" style={{ color: t.mute }} />
        <button type="button" aria-label="Clear shelf" className="grid size-6 place-items-center rounded-full" style={{ background: t.hover, color: t.sub }}><X size={12} /></button>
      </div>
      <div className="flex justify-between gap-2 rounded-[14px] px-3 py-3" style={{ background: t.dark ? 'rgba(255,255,255,.04)' : 'linear-gradient(180deg,#F4F3F1,#FAFAF9)', boxShadow: t.dark ? 'inset 0 0 0 1px rgba(255,255,255,.06)' : 'inset 0 1px 2px rgba(17,17,17,.06), inset 0 0 0 1px rgba(17,17,17,.05)' }}>
        {files.map((f, i) => (
          <div key={f.n} className="flex flex-col items-center gap-1.5" style={{ transform: i === 1 ? 'translateY(-2px)' : undefined }}>
            <Thumb kind={f.k} />
            <span className={`max-w-[86px] truncate rounded-[4px] px-1 text-[11px] font-medium ${i === 1 ? 'bg-[#2F6BE0] text-white' : ''}`}>{f.n}</span>
            <span className="af-mono -mt-1 text-[9.5px]" style={{ color: t.mute }}>{f.s}</span>
          </div>
        ))}
      </div>
      <div className="flex items-center justify-between px-2 pb-1 pt-2.5 text-[11.5px]" style={{ color: t.mute }}>
        <span>Drag out to drop anywhere</span><span className="font-medium" style={{ color: t.sub }}>Drag all</span>
      </div>
    </div>
  )
}

/* options panel */
function Options({ t }: { t: T }) {
  const [fps, setFps] = useState(15)
  const [w, setW] = useState(480)
  const [loop, setLoop] = useState(true)
  return (
    <div className="w-[400px] rounded-[20px] p-4 backdrop-blur-xl" style={{ background: t.panel, color: t.text, boxShadow: t.ring }}>
      <div className="flex items-center gap-3">
        <span className="h-10 w-12 shrink-0 rounded-[7px]" style={{ background: 'linear-gradient(160deg,#FFC08A,#EA7C25 55%,#8E2E0B)' }} />
        <div className="min-w-0 flex-1 leading-tight"><div className="text-[15px] font-semibold tracking-[-0.02em]">GIF options</div><div className="af-mono text-[11px]" style={{ color: t.mute }}>clip.mov · 0:12 · 48 MB</div></div>
        <span className="af-pill-status">Preset</span>
      </div>
      <div className="mt-4 text-[12px] font-semibold" style={{ color: t.sub }}>Frame rate</div>
      <div className="mt-2 flex flex-wrap gap-2">{FPS.map((x) => <SizeChip key={x.f} dark={t.dark} on={fps === x.f} top={`${x.f} fps`} sub={x.s} onClick={() => setFps(x.f)} />)}</div>
      <div className="mt-4 text-[12px] font-semibold" style={{ color: t.sub }}>Width</div>
      <div className="mt-2 flex flex-wrap gap-2">{WIDTHS.map((x) => <SizeChip key={x.w} dark={t.dark} on={w === x.w} top={`${x.w} px`} sub={x.s} onClick={() => setW(x.w)} />)}</div>
      <div className="mt-4 flex items-center justify-between rounded-[12px] px-3 py-2.5" style={{ background: t.hover }}>
        <span className="text-[13px] font-medium">Loop forever</span><Toggle on={loop} onClick={() => setLoop(!loop)} label="Loop" />
      </div>
      <div className="mt-4 flex items-center justify-between">
        <span className="text-[12px]" style={{ color: t.mute }}>Estimate <span className="af-mono font-medium" style={{ color: t.text }}>≈ {fps === 15 && w === 480 ? '4.1 MB' : `${(4.1 * (fps / 15) * (w / 480) ** 2).toFixed(1)} MB`}</span></span>
        <div className="flex gap-2">
          <span className={`af-btn ${t.dark ? 'af-btn-dark' : 'af-btn-light'} !h-9 !rounded-[10px] !px-3.5 !text-[13px]`}>Save as preset</span>
          <span className="af-btn af-btn-primary !h-9 !rounded-[10px] !px-4 !text-[13px]">Convert</span>
        </div>
      </div>
    </div>
  )
}

/* settings window */
function SettingsWin({ t }: { t: T }) {
  const [s, setS] = useState({ login: true, icon: true, updates: false, sounds: false })
  const nav: [ReactNode, string][] = [[<Settings size={15} />, 'General'], [<Keyboard size={15} />, 'Keys'], [<SlidersHorizontal size={15} />, 'Presets'], [<Pin size={15} />, 'Float shelf'], [<Layers size={15} />, 'Formats'], [<User size={15} />, 'Account'], [<Info size={15} />, 'About']]
  const row = (title: string, sub: string | null, ctl: ReactNode, first?: boolean) => (
    <div className="flex items-center gap-4 px-4 py-3" style={{ borderTop: first ? undefined : `1px solid ${t.line}` }}>
      <div className="min-w-0 flex-1 text-[13px] leading-snug"><div className="font-medium">{title}</div>{sub && <div className="text-[12px]" style={{ color: t.mute }}>{sub}</div>}</div>
      {ctl}
    </div>
  )
  const select = (v: string) => (
    <span className="flex h-7 items-center gap-1.5 rounded-[7px] px-2.5 text-[12.5px] font-medium" style={{ background: t.dark ? '#2A2A2A' : '#fff', boxShadow: t.dark ? 'inset 0 1px 0 rgba(255,255,255,.08), 0 0 0 1px #3A3A3A' : 'inset 0 1px 0 #fff, 0 0 0 1px #D9D6D2, 0 1px 2px rgba(17,17,17,.08)' }}>
      {v}<ChevronDown size={13} style={{ color: t.mute }} />
    </span>
  )
  const group = (children: ReactNode) => <div className="overflow-hidden rounded-[12px]" style={{ background: t.dark ? 'rgba(255,255,255,.04)' : '#fff', boxShadow: `0 0 0 1px ${t.dark ? 'rgba(255,255,255,.07)' : '#E7E5E2'}` }}>{children}</div>
  return (
    <div className="relative flex h-[480px] w-[740px] overflow-hidden rounded-[16px]" style={{ background: t.dark ? '#161616' : '#F7F7F7', color: t.text, boxShadow: t.ring }}>
      <div className="absolute left-4 top-4 z-10"><Lights /></div>
      <aside className="flex w-[196px] shrink-0 flex-col gap-0.5 p-2.5 pt-12" style={{ background: t.dark ? 'rgba(255,255,255,.03)' : 'rgba(17,17,17,.025)', borderRight: `1px solid ${t.line}` }}>
        {nav.map(([i, n], k) => (
          <div key={n} className="flex items-center gap-2.5 rounded-[8px] px-2.5 py-[6px] text-[13px] font-medium" style={k === 0 ? hot : { color: t.sub }}>{i}{n}</div>
        ))}
        <div className="mt-auto flex items-center gap-2 px-2 pb-1 text-[11px]" style={{ color: t.mute }}><Mark size={13} variant="mono" />anyfmt 1.0 · local</div>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex h-[46px] items-center px-5 text-[14px] font-semibold">General</div>
        <div className="flex flex-col gap-3.5 px-5 pb-5">
          {group(<>
            {row('Open anyfmt at login', null, <Toggle on={s.login} onClick={() => setS({ ...s, login: !s.login })} label="Open at login" />, true)}
            {row('Show icon in the menu bar', 'Hidden, the wheel still works. Open Settings from Spotlight.', <Toggle on={s.icon} onClick={() => setS({ ...s, icon: !s.icon })} label="Menu bar icon" />)}
          </>)}
          {group(<>
            {row('Save results', null, select('Next to the original'), true)}
            {row('If the name is taken', null, select('Keep both'))}
            {row('Wheel size', null, (
              <div className="flex w-[170px] items-center gap-2">
                <span className="text-[11px]" style={{ color: t.mute }}>S</span>
                <div className="relative h-1 flex-1 rounded-full" style={{ background: t.dark ? '#3A3A3A' : '#E2E0DC' }}>
                  <div className="absolute inset-y-0 left-0 w-[55%] rounded-full bg-[#EA7C25]" />
                  <span className="absolute left-[55%] top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow-[0_1px_3px_rgba(17,17,17,.35),0_0_0_.5px_rgba(17,17,17,.15)]" />
                </div>
                <span className="text-[11px]" style={{ color: t.mute }}>L</span>
              </div>
            ))}
          </>)}
          {group(<>
            {row('Check for updates automatically', 'Off. anyfmt makes no network calls unless you ask.', <Toggle on={s.updates} onClick={() => setS({ ...s, updates: !s.updates })} label="Check for updates" />, true)}
            {row('Play a sound when a job finishes', null, <Toggle on={s.sounds} onClick={() => setS({ ...s, sounds: !s.sounds })} label="Sounds" />)}
          </>)}
        </div>
      </div>
    </div>
  )
}

export function Surfaces() {
  return (
    <Section id="surfaces" n="09" eyebrow="App surfaces" title={<>Small, quick,<br /><span className="text-[#8C8884]">gone when done.</span></>}
      intro="anyfmt has no main window. It shows up as a menu, a pill, a toast, a shelf or a panel, and leaves as soon as it can. Every surface comes in light and dark: dark uses #111 and #1A1A1A with the same orange.">
      <Sub title="Menu-bar dropdown" note="The only menu. Status first, the last file second.">
        <Pair>{(t) => <MenuDropdown t={t} />}</Pair>
      </Sub>
      <Sub title="Progress, done and error" note="A pill for long jobs with a ring, the file, the time left and a cancel button. Toasts for results. Errors say what happened and what to do, and can copy their details.">
        <Pair>{(t) => (
          <div className="flex w-full flex-col items-center gap-4">
            <Fit w={360} h={52}><div className="flex justify-center"><Hud t={t} /></div></Fit>
            <Fit w={360} h={110}><Toast t={t} /></Fit>
            <Fit w={360} h={128}><Toast t={t} err /></Fit>
          </div>
        )}</Pair>
      </Sub>
      <Sub title="Float shelf" note="A floating tray that holds files between drags. Thumbnails, names and sizes, and a grip to move it.">
        <Pair>{(t) => <Fit w={330} h={216}><Shelf t={t} /></Fit>}</Pair>
      </Sub>
      <Sub title="Options panel" note="Opens when you hover a wedge for a moment. Every choice shows what it costs in megabytes, before you convert.">
        <Pair>{(t) => <Fit w={400} h={392}><Options t={t} /></Fit>}</Pair>
      </Sub>
      <Sub title="Settings" note="One window, grouped rows, plain labels. General is the pane people open most.">
        <div className="grid gap-4">
          {[LIGHT, DARK].map((t) => (
            <Backdrop key={String(t.dark)} t={t}><Fit w={740} h={480}><SettingsWin t={t} /></Fit></Backdrop>
          ))}
        </div>
      </Sub>
    </Section>
  )
}
