/**
 * Docs search: ⌘K (or /) anywhere in the docs. Searches titles, headings and text; arrow keys
 * and Enter to jump straight to the section.
 */
import { ArrowElbowDownLeft, FileText, Hash, MagnifyingGlass } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { DOC, search, type Hit } from '../../lib/docs'
import { EASE } from '../../lib/hooks'
import { Kbd } from '../ui'

const QUICK = ['install', 'first-conversion', 'cli', 'mcp', 'api', 'troubleshooting']

function snippet(h: Hit, q: string) {
  const w = q.trim().split(/\s+/)[0]?.toLowerCase() ?? ''
  const at = Math.max(0, h.text.toLowerCase().indexOf(w))
  const start = Math.max(0, at - 40)
  const s = (start ? '…' : '') + h.text.slice(start, start + 140) + (h.text.length > start + 140 ? '…' : '')
  if (!w) return s
  const i = s.toLowerCase().indexOf(w)
  if (i < 0) return s
  return <>{s.slice(0, i)}<mark className="rounded bg-volt px-0.5 text-ink">{s.slice(i, i + w.length)}</mark>{s.slice(i + w.length)}</>
}

export function useSearchHotkey(setOpen: (o: boolean) => void) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      const typing = /^(INPUT|TEXTAREA|SELECT)$/.test((e.target as HTMLElement)?.tagName ?? '')
      if ((e.key === 'k' && (e.metaKey || e.ctrlKey)) || (e.key === '/' && !typing)) { e.preventDefault(); setOpen(true) }
    }
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [setOpen])
}

export function SearchPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [q, setQ] = useState('')
  const [sel, setSel] = useState(0)
  const input = useRef<HTMLInputElement>(null)
  const nav = useNavigate()
  const hits = useMemo(() => search(q), [q])
  const quick = QUICK.map((s) => DOC[s]).filter(Boolean)
  const count = q ? hits.length : quick.length

  useEffect(() => { if (open) { setQ(''); setSel(0); window.setTimeout(() => input.current?.focus(), 30) } }, [open])
  useEffect(() => setSel(0), [q])

  const go = (i: number) => {
    if (q) { const h = hits[i]; if (h) nav(h.doc.path + (h.heading ? `#${h.heading.id}` : '')) }
    else { const d = quick[i]; if (d) nav(d.path) }
    onClose()
  }
  const key = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setSel((s) => Math.min(count - 1, s + 1)) }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setSel((s) => Math.max(0, s - 1)) }
    else if (e.key === 'Enter') { e.preventDefault(); go(sel) }
    else if (e.key === 'Escape') onClose()
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div className="fixed inset-0 z-[60] flex items-start justify-center px-3 pt-[10svh]" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} role="dialog" aria-modal="true" aria-label="Search the docs">
          <button type="button" aria-label="Close search" onClick={onClose} className="absolute inset-0 bg-ink/40" />
          <motion.div initial={{ y: -12, scale: 0.98 }} animate={{ y: 0, scale: 1 }} exit={{ y: -8, scale: 0.98 }} transition={{ duration: 0.28, ease: EASE }}
            className="relative w-full max-w-[640px] overflow-hidden rounded-[24px] bg-white shadow-[0_40px_100px_-30px_rgba(0,0,0,.5)]">
            <div className="flex items-center gap-3 border-b border-line px-5">
              <MagnifyingGlass size={20} className="text-mute-2" aria-hidden />
              <input ref={input} value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={key} placeholder="Search the docs" aria-label="Search the docs"
                role="combobox" aria-expanded="true" aria-controls="docs-results" aria-activedescendant={`r-${sel}`}
                className="h-16 min-w-0 flex-1 bg-transparent text-[18px] outline-none placeholder:text-mute-2" />
              <button type="button" onClick={onClose} className="rounded-md bg-sand-2 px-2 py-1 text-[12px] font-medium text-mute outline-none focus-visible:ring-2 focus-visible:ring-flare">esc</button>
            </div>
            <ul id="docs-results" role="listbox" className="max-h-[56svh] overflow-y-auto p-2">
              {!q && <li className="px-3 pb-1 pt-2 text-[13px] font-semibold text-mute-2">Start here</li>}
              {(q ? hits : quick).map((item, i) => {
                const h = q ? (item as Hit) : null
                const d = h ? h.doc : (item as (typeof quick)[number])
                return (
                  <li key={(h ? h.doc.slug + (h.heading?.id ?? '') : d.slug)} id={`r-${i}`} role="option" aria-selected={sel === i}>
                    <button type="button" tabIndex={-1} onMouseEnter={() => setSel(i)} onClick={() => go(i)}
                      className={`flex w-full items-start gap-3 rounded-[14px] px-3 py-3 text-left transition-colors ${sel === i ? 'bg-sand' : ''}`}>
                      <span className={`mt-[3px] shrink-0 ${sel === i ? 'text-ink' : 'text-mute-2'}`}>{h?.heading ? <Hash size={16} aria-hidden /> : <FileText size={16} aria-hidden />}</span>
                      <span className="min-w-0 flex-1">
                        <span className="block text-[15.5px] font-medium">{d.title}{h?.heading && <span className="text-mute-2"> › {h.heading.text}</span>}</span>
                        <span className="mt-0.5 line-clamp-2 text-[14px] leading-[1.45] text-mute">{h ? snippet(h, q) : d.description}</span>
                      </span>
                      {sel === i && <ArrowElbowDownLeft size={16} className="mt-1 shrink-0 text-mute-2" aria-hidden />}
                    </button>
                  </li>
                )
              })}
              {q && hits.length === 0 && <li className="px-4 py-10 text-center text-[15px] text-mute">Nothing matches “{q}”. Try a format, a command or a key.</li>}
            </ul>
            <div className="hidden items-center gap-5 border-t border-line px-5 py-3 text-[13px] text-mute-2 sm:flex">
              <span className="flex items-center gap-1.5"><Kbd>↑</Kbd><Kbd>↓</Kbd> to move</span>
              <span className="flex items-center gap-1.5"><Kbd>↵</Kbd> to open</span>
              <span className="flex items-center gap-1.5"><Kbd>esc</Kbd> to close</span>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
