import { motion } from 'motion/react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'

const GO: [string, string][] = [['Home', '/'], ['Formats', '/formats'], ['Docs', '/docs'], ['Pricing', '/pricing'], ['Download', '/download'], ['Changelog', '/changelog']]

/** A page that doesn't exist, offered a wheel of pages that do. */
export default function NotFound() {
  useHead({ title: 'Page not found', description: 'That page does not exist.', path: '/404', noindex: true })
  const R0 = 70, R1 = 180, n = GO.length
  return (
    <Page>
      <section className="relative overflow-hidden bg-sand px-5 pb-28 pt-40 sm:px-10">
        <div className="mx-auto grid max-w-[1200px] items-center gap-14 lg:grid-cols-2">
          <div>
            <p className="font-mono text-[14px] text-mute-2">404 · unsupported_route</p>
            <h1 className="mt-5 text-[clamp(44px,6vw,92px)] font-semibold leading-[0.97] tracking-[-0.05em] [text-wrap:balance]">This page doesn't convert.</h1>
            <p className="mt-6 max-w-[440px] text-[18px] leading-[1.5] text-mute">There's no route from this URL to anything we have. Drop it on one of these instead.</p>
          </div>
          <motion.svg viewBox={`${-R1 - 10} ${-R1 - 10} ${R1 * 2 + 20} ${R1 * 2 + 20}`} className="mx-auto w-full max-w-[420px]" initial={{ rotate: -20, scale: 0.8, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }} transition={{ duration: 1, ease: EASE }}>
            {GO.map(([l, to], i) => {
              const gap = 0.03, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
              const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(1)},${(Math.sin(a) * r).toFixed(1)}`
              const mid = (a0 + a1) / 2
              return (
                <Link key={to} to={to} className="group outline-none">
                  <path d={`M${p(R1, a0)} A${R1},${R1} 0 0 1 ${p(R1, a1)} L${p(R0, a1)} A${R0},${R0} 0 0 0 ${p(R0, a0)} Z`} className="fill-white transition-[fill] duration-200 group-hover:fill-flare group-focus-visible:fill-flare" />
                  <text x={Math.cos(mid) * 125} y={Math.sin(mid) * 125} textAnchor="middle" dominantBaseline="central" className="fill-ink text-[17px] font-semibold transition-[fill] group-hover:fill-white group-focus-visible:fill-white">{l}</text>
                </Link>
              )
            })}
            <circle r={R0 - 8} fill="#0A0A0A" />
            <text y="5" textAnchor="middle" className="fill-white text-[15px] font-semibold">404</text>
          </motion.svg>
        </div>
      </section>
    </Page>
  )
}
