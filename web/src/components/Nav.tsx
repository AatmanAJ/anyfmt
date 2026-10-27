/**
 * Site navigation. At the top of a page it's a full-width bar over the hero; once you scroll it
 * gathers itself into a floating white pill. The current section carries an ember dot.
 */
import { List, X } from '@phosphor-icons/react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { EASE } from '../lib/hooks'
import { SITE } from '../lib/site'
import { RollText, SwapArrow } from './Buttons'
import { GitHubMark } from './Marks'
import { Logo } from './ui'

export const NAV: [string, string][] = [['Formats', '/formats'], ['Pricing', '/pricing'], ['Docs', '/docs'], ['Changelog', '/changelog'], ['Compare', '/compare']]

/** Links the phone menu adds under the main five, none of them repeated. */
const MORE: [string, string][] = [['Command line', '/docs/cli'], ['MCP for agents', '/docs/mcp'], ['HTTP API', '/docs/api'], ['Guides', '/convert'], ['Open source', '/open-source'], ['Brand', '/brand'], ['Contact', '/contact']]

export function Nav({ tone = 'light' }: { tone?: 'light' | 'dark' }) {
  const { pathname } = useLocation()
  const [pinned, setPinned] = useState(false)
  const [open, setOpen] = useState(false)
  const reduce = useReducedMotion()

  useEffect(() => {
    const on = () => setPinned(window.scrollY > 48)
    on()
    window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])
  useEffect(() => { setOpen(false) }, [pathname])
  useEffect(() => {
    if (!open) return
    const k = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', k)
    document.documentElement.style.overflow = 'hidden'
    return () => { window.removeEventListener('keydown', k); document.documentElement.style.overflow = '' }
  }, [open])

  const light = pinned || tone === 'light'
  const ink = light ? 'text-ink' : 'text-white'
  const active = (to: string) => pathname === to || pathname.startsWith(to + '/')

  return (
    <header className="fixed inset-x-0 top-0 z-40 px-3 pt-[max(12px,env(safe-area-inset-top))] sm:px-5">
      <motion.nav aria-label="Main"
        initial={false}
        animate={pinned
          ? { maxWidth: 1040, paddingLeft: 22, paddingRight: 8, backgroundColor: 'rgba(255,255,255,1)', boxShadow: '0 1px 0 rgba(0,0,0,.04), 0 18px 40px -18px rgba(0,0,0,.28)', borderRadius: 999 }
          : { maxWidth: 1440, paddingLeft: 18, paddingRight: 18, backgroundColor: 'rgba(255,255,255,0)', boxShadow: '0 0 0 rgba(0,0,0,0), 0 0 0 rgba(0,0,0,0)', borderRadius: 999 }}
        transition={reduce ? { duration: 0 } : { duration: 0.6, ease: EASE }}
        className={`mx-auto flex h-16 items-center justify-between gap-4`}>
        <div className="flex min-w-0 items-center gap-10">
          <Link to="/" aria-label="anyfmt home" className="shrink-0 rounded-md outline-none focus-visible:ring-2 focus-visible:ring-flare">
            <Logo tone={light ? 'ink' : 'white'} className={pinned ? 'text-[26px]' : 'text-[30px]'} />
          </Link>
          <ul className="hidden items-center gap-7 lg:flex">
            {NAV.map(([l, to]) => (
              <li key={to} className="relative">
                <Link to={to} aria-current={active(to) ? 'page' : undefined}
                  className={`link-line py-1 text-[15.5px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${ink}`}>{l}</Link>
                {active(to) && <motion.span layoutId="nav-dot" className="absolute -bottom-2.5 left-1/2 h-1.5 w-1.5 -translate-x-1/2 rounded-full bg-flare" transition={{ type: 'spring', stiffness: 500, damping: 34 }} />}
              </li>
            ))}
          </ul>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Link to="/open-source" aria-label="Open source"
            className={`hidden h-11 w-11 items-center justify-center rounded-full outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare sm:flex ${light ? 'text-ink hover:bg-black/5' : 'text-white hover:bg-white/10'}`}>
            <GitHubMark size={20} />
          </Link>
          <Link to="/download"
            className={`group hidden h-11 items-center gap-3 rounded-full pl-5 pr-1.5 text-[15px] font-medium outline-none ring-1 transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare sm:inline-flex ${pinned ? 'bg-ink text-white ring-ink' : light ? 'bg-white text-ink shadow-[0_8px_24px_-8px_rgba(0,0,0,.18)] ring-black/5' : 'bg-white text-ink ring-white/10'}`}>
            <RollText>Download</RollText>
            <span className={`relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full ${pinned ? 'bg-volt text-ink' : 'bg-ink text-white'}`}><SwapArrow /></span>
          </Link>
          <button type="button" onClick={() => setOpen(true)} aria-label="Open menu" aria-expanded={open}
            className={`flex h-11 items-center gap-2 rounded-full px-4 text-[15px] font-medium outline-none focus-visible:ring-2 focus-visible:ring-flare lg:hidden ${light ? 'bg-ink text-white' : 'bg-white text-ink'}`}>
            <List size={18} weight="bold" aria-hidden />Menu
          </button>
        </div>
      </motion.nav>

      <AnimatePresence>
        {open && (
          <motion.div className="fixed inset-0 z-50 lg:hidden" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} role="dialog" aria-modal="true" aria-label="Menu">
            <button type="button" aria-label="Close menu" onClick={() => setOpen(false)} className="absolute inset-0 bg-ink/50 backdrop-blur-[2px]" />
            <motion.div initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }} transition={{ duration: 0.55, ease: [0.32, 0.72, 0, 1] }}
              className="absolute inset-x-2 bottom-2 max-h-[88svh] overflow-y-auto rounded-[30px] bg-white p-6 pb-[max(24px,env(safe-area-inset-bottom))]">
              <div className="flex items-center justify-between">
                <Logo className="text-[28px]" />
                <button type="button" onClick={() => setOpen(false)} className="flex h-10 w-10 items-center justify-center rounded-full bg-sand-2" aria-label="Close menu"><X size={18} weight="bold" /></button>
              </div>
              <ul className="mt-6 flex flex-col">
                {NAV.map(([l, to], i) => (
                  <motion.li key={to} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease: EASE, delay: 0.08 + i * 0.04 }}>
                    <Link to={to} className="flex items-center justify-between rounded-[12px] py-1 text-[32px] font-semibold tracking-[-0.04em] outline-none focus-visible:ring-2 focus-visible:ring-flare">
                      {l}{active(to) && <span className="h-2.5 w-2.5 rounded-full bg-flare" />}
                    </Link>
                  </motion.li>
                ))}
              </ul>
              <Link to="/download" className="mt-6 flex h-14 items-center justify-center gap-2 rounded-full bg-ink text-[16px] font-medium text-white outline-none focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2">
                Download for Mac <span className="text-white/60">· {SITE.dmgSize}</span>
              </Link>
              <ul className="mt-7 grid grid-cols-2 gap-x-4 gap-y-3 border-t border-line pt-6 text-[16px]">
                {MORE.map(([l, to]) => <li key={to}><Link to={to} className="text-mute outline-none hover:text-ink focus-visible:ring-2 focus-visible:ring-flare">{l}</Link></li>)}
              </ul>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  )
}
