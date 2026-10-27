/** Small shared pieces: the wordmark, section eyebrows, keycaps, copy buttons. */
import { AnimatePresence, motion } from 'motion/react'
import { useState, type ReactNode } from 'react'
import { copyText, EASE } from '../lib/hooks'

export function Logo({ className = '', tone = 'ink' }: { className?: string; tone?: 'ink' | 'white' }) {
  return (
    <span className={`font-wordmark text-[32px] font-bold leading-none tracking-[-0.04em] ${tone === 'ink' ? 'text-ink' : 'text-white'} ${className}`}>
      anyfmt<span className="text-flare">.</span>
    </span>
  )
}

/** The square-dot label that opens every section. */
export function Eyebrow({ children, tone = 'ink', className = '' }: { children: ReactNode; tone?: 'ink' | 'white' | 'flare'; className?: string }) {
  const dot = tone === 'white' ? 'bg-white' : tone === 'flare' ? 'bg-flare' : 'bg-ink'
  return (
    <p className={`flex items-center gap-3 text-[16px] sm:text-[18px] ${tone === 'white' ? 'text-white' : 'text-ink'} ${className}`}>
      <span className={`h-2.5 w-2.5 shrink-0 ${dot}`} />{children}
    </p>
  )
}

export function Container({ children, className = '', wide = false }: { children: ReactNode; className?: string; wide?: boolean }) {
  return <div className={`mx-auto w-full ${wide ? 'max-w-[1600px]' : 'max-w-[1440px]'} px-5 sm:px-10 lg:px-14 ${className}`}>{children}</div>
}

export function Kbd({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <kbd className={`inline-flex min-w-[1.6em] items-center justify-center rounded-md bg-white px-1.5 py-0.5 font-sans text-[0.8em] font-semibold text-ink shadow-[0_1.5px_0_rgba(0,0,0,.14)] ring-1 ring-black/10 ${className}`}>{children}</kbd>
}

/** A keycap with real travel, for the three trigger keys. */
export function Keycap({ glyph, name, pressed = false, size = 'md' }: { glyph: string; name?: string; pressed?: boolean; size?: 'sm' | 'md' | 'lg' }) {
  const box = size === 'lg' ? 'h-[140px] w-[200px] rounded-[22px] p-5' : size === 'md' ? 'h-[84px] w-[110px] rounded-[16px] p-3.5' : 'h-[44px] min-w-[52px] rounded-[10px] px-2.5 py-1.5'
  const g = size === 'lg' ? 'text-[40px]' : size === 'md' ? 'text-[26px]' : 'text-[17px]'
  return (
    <span className={`inline-flex flex-col justify-between bg-[#FBFAF8] ring-1 ring-black/5 transition-[transform,box-shadow] duration-200 ${box} ${pressed ? 'translate-y-[4px] shadow-[0_1px_0_#D9D4CE,0_2px_6px_rgba(0,0,0,.06)]' : 'shadow-[0_5px_0_#D9D4CE,0_14px_26px_-12px_rgba(0,0,0,.18)]'}`}>
      <span className={`${g} leading-none`}>{glyph}</span>
      {name && <span className={`${size === 'sm' ? 'text-[10px]' : 'text-[13px]'} font-medium text-mute`}>{name}</span>}
    </span>
  )
}

/** A copy button whose label rolls to a confirmation. */
export function CopyButton({ text, label = 'Copy', done = 'Copied', className = '', tone = 'light', onCopied }: { text: string | (() => string); label?: string; done?: string; className?: string; tone?: 'light' | 'dark'; onCopied?: () => void }) {
  const [ok, setOk] = useState<null | boolean>(null)
  const run = async () => {
    const res = await copyText(typeof text === 'function' ? text() : text)
    setOk(res)
    if (res) onCopied?.()
    window.setTimeout(() => setOk(null), 1800)
  }
  const skin = tone === 'light' ? 'bg-white text-ink ring-black/10 hover:bg-sand-2' : 'bg-white/10 text-white ring-white/15 hover:bg-white/15'
  return (
    <button type="button" onClick={run} aria-live="polite"
      className={`relative inline-flex h-8 items-center gap-1.5 overflow-hidden rounded-full px-3 text-[13px] font-medium ring-1 outline-none transition-colors duration-300 focus-visible:ring-2 focus-visible:ring-flare ${skin} ${className}`}>
      <svg width="13" height="13" viewBox="0 0 14 14" aria-hidden>
        {ok ? <path d="M3 7.5 6 10.5 11.5 4" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
          : <><rect x="4.5" y="4.5" width="7" height="7.5" rx="1.6" fill="none" stroke="currentColor" strokeWidth="1.4" /><path d="M9.5 4.5V3.2c0-.9-.7-1.6-1.6-1.6H3.6C2.7 1.6 2 2.3 2 3.2v4.3c0 .9.7 1.6 1.6 1.6h.9" fill="none" stroke="currentColor" strokeWidth="1.4" /></>}
      </svg>
      <span className="relative grid">
        <AnimatePresence mode="popLayout" initial={false}>
          <motion.span key={String(ok)} initial={{ y: 14, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -14, opacity: 0 }} transition={{ duration: 0.3, ease: EASE }} className="whitespace-nowrap">
            {ok === null ? label : ok ? done : 'Select and copy'}
          </motion.span>
        </AnimatePresence>
      </span>
    </button>
  )
}

/** A one-line shell command with a prompt glyph and a copy button. */
export function Command({ cmd, tone = 'dark', className = '' }: { cmd: string; tone?: 'dark' | 'light'; className?: string }) {
  const dark = tone === 'dark'
  return (
    <div className={`flex min-w-0 items-center gap-3 rounded-2xl py-2 pl-4 pr-2 ${dark ? 'bg-night text-white' : 'bg-white text-ink ring-1 ring-black/10'} ${className}`}>
      <span aria-hidden className="font-mono text-[13px] text-flare">$</span>
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-[13px] no-scrollbar">{cmd}</code>
      <CopyButton text={cmd} tone={dark ? 'dark' : 'light'} />
    </div>
  )
}

/** Format label chip in the app's style: uppercase, tight, tinted by kind. */
export const KIND_TINT: Record<string, string> = {
  image: '#FF8A2A', vector: '#FFB23E', pdf: '#EE1200', video: '#FF4A14', audio: '#E8213A', document: '#0A0A0A',
  slides: '#C2410C', spreadsheet: '#3F6212', ebook: '#7C2D12', subtitle: '#525252', archive: '#78716C', folder: '#A8A29E',
}
export function FormatChip({ label, kind, size = 'md' }: { label: string; kind: string; size?: 'sm' | 'md' | 'lg' }) {
  const s = size === 'lg' ? 'px-3 py-1.5 text-[18px] rounded-[10px]' : size === 'md' ? 'px-2 py-1 text-[12px] rounded-[7px]' : 'px-1.5 py-0.5 text-[10.5px] rounded-[5px]'
  return <span className={`inline-flex items-center font-semibold uppercase tracking-wide text-white ${s}`} style={{ background: KIND_TINT[kind] ?? '#0A0A0A' }}>{label}</span>
}
