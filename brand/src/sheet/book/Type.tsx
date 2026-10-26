import { DoDont, Lbl, Section, Sub } from './ui'

const SCALE = [
  { name: 'Statement', font: 'Host Grotesk 500', size: '190 / 150', lh: '0.92', tr: '−0.05em', cls: 'sh-display-xl', px: 64, sample: 'Drop.' },
  { name: 'Display', font: 'Host Grotesk 500', size: '45', lh: '1.1', tr: '−0.02em', cls: 'sh-display', px: 45, sample: 'Convert any file' },
  { name: 'Headline', font: 'Host Grotesk 500', size: '34', lh: '1.1', tr: '−0.02em', cls: 'sh-display', px: 34, sample: 'Tools for the file in your hand' },
  { name: 'Subhead', font: 'Inter 500', size: '24', lh: '1.3', tr: '−0.01em', cls: 'font-[500] tracking-[-0.01em]', px: 24, sample: 'Press Shift while you drag.' },
  { name: 'Body', font: 'Inter 400', size: '16', lh: '1.5', tr: '+0.007em', cls: '', px: 16, sample: 'A wheel of everything the file can become opens around your pointer.' },
  { name: 'Small', font: 'Inter 400', size: '14', lh: '1.45', tr: '0', cls: 'text-[var(--sh-graphite)]', px: 14, sample: 'Saved next to the original. Nothing was uploaded.' },
  { name: 'Label', font: 'Geist Mono 400', size: '14', lh: '1.2', tr: '+0.06em, caps', cls: 'sh-mono', px: 14, sample: '793 routes · 0 network calls' },
  { name: 'Code', font: 'Geist Mono 400', size: '14', lh: '1.6', tr: '0', cls: 'sh-code', px: 14, sample: 'anyfmt convert clip.mov --to gif' },
]

// tracking (em) by size: flat at body, tightening through display, −0.05 at statement sizes.
const RAMP: [number, number][] = [[16, 0.007], [24, -0.01], [34, -0.02], [45, -0.02], [72, -0.03], [110, -0.04], [150, -0.05], [190, -0.05]]

function Ramp() {
  const W = 560, H = 200, x = (s: number) => 40 + ((s - 16) / (190 - 16)) * (W - 60), y = (t: number) => 20 + ((0.01 - t) / 0.065) * (H - 50)
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Tracking tightens from +0.007em at 16 px to −0.05em at 150 px and above">
      {[0, -0.02, -0.05].map((t) => (
        <g key={t}><line x1={40} x2={W - 20} y1={y(t)} y2={y(t)} stroke="#D3D9E2" /><text x={0} y={y(t) + 4} fontSize="11" fontFamily="Geist Mono Variable" fill="#686562">{t === 0 ? '0' : t.toFixed(2)}</text></g>
      ))}
      <polyline points={RAMP.map(([s, t]) => `${x(s)},${y(t)}`).join(' ')} fill="none" stroke="#000" strokeWidth={1.5} />
      {RAMP.map(([s, t]) => (
        <g key={s}>
          <rect x={x(s) - 3} y={y(t) - 3} width={6} height={6} fill={[34, 45, 190].includes(s) ? '#000' : '#fff'} stroke="#000" />
          <text x={x(s)} y={H - 6} textAnchor="middle" fontSize="11" fontFamily="Geist Mono Variable" fill="#686562">{s}</text>
        </g>
      ))}
    </svg>
  )
}

export function Type() {
  return (
    <Section id="type" n={4} label="Type" title={<>Big, tight, and <span className="sh-hl">set in one weight.</span></>}
      lede="Host Grotesk 500 for display, tightening as it grows. Inter for reading. Geist Mono, uppercase and tracked out, for every label and number.">
      <Sub n="4.1" title="Host Grotesk at three sizes" note="Display weight is always 500. Bigger means tighter: −0.02em at 34–45 px, −0.05em at 150–190 px.">
        <div className="overflow-hidden">
          <div className="flex items-end justify-between border-b border-[var(--shb-line)] pb-4">
            <span className="sh-display-xl text-[96px] md:text-[190px]">Aa<span className="sh-hl" style={{ display: 'inline-block', lineHeight: 0.86, paddingBottom: '0.06em' }}>fmt</span></span>
            <Lbl className="hidden text-right md:block">190 px · −0.05em<br />line 0.92</Lbl>
          </div>
          <div className="grid gap-8 py-6 md:grid-cols-2">
            <div><div className="sh-display text-[45px]">Every format the file can become</div><Lbl className="mt-3 block">45 px · −0.02em · line 1.1</Lbl></div>
            <div><div className="sh-display text-[34px]">Crop, trim, compress, redact. In the drag.</div><Lbl className="mt-3 block">34 px · −0.02em · line 1.1</Lbl></div>
          </div>
        </div>
      </Sub>

      <Sub n="4.2" title="Tracking ramp">
        <div className="grid gap-8 md:grid-cols-12">
          <div className="rounded-[4px] p-4 shb-hair md:col-span-7 md:p-6"><Ramp /><Lbl className="mt-2 block">Size, px →  ·  tracking, em ↑</Lbl></div>
          <div className="grid grid-cols-3 gap-4 md:col-span-5 md:grid-cols-1">
            {[['Host Grotesk', 'Display', 'sh-display text-[34px]'], ['Inter', 'Body and UI', 'text-[34px] font-[450] tracking-[-0.01em]'], ['Geist Mono', 'Labels, numbers, code', 'sh-code text-[30px]']].map(([f, r, c]) => (
              <div key={f} className="border-t border-black pt-3">
                <div className={c}>Ag</div>
                <div className="mt-2 text-[15px] font-[600]">{f}</div>
                <div className="text-[13px] text-[var(--sh-graphite)]">{r}</div>
              </div>
            ))}
          </div>
        </div>
      </Sub>

      <Sub n="4.3" title="Scale">
        <div className="overflow-hidden rounded-[4px] shb-hair">
          <div className="hidden grid-cols-[120px_1fr_150px_80px_60px_110px] gap-4 border-b border-black bg-[var(--sh-slate)] px-4 py-3 md:grid">
            {['Role', 'Sample', 'Face', 'Size', 'Line', 'Tracking'].map((h) => <span key={h} className="shb-lbl">{h}</span>)}
          </div>
          {SCALE.map((s) => (
            <div key={s.name} className="grid grid-cols-1 gap-2 border-b border-[var(--shb-line)] px-4 py-4 last:border-0 md:grid-cols-[120px_1fr_150px_80px_60px_110px] md:items-center md:gap-4">
              <span className="shb-lbl">{s.name}</span>
              <span className={`${s.cls} min-w-0 truncate`} style={{ fontSize: Math.min(s.px, 64), lineHeight: 1.15 }}>{s.sample}</span>
              <span className="text-[13px] text-[var(--sh-graphite)]">{s.font}</span>
              <span className="shb-num text-[13px]">{s.size}</span>
              <span className="shb-num text-[13px]">{s.lh}</span>
              <span className="shb-num text-[13px]">{s.tr}</span>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="4.4" title="The highlight rule" note="One phrase per headline, the words that carry the claim. Never a whole line, never two boxes, never in body text.">
        <div className="grid gap-4 md:grid-cols-2">
          <DoDont ok note="One phrase, the payoff, at the end." plate="#fff"><span className="sh-display text-[30px]">Convert any file <span className="sh-hl">mid-drag.</span></span></DoDont>
          <DoDont ok={false} note="Two highlights compete; neither wins." plate="#fff"><span className="sh-display text-[30px]"><span className="sh-hl">Convert</span> any file <span className="sh-hl">mid-drag.</span></span></DoDont>
          <DoDont ok={false} note="Boxing the whole headline turns it into a banner." plate="#fff"><span className="sh-display text-[30px]"><span className="sh-hl" style={{ whiteSpace: 'normal' }}>Convert any file mid-drag.</span></span></DoDont>
          <DoDont ok={false} note="Highlights in running text. Use weight or a link." plate="#fff"><span className="max-w-[340px] text-[15px]">Drag a file and press <span className="sh-hl">Shift</span> to open the wheel, then drop on a format.</span></DoDont>
        </div>
      </Sub>
    </Section>
  )
}
