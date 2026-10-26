import { useMotionValueEvent, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { useRef, useState } from 'react'
import { IsoBlock, IsoScene } from '../Iso'
import { isShot } from '../../shared/kit'
import { MarkCubes } from './isoBits'
import { C, Caption, FitText, Tile } from './ui'

function CoverStack({ lift }: { lift: number }) {
  return (
    <IsoScene width={560} height={520} unit={58} anchor={[0.5, 0.6]} title="A stepped stack of blocks topped by the anyfmt mark">
      {(ctx) => (
        <>
          <IsoBlock ctx={ctx} x={-2.6} y={-2.6} z={-1.6} w={5.2} d={5.2} h={0.55} material="ink" />
          <IsoBlock ctx={ctx} x={-2.1} y={-2.1} z={-1.05} w={4.2} d={4.2} h={0.55} material="stripePink" />
          <IsoBlock ctx={ctx} x={-1.6} y={-1.6} z={-0.5} w={3.2} d={3.2} h={0.5} material="lilac" />
          <MarkCubes ctx={ctx} x={-1.05} y={-1.05} z={0} s={1.05} rest="ink" hot="cream" lift={lift} />
        </>
      )}
    </IsoScene>
  )
}

export function Cover() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const liftMV = useTransform(scrollYProgress, [0, 0.7], [0.9, 1.9])
  const [lift, setLift] = useState(0.9)
  useMotionValueEvent(liftMV, 'change', (v) => { if (!reduce && !isShot) setLift(v) })

  return (
    <section id="cover" data-sec="cover">
      <div ref={ref}>
        <Tile bg={C.orange} fg={C.ink} className="flex min-h-[640px] flex-col md:min-h-[min(880px,94vh)]">
          <div className="bk-mono flex items-start justify-between gap-4 p-5 text-[11px] uppercase tracking-[.08em] md:p-7 md:text-[12px]">
            <span>anyfmt<br />Brand book</span>
            <span className="hidden text-center md:block">Block edition<br />v1.0 · 2026</span>
            <span className="text-right">11 chapters<br />CSS + SVG only</span>
          </div>

          <div className="grid flex-1 items-center gap-2 px-5 md:grid-cols-12 md:px-7">
            <div className="order-2 md:order-1 md:col-span-5">
              <p className="bk-display max-w-[15ch] text-[30px] font-[600] leading-[1.02] md:text-[44px]">
                Convert, edit and share any file <span className="text-[#F4F1EC]">in the middle of a drag.</span>
              </p>
              <div className="mt-6 flex flex-wrap gap-2">
                {[['⇧', 'Convert'], ['⌘', 'Tools'], ['⌃', 'Actions']].map(([k, l]) => (
                  <span key={k} className="bk-tag" style={{ background: C.ink, color: C.cream }}><b className="text-[14px] text-[#FF6B1A]">{k}</b>{l}</span>
                ))}
              </div>
            </div>
            <div className="order-1 flex justify-center md:order-2 md:col-span-7">
              <div className="w-full max-w-[560px]"><CoverStack lift={lift} /></div>
            </div>
          </div>

          <FitText className="bk-display px-3 font-[680] leading-[.74] md:px-5" style={{ marginBottom: '-0.02em' }}>
            <span className="block pb-[0.06em]">anyfmt</span>
          </FitText>
        </Tile>
      </div>

      <div className="mt-2 grid gap-2 md:grid-cols-3">
        <Tile bg={C.ink2} className="flex min-h-[180px] flex-col justify-between p-5">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] text-[#8A8790]">The idea</span>
          <p className="bk-display text-[28px] font-[620] leading-[1]">Drag a file. Press a key. <span className="text-[#FF6B1A]">Drop it where it should go.</span></p>
        </Tile>
        <Tile bg={C.lilac} fg={C.ink} className="flex min-h-[180px] flex-col justify-between p-5">
          <span className="bk-mono text-[11px] uppercase tracking-[.08em] opacity-70">The system</span>
          <p className="bk-display text-[28px] font-[620] leading-[1]">Flat colour, isometric depth, one block that rises.</p>
        </Tile>
        <Tile bg="" className="bk-stripe-pink min-h-[180px]">
          <div className="absolute bottom-4 left-4 rounded-[4px] bg-[#0E0E10] px-3 py-2">
            <span className="bk-mono text-[11px] uppercase tracking-[.08em] text-[#FF4FA0]">Material 03 · pink on wine</span>
          </div>
        </Tile>
      </div>
      <Caption label="A brand made of blocks">
        anyfmt is a menu-bar app that turns any file into another one while you're still dragging it. The identity is built the same
        way the app works: a grid of equal choices, and one that rises when you aim at it. Everything here is flat colour and
        isometric blocks, set in Funnel Display, with small mono labels doing the explaining.
      </Caption>
    </section>
  )
}
