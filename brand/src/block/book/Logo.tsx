import type { CSSProperties, ReactNode } from 'react'
import { IsoScene } from '../Iso'
import { Mark, Wordmark } from '../Mark'
import { BlockWheel } from '../BlockWheel'
import { IsoLattice, IsoWire, MarkCubes, pt } from './isoBits'
import { C, Caption, Scaled, Section, Sub, Tile, Verdict, mix } from './ui'

const GHOST = { top: 'rgba(184,179,255,.55)', left: 'rgba(184,179,255,.8)', right: 'rgba(142,135,242,.85)' }
const mono = { fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 13, fontWeight: 500 } as const

function Construction() {
  return (
    <IsoScene width={980} height={640} unit={118} anchor={[0.47, 0.6]} title="Construction of the anyfmt mark on an isometric grid">
      {(ctx) => {
        const g = 0.08, c = 1 - g
        const ghost = { x: 0 + g / 2, y: 0 + g / 2, z: 0 }
        const L = 0.9
        const lifted = { x: ghost.x + L * 0.42, y: ghost.y + L * 0.42, z: ghost.z + L * 0.62 }
        const a = pt(ctx, ghost.x + c / 2, ghost.y + c / 2, ghost.z + c)
        const b = pt(ctx, lifted.x + c / 2, lifted.y + c / 2, lifted.z + c)
        // gap marker between the two front-bottom cubes on the right face
        const g1 = pt(ctx, 0 - g / 2 + 1, 1 - 0.0, -1 + 0.05)
        const ex = pt(ctx, 1, 1, -1)
        const unitA = pt(ctx, -1 + g / 2, 1.18, -1), unitB = pt(ctx, -1 + g / 2 + c, 1.18, -1)
        const axO = pt(ctx, -2.3, 1.6, -1)
        const axX = pt(ctx, -1.7, 1.6, -1), axY = pt(ctx, -2.3, 2.2, -1), axZ = pt(ctx, -2.3, 1.6, -0.4)
        return (
          <>
            <IsoLattice ctx={ctx} n={5} z={-1} stroke="rgba(14,14,16,.13)" />
            <MarkCubes ctx={ctx} x={-1} y={-1} z={-1} rest={GHOST} hot={GHOST} lift={0} edge="#0E0E10" />
            <IsoWire ctx={ctx} {...ghost} w={c} d={c} h={c} dash="5 5" stroke={C.orangeLo} width={1.6} />
            {/* the diagonal it travels along */}
            <line x1={a[0] - (b[0] - a[0]) * 1.6} y1={a[1] - (b[1] - a[1]) * 1.6} x2={b[0] + (b[0] - a[0]) * 1.2} y2={b[1] + (b[1] - a[1]) * 1.2}
                  stroke={C.ink} strokeWidth={1} strokeDasharray="2 5" />
            <MarkCubes ctx={ctx} x={-1} y={-1} z={-1} rest={{ top: 'none', left: 'none', right: 'none' }} hot="orange" lift={L} edge={C.ink} />
            <circle cx={a[0]} cy={a[1]} r={4} fill={C.orangeLo} />
            <circle cx={b[0]} cy={b[1]} r={4} fill={C.ink} />
            <text x={b[0] + 26} y={b[1] - 64} style={mono} fill={C.ink}>core +0.9u along</text>
            <text x={b[0] + 26} y={b[1] - 46} style={mono} fill={C.ink}>the view diagonal</text>
            <text x={b[0] + 26} y={b[1] - 28} style={mono} fill={C.orangeLo}>(x .38 · y .38 · z .56)</text>
            {/* gap callout */}
            <line x1={g1[0]} y1={g1[1]} x2={g1[0] + 120} y2={g1[1] + 70} stroke={C.ink} strokeWidth={1} />
            <circle cx={g1[0]} cy={g1[1]} r={3.5} fill={C.ink} />
            <text x={g1[0] + 126} y={g1[1] + 74} style={mono} fill={C.ink}>gap 0.08u = 8%</text>
            {/* unit bracket */}
            <path d={`M${unitA[0]},${unitA[1]} L${unitB[0]},${unitB[1]}`} stroke={C.ink} strokeWidth={1.2} />
            <path d={`M${unitA[0]},${unitA[1] - 6} v12 M${unitB[0]},${unitB[1] - 6} v12`} stroke={C.ink} strokeWidth={1.2} />
            <text x={(unitA[0] + unitB[0]) / 2 - 40} y={(unitA[1] + unitB[1]) / 2 + 26} style={mono} fill={C.ink}>cube 0.92u</text>
            {/* iso guide */}
            <g stroke={C.ink} strokeWidth={1.4} fill="none">
              <line x1={axO[0]} y1={axO[1]} x2={axX[0]} y2={axX[1]} /><line x1={axO[0]} y1={axO[1]} x2={axY[0]} y2={axY[1]} /><line x1={axO[0]} y1={axO[1]} x2={axZ[0]} y2={axZ[1]} />
              <path d={`M${axO[0] + 40},${axO[1]} A40,40 0 0 0 ${axO[0] + 40 * Math.cos(Math.PI / 6)},${axO[1] - 20 * 0 + 40 * Math.sin(Math.PI / 6)}`} strokeDasharray="2 3" />
              <line x1={axO[0]} y1={axO[1]} x2={axO[0] + 64} y2={axO[1]} strokeDasharray="2 3" />
            </g>
            <text x={axX[0] + 6} y={axX[1] + 14} style={mono} fill={C.ink}>x</text>
            <text x={axY[0] - 16} y={axY[1] + 14} style={mono} fill={C.ink}>y</text>
            <text x={axZ[0] - 4} y={axZ[1] - 8} style={mono} fill={C.ink}>z</text>
            <text x={axO[0] + 70} y={axO[1] + 22} style={mono} fill={C.ink}>30°</text>
            <text x={ex[0] - 230} y={ex[1] + 70} style={{ ...mono, fontSize: 12 }} fill="rgba(14,14,16,.55)">2 × 2 × 2 grid · unit u · 30° isometric</text>
          </>
        )
      }}
    </IsoScene>
  )
}

/** One-colour mark: resting cubes in a 45% tint, the core solid, faces split by hairlines of the ground. */
function MonoMark({ fg, bg, size = 120 }: { fg: string; bg: string; size?: number }) {
  const tint = mix(bg, fg, 0.45)
  const rest = { top: tint, left: tint, right: tint }, hot = { top: fg, left: fg, right: fg }
  return (
    <div style={{ width: size }}>
      <IsoScene width={100} height={112} anchor={[0.5, 0.62]} unit={22} title="anyfmt mono mark">
        {(ctx) => <g transform="translate(0 -6)"><MarkCubes ctx={ctx} x={-1} y={-1} z={0} rest={rest} hot={hot} lift={0.9} edge={bg} /></g>}
      </IsoScene>
    </div>
  )
}

function Step({ n, title, children, bg = C.cream, fg = C.ink }: { n: string; title: string; children: ReactNode; bg?: string; fg?: string }) {
  return (
    <Tile bg={bg} fg={fg} className="flex aspect-square flex-col p-4">
      <div className="bk-mono flex justify-between text-[11px] uppercase tracking-[.08em] opacity-70"><span>{n}</span><span>{title}</span></div>
      <div className="grid flex-1 place-items-center">{children}</div>
    </Tile>
  )
}

function Mini({ gap, lift, hot, rest = 'lilac' }: { gap: number; lift: number; hot: 'orange' | 'lilac'; rest?: 'lilac' | 'ink' }) {
  return (
    <div className="w-[64%]">
      <IsoScene width={200} height={220} unit={56} anchor={[0.5, 0.64]}>
        {(ctx) => <MarkCubes ctx={ctx} x={-1} y={-1} z={-0.6} gap={gap} lift={lift} hot={hot} rest={rest} edge={lift > 0 && hot === 'lilac' ? 'rgba(14,14,16,.35)' : undefined} />}
      </IsoScene>
    </div>
  )
}

const ON: { bg: string; name: string; variant: 'color' | 'flat' | 'icon'; fg: string; note: string }[] = [
  { bg: C.ink, name: 'Ink', variant: 'color', fg: C.cream, note: 'Primary' },
  { bg: C.orange, name: 'Orange', variant: 'icon', fg: C.ink, note: 'Ink + cream core' },
  { bg: C.cream, name: 'Cream', variant: 'flat', fg: C.ink, note: 'Ink + orange core' },
  { bg: C.wine, name: 'Wine', variant: 'color', fg: C.cream, note: 'Primary' },
  { bg: C.lilac, name: 'Lilac', variant: 'flat', fg: C.ink, note: 'Ink + orange core' },
]

function Dont({ label, children, bg = C.cream, style }: { label: string; children: ReactNode; bg?: string; style?: CSSProperties }) {
  return (
    <Tile bg={bg} fg={C.ink} className="flex aspect-[4/3] flex-col p-4">
      <div className="flex items-center justify-between"><Verdict ok={false} /></div>
      <div className="grid flex-1 place-items-center" style={style}>{children}</div>
      <div className="text-[14px] font-[560]" style={{ color: bg === C.cream ? C.ink : C.cream }}>{label}</div>
    </Tile>
  )
}

export function Logo() {
  return (
    <Section id="logo" num="02" title="Logo" accent="." intro="Eight cubes in a 2×2×2 grid. The front-top one is pushed out along the view diagonal and lit orange. It is the wheel's aimed wedge, said in blocks.">
      <Sub n="2.1">Construction</Sub>
      <Tile bg={C.cream} fg={C.ink} label="Fig. 1 · isometric construction" className="px-2 pb-6 pt-12 md:px-6">
        <div className="mx-auto max-w-[980px]"><Construction /></div>
      </Tile>
      <div className="mt-2 grid grid-cols-2 gap-2 md:grid-cols-4">
        <Step n="01" title="2×2×2"><Mini gap={0} lift={0} hot="lilac" /></Step>
        <Step n="02" title="8% gaps"><Mini gap={0.08} lift={0} hot="lilac" /></Step>
        <Step n="03" title="Lift the core"><Mini gap={0.08} lift={0.9} hot="lilac" /></Step>
        <Step n="04" title="Light it" bg={C.ink} fg={C.cream}><Mini gap={0.08} lift={0.9} hot="orange" /></Step>
      </div>
      <Caption label="Grid, gaps, lift">
        The mark sits on a true 30° isometric grid. Each cube is 0.92 of a unit, leaving an 8% gap so the grid stays readable at small
        sizes. The core moves 0.9 units along the view diagonal, which keeps it in line with its old slot: it reads as lifted, not moved.
      </Caption>

      <Sub n="2.2">Meaning</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.wine} className="flex items-center justify-center gap-4 p-6 py-12 md:col-span-8 md:gap-10">
          <div className="w-[44%] max-w-[300px]">
            <Scaled w={300} h={300}>
              <BlockWheel size={300} active={1} hot="orange" hub={<span className="bk-display text-[22px] font-[700]">MOV</span>}
                wedges={['GIF', 'MP4', 'WEBM', 'M4V', 'MP3', 'PNG'].map((l) => ({ id: l, label: l }))} />
            </Scaled>
          </div>
          <span className="bk-display text-[48px] font-[600] text-[#FF6B1A] md:text-[80px]">=</span>
          <Mark size={170} style={{ width: '30%', maxWidth: 170, height: 'auto', flexShrink: 0 }} />
        </Tile>
        <Tile bg={C.lilac} fg={C.ink} className="flex flex-col justify-between p-6 md:col-span-4">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] opacity-70">What it says</span>
          <p className="bk-display mt-10 text-[34px] font-[640] leading-[.98] md:text-[40px]">Everything else waits. <span className="text-[#561629]">One thing rises.</span></p>
        </Tile>
      </div>
      <Caption label="Aim, lift, drop">
        In the app, a wheel of choices opens around your pointer and the one you aim at pops out on a hard shadow. The mark is that
        moment frozen: a tidy grid of options, and the one you picked stepping forward.
      </Caption>

      <Sub n="2.3">Wordmark and lockups</Sub>
      <div className="grid gap-2 md:grid-cols-2">
        <Tile bg={C.ink2} label="Horizontal · primary" fg={C.cream} className="grid min-h-[260px] place-items-center p-8"><span className="md:hidden"><Wordmark size={40} /></span><span className="hidden md:block"><Wordmark size={64} /></span></Tile>
        <Tile bg={C.cream} label="Stacked" fg={C.ink} className="grid min-h-[260px] place-items-center p-8">
          <div className="flex flex-col items-center gap-3"><Mark size={110} variant="flat" /><span className="bk-display text-[54px] font-[620] leading-none">anyfmt</span></div>
        </Tile>
        <Tile bg={C.orange} label="Wordmark only" fg={C.ink} className="grid min-h-[220px] place-items-center p-8">
          <span className="bk-display text-[72px] font-[660] leading-none md:text-[96px]">anyfmt</span>
        </Tile>
        <Tile bg={C.wine} label="With descriptor" fg={C.cream} className="grid min-h-[220px] place-items-center p-8">
          <div className="flex flex-wrap items-center justify-center gap-5">
            <Wordmark size={44} />
            <span className="h-10 w-px bg-[#F4F1EC]/30" />
            <span className="bk-mono text-[13px] uppercase leading-[1.5] tracking-[.06em] text-[#FF4FA0]">Any file.<br />Any format.</span>
          </div>
        </Tile>
      </div>
      <Caption label="Funnel Display, lowercase">
        The name is always lowercase "anyfmt", set in Funnel Display at weight 600 with −4.5% tracking. The gap between mark and name is
        a third of the name's height. In running text it's plain lowercase too, never "AnyFmt" or "ANYFMT".
      </Caption>

      <Sub n="2.4">Clear space and minimum size</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.cream} fg={C.ink} label="Clear space = x, one cube" className="grid min-h-[300px] place-items-center px-4 pb-8 pt-14 md:col-span-7 md:min-h-[360px] md:p-10">
          <div className="w-full max-w-[440px]"><Scaled w={440} h={200}><div className="flex h-[200px] w-[440px] items-center justify-center">
          <div className="relative border border-dashed border-[#FF6B1A] p-[46px]">
            <div className="relative border border-[#0E0E10]/30 bg-[#FF6B1A]/10"><div className="px-1 pt-1"><Wordmark size={52} tone="ink" /></div></div>
            {[['left-0 top-1/2 -translate-y-1/2', 'w-[46px] h-px'], ['right-0 top-1/2 -translate-y-1/2', 'w-[46px] h-px'], ['top-0 left-1/2 -translate-x-1/2', 'h-[46px] w-px'], ['bottom-0 left-1/2 -translate-x-1/2', 'h-[46px] w-px']].map(([pos, sz], i) => (
              <span key={i} className={`absolute ${pos} ${sz} bg-[#FF6B1A]`} />
            ))}
            <span className="bk-mono absolute left-2 top-1 text-[11px] text-[#D9500A]">x</span>
            <span className="bk-mono absolute bottom-1 right-2 text-[11px] text-[#D9500A]">x</span>
          </div>
          </div></Scaled></div>
        </Tile>
        <Tile bg={C.ink2} label="Minimum sizes" fg={C.cream} className="flex flex-col justify-end gap-6 p-6 pt-14 md:col-span-5">
          <div className="flex items-end gap-6">
            {[16, 24, 32, 48].map((s) => (
              <div key={s} className="flex flex-col items-center gap-2"><Mark size={s} /><span className="bk-mono text-[11px] text-[#8A8790]">{s}px</span></div>
            ))}
          </div>
          <div className="flex items-end gap-6">
            <div className="flex flex-col gap-2"><Wordmark size={14} /><span className="bk-mono text-[11px] text-[#8A8790]">lockup 80px wide</span></div>
            <div className="flex flex-col gap-2"><Wordmark size={22} /><span className="bk-mono text-[11px] text-[#8A8790]">120px</span></div>
          </div>
          <p className="text-[13px] leading-[1.5] text-[#F4F1EC]/60">Below 16px the mark becomes the 2D menu-bar glyph (see 3.2). Below 80px wide, drop the name.</p>
        </Tile>
      </div>
      <Caption label="Room to breathe">
        Keep one cube's width clear on every side, measured from the outer edge of the lifted core. Nothing else gets inside that line,
        including other logos, edges of the page and UI chrome.
      </Caption>

      <Sub n="2.5">On colour</Sub>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-5">
        {ON.map((o) => (
          <Tile key={o.name} bg={o.bg} fg={o.fg} className="flex aspect-[3/4] flex-col justify-between p-4">
            <span className="bk-mono text-[11px] uppercase tracking-[.08em] opacity-70">{o.name}</span>
            <div className="grid place-items-center"><Mark size={96} variant={o.variant} /></div>
            <span className="text-[13px] font-[560] opacity-80">{o.note}</span>
          </Tile>
        ))}
        <Tile bg={C.ink2} className="flex aspect-[3/4] flex-col justify-between p-4 md:hidden">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] text-[#8A8790]">Rule</span>
          <p className="text-[14px] leading-[1.45]">The core is never the same colour as the ground.</p>
        </Tile>
      </div>
      <Caption label="The core always contrasts">
        On ink and wine, use the colour mark. On orange the core can't be orange, so the cubes go ink and the core goes cream. On cream
        and lilac, the cubes go ink and keep the orange core.
      </Caption>

      <Sub n="2.6">Mono</Sub>
      <div className="grid grid-cols-3 gap-2">
        {[[C.cream, C.ink], [C.ink, C.cream], [C.orange, C.ink]].map(([bg, fg]) => (
          <Tile key={bg} bg={bg} className="grid aspect-[4/3] place-items-center"><MonoMark fg={fg} bg={bg} size={120} /></Tile>
        ))}
      </div>
      <Caption label="One colour, two values">
        For single-colour printing, engraving and embroidery. The resting cubes print as a 45% tint, the core prints solid, and hairlines
        of the ground colour split the faces. The lift still reads with one ink. If even a tint isn't possible, use the 2D glyph.
      </Caption>

      <Sub n="2.7">Don'ts</Sub>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-3">
        <Dont label="Don't rotate it off the grid"><Mark size={100} style={{ transform: 'rotate(-18deg)' }} /></Dont>
        <Dont label="Don't recolour the core" bg={C.ink}><Mark size={100} style={{ filter: 'hue-rotate(150deg)' }} /></Dont>
        <Dont label="Don't stretch it"><Mark size={100} style={{ transform: 'scaleX(1.6)' }} /></Dont>
        <Dont label="Don't add glows or soft shadows" bg={C.ink}><Mark size={100} style={{ filter: 'drop-shadow(0 0 18px #FF6B1A) drop-shadow(0 10px 20px #FF4FA0)' }} /></Dont>
        <Dont label="Don't place it on stripes" bg={C.cream}>
          <div className="bk-stripe-orange grid size-[140px] place-items-center rounded-[4px]"><Mark size={90} /></div>
        </Dont>
        <Dont label="Don't capitalise the name" bg={C.ink}>
          <span className="flex items-center gap-3"><Mark size={46} /><span className="bk-display text-[40px] font-[640] text-[#F4F1EC]">AnyFmt</span></span>
        </Dont>
      </div>
      <Caption label="Keep it square">
        The mark only works on its grid. No rotation, no distortion, no effects, no busy grounds. If it needs to feel bigger, put it on a
        bigger block of colour.
      </Caption>
    </Section>
  )
}
