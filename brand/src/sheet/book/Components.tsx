import { ArrowRight, Download } from 'lucide-react'
import { Pixels } from '../Mark'
import { SheetWheel } from '../SheetWheel'
import { fileArt } from './pixel'
import { FileTile, Lbl, PX, Section, Sub, Win } from './ui'
import { ACTIONS, CONVERT, TOOLS } from './wheels'

function Pill({ kind, state, dark }: { kind: 'ink' | 'ghost'; state: 'rest' | 'hover' | 'focus'; dark?: boolean }) {
  const cls = kind === 'ink' ? 'sh-btn-ink' : 'sh-btn-ghost'
  const st = dark && state === 'hover' ? '' : state === 'hover' ? (kind === 'ink' ? 'shb-btn-ink-hover' : 'shb-btn-ghost-hover') : state === 'focus' ? 'shb-focus' : ''
  const darkStyle = dark ? (kind === 'ink' ? { background: state === 'hover' ? '#E2E9F3' : '#fff', color: '#000' } : { color: '#fff', boxShadow: 'inset 0 0 0 1px #fff', background: state === 'hover' ? '#202020' : 'transparent' }) : undefined
  return <span className={`sh-btn ${cls} ${st}`} style={darkStyle}>{kind === 'ink' ? <><Download size={16} />Download</> : <>Docs <ArrowRight size={16} /></>}</span>
}

function WheelPlate({ title, keyName, wedges, dark, active, hub }: { title: string; keyName: string; wedges: typeof CONVERT; dark?: boolean; active: number; hub: React.ReactNode }) {
  return (
    <figure>
      <div className={`grid place-items-center overflow-hidden rounded-[4px] py-8 ${dark ? 'shb-dots-d bg-black' : 'sh-dots bg-[var(--sh-mist)]'}`}>
        <div className="origin-center scale-[.84] md:scale-100">
          <SheetWheel wedges={wedges} size={300} active={active} tone={dark ? 'dark' : 'light'} hub={hub} />
        </div>
      </div>
      <figcaption className="mt-3 flex justify-between"><span className="text-[15px] font-[600]">{title}</span><Lbl>{keyName} · {dark ? 'dark' : 'light'}</Lbl></figcaption>
    </figure>
  )
}

const Hub = ({ ext, dark }: { ext: string; dark?: boolean }) => <div className="flex flex-col items-center gap-1"><FileTile ext={ext} size={26} dark={false} /><span className={`shb-num text-[10px] ${dark ? 'text-black' : ''}`}>clip.mov</span></div>

export function Components() {
  return (
    <Section id="components" n={8} label="Components" title={<>A small kit, <span className="sh-hl">used the same way</span> everywhere.</>}
      lede="Pills for actions, tints for grouping, mono for labels. The wheel is the only component with a personality, and it keeps it flat.">
      <Sub n="8.1" title="Pills" note="Black pill for the one primary action, ghost for the rest. Hover darkens or tints; focus is a 2 px ink ring, 3 px out. 36 px tall, radius 50.">
        <div className="grid gap-4 md:grid-cols-2">
          {[false, true].map((dark) => (
            <div key={String(dark)} className={`rounded-[4px] p-4 md:p-6 ${dark ? 'shb-dark bg-black text-white' : 'bg-white shb-hair'}`}>
              <div className="grid grid-cols-[52px_auto_auto] items-center justify-start gap-x-4 gap-y-5 md:grid-cols-[60px_1fr_1fr]">
                <span />{['Ink', 'Ghost'].map((k) => <Lbl key={k} className={dark ? '!text-[#9A9794]' : ''}>{k}</Lbl>)}
                {(['rest', 'hover', 'focus'] as const).map((s) => (
                  <div key={s} className="contents">
                    <Lbl className={dark ? '!text-[#9A9794]' : ''}>{s}</Lbl>
                    <span><Pill kind="ink" state={s} dark={dark} /></span>
                    <span><Pill kind="ghost" state={s} dark={dark} /></span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="8.2" title="Highlight, tags, eyebrows">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="rounded-[4px] bg-white p-6 shb-hair">
            <Lbl>Highlight box</Lbl>
            <div className="sh-display mt-5 text-[34px]">Drop it on <span className="sh-hl">GIF.</span></div>
            <p className="mt-4 text-[13px] text-[var(--sh-graphite)]">Inline, same size and baseline as its line. Padding 0 0.12em, radius 2, clones across line breaks.</p>
          </div>
          <div className="rounded-[4px] bg-white p-6 shb-hair">
            <Lbl>Orange outline tags</Lbl>
            <div className="mt-5 flex flex-wrap gap-2">
              <span className="sh-tag shb-lbl">New</span><span className="sh-tag shb-lbl">Pro</span><span className="sh-tag shb-lbl">Beta · MCP</span><span className="sh-tag shb-lbl">macOS 13+</span>
            </div>
            <p className="mt-4 text-[13px] text-[var(--sh-graphite)]">For status beside a heading, never as a button. One per card at most. 26 px, mono 12.</p>
          </div>
          <div className="rounded-[4px] bg-white p-6 shb-hair">
            <Lbl>Mono eyebrow</Lbl>
            <div className="mt-5">
              <span className="sh-mono">01 · Convert</span>
              <div className="sh-display mt-2 text-[28px]">Every format, one drag</div>
            </div>
            <p className="mt-4 text-[13px] text-[var(--sh-graphite)]">Geist Mono 14, caps, +0.06em. Numbered when it opens a section.</p>
          </div>
        </div>
      </Sub>

      <Sub n="8.3" title="Cards and strips">
        <div className="grid gap-4 md:grid-cols-12">
          <div className="flex flex-col rounded-[4px] bg-[var(--sh-lavender)] p-6 md:col-span-4">
            <Pixels rows={fileArt('GIF', 'o')} palette={PX} px={3} />
            <span className="sh-mono mt-8">Feature card</span>
            <div className="sh-display mt-2 text-[24px]">Convert</div>
            <p className="mt-2 text-[15px] text-[var(--sh-graphite)]">793 routes across images, video, audio, documents, ebooks and archives.</p>
            <a className="sh-link mt-auto pt-6 text-[15px]" href="#components">See every route</a>
          </div>
          <div className="sh-dots rounded-[4px] bg-[var(--sh-mist)] p-4 md:col-span-8 md:p-6">
            <div className="rounded-[4px] bg-[var(--sh-sky)] p-5">
              <div className="flex items-center justify-between"><span className="shb-lbl">Terminal · code card</span><span className="shb-lbl text-[var(--sh-graphite)]">zsh</span></div>
              <pre className="sh-code mt-4 overflow-x-auto text-[14px] leading-[1.7]">{`$ brew install --cask anyfmt
$ anyfmt convert clip.mov --to gif --opt gifWidth=480
  clip.gif  3.8 MB  1.9 s
$ anyfmt mcp`}<span className="sh-caret ml-1" /></pre>
            </div>
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-px overflow-hidden rounded-[4px] bg-[var(--shb-line)] md:grid-cols-4">
          {[['793', 'Routes'], ['26', 'Tools'], ['0', 'Network calls'], ['43 ms', 'Key to wheel']].map(([v, l]) => (
            <div key={l} className="bg-[var(--sh-slate)] p-5">
              <div className="sh-display text-[45px] leading-none">{v}</div>
              <div className="sh-mono mt-3 text-[var(--sh-graphite)]">{l}</div>
            </div>
          ))}
        </div>
        <div className="mt-2"><Lbl>Stat strip · the only place numbers get display type</Lbl></div>
      </Sub>

      <Sub n="8.4" title="Window mockup" note="Flat chrome: hairline, grey dots for lights, a mono or Inter 12 title. Content inside uses the same kit.">
        <Win title="clip.mov · Convert" className="max-w-[760px]">
          <div className="grid gap-0 md:grid-cols-[220px_1fr]">
            <div className="border-b border-[var(--shb-line)] bg-[var(--sh-slate)] p-4 md:border-b-0 md:border-r">
              {['Video', 'Image', 'Audio'].map((t, i) => <div key={t} className={`rounded-[4px] px-3 py-2 text-[14px] ${i === 0 ? 'bg-black text-white' : ''}`}>{t}</div>)}
            </div>
            <div className="p-5">
              <span className="sh-mono text-[12px] text-[var(--sh-graphite)]">Output</span>
              <div className="mt-3 grid grid-cols-3 gap-2">
                {['GIF', 'MP4', 'WEBM', 'M4V', 'MOV', 'MKV'].map((f, i) => <div key={f} className={`rounded-[4px] px-3 py-3 text-[14px] font-[500] ${i === 0 ? 'bg-black text-white' : 'bg-white shb-hair'}`}>{f}</div>)}
              </div>
              <div className="mt-5 flex justify-end gap-2"><span className="sh-btn sh-btn-ghost">Cancel</span><span className="sh-btn sh-btn-ink">Convert</span></div>
            </div>
          </div>
        </Win>
      </Sub>

      <Sub n="8.5" title="The wheel, all three sets" note="Shift for Convert, Command for Tools, Control for Actions. The aimed wedge fills ink; orange is only the tick on its rim.">
        <div className="grid gap-4 md:grid-cols-3">
          <WheelPlate title="Convert" keyName="⇧ Shift" wedges={CONVERT} active={0}  hub={<Hub ext="MOV" />} />
          <WheelPlate title="Tools" keyName="⌘ Command" wedges={TOOLS} active={2}  hub={<Hub ext="MOV" />} />
          <WheelPlate title="Actions" keyName="⌃ Control" wedges={ACTIONS} active={1}  hub={<Hub ext="MOV" />} />
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-3">
          <WheelPlate title="Convert" keyName="⇧ Shift" wedges={CONVERT} active={3} dark hub={<Hub ext="MOV" dark />} />
          <WheelPlate title="Tools" keyName="⌘ Command" wedges={TOOLS} active={0} dark hub={<Hub ext="MOV" dark />} />
          <WheelPlate title="Actions" keyName="⌃ Control" wedges={ACTIONS} active={5} dark hub={<Hub ext="MOV" dark />} />
        </div>
      </Sub>
    </Section>
  )
}
