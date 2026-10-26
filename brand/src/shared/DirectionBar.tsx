import { motion } from 'motion/react'
import { Link } from 'react-router-dom'
import { directions } from '../directions/registry'
import { cn } from './cn'

/** Floating switcher on every direction page: hub, the five directions, book vs landing. */
export function DirectionBar({ id, view }: { id: string; view: 'book' | 'landing' }) {
  if (new URLSearchParams(location.search).has('clean') || new URLSearchParams(location.search).has('shot')) return null
  return (
    <motion.nav
      initial={{ y: 40, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.6, type: 'spring', stiffness: 260, damping: 24 }}
      className="fixed bottom-4 left-1/2 z-[100] flex max-w-[calc(100vw-24px)] -translate-x-1/2 items-center gap-1 overflow-x-auto rounded-full border border-white/10 bg-neutral-950/80 p-1 font-geist text-[12px] text-white/70 shadow-[0_20px_50px_-10px_rgba(0,0,0,.6)] backdrop-blur-xl no-scrollbar"
      aria-label="Directions">
      <Link to="/" className="shrink-0 rounded-full px-3 py-1.5 hover:bg-white/10 hover:text-white">All</Link>
      <span className="mx-0.5 h-4 w-px shrink-0 bg-white/15" />
      {directions.map((d) => (
        <Link key={d.id} to={view === 'book' ? `/d/${d.id}` : `/d/${d.id}/landing`}
          className={cn('flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 hover:bg-white/10 hover:text-white', d.id === id && 'bg-white text-neutral-950 hover:bg-white hover:text-neutral-950')}>
          <span className="size-2 rounded-full" style={{ background: d.palette[0].hex }} />{d.name}
        </Link>
      ))}
      <span className="mx-0.5 h-4 w-px shrink-0 bg-white/15" />
      <Link to={`/d/${id}`} className={cn('shrink-0 rounded-full px-3 py-1.5 hover:text-white', view === 'book' && 'text-white underline underline-offset-4')}>Book</Link>
      <Link to={`/d/${id}/landing`} className={cn('shrink-0 rounded-full px-3 py-1.5 hover:text-white', view === 'landing' && 'text-white underline underline-offset-4')}>Landing</Link>
    </motion.nav>
  )
}
