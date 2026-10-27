/**
 * Call-to-action buttons. Starting points on 21st.dev: Arrow Fill Button (hyperiux), Download
 * Button (bidyut10) and Star On Github (socolled); rebuilt for anyfmt. Every one is a real link.
 */
import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { SNAP } from '../lib/hooks'
import { AppleMark, GitHubMark } from './Marks'

/** Letters that roll up and are replaced by a copy from below, staggered. */
export function RollText({ children, className = '' }: { children: string; className?: string }) {
  return (
    <span className={`relative inline-flex overflow-hidden ${className}`} aria-label={children}>
      {[...children].map((ch, i) => (
        <span key={i} aria-hidden className="roll-ch relative inline-block" style={{ transitionDelay: `${i * 18}ms` }}>
          <span className="block">{ch === ' ' ? '\u00a0' : ch}</span>
          <span className="absolute left-0 top-full block">{ch === ' ' ? '\u00a0' : ch}</span>
        </span>
      ))}
    </span>
  )
}

/** The arrow that leaves up-right while a new one arrives from bottom-left. */
export function SwapArrow({ size = 14, dir = 'ne' }: { size?: number; dir?: 'ne' | 'e' | 's' }) {
  const path = dir === 'ne' ? 'M3.5 10.5l7-7M5 3.5h5.5V9' : dir === 'e' ? 'M2 7h10M8 3l4 4-4 4' : 'M7 2v10M3 8l4 4 4-4'
  const away = dir === 'ne' ? 'group-hover:translate-x-5 group-hover:-translate-y-5' : dir === 'e' ? 'group-hover:translate-x-5' : 'group-hover:translate-y-5'
  const back = dir === 'ne' ? '-translate-x-5 translate-y-5' : dir === 'e' ? '-translate-x-5' : '-translate-y-5'
  return (
    <>
      {[0, 1].map((k) => (
        <svg key={k} width={size} height={size} viewBox="0 0 14 14" aria-hidden
          className={`absolute transition-transform duration-500 ${k === 0 ? away : `${back} group-hover:translate-x-0 group-hover:translate-y-0`}`}
          style={{ transitionTimingFunction: SNAP }}>
          <path d={path} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      ))}
    </>
  )
}

const isExternal = (to: string) => /^https?:|^mailto:/.test(to)

export function SmartLink({ to, className, children, ...rest }: { to: string; className?: string; children: ReactNode } & Omit<React.AnchorHTMLAttributes<HTMLAnchorElement>, 'href'>) {
  if (isExternal(to)) return <a href={to} target="_blank" rel="noreferrer" className={className} {...rest}>{children}</a>
  return <Link to={to} className={className} {...rest}>{children}</Link>
}

/** White pill with a letter roll and the swapping arrow. */
export function PillLink({ to, children, tone = 'light', className = '' }: { to: string; children: string; tone?: 'light' | 'dark' | 'volt'; className?: string }) {
  const skin = tone === 'light' ? 'bg-white text-ink ring-black/5' : tone === 'dark' ? 'bg-ink text-white ring-white/10' : 'bg-volt text-ink ring-black/5'
  const dot = tone === 'dark' ? 'bg-white text-ink' : 'bg-ink text-white'
  return (
    <SmartLink to={to}
      className={`group inline-flex h-12 items-center gap-3 rounded-full pl-6 pr-2 text-[15px] font-medium shadow-[0_1px_0_rgba(0,0,0,.04),0_8px_24px_-8px_rgba(0,0,0,.18)] outline-none ring-1 transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare ${skin} ${className}`}>
      <RollText>{children}</RollText>
      <span className={`relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full ${dot}`}><SwapArrow /></span>
    </SmartLink>
  )
}

/** The big download pill: lime floods out of the arrow on hover. Goes to the download page. */
export function DownloadButton({ tone = 'dark', label = 'Download for Mac', to = '/download' }: { tone?: 'dark' | 'light'; label?: string; to?: string }) {
  const dark = tone === 'dark'
  return (
    <SmartLink to={to}
      className={`group relative inline-flex h-14 items-center overflow-hidden rounded-full pl-6 pr-2 text-base font-medium outline-none transition-[transform,background-color] duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-offset-2 ${dark ? 'bg-ink text-white focus-visible:ring-ink' : 'bg-white text-ink focus-visible:ring-white focus-visible:ring-offset-ink'} hover:bg-volt hover:delay-[0ms,250ms]`}>
      <span aria-hidden className="pointer-events-none absolute inset-0 rounded-full bg-volt transition-[clip-path] duration-500 [clip-path:circle(20px_at_calc(100%-28px)_50%)] group-hover:[clip-path:circle(150%_at_calc(100%-28px)_50%)]"
        style={{ transitionTimingFunction: SNAP }} />
      <span className="relative flex items-center gap-2.5 pr-4 transition-colors duration-500 group-hover:text-ink" style={{ transitionTimingFunction: SNAP }}>
        <AppleMark size={18} className="-mt-0.5" />
        <span className="whitespace-nowrap">{label}</span>
      </span>
      <span className="relative flex h-10 w-10 items-center justify-center rounded-full text-ink">
        <span className="relative flex h-5 w-5 items-center justify-center overflow-hidden"><SwapArrow size={16} dir="s" /></span>
      </span>
    </SmartLink>
  )
}

/** Glass pill with a conic streak border on hover. */
export function GitHubButton({ label = 'Read the source', to = '/open-source', tone = 'light' }: { label?: string; to?: string; tone?: 'light' | 'dark' }) {
  return (
    <SmartLink to={to}
      className={`gh group relative inline-flex h-12 items-center rounded-full p-[1.5px] text-[15px] font-medium outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare ${tone === 'light' ? 'text-ink' : 'gh-dark text-white'}`}>
      <span aria-hidden className="gh-ring pointer-events-none absolute inset-0 rounded-full" />
      <span className={`relative flex h-full items-center gap-2.5 rounded-full px-4 backdrop-blur-xl ${tone === 'light' ? 'bg-white/85' : 'bg-ink/85'}`}>
        <GitHubMark size={18} />
        <RollText>{label}</RollText>
      </span>
    </SmartLink>
  )
}

/** Lime announcement pill with a sheen pass and a nudging arrow. */
export function Badge({ children, to }: { children: ReactNode; to: string }) {
  return (
    <SmartLink to={to}
      className="badge group relative inline-flex h-10 items-center gap-2 overflow-hidden rounded-full bg-volt px-4 text-[15px] font-medium text-ink outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-ink">
      <span aria-hidden className="badge-sheen pointer-events-none absolute inset-y-0 -left-1/2 w-1/3 skew-x-[-20deg] bg-white/70" />
      <span className="relative whitespace-nowrap">{children}</span>
      <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden className="relative transition-transform duration-500 group-hover:translate-x-1" style={{ transitionTimingFunction: SNAP }}>
        <path d="M2.5 8h10M8.5 3.5 13 8l-4.5 4.5" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </SmartLink>
  )
}

/** Text link with an arrow that swaps on hover. */
export function ArrowLink({ to, children, className = '' }: { to: string; children: ReactNode; className?: string }) {
  return (
    <SmartLink to={to} className={`group inline-flex items-center gap-2 font-medium outline-none focus-visible:ring-2 focus-visible:ring-flare ${className}`}>
      <span className="link-line">{children}</span>
      <span className="relative flex h-4 w-4 items-center justify-center overflow-hidden"><SwapArrow size={13} dir="e" /></span>
    </SmartLink>
  )
}
