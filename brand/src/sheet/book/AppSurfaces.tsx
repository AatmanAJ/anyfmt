import { useState, type ReactNode } from 'react'
import { Check, ChevronRight, Copy, Layers, Settings, TriangleAlert, X } from 'lucide-react'
import { Mark } from '../Mark'
import { FileTile, Lbl, Section, Sub, Win } from './ui'

type T = { bg: string; s1: string; s2: string; line: string; edge: string; text: string; mute: string; inv: string; invText: string }
const LIGHT: T = { bg: '#FFFFFF', s1: '#F8FAFC', s2: '#E2E9F3', line: '#D3D9E2', edge: '#000000', text: '#000000', mute: '#686562', inv: '#000000', invText: '#FFFFFF' }
const DARK: T = { bg: '#0B0B0B', s1: '#161616', s2: '#202020', line: '#2C2C2C', edge: '#4A4A4A', text: '#FFFFFF', mute: '#9A9794', inv: '#FFFFFF', invText: '#000000' }

const edge = (t: T, c = t.edge) => ({ boxShadow: `inset 0 0 0 1px ${c}` })

function MenuDrop({ t }: { t: T }) {
  const rows: [string, ReactNode?][] = [['Choose a file to convert…', <span key="a" className="shb-num text-[12px]">⌘O</span>], ['Open Float shelf', <span key="b" className="shb-num text-[12px]" style={{ color: t.mute }}>3 files</span>], ['Recent conversions', <ChevronRight key="c" size={14} />]]
  return (
    <div className="w-full max-w-[300px] rounded-[8px] p-1.5" style={{ background: t.bg, color: t.text, ...edge(t) }}>
      <div className="flex items-center gap-2.5 px-2.5 py-2">
        <Mark size={22} ink={t.text} /><div className="flex-1"><div className="text-[14px] font-[600]">anyfmt</div><div className="text-[12px]" style={{ color: t.mute }}>Ready · drag any file</div></div>
      </div>
      <div className="my-1 h-px" style={{ background: t.line }} />
      {rows.map(([l, r], i) => (
        <div key={l} className="flex items-center justify-between rounded-[4px] px-2.5 py-[7px] text-[14px]" style={i === 0 ? { background: t.inv, color: t.invText } : undefined}>
          <span>{l}</span><span className="flex items-center" style={i === 0 ? { color: t.invText } : undefined}>{r}</span>
        </div>
      ))}
      <div className="my-1 h-px" style={{ background: t.line }} />
      <div className="px-2.5 py-1"><div className="shb-lbl text-[11px]" style={{ color: t.mute }}>Last</div></div>
      {['clip.gif · 3.8 MB', 'IMG_0042.jpg · 2.1 MB'].map((f) => <div key={f} className="sh-code px-2.5 py-[5px] text-[13px]">{f}</div>)}
      <div className="my-1 h-px" style={{ background: t.line }} />
      {['Settings…', 'Quit anyfmt'].map((l, i) => <div key={l} className="flex justify-between px-2.5 py-[6px] text-[14px]"><span>{l}</span><span className="shb-num text-[12px]" style={{ color: t.mute }}>{i === 0 ? '⌘,' : '⌘Q'}</span></div>)}
    </div>
  )
}

function Progress({ t }: { t: T }) {
  return (
    <div className="flex h-[44px] w-full max-w-[340px] items-center gap-3 rounded-[999px] pl-2 pr-4" style={{ background: t.bg, color: t.text, ...edge(t) }}>
      <FileTile ext="MOV" size={22} dark={t === DARK} />
      <div className="min-w-0 flex-1">
        <div className="flex justify-between text-[13px]"><span className="truncate font-[500]">clip.mov → GIF</span><span className="shb-num" style={{ color: t.mute }}>62%</span></div>
        <div className="mt-1 h-[3px] rounded-full" style={{ background: t.line }}><div className="h-full rounded-full" style={{ width: '62%', background: t.text }} /></div>
      </div>
      <X size={14} style={{ color: t.mute }} />
    </div>
  )
}

function Toast({ t, err }: { t: T; err?: boolean }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="flex w-full max-w-[380px] items-start gap-3 rounded-[10px] p-3" style={{ background: t.bg, color: t.text, ...edge(t) }}>
      {err ? <TriangleAlert size={20} strokeWidth={1.5} className="mt-[1px] flex-none" /> : <FileTile ext="GIF" size={24} dark={t === DARK} />}
      <div className="min-w-0 flex-1">
        <div className="text-[14px] font-[600]">{err ? 'Couldn’t convert talk.mkv' : 'Converted to GIF'}</div>
        <div className="text-[13px]" style={{ color: t.mute }}>{err ? 'The audio track uses a codec MP4 can’t hold (TrueHD). Convert to MKV, or to MP4 without audio.' : 'clip.gif · 3.8 MB · next to clip.mov'}</div>
        <div className="mt-2.5 flex gap-2">
          {err
            ? <button onClick={() => setCopied(true)} className="sh-btn !h-7 !px-3 !text-[12px]" style={{ ...edge(t, t.text), color: t.text }}>{copied ? <><Check size={13} />Copied</> : <><Copy size={13} />Copy details</>}</button>
            : <button className="sh-btn !h-7 !px-3 !text-[12px]" style={{ background: t.inv, color: t.invText }}>Show in Finder</button>}
          <button className="sh-btn !h-7 !px-3 !text-[12px]" style={{ color: t.mute }}>{err ? 'Try MP4, no audio' : 'Undo'}</button>
        </div>
      </div>
    </div>
  )
}

function Shelf({ t }: { t: T }) {
  return (
    <div className="w-full max-w-[380px] rounded-[10px] p-3" style={{ background: t.bg, color: t.text, ...edge(t) }}>
      <div className="flex items-center justify-between px-1">
        <span className="flex items-center gap-2 text-[13px] font-[600]"><Layers size={14} />Float</span>
        <span className="shb-lbl text-[11px]" style={{ color: t.mute }}>3 files · drag out</span>
      </div>
      <div className="mt-3 grid grid-cols-3 gap-2">
        {[['JPG', 'beach.jpg'], ['MP3', 'memo.mp3'], ['PDF', 'invoice.pdf']].map(([e, n]) => (
          <div key={n} className="flex flex-col items-center gap-1.5 rounded-[6px] py-3" style={{ background: t.s1 }}>
            <FileTile ext={e} size={30} dark={t === DARK} /><span className="sh-code max-w-full truncate px-1 text-[11px]">{n}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function Options({ t }: { t: T }) {
  const [fps, setFps] = useState(1)
  const chips = [['10 fps', '2.4 MB'], ['15 fps', '3.8 MB'], ['24 fps', '6.1 MB'], ['30 fps', '7.6 MB']]
  return (
    <div className="w-full max-w-[380px] rounded-[10px] p-4" style={{ background: t.bg, color: t.text, ...edge(t) }}>
      <div className="flex items-center justify-between"><span className="text-[14px] font-[600]">GIF options</span><span className="shb-lbl text-[11px]" style={{ color: t.mute }}>clip.mov · 12 s</span></div>
      <div className="shb-lbl mt-4 text-[11px]" style={{ color: t.mute }}>Frame rate · estimated size</div>
      <div className="mt-2 grid grid-cols-4 gap-1.5" role="radiogroup" aria-label="Frame rate">
        {chips.map(([f, s], i) => (
          <button key={f} role="radio" aria-checked={fps === i} onClick={() => setFps(i)} className="flex flex-col items-start rounded-[6px] px-2 py-2 text-left"
            style={fps === i ? { background: t.inv, color: t.invText } : { background: t.s1, ...edge(t, t.line) }}>
            <span className="text-[13px] font-[600]">{f}</span><span className="shb-num text-[11px]" style={{ opacity: 0.7 }}>{s}</span>
          </button>
        ))}
      </div>
      <div className="mt-4 flex items-center justify-between text-[13px]"><span>Width</span><span className="shb-num rounded-[4px] px-2 py-1" style={{ background: t.s1, ...edge(t, t.line) }}>480 px</span></div>
      <div className="mt-2 flex items-center justify-between text-[13px]"><span>Loop</span><span className="shb-toggle" aria-checked="true" style={{ background: t.text, display: 'inline-block', ['--thumb' as string]: t.bg }} /></div>
      <div className="mt-4 flex justify-end gap-2"><button className="sh-btn !h-8 !px-4 !text-[13px]" style={{ ...edge(t, t.text), color: t.text }}>Save preset</button><button className="sh-btn !h-8 !px-4 !text-[13px]" style={{ background: t.inv, color: t.invText }}>Convert</button></div>
    </div>
  )
}

function General({ t }: { t: T }) {
  const dark = t === DARK
  return (
    <Win dark={dark} title="General" className="w-full max-w-[560px]">
      <div className="grid grid-cols-[130px_1fr] md:grid-cols-[160px_1fr]" style={{ background: t.bg, color: t.text }}>
        <div className="p-2" style={{ background: t.s1, borderRight: `1px solid ${t.line}` }}>
          {['General', 'Keys', 'Wheel', 'Presets', 'Pro', 'About'].map((s, i) => (
            <div key={s} className="flex items-center gap-2 rounded-[4px] px-2.5 py-[6px] text-[13px]" style={i === 0 ? { background: t.inv, color: t.invText } : undefined}>{i === 0 && <Settings size={13} />}{s}</div>
          ))}
        </div>
        <div className="p-4">
          {[['Open at login', true], ['Show in menu bar', true], ['Check for updates', false], ['Play a sound when done', false]].map(([l, on]) => (
            <div key={l as string} className="flex items-center justify-between py-2.5 text-[13px]" style={{ borderBottom: `1px solid ${t.line}` }}>
              <span>{l as string}</span><span className="shb-toggle" aria-checked={on as boolean} style={{ background: on ? t.text : t.line, display: 'inline-block', ['--thumb' as string]: on ? t.bg : '#fff' }} />
            </div>
          ))}
          <div className="flex items-center justify-between py-2.5 text-[13px]" style={{ borderBottom: `1px solid ${t.line}` }}>
            <span>Save converted files</span><span className="rounded-[4px] px-2 py-1 text-[12px]" style={{ background: t.s1, ...edge(t, t.line) }}>Next to original ▾</span>
          </div>
          <p className="mt-3 text-[12px]" style={{ color: t.mute }}>Updates are off, so anyfmt makes no network calls.</p>
        </div>
      </div>
    </Win>
  )
}

const ROWS: [string, string, (p: { t: T }) => ReactNode][] = [
  ['10.1', 'Menu-bar dropdown', MenuDrop],
  ['10.2', 'Progress pill', Progress],
  ['10.3', 'Done toast', (p) => <Toast {...p} />],
  ['10.4', 'Error toast · Copy details', (p) => <Toast {...p} err />],
  ['10.5', 'Float shelf', Shelf],
  ['10.6', 'Options panel · frame-rate chips', Options],
  ['10.7', 'Settings · General', General],
]

export function AppSurfaces() {
  return (
    <Section id="app" n={10} label="App surfaces" title={<>The same rules, <span className="sh-hl">in the menu bar.</span></>}
      lede="App surfaces float, so they take the ink hairline. In dark mode ink and paper swap; the tints become greys. Orange stays out of the interface entirely.">
      {ROWS.map(([n, title, C]) => (
        <Sub key={n} n={n} title={title}>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="sh-dots relative grid min-h-[200px] place-items-center rounded-[4px] bg-[var(--sh-mist)] px-5 pb-6 pt-10 md:px-8"><Lbl className="absolute left-3 top-3 !text-black">Light</Lbl><C t={LIGHT} /></div>
            <div className="shb-dots-d relative grid min-h-[200px] place-items-center rounded-[4px] px-5 pb-6 pt-10 md:px-8" style={{ backgroundColor: '#1A1A1A' }}><Lbl className="absolute left-3 top-3 !text-[#9A9794]">Dark</Lbl><C t={DARK} /></div>
          </div>
        </Sub>
      ))}
    </Section>
  )
}
