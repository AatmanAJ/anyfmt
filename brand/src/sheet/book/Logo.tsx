import { Mark, Wordmark } from '../Mark'
import { wheelArt } from './pixel'
import { DoDont, Lbl, Section, Sub } from './ui'

const N = 22
const CELLS = wheelArt(N)

/** The wordmark with the box colours exposed, for grounds where orange can't carry it. */
function WM({ size = 40, ink = '#000', box = '#FF4500', boxText = '#000', mark = true, hot = 1 as number | null, accent = '#FF4500' }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.4, color: ink }}>
      {mark && <Mark size={size * 1.15} ink={ink} hot={hot} accent={accent} />}
      <span className="sh-display" style={{ fontSize: size, lineHeight: 1, letterSpacing: '-0.04em' }}>
        any<span style={{ background: box, color: boxText, padding: '0 0.12em', borderRadius: 2, marginLeft: '0.03em' }}>fmt</span>
      </span>
    </span>
  )
}

function Construction() {
  const u = 18, S = N * u, c = S / 2
  const r0 = N * 0.27 * u, r1 = (N / 2 - 0.15) * u
  return (
    <div className="grid gap-8 md:grid-cols-12">
      <div className="md:col-span-7">
        <div className="sh-dots overflow-hidden rounded-[4px] bg-[var(--sh-lavender)] p-4 md:p-8">
          <svg viewBox={`-8 -8 ${S + 16} ${S + 16}`} className="mx-auto block w-full max-w-[460px]" aria-label="The mark on its 22 by 22 construction grid">
            <rect x={0} y={0} width={S} height={S} fill="#fff" />
            {CELLS.flatMap((r, y) => [...r].map((ch, x) => ch === '.' ? null :
              <rect key={`${x}-${y}`} x={x * u} y={y * u} width={u} height={u} fill={ch === 'o' ? '#FF4500' : '#000'} />))}
            {Array.from({ length: N + 1 }, (_, i) => (
              <g key={i} stroke="#C5D3E8" strokeWidth={i % 11 === 0 ? 1.2 : 0.6}>
                <line x1={i * u} y1={0} x2={i * u} y2={S} /><line x1={0} y1={i * u} x2={S} y2={i * u} />
              </g>
            ))}
            {/* spokes: the six wedge boundaries the gap rule cuts along */}
            {Array.from({ length: 6 }, (_, i) => {
              const a = Math.PI / 6 + (i * Math.PI) / 3, R = r1 + 14
              return <line key={i} x1={c} y1={c} x2={c + R * Math.sin(a)} y2={c - R * Math.cos(a)} stroke="#686562" strokeWidth={1} strokeDasharray="3 3" />
            })}
            <circle cx={c} cy={c} r={r0} fill="none" stroke="#000" strokeWidth={1.2} strokeDasharray="5 4" />
            <circle cx={c} cy={c} r={r1} fill="none" stroke="#000" strokeWidth={1.2} strokeDasharray="5 4" />
            <circle cx={c} cy={c} r={3} fill="#000" />
          </svg>
        </div>
        <div className="mt-3 flex justify-between"><Lbl>Fig. 2 · 22 × 22 grid · 1 cell = 1 px at 22 px</Lbl><Lbl className="hidden md:inline">Drawn by the same code as the app</Lbl></div>
      </div>
      <dl className="md:col-span-5">
        {[
          ['Grid', '22 × 22 cells. Every pixel is a whole cell; nothing is anti-aliased.'],
          ['Outer ring', 'r₁ = n/2 − 0.15 = 10.85 cells. A cell is in if its centre is inside.'],
          ['Inner ring', 'r₀ = 0.27 n = 5.94 cells. The hole is where the file sits.'],
          ['Wedges', 'Six, 60° each. Wedge 0 is centred at twelve o’clock, like the wheel in the app.'],
          ['Gap rule', 'Drop a cell when its arc distance to a spoke is under 0.85 cells. The gaps widen towards the rim, as real wedges do.'],
          ['The lit wedge', 'Wedge 1, at two o’clock, is orange: the format you’re aiming at. Exactly one, always that one.'],
        ].map(([k, v]) => (
          <div key={k} className="grid grid-cols-[110px_1fr] gap-4 border-t border-[var(--shb-line)] py-3 first:border-black">
            <dt className="shb-lbl pt-[3px]">{k}</dt><dd className="text-[15px] leading-[1.5]">{v}</dd>
          </div>
        ))}
      </dl>
    </div>
  )
}

export function Logo() {
  return (
    <Section id="logo" n={1} label="Logo" title={<>A wheel, drawn in <span className="sh-hl">whole pixels.</span></>}
      lede="The mark is the wheel that opens around your pointer, reduced to a 22-pixel grid. One wedge is lit: the choice you’re about to make.">
      <Sub n="1.1" title="Construction" note="The geometry is code, not a drawing. Change n and the same rules redraw it at any grid.">
        <Construction />
      </Sub>

      <Sub n="1.2" title="Meaning">
        <div className="grid gap-px overflow-hidden rounded-[4px] bg-[var(--shb-line)] md:grid-cols-3">
          {[
            [<Mark key="a" size={44} hot={null} />, 'Six wedges', 'The wheel anyfmt opens around your pointer. Convert, Tools and Actions all use it.'],
            [<Mark key="b" size={44} />, 'One lit', 'The wedge under your pointer. It’s the only orange in the mark, as it is on screen.'],
            [<span key="c" className="grid size-11 grid-cols-4 gap-[2px]">{Array.from({ length: 16 }, (_, i) => <i key={i} className={i === 6 ? 'bg-[var(--sh-orange)]' : 'bg-black'} />)}</span>, 'Pixels', 'Files are data. The mark is made of the same unit your images are.'],
          ].map(([icon, t, d], i) => (
            <div key={i} className="bg-[var(--sh-slate)] p-6">
              <div className="h-11">{icon}</div>
              <div className="sh-display mt-6 text-[24px]">{t}</div>
              <p className="mt-2 text-[15px] text-[var(--sh-graphite)]">{d}</p>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="1.3" title="The wordmark" note="The highlight is part of the name. ‘fmt’ always sits in the orange box: it is the format you’re converting to.">
        <div className="grid gap-8 md:grid-cols-12">
          <div className="grid place-items-center rounded-[4px] bg-white py-16 shb-hair md:col-span-7">
            <div className="relative">
              <Wordmark size={72} mark={false} />
              <div className="absolute -bottom-9 left-0 right-0 flex justify-between">
                <Lbl>any · ink</Lbl><Lbl>fmt · in the box</Lbl>
              </div>
            </div>
          </div>
          <ul className="md:col-span-5">
            {[
              ['Set in', 'Host Grotesk 500, −0.04em, always lowercase.'],
              ['Box', '#FF4500, padding 0 0.12em, radius 2 px, same height as the cap line to descender.'],
              ['Gap', '0.03em between “any” and the box. The box never touches the y.'],
              ['In running text', 'Write anyfmt, lowercase, no box. The box belongs to the logo and to headlines.'],
            ].map(([k, v]) => (
              <li key={k} className="grid grid-cols-[110px_1fr] gap-4 border-t border-[var(--shb-line)] py-3 first:border-black">
                <span className="shb-lbl pt-[3px]">{k}</span><span className="text-[15px]">{v}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-4">
          <DoDont ok note="fmt in the box, any in ink."><WM size={28} mark={false} /></DoDont>
          <DoDont ok={false} note="Boxing the whole name."><span className="sh-display text-[28px] tracking-[-0.04em]"><span className="sh-hl">anyfmt</span></span></DoDont>
          <DoDont ok={false} note="Capitals. It’s anyfmt."><span className="sh-display text-[28px] tracking-[-0.04em]">Any<span className="sh-hl">Fmt</span></span></DoDont>
          <DoDont ok={false} note="An outline box. The box is a fill."><span className="sh-display text-[28px] tracking-[-0.04em]">any<span className="rounded-[2px] px-[0.12em]" style={{ boxShadow: 'inset 0 0 0 1.5px #FF4500' }}>fmt</span></span></DoDont>
        </div>
      </Sub>

      <Sub n="1.4" title="Lockups, clear space, sizes" note="Clear space is half the mark’s height on every side. Sizes that are whole multiples of 22 render sharpest.">
        <div className="grid gap-4 md:grid-cols-3">
          {[
            ['Horizontal · primary', <WM key="h" size={34} />],
            ['Stacked', <div key="s" className="flex flex-col items-center gap-3"><Mark size={66} /><WM size={30} mark={false} /></div>],
            ['Mark only · small spaces', <Mark key="m" size={66} />],
          ].map(([t, el], i) => (
            <figure key={i}>
              <div className="relative grid h-[220px] place-items-center rounded-[4px] bg-[var(--sh-slate)]">
                <div className="relative p-[22px]" style={{ outline: "1px dashed #000", outlineOffset: -1 }}>
                  <div style={{ outline: '1px solid #C5D3E8' }}>{el}</div>
                </div>
              </div>
              <figcaption className="mt-3"><Lbl>{t as string}</Lbl></figcaption>
            </figure>
          ))}
        </div>
        <div className="mt-6 rounded-[4px] p-6 shb-hair md:p-8">
          <div className="flex flex-wrap items-end gap-x-10 gap-y-6">
            {[16, 22, 44, 88].map((s) => (
              <div key={s} className="flex flex-col items-start gap-3">
                <Mark size={s} />
                <span className="shb-lbl">{s} px{s % 22 === 0 ? ' · sharp' : ' · minimum'}</span>
              </div>
            ))}
            <span className="hidden h-[88px] w-px bg-[var(--shb-line)] md:block" />
            {[30, 57].map((s) => (
              <div key={s} className="flex flex-col items-start gap-3 opacity-90">
                <Mark size={s} />
                <span className="shb-lbl text-[var(--sh-graphite)]">{s} px · uneven pixels</span>
              </div>
            ))}
          </div>
          <p className="mt-6 max-w-[720px] text-[14px] text-[var(--sh-graphite)]">
            At 22, 44 and 88 px every cell lands on whole device pixels. In between, some cells round to two pixels and some to one, and the wedges wobble. 16 px is the floor; below it, use the wordmark-free favicon at 16.
          </p>
        </div>
      </Sub>

      <Sub n="1.5" title="On grounds" note="White, black and mist carry the orange wedge. On orange, the mark goes ink and the lit wedge knocks out to paper.">
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          {[
            { name: 'On white', bg: '#fff', el: <WM size={26} />, hair: true },
            { name: 'On black', bg: '#000', el: <WM size={26} ink="#fff" boxText="#000" /> },
            { name: 'On mist', bg: 'var(--sh-mist)', el: <WM size={26} />, dots: true },
            { name: 'On orange', bg: '#FF4500', el: <WM size={26} accent="#fff" box="#000" boxText="#fff" /> },
          ].map((g) => (
            <figure key={g.name}>
              <div className={`grid h-[180px] place-items-center rounded-[4px] ${g.hair ? 'shb-hair' : ''} ${g.dots ? 'sh-dots' : ''}`} style={{ background: g.bg }}>{g.el}</div>
              <figcaption className="mt-3"><Lbl>{g.name}</Lbl></figcaption>
            </figure>
          ))}
        </div>
      </Sub>

      <Sub n="1.6" title="Mono version" note="For one-colour jobs (etching, a stamp, a fax) the lit wedge knocks out. The gap where it should be still reads as ‘this one’.">
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <div className="grid h-[180px] place-items-center rounded-[4px] shb-hair"><Mark size={88} accent="transparent" /></div>
          <div className="grid h-[180px] place-items-center rounded-[4px] bg-black"><Mark size={88} ink="#fff" accent="transparent" /></div>
          <div className="grid h-[180px] place-items-center rounded-[4px] shb-hair"><WM size={26} accent="transparent" box="#000" boxText="#fff" /></div>
          <div className="grid h-[180px] place-items-center rounded-[4px] bg-black"><WM size={26} ink="#fff" accent="transparent" box="#fff" boxText="#000" /></div>
        </div>
      </Sub>

      <Sub n="1.7" title="Don’ts">
        <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
          <DoDont ok={false} note="Rotating it. Wedge 0 points up."><Mark size={66} style={{ transform: 'rotate(23deg)' }} /></DoDont>
          <DoDont ok={false} note="Lighting a second wedge."><span className="relative block size-[66px]"><Mark size={66} className="absolute inset-0" /><Mark size={66} hot={4} ink="transparent" className="absolute inset-0" /></span></DoDont>
          <DoDont ok={false} note="Smoothing it into vectors."><svg width={66} height={66} viewBox="0 0 22 22">{Array.from({ length: 6 }, (_, i) => { const a0 = (i - 0.5) * Math.PI / 3 + 0.06, a1 = (i + 0.5) * Math.PI / 3 - 0.06, p = (r: number, a: number) => `${11 + r * Math.sin(a)},${11 - r * Math.cos(a)}`; return <path key={i} d={`M${p(10.8, a0)}A10.8 10.8 0 0 1 ${p(10.8, a1)}L${p(5.9, a1)}A5.9 5.9 0 0 0 ${p(5.9, a0)}Z`} fill={i === 1 ? '#FF4500' : '#000'} /> })}</svg></DoDont>
          <DoDont ok={false} note="Shadows, glows or bevels."><Mark size={66} style={{ filter: 'drop-shadow(0 6px 8px rgba(0,0,0,.35))' }} /></DoDont>
          <DoDont ok={false} note="Stretching or squashing."><Mark size={66} style={{ transform: 'scaleX(1.45)' }} /></DoDont>
          <DoDont ok={false} note="Any other accent colour."><Mark size={66} accent="#2FB36B" /></DoDont>
        </div>
      </Sub>
    </Section>
  )
}
