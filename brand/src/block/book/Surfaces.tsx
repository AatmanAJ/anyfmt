import { AlertTriangle, BatteryFull, Check, ChevronDown, Copy, FolderOpen, Layers, RotateCcw, Search, Settings, Sparkles, Wifi } from 'lucide-react'
import type { ReactNode } from 'react'
import { Mark } from '../Mark'
import { Glyph } from './Icon'
import { C, Caption, Lights, Scaled, Section, Sub, Tile } from './ui'

type T = { dark: boolean; desk: string; bar: string; panel: string; well: string; text: string; sub: string; line: string; hover: string }
const DARK: T = { dark: true, desk: C.ink, bar: '#1A1A1E', panel: C.ink2, well: C.ink, text: C.cream, sub: '#8A8790', line: C.ink3, hover: C.ink3 }
const LIGHT: T = { dark: false, desk: '#E4E0D8', bar: '#F1EEE8', panel: '#FFFFFF', well: C.cream, text: C.ink, sub: '#77737C', line: '#E2DED6', hover: C.cream }

const panelStyle = (t: T) => ({ background: t.panel, color: t.text, boxShadow: `0 0 0 1px ${t.line}, 0 24px 48px -24px rgba(0,0,0,${t.dark ? 0.8 : 0.35})` })

function MenuBar({ t }: { t: T }) {
  return (
    <div className="flex h-[30px] items-center gap-5 px-4 text-[13px] font-[560]" style={{ background: t.bar, color: t.text }}>
      <span className="font-[700]">Finder</span><span className="opacity-80">File</span><span className="opacity-80">Edit</span><span className="opacity-80">View</span>
      <span className="ml-auto grid place-items-center rounded-[4px] px-1.5 py-[3px]" style={{ background: t.dark ? 'rgba(255,255,255,.18)' : 'rgba(0,0,0,.1)' }}><Glyph size={16} /></span>
      <Wifi size={15} /><BatteryFull size={18} /><Search size={14} /><span>Mon 26 Oct 9:41</span>
    </div>
  )
}

function Item({ t, children, right, hot }: { t: T; children: ReactNode; right?: ReactNode; hot?: boolean }) {
  return (
    <div className="flex h-[30px] items-center gap-2.5 rounded-[5px] px-2.5 text-[13.5px]" style={{ background: hot ? C.orange : undefined, color: hot ? C.ink : undefined }}>
      {children}<span className="bk-mono ml-auto text-[11px]" style={{ color: hot ? C.ink : t.sub }}>{right}</span>
    </div>
  )
}

function Dropdown({ t }: { t: T }) {
  return (
    <div className="w-[300px] rounded-[10px] p-1.5" style={panelStyle(t)}>
      <div className="flex items-center gap-2.5 px-2.5 py-2">
        <Mark size={22} variant={t.dark ? 'color' : 'flat'} />
        <span className="bk-display text-[17px] font-[650]">anyfmt</span>
        <span className="bk-tag ml-auto !h-[20px] !px-1.5 !text-[10px]" style={{ background: C.lilac, color: C.ink }}>Local</span>
      </div>
      <div className="bk-mono px-2.5 pb-1 pt-2 text-[10.5px] uppercase tracking-[.08em]" style={{ color: t.sub }}>Recent</div>
      <Item t={t} right="MOV → GIF" hot>clip.gif</Item>
      <Item t={t} right="HEIC → JPG">IMG_2041.jpg</Item>
      <Item t={t} right="Compress">deck.pdf</Item>
      <div className="my-1.5 h-px" style={{ background: t.line }} />
      <Item t={t} right="3"><Layers size={14} />Float shelf</Item>
      <Item t={t} right="5"><Sparkles size={14} />Presets</Item>
      <Item t={t} right="⌘,"><Settings size={14} />Settings…</Item>
      <div className="my-1.5 h-px" style={{ background: t.line }} />
      <Item t={t} right="⌘Q">Quit anyfmt</Item>
    </div>
  )
}

function ProgressPill({ t }: { t: T }) {
  return (
    <div className="flex h-[44px] w-[320px] items-center gap-3 rounded-full pl-2 pr-4" style={panelStyle(t)}>
      <span className="grid size-[30px] place-items-center rounded-full" style={{ background: C.orange }}>
        <svg width="16" height="16" viewBox="0 0 16 16" className="bkb-spin"><circle cx="8" cy="8" r="6" fill="none" stroke={C.ink} strokeWidth="2.4" strokeDasharray="22 40" strokeLinecap="round" /></svg>
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex justify-between text-[13px] font-[600]"><span>clip.mov → GIF</span><span className="bk-mono text-[11.5px]" style={{ color: t.sub }}>62%</span></div>
        <div className="mt-1 h-[5px] overflow-hidden rounded-[2px]" style={{ background: t.line }}><div className="h-full w-[62%]" style={{ background: C.orange }} /></div>
      </div>
    </div>
  )
}

function DoneToast({ t }: { t: T }) {
  return (
    <div className="flex w-[360px] items-center gap-3 rounded-[10px] p-2.5 pr-3" style={panelStyle(t)}>
      <span className="grid size-[34px] shrink-0 place-items-center rounded-[7px]" style={{ background: C.orange, color: C.ink }}><Check size={18} strokeWidth={3} /></span>
      <div className="min-w-0 flex-1"><div className="text-[14px] font-[650]">Converted.</div><div className="bk-mono truncate text-[11.5px]" style={{ color: t.sub }}>clip.gif · 4.1 MB · Desktop</div></div>
      <button className="h-[28px] rounded-[5px] px-2.5 text-[12.5px] font-[600]" style={{ background: t.well, boxShadow: `inset 0 0 0 1px ${t.line}` }}>Reveal</button>
    </div>
  )
}

function ErrorToast({ t }: { t: T }) {
  return (
    <div className="w-[360px] rounded-[10px] p-3" style={panelStyle(t)}>
      <div className="flex gap-3">
        <span className="grid size-[34px] shrink-0 place-items-center rounded-[7px]" style={{ background: C.pink, color: C.ink }}><AlertTriangle size={17} strokeWidth={2.6} /></span>
        <div className="min-w-0 flex-1">
          <div className="text-[14px] font-[650]">Couldn't convert IMG_2041.heic.</div>
          <div className="text-[13px] leading-[1.4]" style={{ color: t.sub }}>It's still downloading from iCloud. Wait for it to finish, then drop it again.</div>
        </div>
      </div>
      <div className="mt-3 flex justify-end gap-2">
        <button className="flex h-[28px] items-center gap-1.5 rounded-[5px] px-2.5 text-[12.5px] font-[600]" style={{ background: t.well, boxShadow: `inset 0 0 0 1px ${t.line}` }}><Copy size={12} />Copy details</button>
        <button className="flex h-[28px] items-center gap-1.5 rounded-[5px] px-2.5 text-[12.5px] font-[650]" style={{ background: C.orange, color: C.ink, boxShadow: `2px 2px 0 ${C.wine2}` }}><RotateCcw size={12} />Retry</button>
      </div>
    </div>
  )
}

function FileChip({ ext, name, t, color }: { ext: string; name: string; t: T; color: string }) {
  return (
    <div className="flex items-center gap-2.5 rounded-[7px] p-2" style={{ background: t.well, boxShadow: `inset 0 0 0 1px ${t.line}` }}>
      <span className="bk-mono grid h-[38px] w-[32px] place-items-center rounded-[4px] text-[9px] font-[700]" style={{ background: color, color: C.ink }}>{ext}</span>
      <div className="min-w-0"><div className="truncate text-[13px] font-[600]">{name}</div><div className="bk-mono text-[10.5px]" style={{ color: t.sub }}>drag out</div></div>
    </div>
  )
}

function Shelf({ t }: { t: T }) {
  return (
    <div className="w-[210px] rounded-[12px] p-2" style={panelStyle(t)}>
      <div className="flex items-center justify-between px-1.5 pb-2 pt-1"><span className="text-[13px] font-[700]">Float</span><span className="bk-mono text-[11px]" style={{ color: t.sub }}>3 files</span></div>
      <div className="flex flex-col gap-1.5">
        <FileChip t={t} ext="GIF" name="clip.gif" color={C.orange} />
        <FileChip t={t} ext="PDF" name="deck-compressed.pdf" color={C.lilac} />
        <FileChip t={t} ext="JPG" name="IMG_2041.jpg" color={C.pink} />
      </div>
      <div className="mt-2 rounded-[7px] border border-dashed px-2 py-2.5 text-center text-[12px]" style={{ borderColor: t.line, color: t.sub }}>Drop here to keep</div>
    </div>
  )
}

function Options({ t }: { t: T }) {
  return (
    <div className="w-[300px] rounded-[12px] p-3.5" style={panelStyle(t)}>
      <div className="flex items-center justify-between"><span className="text-[14px] font-[700]">MOV → GIF</span><span className="bk-tag !h-[20px] !px-1.5 !text-[10px]" style={{ background: C.orange, color: C.ink }}>Options</span></div>
      <div className="bk-mono mb-1.5 mt-3 text-[10.5px] uppercase tracking-[.08em]" style={{ color: t.sub }}>Frame rate</div>
      <div className="grid grid-cols-4 gap-1.5">
        {[['10', '1.6'], ['15', '2.4'], ['24', '3.8'], ['30', '4.7']].map(([f, s], i) => (
          <div key={f} className="rounded-[5px] px-1.5 py-1.5 text-center" style={{ background: i === 1 ? C.orange : t.well, color: i === 1 ? C.ink : t.text, boxShadow: i === 1 ? `2px 2px 0 ${C.wine2}` : `inset 0 0 0 1px ${t.line}` }}>
            <div className="text-[13px] font-[700] leading-none">{f}</div><div className="bk-mono mt-0.5 text-[9.5px] opacity-70">{s} MB</div>
          </div>
        ))}
      </div>
      <div className="bk-mono mb-1.5 mt-3 flex justify-between text-[10.5px] uppercase tracking-[.08em]" style={{ color: t.sub }}><span>Width</span><span>640 px</span></div>
      <div className="relative h-[6px] rounded-[2px]" style={{ background: t.line }}><div className="h-full w-[45%] rounded-[2px]" style={{ background: C.orange }} /><span className="absolute top-1/2 size-[16px] -translate-y-1/2 rounded-[3px]" style={{ left: 'calc(45% - 8px)', background: t.dark ? C.cream : C.ink }} /></div>
      <div className="mt-3 flex items-center justify-between text-[13px]"><span>Loop forever</span><span className="relative h-[20px] w-[36px] rounded-[4px]" style={{ background: C.orange }}><span className="absolute right-[2px] top-[2px] size-[16px] rounded-[3px] bg-[#F4F1EC]" /></span></div>
      <div className="mt-3.5 flex items-center justify-between">
        <span className="bk-mono text-[11px]" style={{ color: t.sub }}>≈ 2.4 MB</span>
        <span className="bk-btn bk-btn-orange !h-[32px] !px-3.5 !text-[13px]">Convert</span>
      </div>
    </div>
  )
}

function Desk({ t }: { t: T }) {
  return (
    <div className="relative overflow-hidden rounded-[10px]" style={{ width: 1080, height: 600, background: t.desk }}>
      <div className={t.dark ? 'bkb-dots absolute inset-0 opacity-50' : ''} />
      <MenuBar t={t} />
      <div className="absolute right-[110px] top-[36px]"><Dropdown t={t} /></div>
      <div className="absolute left-[28px] top-[62px] flex flex-col gap-3">
        <ProgressPill t={t} />
        <DoneToast t={t} />
        <ErrorToast t={t} />
      </div>
      <div className="absolute bottom-[24px] left-[28px]"><Options t={t} /></div>
      <div className="absolute bottom-[24px] left-[404px]"><Shelf t={t} /></div>
      <div className="absolute bottom-[14px] right-[26px] text-right">
        <div className="bk-mono mb-1 text-[11px] uppercase tracking-[.08em]" style={{ color: t.sub }}>Appearance</div>
        <div className="bk-display text-[110px] font-[680] leading-[.8]" style={{ color: t.dark ? C.ink3 : '#D3CEC4' }}>{t.dark ? 'Dark.' : 'Light.'}</div>
      </div>
    </div>
  )
}

function SettingsPane({ t }: { t: T }) {
  const rows: [string, string, ReactNode][] = [
    ['Open at login', 'Start anyfmt when you log in.', <Sw on />],
    ['Show in menu bar', 'Hide it and use the keys only.', <Sw on />],
    ['Save new files', 'Where converted copies go.', <Sel>Next to the original</Sel>],
    ['When a name is taken', 'Never overwrites.', <Sel>Add a number</Sel>],
    ['Sounds', 'A small click on drop.', <Sw />],
    ['Updates', 'Checked once a day.', <Sel>Automatic</Sel>],
  ]
  function Sw({ on }: { on?: boolean }) {
    return <span className="relative block h-[22px] w-[40px] rounded-[4px]" style={{ background: on ? C.orange : t.line }}><span className="absolute top-[3px] size-[16px] rounded-[3px] bg-[#F4F1EC]" style={{ left: on ? 21 : 3 }} /></span>
  }
  function Sel({ children }: { children: ReactNode }) {
    return <span className="flex h-[28px] items-center gap-2 rounded-[5px] px-2.5 text-[13px] font-[560]" style={{ background: t.well, boxShadow: `inset 0 0 0 1px ${t.line}` }}>{children}<ChevronDown size={13} /></span>
  }
  return (
    <div className="flex overflow-hidden rounded-[12px]" style={{ width: 760, height: 520, ...panelStyle(t) }}>
      <div className="flex w-[200px] shrink-0 flex-col gap-0.5 p-3" style={{ background: t.dark ? '#16161A' : '#F6F4EF', borderRight: `1px solid ${t.line}` }}>
        <div className="mb-4 mt-0.5"><Lights /></div>
        {['General', 'Keys', 'Wheels', 'Presets', 'Agents', 'Pro', 'About'].map((n, i) => (
          <div key={n} className="flex h-[30px] items-center gap-2 rounded-[5px] px-2.5 text-[13.5px] font-[560]" style={{ background: i === 0 ? C.orange : undefined, color: i === 0 ? C.ink : undefined, boxShadow: i === 0 ? `2px 2px 0 ${C.wine2}` : undefined }}>
            {n}{n === 'Pro' && <span className="bk-tag ml-auto !h-[18px] !px-1.5 !text-[9.5px]" style={{ background: C.pink, color: C.ink }}>Optional</span>}
          </div>
        ))}
      </div>
      <div className="flex-1 overflow-hidden p-6">
        <div className="bk-display mb-1 text-[28px] font-[650] leading-none">General</div>
        <div className="mb-4 text-[13px]" style={{ color: t.sub }}>Everything runs on this Mac.</div>
        <div className="rounded-[8px]" style={{ background: t.well, boxShadow: `inset 0 0 0 1px ${t.line}` }}>
          {rows.map(([a, b, c], i) => (
            <div key={a} className="flex items-center gap-4 px-4 py-2.5" style={{ borderTop: i ? `1px solid ${t.line}` : undefined }}>
              <div className="flex-1"><div className="text-[14px] font-[600]">{a}</div><div className="text-[12px]" style={{ color: t.sub }}>{b}</div></div>{c}
            </div>
          ))}
        </div>
        <div className="mt-3 flex items-center gap-2 text-[12px]" style={{ color: t.sub }}><FolderOpen size={13} />0 network calls unless you ask for a Pro feature.</div>
      </div>
    </div>
  )
}

export function Surfaces() {
  return (
    <Section id="surfaces" num="10" title="App" accent=" surfaces." intro="The real UI, in both appearances. Panels are flat, corners are small, and orange marks the one thing happening right now.">
      <Sub n="10.1">Menu bar, pills, toasts, shelf, options</Sub>
      <div className="grid gap-2">
        <Tile bg={C.ink2} label="Dark" fg={C.cream} className="px-3 pb-4 pt-12 md:px-6"><Scaled w={1080} h={600}><Desk t={DARK} /></Scaled></Tile>
        <Tile bg={C.lilac} label="Light" fg={C.ink} className="px-3 pb-4 pt-12 md:px-6"><Scaled w={1080} h={600}><Desk t={LIGHT} /></Scaled></Tile>
      </div>
      <Caption label="One thing is orange">
        In any surface, orange marks what's happening: the running job, the chosen chip, the primary button, the selected row. Everything
        else is ink, cream and hairlines. Errors use pink and always carry Copy details, so a bug report is one click.
      </Caption>

      <Sub n="10.2">Settings · General</Sub>
      <div className="grid gap-2 md:grid-cols-2">
        <Tile bg={C.wine} label="Dark" fg={C.cream} className="px-3 pb-4 pt-12 md:px-5"><Scaled w={760} h={520}><SettingsPane t={DARK} /></Scaled></Tile>
        <Tile bg={C.orange} label="Light" fg={C.ink} className="px-3 pb-4 pt-12 md:px-5"><Scaled w={760} h={520}><SettingsPane t={LIGHT} /></Scaled></Tile>
      </div>
      <Caption label="Plain settings">
        Every row says what it does in a few words. The safe choice is the default: files go next to the original and nothing is ever
        overwritten.
      </Caption>
    </Section>
  )
}
