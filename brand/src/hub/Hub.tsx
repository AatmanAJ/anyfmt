import { motion } from 'motion/react'
import { ArrowUpRight } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { directions } from '../directions/registry'
import type { DirectionMeta } from '../directions/types'
import { Wheel } from '../shared/Wheel'
import { Reveal, WordsReveal } from '../shared/kit'
import { product } from '../shared/product'

const segs = product.formatsVideo.map((f) => ({ id: f, label: f }))

function DirectionCard({ d, i }: { d: DirectionMeta; i: number }) {
  const [hover, setHover] = useState(false)
  return (
    <Reveal delay={i * 0.06}>
      <Link to={`/d/${d.id}`} onPointerEnter={() => setHover(true)} onPointerLeave={() => setHover(false)}
        className="group relative grid overflow-hidden rounded-[28px] ring-1 ring-white/10 transition-transform duration-500 hover:-translate-y-1 md:grid-cols-[1.1fr_1fr]"
        style={{ background: d.card.bg, color: d.card.fg }}>
        <div className="flex flex-col justify-between gap-10 p-7 md:p-10">
          <div className="flex items-center justify-between font-mono text-[11px] uppercase tracking-[0.18em] opacity-60">
            <span>Direction {String(i + 1).padStart(2, '0')}</span>
            <span className="hidden sm:inline">{d.lineage}</span>
          </div>
          <div>
            <h2 className="text-[64px] leading-[0.9] md:text-[96px]" style={{ fontFamily: d.displayFamily }}>{d.name}</h2>
            <p className="mt-4 max-w-md text-[15px] leading-relaxed opacity-75">{d.tagline}</p>
          </div>
          <div className="flex flex-wrap items-end justify-between gap-6">
            <div className="flex gap-1.5">
              {d.palette.map((p) => (
                <div key={p.hex} className="flex flex-col gap-1.5">
                  <span className="block h-10 w-10 rounded-[10px] ring-1 ring-black/10 md:h-12 md:w-12" style={{ background: p.hex }} />
                  <span className="font-mono text-[9px] opacity-50">{p.hex}</span>
                </div>
              ))}
            </div>
            <div className="text-right text-[12px] opacity-60">{d.fonts.display} / {d.fonts.text}</div>
          </div>
        </div>
        <div className="relative flex min-h-[340px] items-center justify-center overflow-hidden">
          <div className="absolute inset-0 opacity-40" style={{ background: `radial-gradient(circle at 50% 50%, ${d.card.accent}55, transparent 60%)` }} />
          <motion.div animate={{ rotate: hover ? 0 : -6, scale: hover ? 1.04 : 1 }} transition={{ type: 'spring', stiffness: 200, damping: 20 }}>
            <Wheel segments={segs} skin={d.skin} size={300} hubLabel={<span className="text-[11px] font-semibold">MOV</span>} />
          </motion.div>
          <span className="absolute right-6 top-6 flex size-11 items-center justify-center rounded-full transition-transform duration-300 group-hover:rotate-45"
                style={{ background: d.card.accent, color: d.card.bg }}>
            <ArrowUpRight size={20} />
          </span>
        </div>
      </Link>
    </Reveal>
  )
}

export function Hub() {
  return (
    <div className="min-h-screen bg-[#0A0A0B] font-geist text-[#EDEDEA] selection:bg-white selection:text-black">
      <div className="pointer-events-none fixed inset-0 opacity-[0.035] [background-image:url('data:image/svg+xml;utf8,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%22160%22 height=%22160%22><filter id=%22n%22><feTurbulence baseFrequency=%22.8%22/></filter><rect width=%22100%%22 height=%22100%%22 filter=%22url(%23n)%22/></svg>')]" />
      <header className="mx-auto max-w-[1240px] px-4 pb-16 pt-20 sm:px-6 md:pt-28">
        <div className="mb-10 flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.2em] text-white/50">
          <span className="size-1.5 animate-pulse rounded-full bg-[#D7FF3A]" /> anyfmt · Brand exploration · 5 directions
        </div>
        <h1 className="max-w-5xl font-serif text-[56px] leading-[0.95] tracking-[-0.01em] sm:text-[88px] md:text-[120px]">
          <WordsReveal text="One wheel." /><br />
          <span className="italic text-white/55"><WordsReveal text="Five ways to wear it." delay={0.15} /></span>
        </h1>
        <Reveal delay={0.3}>
          <p className="mt-8 max-w-xl text-[17px] leading-relaxed text-white/60">
            {product.how} Each direction below is a complete system: mark, palette, type, voice, a full landing page,
            onboarding, and the app’s own surfaces. Pick one, or point at the parts you like.
          </p>
        </Reveal>
      </header>

      <main className="mx-auto flex max-w-[1240px] flex-col gap-5 px-4 pb-32 sm:px-6">
        {directions.map((d, i) => <DirectionCard key={d.id} d={d} i={i} />)}

        <Reveal>
          <section className="mt-16 grid gap-10 rounded-[28px] border border-white/10 p-7 md:grid-cols-[1fr_2fr] md:p-10">
            <div>
              <h3 className="font-serif text-[40px] leading-none">What never changes</h3>
              <p className="mt-3 text-[14px] text-white/50">The look changes per direction. These facts don’t.</p>
            </div>
            <dl className="grid gap-x-8 gap-y-6 sm:grid-cols-2">
              {product.stats.map((s) => (
                <div key={s.label} className="border-t border-white/10 pt-4">
                  <dt className="font-serif text-[44px] leading-none">{s.value}</dt>
                  <dd className="mt-2 text-[13px] text-white/55">{s.label}</dd>
                </div>
              ))}
              {product.keys.map((k) => (
                <div key={k.key} className="border-t border-white/10 pt-4">
                  <dt className="text-[28px] leading-none">{k.key} <span className="font-serif text-[30px]">{k.wheel}</span></dt>
                  <dd className="mt-2 text-[13px] text-white/55">{k.blurb}</dd>
                </div>
              ))}
              <div className="border-t border-white/10 pt-4">
                <dt className="font-serif text-[30px] leading-none">Free, local</dt>
                <dd className="mt-2 text-[13px] text-white/55">{product.licence}</dd>
              </div>
            </dl>
          </section>
        </Reveal>
      </main>
    </div>
  )
}
