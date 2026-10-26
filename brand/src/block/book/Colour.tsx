import { IsoBlock, IsoScene, type Material } from '../Iso'
import { MarkCubes } from './isoBits'
import { C, Caption, Section, Sub, Tile, contrast, grade } from './ui'

type Swatch = { name: string; hex: string; role: string; fg: string; span: string }
const PALETTE: Swatch[] = [
  { name: 'Orange', hex: C.orange, role: 'The signal. The lit core, primary buttons, the aimed wedge.', fg: C.ink, span: 'md:col-span-6 md:row-span-2 min-h-[300px] md:min-h-[440px]' },
  { name: 'Ink', hex: C.ink, role: 'The ground. Most pages, all app chrome.', fg: C.cream, span: 'md:col-span-3 min-h-[200px]' },
  { name: 'Lilac', hex: C.lilac, role: 'The calm second voice. Resting cubes, highlights on ink.', fg: C.ink, span: 'md:col-span-3 min-h-[200px]' },
  { name: 'Wine', hex: C.wine, role: 'Depth. Shadows, stripe grounds, deep panels.', fg: C.cream, span: 'md:col-span-2 min-h-[220px]' },
  { name: 'Wine 2', hex: C.wine2, role: 'Hard offset shadows.', fg: C.cream, span: 'md:col-span-2 min-h-[220px]' },
  { name: 'Pink', hex: C.pink, role: 'Spice. Stripes, don\'ts, one word per page.', fg: C.ink, span: 'md:col-span-2 min-h-[220px]' },
  { name: 'Cream', hex: C.cream, role: 'Paper. Light surfaces and type on dark.', fg: C.ink, span: 'md:col-span-6 min-h-[160px]' },
  { name: 'Ink 2', hex: C.ink2, role: 'Cards and raised UI on ink.', fg: C.cream, span: 'md:col-span-3 min-h-[160px]' },
  { name: 'Ink 3', hex: C.ink3, role: 'Borders, wells, disabled.', fg: C.cream, span: 'md:col-span-3 min-h-[160px]' },
]

function Ratio({ a, b, label }: { a: string; b: string; label: string }) {
  const r = contrast(a, b)
  const g = grade(r)
  return (
    <div className="flex items-center gap-2">
      <span className="bk-mono w-[66px] text-[11px] opacity-70">{label}</span>
      <span className="bk-mono text-[12px] font-[600] tabular-nums">{r.toFixed(2)}</span>
      <span className="bk-mono rounded-[3px] px-1.5 py-[1px] text-[10px] font-[600]" style={{ background: g === 'Fail' ? 'transparent' : 'currentColor', boxShadow: g === 'Fail' ? 'inset 0 0 0 1px currentColor' : undefined }}>
        <span style={{ color: g === 'Fail' ? undefined : a }}>{g}</span>
      </span>
    </div>
  )
}

const PAIRS = [
  { bg: C.orange, fg: C.ink, name: 'Orange + Ink', use: 'Covers, primary actions, the big moments.' },
  { bg: C.lilac, fg: C.ink, name: 'Lilac + Ink', use: 'Secondary panels, quiet highlights, charts.' },
  { bg: C.wine, fg: C.pink, name: 'Pink + Wine', use: 'Accents, labels and stripes. Big type only.' },
  { bg: C.cream, fg: C.ink, name: 'Cream + Ink', use: 'Reading. Docs, long copy, light UI.' },
]

const STRIPES: { cls: string; mat: Material; name: string; spec: string }[] = [
  { cls: 'bk-stripe-pink', mat: 'stripePink', name: 'Pink on wine', spec: '#FF4FA0 / #561629' },
  { cls: 'bk-stripe-lilac', mat: 'stripeLilac', name: 'Lilac on ink', spec: '#B8B3FF / #2C2C33' },
  { cls: 'bk-stripe-orange', mat: 'stripeOrange', name: 'Orange on wine', spec: '#FF6B1A / #561629' },
]

const SHARE = [
  { c: C.ink, n: 'Ink', p: 45 }, { c: C.orange, n: 'Orange', p: 20 }, { c: C.cream, n: 'Cream', p: 15 },
  { c: C.lilac, n: 'Lilac', p: 10 }, { c: C.wine, n: 'Wine', p: 7 }, { c: C.pink, n: 'Pink', p: 3 },
]

export function Colour() {
  return (
    <Section id="colour" num="04" title="Colour" accent="." intro="Loud blocks, hard edges, no gradients. Orange is the signal, ink is the ground, and lilac, wine and pink do the supporting work.">
      <Sub n="4.1">Palette</Sub>
      <div className="grid grid-cols-1 gap-2 md:grid-cols-12">
        {PALETTE.map((s) => (
          <Tile key={s.name} bg={s.hex} fg={s.fg} className={`bkb-lift flex flex-col justify-between p-5 ${s.span}`}>
            {s.hex === C.orange && (
              <div className="pointer-events-none absolute -right-6 top-6 hidden w-[340px] md:block" aria-hidden>
                <IsoScene width={340} height={320} unit={66} anchor={[0.5, 0.6]}>
                  {(ctx) => <MarkCubes ctx={ctx} x={-1} y={-1} z={0} rest="ink" hot="cream" lift={0.9} />}
                </IsoScene>
              </div>
            )}
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="bk-display text-[30px] font-[640] leading-none md:text-[34px]">{s.name}</div>
                <div className="bk-mono mt-1.5 text-[12px] opacity-75">{s.hex}</div>
              </div>
            </div>
            <div className="mt-6">
              <p className="mb-3 max-w-[34ch] text-[14px] leading-[1.4] opacity-85">{s.role}</p>
              <div className="flex flex-col gap-1">
                <Ratio a={s.hex} b={C.ink} label="vs ink" />
                <Ratio a={s.hex} b={C.cream} label="vs cream" />
              </div>
            </div>
          </Tile>
        ))}
      </div>
      <Caption label="WCAG 2.2, computed">
        Ratios are worked out from the hex values on this page. "AA" means 4.5:1 or better and is safe for body text; "AA Large" (3:1)
        is for 24px+ or 19px bold and for UI shapes. Orange on ink passes AA; orange on cream does not, so cream pages use ink for text and
        save orange for blocks.
      </Caption>

      <Sub n="4.2">Approved pairings</Sub>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
        {PAIRS.map((p) => {
          const r = contrast(p.bg, p.fg)
          return (
            <Tile key={p.name} bg={p.bg} fg={p.fg} className="flex aspect-[3/4] flex-col justify-between p-4 md:p-5">
              <div className="bk-mono flex justify-between text-[11px] uppercase tracking-[.06em]"><span>{p.name}</span></div>
              <div className="bk-display text-[88px] font-[650] leading-[.8] md:text-[120px]">Aa</div>
              <div>
                <div className="bk-mono text-[13px] font-[600]">{r.toFixed(2)} : 1 · {grade(r)}</div>
                <p className="mt-1 text-[13px] leading-[1.4] opacity-80">{p.use}</p>
              </div>
            </Tile>
          )
        })}
      </div>
      <Caption label="Four pairs, no others for text">
        These are the only foreground/background pairs for type. Everything else, like lilac on orange or pink on ink, is fine for
        blocks and illustration but never for words.
      </Caption>

      <Sub n="4.3">Stripe materials</Sub>
      <div className="grid gap-2 md:grid-cols-3">
        {STRIPES.map((s) => (
          <Tile key={s.name} bg={C.ink2} className="flex flex-col">
            <div className={`${s.cls} h-[140px]`} />
            <div className="flex items-center gap-4 p-4">
              <div className="w-[120px] shrink-0">
                <IsoScene width={140} height={130} unit={52} anchor={[0.5, 0.7]}>
                  {(ctx) => <IsoBlock ctx={ctx} x={-0.6} y={-0.6} z={0} w={1.2} d={1.2} h={1.2} material={s.mat} />}
                </IsoScene>
              </div>
              <div>
                <div className="bk-display text-[24px] font-[620] leading-none">{s.name}</div>
                <div className="bk-mono mt-2 text-[11px] text-[#8A8790]">{s.spec}<br />45° · bands 1:1 · ¼ unit</div>
              </div>
            </div>
          </Tile>
        ))}
      </div>
      <Caption label="Stripes follow the face">
        On flat surfaces stripes run at 135°, 14px bands. On isometric blocks they're drawn in each face's own plane, so they wrap round
        the corners like a printed material. Use stripes on one block per scene, usually the base slab.
      </Caption>

      <Sub n="4.4">Proportion</Sub>
      <Tile bg={C.ink2} className="p-5 md:p-8">
        <div className="flex h-[120px] overflow-hidden rounded-[4px] md:h-[160px]">
          {SHARE.map((s) => (
            <div key={s.n} className="flex flex-col justify-end p-2 md:p-3" style={{ width: `${s.p}%`, background: s.c, color: s.c === C.ink || s.c === C.wine ? C.cream : C.ink, boxShadow: s.c === C.ink ? 'inset 0 0 0 1px #2A2A30' : undefined }}>
              {s.p >= 5 && <><span className="bk-display hidden text-[22px] font-[650] leading-none md:block">{s.p}%</span>
              <span className="bk-mono hidden text-[10px] uppercase md:block">{s.n}</span></>}
            </div>
          ))}
        </div>
        <div className="mt-4 grid grid-cols-3 gap-2 md:hidden">
          {SHARE.map((s) => <span key={s.n} className="bk-mono flex items-center gap-1.5 text-[11px]"><i className="size-2.5" style={{ background: s.c }} />{s.n} {s.p}%</span>)}
        </div>
        <div className="bk-mono mt-3 hidden text-[11px] text-[#8A8790] md:block">Pink 3%: one stripe, one word, one tag.</div>
        <div className="mt-6 grid grid-cols-6 grid-rows-3 gap-1.5 md:h-[240px]" aria-label="A mosaic in the recommended proportions">
          <div className="col-span-3 row-span-3 rounded-[4px] bg-[#0E0E10] ring-1 ring-inset ring-[#2A2A30] min-h-[60px]" />
          <div className="col-span-2 row-span-2 rounded-[4px] bg-[#FF6B1A]" />
          <div className="rounded-[4px] bg-[#F4F1EC]" />
          <div className="rounded-[4px] bg-[#B8B3FF]" />
          <div className="rounded-[4px] bg-[#3A0E1E]" />
          <div className="rounded-[4px] bg-[#F4F1EC]" />
          <div className="rounded-[4px] bg-[#FF4FA0]" />
        </div>
      </Tile>
      <Caption label="Mostly ink, a lot of orange">
        A page should read as ink with big orange moments. Cream for reading, lilac for calm, wine for depth. Pink is a seasoning: one
        stripe, one word, one tag.
      </Caption>
    </Section>
  )
}
