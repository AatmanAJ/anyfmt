import { motion } from 'motion/react'
import { ArrowRight, Download } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../shared/cn'

export const HEROES = [
  { n: 1, slug: 'glass', name: 'Glass', from: 'Glass Headline Hero', by: 'kedhareswer' },
  { n: 2, slug: 'morph', name: 'Morph', from: 'Scroll Morph Hero', by: 'prashantsom75' },
  { n: 3, slug: 'aurora', name: 'Aurora', from: 'Aurora Hero', by: 'bevelui' },
  { n: 4, slug: 'shutter', name: 'Shutter', from: 'Hero Shutter Text', by: 'daiwiikharihar' },
  { n: 5, slug: 'orbit', name: 'Orbit', from: 'Cinematic Orbit Hero', by: 'daiwiikharihar' },
] as const

export const COPY = {
  eyebrow: 'Free and open source · for macOS',
  body: 'Drag a file, tap Shift, and drop it on the format you want. anyfmt converts, edits and shares files mid-drag, right on your Mac.',
}

/** The mark at small size: a ring of eight wedges with one lifted out. */
export function Glyph({ size = 18 }: { size?: number }) {
  const N = 8
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
      {Array.from({ length: N }, (_, i) => {
        const a0 = (i / N) * Math.PI * 2 - Math.PI / N + 0.09, a1 = a0 + (Math.PI * 2) / N - 0.18
        const lift = i === 1 ? 1.6 : 0, mid = (a0 + a1) / 2
        const dx = lift * Math.sin(mid), dy = -lift * Math.cos(mid)
        const p = (r: number, a: number) => `${(12 + dx + r * Math.sin(a)).toFixed(2)},${(12 + dy - r * Math.cos(a)).toFixed(2)}`
        return <path key={i} d={`M${p(10.5, a0)} A10.5,10.5 0 0 1 ${p(10.5, a1)} L${p(5.5, a1)} A5.5,5.5 0 0 0 ${p(5.5, a0)} Z`} fill="currentColor" opacity={i === 1 ? 1 : 0.85} />
      })}
    </svg>
  )
}

export function Nav({ tone }: { tone: 'light' | 'dark' }) {
  const dark = tone === 'dark'
  return (
    <header className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center px-4 pt-4 sm:px-6">
      <nav className={cn('pointer-events-auto flex h-12 w-full max-w-[1200px] items-center justify-between', dark ? 'text-white' : 'text-[#111]')}>
        <a href="#" className="flex items-center gap-2 text-[17px] font-semibold tracking-[-0.03em]"><Glyph />anyfmt</a>
        <div className={cn('hidden items-center gap-7 text-[14px] md:flex', dark ? 'text-white/70' : 'text-black/60')}>
          {['How it works', 'Formats', 'Agents', 'Pricing'].map((l) => (
            <a key={l} href="#" onClick={(e) => e.preventDefault()} className={cn('transition-colors', dark ? 'hover:text-white' : 'hover:text-black')}>{l}</a>
          ))}
        </div>
        <Pill tone={tone} small><Download size={15} />Download</Pill>
      </nav>
    </header>
  )
}

export function Pill({ children, tone, variant = 'solid', small }: { children: ReactNode; tone: 'light' | 'dark'; variant?: 'solid' | 'ghost'; small?: boolean }) {
  const dark = tone === 'dark'
  const solid = dark ? 'bg-white text-black hover:bg-white/90' : 'bg-[#111] text-white hover:bg-black'
  const ghost = dark ? 'text-white ring-1 ring-white/25 hover:bg-white/10' : 'text-[#111] ring-1 ring-black/15 hover:bg-black/5'
  return (
    <motion.button type="button" whileTap={{ scale: 0.97 }}
      className={cn('group inline-flex items-center gap-2 rounded-full font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2',
        small ? 'h-9 px-4 text-[13.5px]' : 'h-12 px-6 text-[15px]', variant === 'solid' ? solid : ghost)}>
      {children}
      {variant === 'solid' && !small && <ArrowRight size={16} className="transition-transform group-hover:translate-x-0.5" />}
    </motion.button>
  )
}

export function Ctas({ tone }: { tone: 'light' | 'dark' }) {
  return (
    <div className="flex flex-wrap items-center justify-center gap-3">
      <Pill tone={tone}><Download size={17} />Download for Mac</Pill>
      <Pill tone={tone} variant="ghost">See how it works</Pill>
    </div>
  )
}

/** Floating switcher for comparing the five heroes. */
export function Switcher({ current }: { current: number }) {
  return (
    <div className="fixed inset-x-0 bottom-4 z-[60] flex justify-center px-3">
      <div className="flex max-w-full items-center gap-1 overflow-x-auto rounded-full bg-[rgba(17,17,17,.82)] p-1 text-[12.5px] text-white/70 shadow-[0_12px_40px_-10px_rgba(0,0,0,.5)] ring-1 ring-white/10 backdrop-blur-xl [scrollbar-width:none]">
        <Link to="/heroes" className="shrink-0 rounded-full px-3 py-1.5 hover:text-white">All</Link>
        {HEROES.map((h) => (
          <Link key={h.n} to={`/heroes/${h.n}`} className={cn('relative shrink-0 rounded-full px-3 py-1.5 transition-colors hover:text-white', current === h.n && 'text-black')}>
            {current === h.n && <motion.span layoutId="hero-switch" className="absolute inset-0 rounded-full bg-white" transition={{ type: 'spring', stiffness: 500, damping: 36 }} />}
            <span className="relative"><span className="font-mono opacity-60">{h.n}</span> {h.name}</span>
          </Link>
        ))}
      </div>
    </div>
  )
}
