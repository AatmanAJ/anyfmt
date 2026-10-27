/**
 * Call-to-action buttons for the Flare page. Starting points on 21st.dev: Arrow Fill Button
 * (hyperiux), Download Button (bidyut10) and Star On Github (socolled); rebuilt for anyfmt.
 */

import { AppleLogo, GithubLogo } from '@phosphor-icons/react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'

const EASE = [0.22, 1, 0.36, 1] as const
const SNAP = 'cubic-bezier(0.785,0.135,0.15,0.86)'

const Apple = ({ size = 16 }: { size?: number }) => <AppleLogo size={size} weight="fill" aria-hidden />
const GitHubMark = ({ size = 18 }: { size?: number }) => <GithubLogo size={size} weight="fill" aria-hidden />

const StarPath = 'M12 2.6l2.83 5.74 6.33.92-4.58 4.47 1.08 6.3L12 17.05l-5.66 2.98 1.08-6.3L2.84 9.26l6.33-.92L12 2.6Z'

/** Letters that roll up and are replaced by a copy from below, staggered. */
export function RollText({ children, className = '' }: { children: string; className?: string }) {
  return (
    <span className={`roll relative inline-flex overflow-hidden ${className}`} aria-label={children}>
      {[...children].map((ch, i) => (
        <span key={i} aria-hidden className="roll-ch relative inline-block" style={{ transitionDelay: `${i * 18}ms` }}>
          <span className="block">{ch === ' ' ? ' ' : ch}</span>
          <span className="absolute left-0 top-full block">{ch === ' ' ? ' ' : ch}</span>
        </span>
      ))}
    </span>
  )
}

/** Nav pill: white, letter roll, arrow leaves up-right and a new one arrives from bottom-left. */
export function NavDownload({ href = '#download', onClick }: { href?: string; onClick?: () => void }) {
  return (
    <a href={href} onClick={(e) => { if (onClick) { e.preventDefault(); onClick() } }}
      className="group inline-flex h-12 items-center gap-3 rounded-full bg-white pl-6 pr-2 text-[15px] font-medium text-[#0A0A0A] shadow-[0_1px_0_rgba(0,0,0,.04),0_8px_24px_-8px_rgba(0,0,0,.18)] outline-none ring-1 ring-black/5 transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black">
      <RollText>Download</RollText>
      <span className="relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-[#0A0A0A] text-white">
        {[0, 1].map((k) => (
          <svg key={k} width="14" height="14" viewBox="0 0 14 14" aria-hidden
            className={`absolute transition-transform duration-500 ${k === 0 ? 'group-hover:translate-x-5 group-hover:-translate-y-5' : '-translate-x-5 translate-y-5 group-hover:translate-x-0 group-hover:translate-y-0'}`}
            style={{ transitionTimingFunction: SNAP }}>
            <path d="M3.5 10.5l7-7M5 3.5h5.5V9" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        ))}
      </span>
    </a>
  )
}

/** Hero download: black pill. Hover floods lime out of the arrow; click runs the honest morph. */
export function DownloadButton({ tone = 'dark', label = 'Download for Mac' }: { tone?: 'dark' | 'light'; label?: string }) {
  const [phase, setPhase] = useState<'idle' | 'busy' | 'done'>('idle')
  const [p, setP] = useState(0)
  const reduce = useReducedMotion()
  const timers = useRef<number[]>([])
  useEffect(() => () => timers.current.forEach(clearTimeout), [])
  const run = () => {
    if (phase !== 'idle') return
    setPhase('busy')
    const start = performance.now(), dur = reduce ? 0 : 1300
    const tick = () => {
      const k = dur ? Math.min(1, (performance.now() - start) / dur) : 1
      setP(1 - (1 - k) ** 2)
      if (k < 1) requestAnimationFrame(tick)
      else { setPhase('done'); timers.current.push(window.setTimeout(() => { setPhase('idle'); setP(0) }, 3200)) }
    }
    requestAnimationFrame(tick)
  }
  const dark = tone === 'dark'
  const base = dark ? 'bg-[#0A0A0A] text-white' : 'bg-white text-[#0A0A0A]'
  const fill = '#E4FF3A'
  const text = phase === 'busy' ? 'Packing anyfmt.dmg' : phase === 'done' ? 'First release lands soon' : label
  return (
    <button type="button" onClick={run} aria-live="polite"
      className={`group relative inline-flex h-14 items-center overflow-hidden rounded-full pl-6 pr-2 text-base font-medium outline-none transition-[transform] duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-offset-2 ${dark ? 'focus-visible:ring-black' : 'focus-visible:ring-white focus-visible:ring-offset-black'} ${base}`}>
      {/* lime flood, grows out of the icon circle */}
      <span aria-hidden className="pointer-events-none absolute inset-0 rounded-full transition-[clip-path] duration-500 [clip-path:circle(20px_at_calc(100%-28px)_50%)] group-hover:[clip-path:circle(150%_at_calc(100%-28px)_50%)]"
        style={{ background: fill, transitionTimingFunction: SNAP }} />
      <span className="relative flex items-center gap-2.5 pr-4 transition-colors duration-500 group-hover:text-[#0A0A0A]" style={{ transitionTimingFunction: SNAP }}>
        <Apple size={18} />
        <span className="relative grid">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span key={text} initial={{ y: 18, opacity: 0, filter: 'blur(4px)' }} animate={{ y: 0, opacity: 1, filter: 'blur(0px)' }} exit={{ y: -18, opacity: 0, filter: 'blur(4px)' }}
              transition={{ duration: 0.45, ease: EASE }} className="whitespace-nowrap">{text}</motion.span>
          </AnimatePresence>
        </span>
      </span>
      <span className="relative flex h-10 w-10 items-center justify-center rounded-full text-[#0A0A0A]">
        {phase === 'idle' && (
          <span className="relative flex h-5 w-5 items-center justify-center overflow-hidden">
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden className="absolute transition-transform duration-500 group-hover:translate-y-5" style={{ transitionTimingFunction: SNAP }}><path d="M8 2.5v10M3.5 8.5 8 13l4.5-4.5" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" /></svg>
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden className="absolute -translate-y-5 transition-transform duration-500 group-hover:translate-y-0" style={{ transitionTimingFunction: SNAP }}><path d="M8 2.5v10M3.5 8.5 8 13l4.5-4.5" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </span>
        )}
        {phase === 'busy' && (
          <svg width="26" height="26" viewBox="0 0 26 26" aria-hidden className="-rotate-90">
            <circle cx="13" cy="13" r="10" fill="none" stroke="rgba(0,0,0,.15)" strokeWidth="2.5" />
            <circle cx="13" cy="13" r="10" fill="none" stroke="#0A0A0A" strokeWidth="2.5" strokeLinecap="round" strokeDasharray={62.8} strokeDashoffset={62.8 * (1 - p)} />
          </svg>
        )}
        {phase === 'done' && (
          <motion.svg initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: 'spring', stiffness: 500, damping: 22 }} width="18" height="18" viewBox="0 0 18 18" aria-hidden>
            <motion.path d="M4 9.5 7.5 13 14 5.5" fill="none" stroke="#0A0A0A" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.4, ease: EASE }} />
          </motion.svg>
        )}
      </span>
    </button>
  )
}

/** Glass pill with a conic streak border on hover; a click bursts the star and rolls the label. */
export function GitHubButton({ compact = false }: { compact?: boolean }) {
  const [starred, setStarred] = useState(false)
  const [burst, setBurst] = useState(0)
  const [tip, setTip] = useState(false)
  const click = () => { setStarred((s) => !s); if (!starred) setBurst((b) => b + 1) }
  return (
    <span className="relative inline-flex" onPointerEnter={() => setTip(true)} onPointerLeave={() => setTip(false)}>
      <button type="button" onClick={click} aria-pressed={starred} onFocus={() => setTip(true)} onBlur={() => setTip(false)}
        className="gh group relative inline-flex h-12 items-center gap-2.5 rounded-full p-[1.5px] text-[15px] font-medium text-[#0A0A0A] outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black">
        <span aria-hidden className="gh-ring pointer-events-none absolute inset-0 rounded-full" />
        <span className="relative flex h-full items-center gap-2.5 rounded-full bg-white/80 px-4 backdrop-blur-xl">
          <GitHubMark size={18} />
          {!compact && (
            <span className="relative grid h-5 overflow-hidden">
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span key={String(starred)} initial={{ y: 20 }} animate={{ y: 0 }} exit={{ y: -20 }} transition={{ duration: 0.4, ease: EASE }} className="whitespace-nowrap leading-5">
                  {starred ? 'Starred, thank you' : 'Star on GitHub'}
                </motion.span>
              </AnimatePresence>
            </span>
          )}
          <span className="relative flex h-6 w-6 items-center justify-center">
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden className="transition-[transform,color] duration-500 group-hover:rotate-[72deg]" style={{ transitionTimingFunction: SNAP, color: starred ? '#FF4A14' : undefined }}>
              <path d={StarPath} fill={starred ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" className="transition-[fill] duration-300 group-hover:fill-[#FFB23E] group-hover:stroke-[#FF6A1F]" />
            </svg>
            <AnimatePresence>
              {burst > 0 && starred && Array.from({ length: 10 }, (_, i) => {
                const a = (i / 10) * Math.PI * 2
                return (
                  <motion.span key={`${burst}-${i}`} aria-hidden className="pointer-events-none absolute h-1.5 w-1.5 rounded-full"
                    style={{ background: i % 2 ? '#FF4A14' : '#FFB23E' }}
                    initial={{ x: 0, y: 0, scale: 1, opacity: 1 }} animate={{ x: Math.cos(a) * 26, y: Math.sin(a) * 26, scale: 0, opacity: 0 }}
                    transition={{ duration: 0.7, ease: EASE }} />
                )
              })}
            </AnimatePresence>
          </span>
        </span>
      </button>
      <AnimatePresence>
        {tip && (
          <motion.span role="tooltip" initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }} transition={{ duration: 0.2, ease: EASE }}
            className="pointer-events-none absolute left-1/2 top-full z-20 mt-2 -translate-x-1/2 whitespace-nowrap rounded-lg bg-[#0A0A0A] px-3 py-1.5 text-xs font-medium text-white">
            The repo goes public with the first release
          </motion.span>
        )}
      </AnimatePresence>
    </span>
  )
}

/** Lime announcement pill with a sheen pass and a nudging arrow. */
export function Badge({ children, onClick }: { children: ReactNode; onClick?: () => void }) {
  return (
    <button type="button" onClick={onClick}
      className="badge group relative inline-flex h-10 items-center gap-2 overflow-hidden rounded-full bg-[#E4FF3A] px-4 text-[15px] font-medium text-[#0A0A0A] outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black">
      <span aria-hidden className="badge-sheen pointer-events-none absolute inset-y-0 -left-1/2 w-1/3 skew-x-[-20deg] bg-white/70" />
      <span className="relative">{children}</span>
      <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden className="relative transition-transform duration-500 group-hover:translate-x-1" style={{ transitionTimingFunction: SNAP }}>
        <path d="M2.5 8h10M8.5 3.5 13 8l-4.5 4.5" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </button>
  )
}

export function ButtonStyles() {
  return (
    <style>{`
      .roll-ch { transition: transform .5s ${SNAP}; }
      .group:hover .roll-ch, .group:focus-visible .roll-ch { transform: translateY(-100%); }
      @property --gh-a { syntax: '<angle>'; inherits: false; initial-value: 0deg; }
      .gh-ring { background: rgba(10,10,10,.12); }
      .gh:hover .gh-ring, .gh:focus-visible .gh-ring {
        background: conic-gradient(from var(--gh-a), #FF2A0E, #FF7A1F, #FFC24A, #FFF1D6, #FF7A1F, #FF2A0E);
        animation: gh-spin 2.4s linear infinite;
      }
      @keyframes gh-spin { to { --gh-a: 360deg; } }
      .badge-sheen { transform: translateX(-120%) skewX(-20deg); }
      .badge:hover .badge-sheen { transition: transform .9s ${SNAP}; transform: translateX(520%) skewX(-20deg); }
      @media (prefers-reduced-motion: reduce) {
        .roll-ch, .group:hover .roll-ch { transform: none; transition: none; }
        .gh:hover .gh-ring { animation: none; }
      }
    `}</style>
  )
}
