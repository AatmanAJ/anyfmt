import { Copy, FolderOpen, Share } from 'lucide-react'
import { DoDont, Lbl, Section, Sub } from './ui'

const LEVELS = [
  { e: 'E0', name: 'Page', how: 'Paper. No edge.', demo: 'bg-white shb-hair' },
  { e: 'E1', name: 'Grouped', how: 'One step up the tint ladder. No line.', demo: 'bg-[var(--sh-lavender)]' },
  { e: 'E2', name: 'Contained', how: 'Paper on a tint, quiet hairline #D3D9E2.', demo: 'bg-[var(--sh-lavender)]', inner: 'bg-white shb-hair' },
  { e: 'E3', name: 'Floating', how: 'Paper, ink hairline. Menus, popovers, toasts.', demo: 'bg-[var(--sh-slate)]', inner: 'bg-white shb-hair-ink' },
  { e: 'E4', name: 'Modal', how: 'Ink hairline over a dotted mist scrim.', demo: 'bg-[var(--sh-mist)] sh-dots', inner: 'bg-white shb-hair-ink' },
]

export function Elevation() {
  return (
    <Section id="surfaces" n={5} label="Surfaces" title={<>Tint and line, <span className="sh-hl">never shadow.</span></>}
      lede="A surface rises by changing tint or gaining a hairline. Floating things get an ink hairline. The only blur in the system is the Dock’s, and that’s Apple’s.">
      <Sub n="5.1" title="Five levels">
        <div className="grid gap-4 md:grid-cols-5">
          {LEVELS.map((l) => (
            <div key={l.e}>
              <div className={`grid h-[180px] place-items-center rounded-[4px] p-5 ${l.demo}`}>
                {l.inner ? <div className={`h-full w-full rounded-[4px] ${l.inner} p-3`}><div className="h-2 w-12 rounded-full bg-black" /><div className="mt-2 h-2 w-20 rounded-full bg-[var(--sh-mist)]" /></div> : <span className="sh-display text-[34px]">{l.e}</span>}
              </div>
              <div className="mt-3 border-t border-black pt-2">
                <div className="flex items-baseline gap-2"><span className="shb-num text-[12px] text-[var(--sh-graphite)]">{l.e}</span><span className="text-[15px] font-[600]">{l.name}</span></div>
                <p className="mt-1 text-[14px] text-[var(--sh-graphite)]">{l.how}</p>
              </div>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="5.2" title="In use" note="A menu over a card over a tint: each step is a tint or a line, and you can still tell them apart in greyscale.">
        <div className="sh-dots relative overflow-hidden rounded-[4px] bg-[var(--sh-mist)] p-6 md:p-12">
          <div className="max-w-[560px] rounded-[4px] bg-[var(--sh-lavender)] p-6">
            <Lbl className="!text-black">E1 · Feature card</Lbl>
            <div className="sh-display mt-3 text-[28px]">Actions</div>
            <p className="mt-2 text-[15px] text-[var(--sh-graphite)]">AirDrop, a Float shelf that holds files between drags, copy path, open in Terminal.</p>
            <div className="mt-5 rounded-[4px] bg-white p-4 shb-hair">
              <Lbl>E2 · Inset plate</Lbl>
              <div className="sh-code mt-2 text-[14px]">~/Desktop/clip.gif · 3.8 MB</div>
            </div>
          </div>
          <div className="relative mt-[-40px] ml-auto w-[240px] rounded-[6px] bg-white p-1.5 shb-hair-ink md:absolute md:right-12 md:top-28 md:mt-0">
            {[[Share, 'AirDrop'], [Copy, 'Copy Path'], [FolderOpen, 'Show in Finder']].map(([I, t], i) => {
              const Icon = I as typeof Share
              return <div key={i} className={`flex items-center gap-2.5 rounded-[3px] px-2.5 py-2 text-[14px] ${i === 1 ? 'bg-black text-white' : ''}`}><Icon size={15} strokeWidth={1.5} />{t as string}</div>
            })}
            <div className="shb-lbl px-2.5 pb-1 pt-2 text-[11px] text-[var(--sh-graphite)]">E3 · Floating menu</div>
          </div>
        </div>
      </Sub>

      <Sub n="5.3" title="Shape and spacing">
        <div className="grid gap-4 md:grid-cols-4">
          {[
            ['4 px', 'Cards, plates, tags’ corners', <div key="a" className="size-16 rounded-[4px] bg-[var(--sh-lavender)]" />],
            ['10 px', 'Windows and panels', <div key="b" className="h-16 w-24 rounded-[10px] bg-white shb-hair" />],
            ['50 px', 'Pills: every button', <span key="c" className="sh-btn sh-btn-ink">Download</span>],
            ['4 px grid', 'Every gap is a multiple of 4', <div key="d" className="flex items-end gap-1">{[4, 8, 12, 16, 24, 32].map((s) => <i key={s} className="block bg-black" style={{ width: 8, height: s * 1.5 }} />)}</div>],
          ].map(([t, d, el], i) => (
            <div key={i} className="rounded-[4px] bg-[var(--sh-slate)] p-5">
              <div className="grid h-20 place-items-start">{el}</div>
              <div className="sh-display mt-4 text-[24px]">{t as string}</div>
              <div className="text-[14px] text-[var(--sh-graphite)]">{d as string}</div>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="5.4" title="Do and don’t">
        <div className="grid gap-4 md:grid-cols-3">
          <DoDont ok note="Tint groups, a hairline contains." plate="#fff"><div className="w-full max-w-[220px] rounded-[4px] bg-[var(--sh-lavender)] p-4"><div className="h-2 w-16 rounded-full bg-black" /><div className="mt-3 rounded-[4px] bg-white p-3 shb-hair"><div className="h-2 w-24 rounded-full bg-[var(--sh-mist)]" /></div></div></DoDont>
          <DoDont ok={false} note="Drop shadows to lift a card." plate="#fff"><div className="w-full max-w-[220px] rounded-[12px] bg-white p-4" style={{ boxShadow: '0 12px 30px rgba(0,0,0,.18)' }}><div className="h-2 w-16 rounded-full bg-black" /><div className="mt-3 h-8 rounded-[8px] bg-[var(--sh-slate)]" /></div></DoDont>
          <DoDont ok={false} note="Gradients or glass as a surface." plate="#fff"><div className="w-full max-w-[220px] rounded-[12px] p-4" style={{ background: 'linear-gradient(135deg,#C4EDFF,#E2E9F3 50%,#FFFDE6)' }}><div className="h-2 w-16 rounded-full bg-black" /><div className="mt-3 h-8 rounded-[8px] bg-white/50" /></div></DoDont>
        </div>
      </Sub>
    </Section>
  )
}
