import { motion } from 'motion/react'
import { Link } from 'react-router-dom'
import { PillLink } from '../components/Buttons'
import { Page } from '../components/Page'
import { Container } from '../components/ui'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'

const GO: [string, string][] = [['Home', '/'], ['Formats', '/formats'], ['Docs', '/docs'], ['Pricing', '/pricing'], ['Download', '/download'], ['Changelog', '/changelog']]

/** A page that doesn't exist, offered a wheel of pages that do. */
export default function NotFound() {
  useHead({ title: 'Page not found', description: 'That page does not exist.', path: '/404', noindex: true })
  const R0 = 70, R1 = 180, n = GO.length
  return (
    <Page>
      <section className="bg-sand pb-24 pt-36 lg:pb-32 lg:pt-44">
        <Container className="grid items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
          <div>
            <p className="text-[15px] text-mute-2">Error 404</p>
            <h1 className="mt-5 text-[clamp(48px,6.4vw,104px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">This page doesn't convert.</h1>
            <p className="mt-6 max-w-[460px] text-[17px] leading-[1.55] text-mute">There's no route from this address to anything on the site. Pick a page from the wheel, or start again from the home page.</p>
            <div className="mt-8"><PillLink to="/" tone="dark">Back to the home page</PillLink></div>
          </div>
          <nav aria-label="Pages that do exist">
            <motion.svg viewBox={`${-R1 - 10} ${-R1 - 10} ${R1 * 2 + 20} ${R1 * 2 + 20}`} className="mx-auto h-auto w-full max-w-[440px]" initial={{ rotate: -20, scale: 0.85, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }} transition={{ duration: 1, ease: EASE }}>
              {GO.map(([l, to], i) => {
                const gap = 0.03, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
                const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(1)},${(Math.sin(a) * r).toFixed(1)}`
                const mid = (a0 + a1) / 2
                return (
                  <Link key={to} to={to} className="group outline-none">
                    <path d={`M${p(R1, a0)} A${R1},${R1} 0 0 1 ${p(R1, a1)} L${p(R0, a1)} A${R0},${R0} 0 0 0 ${p(R0, a0)} Z`}
                      className="fill-white stroke-black/[.08] transition-[fill] duration-200 group-hover:fill-flare group-focus-visible:fill-flare" />
                    <text x={Math.cos(mid) * 125} y={Math.sin(mid) * 125} textAnchor="middle" dominantBaseline="central" className="pointer-events-none fill-ink text-[17px] font-semibold transition-[fill] group-hover:fill-white group-focus-visible:fill-white">{l}</text>
                  </Link>
                )
              })}
              <circle r={R0 - 8} fill="#0A0A0A" />
              <text y="1" textAnchor="middle" dominantBaseline="central" className="fill-white text-[17px] font-semibold">404</text>
            </motion.svg>
          </nav>
        </Container>
      </section>
    </Page>
  )
}
