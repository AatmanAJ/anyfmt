import { ArrowRight } from 'lucide-react'
import { C, DoDont, Lbl, Section, Sub, contrast, grade } from './ui'

const LADDER = [
  { lv: 0, name: 'Paper', hex: C.paper, role: 'The page. Most of every screen.' },
  { lv: 1, name: 'Slate', hex: C.slate, role: 'Strip cells, table rows, quiet plates.' },
  { lv: 2, name: 'Lavender mist', hex: C.lavender, role: 'Feature cards. The default card tint.' },
  { lv: 3, name: 'Blue-gray mist', hex: C.mist, role: 'Hero washes and code cards, with dots.' },
  { lv: 4, name: 'Sky', hex: C.sky, role: 'Terminal and code blocks only.' },
]

const PAIRS: [string, string, string, string][] = [
  ['Ink on paper', C.ink, C.paper, 'Body, headlines, pills'],
  ['Graphite on paper', C.graphite, C.paper, 'Muted text, captions'],
  ['Ink on lavender', C.ink, C.lavender, 'Card text'],
  ['Graphite on lavender', C.graphite, C.lavender, 'Card subtitles'],
  ['Ink on mist', C.ink, C.mist, 'Hero text'],
  ['Ink on sky', C.ink, C.sky, 'Code'],
  ['Ink on orange', C.ink, C.orange, 'Highlight box, footer'],
  ['Paper on orange', C.paper, C.orange, 'Never'],
  ['Orange on paper', C.orange, C.paper, 'Never as text'],
]

const PIX = [
  ['k', C.ink, 'Ink', 'Outlines, shadows'], ['w', C.paper, 'Paper', 'Highlights, pages'], ['o', C.orange, 'Signal', 'The lit wedge, bands'],
  ['y', C.yellow, 'Yellow', 'Fields, file bands'], ['g', C.green, 'Green', 'Hills'], ['G', C.forest, 'Forest', 'Far hills'],
  ['m', C.mist, 'Mist', 'Folds, text lines'], ['s', C.sky, 'Sky', 'Sky, always dotted'],
]

export function Colour() {
  return (
    <Section id="colour" n={3} label="Colour" title={<>Black and white, then <span className="sh-hl">one signal.</span></>}
      lede="Ink on paper does the work. Five pale tints group things instead of shadows. Orange appears once per view, as punctuation: never as a control.">
      <Sub n="3.1" title="Monochrome first">
        <div className="grid gap-4 md:grid-cols-12">
          <div className="flex min-h-[260px] flex-col justify-between rounded-[4px] bg-black p-6 text-white md:col-span-6">
            <span className="shb-lbl">Ink</span>
            <div><div className="sh-display text-[45px]">#000000</div><div className="shb-lbl mt-2 text-[#9A9794]">Text, pills, rules, the mark</div></div>
          </div>
          <div className="flex min-h-[260px] flex-col justify-between rounded-[4px] bg-white p-6 shb-hair md:col-span-4">
            <span className="shb-lbl">Paper</span>
            <div><div className="sh-display text-[45px]">#FFFFFF</div><div className="shb-lbl mt-2 text-[var(--sh-graphite)]">The page</div></div>
          </div>
          <div className="flex min-h-[260px] flex-col justify-between rounded-[4px] p-6 text-white md:col-span-2" style={{ background: C.graphite }}>
            <span className="shb-lbl">Graphite</span>
            <div><div className="sh-display text-[24px]">#686562</div><div className="shb-lbl mt-2 opacity-80">The only muted tone</div></div>
          </div>
        </div>
      </Sub>

      <Sub n="3.2" title="The surface ladder" note="Five levels, each a role. Climb one step to group; never skip two. Cream #FFFDE6 sits off the ladder for warm callouts.">
        <div className="grid gap-3 md:grid-cols-5">
          {LADDER.map((l) => (
            <div key={l.lv} className="flex flex-col">
              <div className="flex md:h-[300px] md:items-end"><div className={`flex h-24 w-full flex-col justify-end rounded-[4px] p-4 md:h-[var(--h)] ${l.lv === 0 ? 'shb-hair' : ''} ${l.lv === 3 ? 'sh-dots' : ''}`} style={{ background: l.hex, ['--h' as string]: `${120 + l.lv * 45}px` }}>
                <span className="sh-display text-[56px] leading-none">{l.lv}</span>
              </div></div>
              <div className="mt-3 border-t border-black pt-2">
                <div className="flex items-baseline justify-between"><span className="text-[15px] font-[600]">{l.name}</span><span className="shb-num text-[12px] text-[var(--sh-graphite)]">{l.hex}</span></div>
                <p className="mt-1 text-[14px] text-[var(--sh-graphite)]">{l.role}</p>
              </div>
            </div>
          ))}
        </div>
        <div className="mt-4 flex items-center gap-4 rounded-[4px] p-4" style={{ background: C.cream }}>
          <span className="shb-lbl">Cream · #FFFDE6</span><span className="text-[14px] text-[var(--sh-graphite)]">Warm callouts: a tip, a note about Pro, “this stays on your Mac”.</span>
        </div>
      </Sub>

      <Sub n="3.3" title="The orange rules" note="#FF4500 is allowed in five places. Everywhere else it is a mistake, including hover.">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-[4px] p-6 shb-hair">
            <Lbl className="!text-black">Allowed</Lbl>
            <ul className="mt-4 grid gap-4">
              <li className="flex items-center justify-between gap-4 border-t border-[var(--shb-line)] pt-4"><span className="text-[15px]">The highlight box, one per headline</span><span className="sh-display text-[22px]">Drop <span className="sh-hl">here</span></span></li>
              <li className="flex items-center justify-between gap-4 border-t border-[var(--shb-line)] pt-4"><span className="text-[15px]">Outline tags</span><span className="sh-tag shb-lbl">New · Float</span></li>
              <li className="flex items-center justify-between gap-4 border-t border-[var(--shb-line)] pt-4"><span className="text-[15px]">The full-bleed footer band</span><span className="h-6 w-28 rounded-[2px] bg-[var(--sh-orange)]" /></li>
              <li className="flex items-center justify-between gap-4 border-t border-[var(--shb-line)] pt-4"><span className="text-[15px]">The lit wedge, the wheel’s rim tick</span><svg width="64" height="24" viewBox="0 0 64 24"><rect x="0" y="0" width="64" height="24" fill="#000" /><rect x="0" y="0" width="64" height="4" fill="#FF4500" /></svg></li>
              <li className="flex items-center justify-between gap-4 border-t border-[var(--shb-line)] pt-4"><span className="text-[15px]">Pixel art, as one of eight inks</span><span className="flex gap-[2px]">{['#000', '#FF4500', '#FFD23F', '#2FB36B'].map((c) => <i key={c} className="size-3" style={{ background: c }} />)}</span></li>
            </ul>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <DoDont ok={false} note="As a button fill."><span className="sh-btn" style={{ background: C.orange }}>Download <ArrowRight size={16} /></span></DoDont>
            <DoDont ok={false} note="As a border or focus ring."><span className="rounded-[4px] bg-white px-4 py-3 text-[14px]" style={{ boxShadow: 'inset 0 0 0 1.5px #FF4500' }}>Search formats</span></DoDont>
            <DoDont ok={false} note="As a hover or selected state."><span className="sh-btn sh-btn-ghost" style={{ background: '#FFE3D6', boxShadow: 'inset 0 0 0 1px #FF4500' }}>Settings</span></DoDont>
            <DoDont ok={false} note="As text colour, even for links."><span className="text-[17px] font-[500] underline" style={{ color: C.orange }}>Read the docs</span></DoDont>
          </div>
        </div>
      </Sub>

      <Sub n="3.4" title="Pixel-art palette" note="Eight inks, for illustrations only. Green, yellow and forest never appear in the interface.">
        <div className="grid grid-cols-4 gap-px overflow-hidden rounded-[4px] bg-[var(--shb-line)] md:grid-cols-8">
          {PIX.map(([ch, hex, name, use]) => (
            <div key={ch} className="bg-white p-4">
              <div className="size-12" style={{ background: hex, outline: hex === C.paper ? '1px solid #D3D9E2' : undefined, outlineOffset: -1 }} />
              <div className="mt-3 flex items-baseline gap-2"><span className="shb-num text-[12px]">{ch}</span><span className="text-[14px] font-[600]">{name}</span></div>
              <div className="shb-num text-[12px] text-[var(--sh-graphite)]">{hex}</div>
              <div className="mt-1 text-[13px] text-[var(--sh-graphite)]">{use}</div>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="3.5" title="Contrast, computed live" note="WCAG 2 ratios, worked out on this page from the hex values above. Graphite passes AA on paper and on lavender; nothing sits on orange but ink.">
        <div className="overflow-hidden rounded-[4px] shb-hair">
          <div className="hidden grid-cols-[1.4fr_120px_1fr_100px_110px] gap-4 border-b border-black bg-[var(--sh-slate)] px-4 py-3 md:grid">
            {['Pair', 'Sample', 'Use', 'Ratio', 'Grade'].map((h) => <span key={h} className="shb-lbl">{h}</span>)}
          </div>
          {PAIRS.map(([name, fg, bg, use]) => {
            const r = contrast(fg, bg), g = grade(r)
            const never = use.startsWith('Never')
            return (
              <div key={name} className="grid grid-cols-[1fr_auto] items-center gap-x-4 gap-y-2 border-b border-[var(--shb-line)] px-4 py-3 last:border-0 md:grid-cols-[1.4fr_120px_1fr_100px_110px]">
                <span className="text-[15px] font-[500]">{name}</span>
                <span className="order-first col-span-2 md:order-none md:col-span-1"><span className="inline-flex h-8 items-center rounded-[3px] px-3 text-[15px] font-[600]" style={{ background: bg, color: fg, boxShadow: bg === C.paper ? 'inset 0 0 0 1px #D3D9E2' : undefined }}>Aa 793</span></span>
                <span className={`hidden text-[14px] md:block ${never ? 'font-[600]' : 'text-[var(--sh-graphite)]'}`}>{use}</span>
                <span className="shb-num text-[15px]">{r.toFixed(2)}:1</span>
                <span className={`shb-lbl hidden w-fit rounded-[999px] px-2 py-1 md:inline ${g === 'Fail' ? 'shb-hair-ink' : g === 'AAA' ? 'bg-black text-white' : 'bg-[var(--sh-lavender)]'}`}>{g}</span>
              </div>
            )
          })}
        </div>
      </Sub>

      <Sub n="3.6" title="Proportion" note="Measured across a typical page: almost all paper and ink, a little tint, five per cent orange at most.">
        <div className="flex h-16 overflow-hidden rounded-[4px]" style={{ outline: '1px solid #D3D9E2', outlineOffset: -1 }}>
          {[
            ['Paper', 60, C.paper], ['Ink', 22, C.ink], ['Slate', 3, C.slate], ['Lavender', 5, C.lavender], ['Mist', 3, C.mist], ['Sky', 2, C.sky], ['Orange', 5, C.orange],
          ].map(([n, p, c]) => (
            <div key={n as string} title={`${n} ${p}%`} className="flex items-end p-2" style={{ width: `${p}%`, background: c as string, boxShadow: n === 'Paper' ? 'inset -1px 0 0 #D3D9E2' : undefined }}>
              {(p as number) >= 20 && <span className={`shb-lbl text-[11px] ${n === 'Ink' ? 'text-white' : ''}`}>{n} {p}%</span>}
            </div>
          ))}
        </div>
        <div className="mt-3 grid grid-cols-2 gap-y-2 md:flex md:gap-8">
          <span className="shb-lbl">95% monochrome and tint</span>
          {[['Paper', 60], ['Ink', 22], ['Tints', 13], ['Orange', 5]].map(([n, p]) => <span key={n as string} className="shb-lbl text-[var(--sh-graphite)]">{n} {p}%</span>)}
        </div>
      </Sub>
    </Section>
  )
}
