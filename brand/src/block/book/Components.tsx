import { Airplay, Copy, Crop, Eraser, FolderInput, Image, Layers, Link, Minimize2, Pencil, Scissors, Tag, Terminal, Type as TypeIcon } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { BlockWheel, type Wedge } from '../BlockWheel'
import { isShot } from '../../shared/kit'
import { C, Caption, Scaled, Section, Sub, Tile } from './ui'

const ic = { size: 15, strokeWidth: 2.2 }
export const SETS: Record<'convert' | 'tools' | 'actions', { key: string; name: string; hub: string; wedges: Wedge[] }> = {
  convert: { key: '⇧', name: 'Convert', hub: 'MOV', wedges: ['GIF', 'MP4', 'WEBM', 'M4V', 'MKV', 'MP3', 'PNG', 'MOV'].slice(0, 7).map((l) => ({ id: l, label: l })) },
  tools: {
    key: '⌘', name: 'Tools', hub: 'JPG', wedges: [
      { id: 'compress', label: 'Compress', icon: <Minimize2 {...ic} /> }, { id: 'crop', label: 'Crop', icon: <Crop {...ic} /> },
      { id: 'edit', label: 'Edit', icon: <Pencil {...ic} /> }, { id: 'annotate', label: 'Annotate', icon: <TypeIcon {...ic} /> },
      { id: 'bg', label: 'Add BG', icon: <Image {...ic} /> }, { id: 'redact', label: 'Redact', icon: <Eraser {...ic} /> },
      { id: 'meta', label: 'Metadata', icon: <Tag {...ic} /> }, { id: 'trim', label: 'Trim', icon: <Scissors {...ic} /> },
    ],
  },
  actions: {
    key: '⌃', name: 'Actions', hub: 'PDF', wedges: [
      { id: 'airdrop', label: 'AirDrop', icon: <Airplay {...ic} /> }, { id: 'float', label: 'Float', icon: <Layers {...ic} /> },
      { id: 'copy', label: 'Copy', icon: <Copy {...ic} /> }, { id: 'move', label: 'Move', icon: <FolderInput {...ic} /> },
      { id: 'path', label: 'Copy Path', icon: <Link {...ic} /> }, { id: 'term', label: 'Terminal', icon: <Terminal {...ic} /> },
    ],
  },
}

const Hub = ({ t }: { t: string }) => <span className="bk-display text-[20px] font-[700] leading-none">{t}</span>

function ButtonsSheet({ dark }: { dark?: boolean }) {
  const kinds = ['orange', 'ink', 'line'] as const
  const states = [['rest', ''], ['hover', 'is-hover'], ['pressed', 'is-pressed']] as const
  return (
    <div className="grid grid-cols-[64px_repeat(3,minmax(0,1fr))] items-center gap-x-3 gap-y-5 md:grid-cols-[80px_repeat(3,minmax(0,1fr))]">
      <span />
      {states.map(([s]) => <span key={s} className="bk-mono text-[11px] uppercase tracking-[.08em] opacity-60">{s}</span>)}
      {kinds.map((k) => (
        <div key={k} className="contents">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] opacity-60">{k}</span>
          {states.map(([s, cls]) => (
            <div key={s}>
              <span className={`bk-btn bk-btn-${k} ${cls} !h-[40px] !px-3 !text-[14px] md:!h-[44px] md:!px-5 md:!text-[15px]`}
                    style={k === 'ink' && dark ? { background: C.cream, color: C.ink } : undefined}>Convert</span>
            </div>
          ))}
        </div>
      ))}
    </div>
  )
}

function FpsChips() {
  const opts = [['10 fps', '1.6 MB'], ['15 fps', '2.4 MB'], ['24 fps', '3.8 MB'], ['30 fps', '4.7 MB']]
  const [sel, setSel] = useState(1)
  return (
    <div className="flex flex-wrap gap-2.5">
      {opts.map(([f, s], i) => {
        const on = sel === i
        return (
          <button key={f} onClick={() => setSel(i)} aria-pressed={on}
            className="flex flex-col items-start rounded-[6px] px-3 py-2 text-left transition-transform active:translate-x-[3px] active:translate-y-[3px]"
            style={{ background: on ? C.orange : C.ink, color: on ? C.ink : C.cream, boxShadow: on ? `3px 3px 0 ${C.wine2}` : `inset 0 0 0 1px ${C.ink3}` }}>
            <span className="text-[15px] font-[650] leading-none">{f}</span>
            <span className="bk-mono mt-1 text-[11px] opacity-70">{s}</span>
          </button>
        )
      })}
    </div>
  )
}

export function Thinking({ label = 'Thinking' }: { label?: string }) {
  return (
    <div className="inline-flex items-center gap-2.5 rounded-[6px] bg-[#F4F1EC] px-3.5 py-2.5 text-[#0E0E10] shadow-[4px_4px_0_#0E0E10]">
      <span className="bk-mono text-[13px] font-[600]">[ ]</span>
      <span className="text-[15px] font-[600]">{label}</span>
      <span className="bkb-think flex gap-1">{[0, 1, 2].map((i) => <span key={i} className="block size-1.5 rounded-full bg-[#FF6B1A]" />)}</span>
    </div>
  )
}

function Bubble({ me, children }: { me?: boolean; children: ReactNode }) {
  return (
    <div className={`max-w-[85%] rounded-[14px] px-4 py-3 text-[14.5px] leading-[1.45] ${me ? 'self-end rounded-br-[3px]' : 'self-start rounded-bl-[3px]'}`}
         style={{ background: me ? C.lilac : C.cream, color: C.ink }}>{children}</div>
  )
}

function Playground() {
  const [set, setSet] = useState<keyof typeof SETS>('convert')
  const [msg, setMsg] = useState<string | null>(null)
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if (e.key === 'Shift') setSet('convert'); else if (e.key === 'Meta') setSet('tools'); else if (e.key === 'Control') setSet('actions')
    }
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [])
  const s = SETS[set]
  return (
    <div className="flex flex-col items-center gap-5">
      <div className="flex gap-2">
        {(Object.keys(SETS) as (keyof typeof SETS)[]).map((k) => (
          <button key={k} onClick={() => setSet(k)} className="bk-tag !h-[32px] !px-3 !text-[12px]"
            style={{ background: set === k ? C.orange : C.ink, color: set === k ? C.ink : C.cream, boxShadow: set === k ? `3px 3px 0 ${C.wine2}` : `inset 0 0 0 1px ${C.ink3}` }}>
            <b className="text-[14px]">{SETS[k].key}</b>{SETS[k].name}
          </button>
        ))}
      </div>
      <div className="w-full max-w-[400px]">
        <Scaled w={400} h={400}>
          <BlockWheel key={set} size={400} wedges={s.wedges} hub={<Hub t={s.hub} />} active={isShot ? 1 : undefined}
            onPick={(w) => { setMsg(set === 'convert' ? `Converted to ${w.label}.` : `${w.label}: done.`); setTimeout(() => setMsg(null), 1800) }} />
        </Scaled>
      </div>
      <div className="h-9">{msg && <span className="inline-flex h-9 items-center gap-2 rounded-full bg-[#F4F1EC] px-4 text-[14px] font-[600] text-[#0E0E10]"><span className="size-2 rounded-full bg-[#FF6B1A]" />{msg}</span>}</div>
    </div>
  )
}

export function Components() {
  return (
    <Section id="components" num="08" title="Components" accent="." intro="Flat, chunky parts with one trick: a hard offset shadow that collapses when you press. Small dark cards, orange accents.">
      <Sub n="8.1">Buttons</Sub>
      <div className="grid gap-2 md:grid-cols-2">
        <Tile bg={C.cream} fg={C.ink} label="On cream" className="p-5 pt-14 md:p-8 md:pt-14"><ButtonsSheet /></Tile>
        <Tile bg={C.ink2} fg={C.cream} label="On ink (ink button inverts to cream)" className="p-5 pt-14 md:p-8 md:pt-14"><ButtonsSheet dark /></Tile>
      </div>
      <Caption label="Rest, hover, pressed">
        Rest: 4px hard shadow. Hover: lifts 1px, shadow grows to 5px. Pressed: the button moves into its shadow and the shadow is gone.
        Orange throws a wine shadow; ink throws an orange one. Line buttons tint on hover instead.
      </Caption>

      <Sub n="8.2">Tags, chips, pills</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.ink2} label="Tags" fg={C.cream} className="flex flex-wrap content-start gap-2 p-5 pt-14 md:col-span-4">
          {[['Local', C.lilac, C.ink], ['Pro', C.pink, C.ink], ['New', C.orange, C.ink], ['macOS 13+', C.ink3, C.cream], ['AGPL-3.0', C.cream, C.ink], ['⇧ Convert', C.ink, C.orange]].map(([t, bg, fg]) => (
            <span key={t} className="bk-tag" style={{ background: bg, color: fg, boxShadow: bg === C.ink ? `inset 0 0 0 1px ${C.ink3}` : undefined }}>{t}</span>
          ))}
        </Tile>
        <Tile bg={C.wine} label="Frame-rate chips · size per chip" fg={C.cream} className="p-5 pt-14 md:col-span-8"><FpsChips /></Tile>
        <Tile bg={C.orange} fg={C.ink} label="Thinking pill" className="grid min-h-[200px] place-items-center p-5 pt-12 md:col-span-4"><Thinking /></Tile>
        <Tile bg={C.ink} className="flex flex-col gap-2 p-5 ring-1 ring-inset ring-[#2A2A30] md:col-span-8">
          <span className="bk-mono mb-2 text-[11px] uppercase tracking-[.08em] text-[#8A8790]">Chat bubbles · the MCP server in an agent</span>
          <Bubble me>Turn every HEIC on my Desktop into JPG at 80%.</Bubble>
          <div className="self-start"><span className="bk-tag" style={{ background: C.ink2, color: C.orange, boxShadow: `inset 0 0 0 1px ${C.ink3}` }}>anyfmt.convert · 12 files · local</span></div>
          <Bubble>Done. 12 JPGs saved next to the originals on your Desktop. Nothing left your Mac.</Bubble>
          <div className="mt-1 self-start"><Thinking label="Converting" /></div>
        </Tile>
      </div>
      <Caption label="Mono labels, hard shadows">
        Tags are mono caps on a flat block. Chips are choices: the chosen one goes orange and lifts onto a wine shadow. Each frame-rate chip
        shows the size it will produce, so the choice is a real one.
      </Caption>

      <Sub n="8.3">BlockWheel</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.ink2} label="Playground: hold ⇧ ⌘ ⌃, aim, click" fg={C.cream} className="px-4 pb-4 pt-14 md:col-span-5 md:row-span-2">
          <Playground />
        </Tile>
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-3 md:col-span-7">
          {(['convert', 'tools', 'actions'] as const).map((k, i) => (
            <Tile key={`dk-${k}`} bg={i === 1 ? C.wine : C.ink} label={`${SETS[k].key} ${SETS[k].name} · dark`} fg={C.cream} className="px-3 pb-3 pt-12 ring-1 ring-inset ring-[#2A2A30]">
              <Scaled w={260} h={260}><BlockWheel size={260} wedges={SETS[k].wedges} active={[2, 0, 1][i]} hot={(['orange', 'pink', 'lilac'] as const)[i]} hub={<Hub t={SETS[k].hub} />} /></Scaled>
            </Tile>
          ))}
        </div>
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-3 md:col-span-7">
          {(['convert', 'tools', 'actions'] as const).map((k, i) => (
            <Tile key={`lt-${k}`} bg={i === 1 ? C.lilac : C.cream} label={`${SETS[k].key} ${SETS[k].name} · light`} fg={C.ink} className="px-3 pb-3 pt-12">
              <Scaled w={260} h={260}><BlockWheel size={260} tone="light" wedges={SETS[k].wedges} active={[0, 3, 4][i]} hot={(['orange', 'pink', 'orange'] as const)[i]} hub={<Hub t={SETS[k].hub} />} /></Scaled>
            </Tile>
          ))}
        </div>
      </div>
      <Caption label="Three wheels, two tones">
        ⇧ opens Convert, ⌘ opens Tools, ⌃ opens Actions. Dark tone sits on ink, wine and orange; light tone on cream and lilac. The aimed
        wedge pops out along its own angle onto a hard shadow, exactly like the core of the mark.
      </Caption>
    </Section>
  )
}
