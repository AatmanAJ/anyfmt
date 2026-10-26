import { useMotionValueEvent, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { IsoBlock, IsoKeycap, IsoLeftText, IsoScene, MATERIALS, type Faces, type IsoCtx, type Material } from '../Iso'
import { isShot } from '../../shared/kit'
import { IsoLattice, IsoWire, MarkCubes, pt } from './isoBits'
import { C, Caption, Section, Sub, Tile } from './ui'

const mono = { fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 12, fontWeight: 500 } as const

function GridUnit() {
  return (
    <IsoScene width={560} height={420} unit={70} anchor={[0.5, 0.6]} title="The isometric grid and one unit cube">
      {(ctx) => {
        const o = pt(ctx, 1, 1, 0)
        const xA = pt(ctx, 2.6, 1, 0), yA = pt(ctx, 1, 2.6, 0), zA = pt(ctx, 1, 1, 2.2)
        const e1 = pt(ctx, 0, 1, 0), e2 = pt(ctx, 1, 1, 0)
        return (
          <>
            <IsoLattice ctx={ctx} n={4} stroke="rgba(14,14,16,.16)" />
            <IsoBlock ctx={ctx} x={0} y={0} z={0} w={1} d={1} h={1} material="orange" edge={C.ink} />
            <IsoWire ctx={ctx} x={-1} y={0} z={0} w={1} d={1} h={0.5} stroke={C.ink} dash="3 4" />
            <IsoWire ctx={ctx} x={0} y={-1} z={0} w={1} d={1} h={0.25} stroke={C.ink} dash="3 4" />
            <g stroke={C.ink} strokeWidth={1.4}>
              <line x1={o[0]} y1={o[1]} x2={xA[0]} y2={xA[1]} /><line x1={o[0]} y1={o[1]} x2={yA[0]} y2={yA[1]} />
              <line x1={o[0]} y1={o[1]} x2={zA[0]} y2={zA[1]} strokeDasharray="4 4" />
            </g>
            <text x={xA[0] + 6} y={xA[1] + 4} style={mono} fill={C.ink}>+x</text>
            <text x={yA[0] - 26} y={yA[1] + 6} style={mono} fill={C.ink}>+y</text>
            <text x={zA[0] + 8} y={zA[1]} style={mono} fill={C.ink}>+z</text>
            <text x={(e1[0] + e2[0]) / 2 - 10} y={(e1[1] + e2[1]) / 2 + 24} style={mono} fill={C.ink}>1u</text>
            <text x={pt(ctx, -1, 0, 0.5)[0] - 70} y={pt(ctx, -1, 0, 0.5)[1] - 10} style={mono} fill={C.ink}>½u</text>
            <text x={pt(ctx, 0, -1, 0.25)[0] + 34} y={pt(ctx, 0, -1, 0.25)[1] - 24} style={mono} fill={C.ink}>¼u</text>
          </>
        )
      }}
    </IsoScene>
  )
}

const MATS: { m: Material; n: string }[] = [
  { m: 'orange', n: 'Orange' }, { m: 'lilac', n: 'Lilac' }, { m: 'pink', n: 'Pink' }, { m: 'cream', n: 'Cream' }, { m: 'wine', n: 'Wine' },
  { m: 'ink', n: 'Ink' }, { m: 'inkLight', n: 'Ink light' }, { m: 'stripePink', n: 'Stripe pink' }, { m: 'stripeLilac', n: 'Stripe lilac' }, { m: 'stripeOrange', n: 'Stripe orange' },
]

function Cube({ m }: { m: Material }) {
  return (
    <IsoScene width={120} height={120} unit={46} anchor={[0.5, 0.72]}>
      {(ctx) => <IsoBlock ctx={ctx} x={-0.5} y={-0.5} z={0} w={1} d={1} h={1} material={m} />}
    </IsoScene>
  )
}

function BuildStep({ n, title, children, note }: { n: string; title: string; children: (ctx: IsoCtx) => ReactNode; note: string }) {
  return (
    <Tile bg={C.ink2} className="flex flex-col p-4">
      <div className="bk-mono flex justify-between text-[11px] uppercase tracking-[.08em] text-[#8A8790]"><span>{n}</span><span className="text-[#FF6B1A]">{title}</span></div>
      <div className="py-2"><IsoScene width={240} height={190} unit={34} anchor={[0.5, 0.66]}>{children}</IsoScene></div>
      <p className="text-[13px] leading-[1.4] text-[#F4F1EC]/70">{note}</p>
    </Tile>
  )
}

const SLAB: Faces = { top: '#FF6B1A', left: '#FF85BD', right: 'stripe:pink:right' }

function SurveyStack({ gap }: { gap: number }) {
  const words = ['Drop it.', 'Press it.', 'Drag it.']
  return (
    <IsoScene width={680} height={720} unit={86} anchor={[0.47, 0.76]} title="Three stacked slabs labelled Drag it, Press it, Drop it">
      {(ctx) => (
        <>
          {words.map((w, i) => {
            const z = i * (0.75 + gap)
            return (
              <g key={w}>
                <IsoBlock ctx={ctx} x={-1.6} y={-1.6} z={z} w={3.2} d={3.2} h={0.75} material={SLAB} />
                <IsoLeftText ctx={ctx} x={-1.3} y={1.6} z={z + 0.2} size={36} weight={700} fill={C.ink}>{w}</IsoLeftText>
              </g>
            )
          })}
        </>
      )}
    </IsoScene>
  )
}

function Stairs() {
  return (
    <IsoScene width={560} height={460} unit={44} anchor={[0.52, 0.8]} title="Isometric stairs with a file block climbing">
      {(ctx) => (
        <>
          {Array.from({ length: 6 }, (_, i) => {
            const x = -3 + i
            const h = (6 - i) * 0.55
            return <IsoBlock key={i} ctx={ctx} x={x} y={-1.6} z={0} w={1} d={3.2} h={h} material={i % 2 ? 'stripePink' : { top: '#FF85BD', left: '#FF4FA0', right: '#D62F7E' }} />
          })}
          <IsoBlock ctx={ctx} x={-2.8} y={-0.3} z={6 * 0.55} w={0.6} d={0.6} h={0.6} material="cream" />
          <IsoBlock ctx={ctx} x={-0.85} y={-0.35} z={4 * 0.55} w={0.7} d={0.7} h={0.7} material="orange" />
        </>
      )}
    </IsoScene>
  )
}

const rnd = (i: number) => { const x = Math.sin(i * 12.9898) * 43758.5453; return x - Math.floor(x) }

function Field() {
  const N = 7
  const cells: { x: number; y: number; h: number; m: Material }[] = []
  for (let x = 0; x < N; x++) for (let y = 0; y < N; y++) {
    const r = rnd(x * 31 + y * 7 + 3)
    const hot = (x === 4 && y === 4)
    cells.push({ x: x - N / 2, y: y - N / 2, h: hot ? 1.6 : 0.4 + Math.round(r * 2) * 0.15, m: hot ? 'orange' : r > 0.45 ? 'lilac' : 'inkLight' })
  }
  cells.sort((a, b) => a.x + a.y - (b.x + b.y) || a.x - b.x)
  return (
    <IsoScene width={600} height={440} unit={40} anchor={[0.5, 0.5]} title="A field of cubes that reads as hexagons">
      {(ctx) => <>{cells.map((c, i) => <IsoBlock key={i} ctx={ctx} x={c.x + 0.04} y={c.y + 0.04} z={0} w={0.92} d={0.92} h={c.h} material={c.m} />)}</>}
    </IsoScene>
  )
}

function Pyramid() {
  const layers: Material[] = ['stripeOrange', 'lilac', 'orange', 'lilac', 'orange']
  return (
    <IsoScene width={520} height={400} unit={40} anchor={[0.5, 0.64]} title="A stepped pyramid">
      {(ctx) => <>{layers.map((m, i) => {
        const s = 5 - i
        return <IsoBlock key={i} ctx={ctx} x={-s / 2} y={-s / 2} z={i * 0.5} w={s} d={s} h={0.5} material={m} />
      })}</>}
    </IsoScene>
  )
}

function Keycaps() {
  const [down, setDown] = useState<Record<string, boolean>>({})
  useEffect(() => {
    const set = (e: KeyboardEvent) => setDown({ shift: e.shiftKey, meta: e.metaKey, ctrl: e.ctrlKey })
    const dn = set, up = set
    window.addEventListener('keydown', dn); window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', dn); window.removeEventListener('keyup', up) }
  }, [])
  const anyDown = down.shift || down.meta || down.ctrl
  return (
    <IsoScene width={760} height={420} unit={130} anchor={[0.5, 0.5]} title="Keycaps for Shift, Command and Control">
      {(ctx) => (
        <>
          <IsoBlock ctx={ctx} x={-1.85} y={-0.35} z={-0.25} w={3.7} d={1.7} h={0.25} material="ink" />
          <IsoKeycap ctx={ctx} x={-1.7} y={-0.15} legend="⇧" sub="convert" material="cream" pressed={anyDown ? down.shift : true} />
          <IsoKeycap ctx={ctx} x={-0.5} y={-0.15} legend="⌘" sub="tools" material="lilac" pressed={!!down.meta} />
          <IsoKeycap ctx={ctx} x={0.7} y={-0.15} legend="⌃" sub="actions" material="inkLight" ink={C.cream} pressed={!!down.ctrl} />
        </>
      )}
    </IsoScene>
  )
}

export function IsoSystem() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const gapMV = useTransform(scrollYProgress, [0.15, 0.55], [0.02, 0.5])
  const [gap, setGap] = useState(isShot || reduce ? 0.45 : 0.02)
  useMotionValueEvent(gapMV, 'change', (v) => { if (!isShot && !reduce) setGap(v) })

  return (
    <Section id="iso" num="06" title="Isometric" accent=" system." intro="Our signature. Everything with depth is drawn on one true 30° grid, from a handful of materials, lit the same way every time.">
      <Sub n="6.1">Grid and unit</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.cream} fg={C.ink} label="Fig. 2 · grid, axes, unit" className="grid place-items-center px-4 pb-4 pt-12 md:col-span-7">
          <div className="w-full max-w-[560px]"><GridUnit /></div>
        </Tile>
        <Tile bg={C.ink2} className="flex flex-col justify-between gap-6 p-6 md:col-span-5">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] text-[#8A8790]">The rules</span>
          <ul className="flex flex-col divide-y divide-[#2A2A30]">
            {[
              ['Angle', 'True isometric. Axes at 30°, no perspective.'],
              ['Unit', '1u = 40px at 1×. Sizes in ½u, heights in ¼u.'],
              ['Light', 'From the top-left. Top lightest, left mid, right darkest.'],
              ['Edges', 'No outlines on colour. Hairlines only on diagrams.'],
              ['Order', 'Draw back to front: lower x + y, then lower z.'],
            ].map(([k, v]) => (
              <li key={k} className="grid grid-cols-[80px_1fr] gap-3 py-3 text-[14px] leading-[1.4]"><span className="bk-mono text-[11px] uppercase text-[#FF6B1A]">{k}</span><span className="text-[#F4F1EC]/80">{v}</span></li>
            ))}
          </ul>
        </Tile>
      </div>
      <Caption label="One grid for everything">
        The mark, the illustrations, the keycaps and the charts all sit on the same lattice, so any two drawings can share a page and still
        line up.
      </Caption>

      <Sub n="6.2">Materials</Sub>
      <Tile bg={C.ink2} className="grid grid-cols-2 gap-y-4 p-4 sm:grid-cols-5 md:p-6">
        {MATS.map(({ m, n }) => {
          const f = MATERIALS[m]
          return (
            <div key={m} className="flex flex-col items-center gap-1">
              <div className="w-[96px]"><Cube m={m} /></div>
              <span className="text-[14px] font-[580]">{n}</span>
              <span className="bk-mono text-center text-[10px] leading-[1.4] text-[#8A8790]">{f.top.startsWith('stripe') ? 'stripes in plane' : `${f.top} ${f.left} ${f.right}`}</span>
            </div>
          )
        })}
      </Tile>
      <Caption label="Solid and striped">
        Each solid material is three flat values: a lit top, the base colour on the left, a shade on the right. Stripe materials are drawn
        in each face's plane so they turn the corner. No gradients, no textures beyond stripes.
      </Caption>

      <Sub n="6.3">Building a stack</Sub>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 md:grid-cols-4">
        <BuildStep n="01" title="Slab" note="Start with a wide, low base. Stripes go here, if anywhere.">
          {(ctx) => <IsoBlock ctx={ctx} x={-2} y={-2} z={0} w={4} d={4} h={0.5} material="stripePink" />}
        </BuildStep>
        <BuildStep n="02" title="Step in" note="Each layer steps in by ½u on every side.">
          {(ctx) => <><IsoBlock ctx={ctx} x={-2} y={-2} z={0} w={4} d={4} h={0.5} material="stripePink" /><IsoBlock ctx={ctx} x={-1.5} y={-1.5} z={0.5} w={3} d={3} h={0.5} material="lilac" /></>}
        </BuildStep>
        <BuildStep n="03" title="Stack" note="Alternate materials. Three layers is plenty.">
          {(ctx) => <><IsoBlock ctx={ctx} x={-2} y={-2} z={0} w={4} d={4} h={0.5} material="stripePink" /><IsoBlock ctx={ctx} x={-1.5} y={-1.5} z={0.5} w={3} d={3} h={0.5} material="lilac" /><MarkCubes ctx={ctx} x={-1} y={-1} z={1} rest="inkLight" hot="inkLight" lift={0} /></>}
        </BuildStep>
        <BuildStep n="04" title="Lift one" note="One block per scene rises and turns orange.">
          {(ctx) => <><IsoBlock ctx={ctx} x={-2} y={-2} z={0} w={4} d={4} h={0.5} material="stripePink" /><IsoBlock ctx={ctx} x={-1.5} y={-1.5} z={0.5} w={3} d={3} h={0.5} material="lilac" /><MarkCubes ctx={ctx} x={-1} y={-1} z={1} rest="inkLight" hot="orange" lift={0.9} /></>}
        </BuildStep>
      </div>
      <Caption label="Slab, step, stack, lift">
        Every illustration is the same recipe. The lift is the brand: in any scene, exactly one block is raised and lit.
      </Caption>

      <Sub n="6.4">Examples</Sub>
      <div ref={ref} className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.lilac} fg={C.ink} className="relative flex min-h-[560px] flex-col md:col-span-6 md:row-span-2 md:min-h-[760px]">
          <div className="flex items-start justify-between p-5 md:p-7">
            <div>
              <span className="mb-3 block h-2 w-12 bg-[#FF6B1A]" />
              <div className="bk-display text-[40px] font-[650] leading-[.9] md:text-[52px]">Field<br />Notes</div>
            </div>
            <span className="bk-mono text-right text-[11px] uppercase leading-[1.5]">anyfmt<br />Vol. 01</span>
          </div>
          <div className="my-auto px-2 pb-10 md:px-6"><SurveyStack gap={gap} /></div>
          <span className="bk-mono absolute bottom-4 right-5 text-[11px] uppercase opacity-60">Scroll to pull it apart</span>
        </Tile>
        <Tile bg={C.wine} label="Stairs" fg={C.cream} className="grid min-h-[360px] place-items-end px-2 pb-4 pt-12 md:col-span-6">
          <div className="w-full max-w-[560px] justify-self-center"><Stairs /></div>
        </Tile>
        <Tile bg={C.ink} label="Hexagon field" fg={C.cream} className="relative grid min-h-[380px] place-items-center px-2 pb-4 pt-12 ring-1 ring-inset ring-[#2A2A30] md:col-span-6">
          <div className="bkb-dots absolute inset-0 opacity-60" />
          <div className="relative w-full max-w-[600px]"><Field /></div>
          <div className="absolute bottom-4 right-4 max-w-[210px] rounded-[6px] bg-[#F4F1EC] p-3 text-[#0E0E10] shadow-[4px_4px_0_#FF6B1A]">
            <div className="bk-display text-[22px] font-[650] leading-none">26 tools.</div>
            <div className="mt-1 text-[13px] leading-[1.3]">One wheel. The one you aim at rises.</div>
          </div>
        </Tile>
        <Tile bg={C.ink2} label="Stepped pyramid" fg={C.cream} className="grid min-h-[340px] place-items-center px-2 pb-4 pt-12 md:col-span-6">
          <div className="w-full max-w-[520px]"><Pyramid /></div>
        </Tile>
        <Tile bg={C.cream} fg={C.ink} label="Cover detail" className="relative min-h-[340px] overflow-hidden md:col-span-6">
          <div className="absolute -bottom-10 -right-16 w-[520px]">
            <IsoScene width={520} height={380} unit={70} anchor={[0.5, 0.6]}>
              {(ctx) => <MarkCubes ctx={ctx} x={-1} y={-1} z={0} s={1.4} rest="stripeLilac" hot="orange" lift={0.9} />}
            </IsoScene>
          </div>
          <p className="bk-display absolute left-5 top-14 max-w-[9ch] text-[44px] font-[650] leading-[.9]">Crop it, <span className="text-[#FF6B1A]">big.</span></p>
        </Tile>
      </div>
      <Caption label="Field notes, stairs, fields">
        The stack reads top to bottom like the app: drag it, press it, drop it. Stairs carry a file block upward. The field is a grid of
        equal choices with one raised. Crop scenes hard when you need drama; the grid makes any crop look deliberate.
      </Caption>

      <Sub n="6.5">Keycaps</Sub>
      <Tile bg={C.orange} fg={C.ink} label="Try it: hold ⇧, ⌘ or ⌃" className="grid min-h-[360px] place-items-center px-2 pb-6 pt-14">
        <div className="w-full max-w-[760px]"><Keycaps /></div>
      </Tile>
      <Caption label="Keys are blocks too">
        Keycaps are a 0.18u ink plinth with a cap on top, legend on the lid. A pressed key drops to 0.28u. Use them wherever we name a
        shortcut big; inline, use the mono tag instead.
      </Caption>
    </Section>
  )
}
