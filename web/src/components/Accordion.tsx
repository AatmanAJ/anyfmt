import { AnimatePresence, motion } from 'motion/react'
import { useState, type ReactNode } from 'react'
import { EASE } from '../lib/hooks'

/** Question rows with a plus that turns into an ember cross. One open at a time. */
export function Accordion({ items, first = 0, tone = 'light' }: { items: [string, ReactNode][]; first?: number; tone?: 'light' | 'sand' }) {
  const [open, setOpen] = useState(first)
  return (
    <ul className="divide-y divide-line border-y border-line">
      {items.map(([q, a], i) => (
        <li key={q}>
          <button type="button" aria-expanded={open === i} onClick={() => setOpen(open === i ? -1 : i)}
            className="group flex w-full items-center justify-between gap-6 py-6 text-left text-[clamp(18px,1.5vw,23px)] font-medium tracking-[-0.02em] outline-none focus-visible:ring-2 focus-visible:ring-ink">
            {q}
            <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition-[background-color,transform] duration-500 ${open === i ? 'rotate-45 bg-flare text-white' : `${tone === 'light' ? 'bg-sand-2' : 'bg-white'} text-ink group-hover:bg-volt`}`}>
              <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden><path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
            </span>
          </button>
          <AnimatePresence initial={false}>
            {open === i && (
              <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.45, ease: EASE }}
                className="max-w-[660px] overflow-hidden text-[17px] leading-[1.6] text-mute"><div className="pb-6">{a}</div></motion.div>
            )}
          </AnimatePresence>
        </li>
      ))}
    </ul>
  )
}
