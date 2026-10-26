import { useState } from 'react'
import { product } from '../../shared/product'
import { Reveal } from '../../shared/kit'
import { BlockWheel } from '../BlockWheel'
import { IsoBlock, IsoKeycap, IsoScene, type Material } from '../Iso'
import { KEYS } from './data'
import { Display, Eyebrow } from './ui'

/* ───────────────────────── Formats marquee ───────────────────────── */

const FORMATS = Array.from(new Set([...product.formatsVideo, ...product.formatsImage]))

export function FormatsMarquee() {
  return (
    <section aria-label="Formats" className="mx-auto max-w-[1440px] px-2">
      <div className="overflow-hidden bg-[var(--bk-orange)] py-5 text-[var(--bk-ink)] sm:py-7">
        <div className="bk-marquee flex w-max items-center" style={{ animationDuration: '46s' }}>
          {[0, 1].map((k) => (
            <div key={k} className="flex shrink-0 items-center" aria-hidden={k === 1}>
              {FORMATS.map((f) => (
                <span key={f} className="flex items-center">
                  <span className="bk-display px-5 font-semibold leading-none tracking-[-0.05em] sm:px-8" style={{ fontSize: 'clamp(54px, 7.4vw, 112px)' }}>{f}</span>
                  <span className="inline-block size-3 rotate-45 bg-[var(--bk-wine-2)] sm:size-4" />
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>
      <div className="mt-2 overflow-hidden bg-[var(--bk-wine)] py-3.5">
        <div className="bk-marquee flex w-max items-center" style={{ animationDuration: '60s', animationDirection: 'reverse' }}>
          {[0, 1].map((k) => (
            <div key={k} className="flex shrink-0 items-center gap-2" aria-hidden={k === 1}>
              {product.conversions.map((c) => {
                const [a, b] = c.split(/ [→←] /)
                const arrow = c.includes('←') ? '←' : '→'
                return (
                  <span key={c} className="bk-mono flex items-center gap-2 px-4 text-[15px] font-medium text-[var(--bk-cream)]">
                    {a}<span className="text-[var(--bk-pink)]">{arrow}</span>{b}
                    <span className="ml-4 inline-block size-1.5 bg-[var(--bk-pink)]/60" />
                  </span>
                )
              })}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Three keys ───────────────────────── */

const LOOK: { panel: string; text: string; cap: Material; legend: string; base: Material; wheelPanel: string; tone: 'dark' | 'light'; hot: 'orange' | 'lilac' | 'pink'; aim: number }[] = [
  { panel: 'var(--bk-orange)', text: 'var(--bk-ink)', cap: 'cream', legend: '#0E0E10', base: 'wine', wheelPanel: 'var(--bk-ink-2)', tone: 'dark', hot: 'orange', aim: 0 },
  { panel: 'var(--bk-lilac)', text: 'var(--bk-ink)', cap: 'ink', legend: '#F4F1EC', base: 'ink', wheelPanel: 'var(--bk-cream)', tone: 'light', hot: 'lilac', aim: 1 },
  { panel: 'var(--bk-wine)', text: 'var(--bk-cream)', cap: 'pink', legend: '#0E0E10', base: 'ink', wheelPanel: 'var(--bk-lilac)', tone: 'dark', hot: 'pink', aim: 0 },
]

function KeyColumn({ i }: { i: number }) {
  const k = KEYS[i], look = LOOK[i]
  const [over, setOver] = useState(false)
  return (
    <div className="grid gap-2" onPointerEnter={() => setOver(true)} onPointerLeave={() => setOver(false)}>
      <div className="relative flex min-h-[300px] flex-col justify-between overflow-hidden p-5 sm:p-7" style={{ background: look.panel, color: look.text }}>
        <div className="flex items-start justify-between">
          <span className="bk-mono text-[11.5px] font-medium uppercase tracking-[0.08em]">0{i + 1} · {k.name}</span>
          <span className="bk-mono text-[11.5px] font-medium uppercase tracking-[0.08em] opacity-70">hold</span>
        </div>
        <div className="mx-auto mt-3 w-[260px]">
          <IsoScene width={260} height={200} unit={104} anchor={[0.5, 0.48]}>
            {(ctx) => (<>
              <IsoBlock ctx={ctx} x={-0.78} y={-0.78} z={-0.14} w={1.56} d={1.56} h={0.14} material={look.base} />
              <IsoKeycap ctx={ctx} x={-0.5} y={-0.5} legend={k.key} sub={k.name.toLowerCase()} material={look.cap} ink={look.legend} pressed={over} />
            </>)}
          </IsoScene>
        </div>
        <div>
          <div className="bk-display text-[52px] font-semibold leading-[0.9] tracking-[-0.05em] sm:text-[60px]">{k.wheel}</div>
          <p className="mt-2 max-w-[300px] text-[16px] leading-snug opacity-80 lg:min-h-[2.75em]">{k.blurb}</p>
        </div>
      </div>
      <div className="grid place-items-center overflow-hidden px-4 py-8" style={{ background: look.wheelPanel }}>
        <BlockWheel size={290} wedges={k.wedges} tone={look.tone} hot={look.hot} active={over ? undefined : look.aim}
          hub={<span className="bk-display text-[26px] font-bold leading-none">{k.key}</span>} />
      </div>
    </div>
  )
}

export function ThreeKeys() {
  return (
    <section id="keys" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="grid gap-2 lg:grid-cols-12">
        <div className="bg-[var(--bk-cream)] px-5 py-10 text-[var(--bk-ink)] sm:px-10 sm:py-14 lg:col-span-12 lg:flex lg:items-end lg:justify-between lg:gap-10">
          <div>
            <Eyebrow n="01" className="mb-6 text-[var(--bk-ink)]">How it works</Eyebrow>
            <Display a="Three keys." b="Every move." className="text-[clamp(52px,8.4vw,128px)] tracking-[-0.06em]" />
          </div>
          <p className="mt-6 max-w-[400px] text-[18px] leading-[1.45] text-[var(--bk-ink)]/75 lg:mt-0">
            Start dragging any file in Finder. Hold one key and its wheel opens around the pointer. Let go over a wedge. That is it.
          </p>
        </div>
      </div>
      <Reveal className="mt-2 grid gap-2 lg:grid-cols-3">
        {[0, 1, 2].map((i) => <KeyColumn key={i} i={i} />)}
      </Reveal>
    </section>
  )
}
