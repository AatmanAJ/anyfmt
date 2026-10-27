/**
 * "Copy for AI": one click puts the page on the clipboard as clean Markdown with its source URL,
 * sized in tokens. The menu offers all docs at once, opening the page in Claude or ChatGPT, and
 * the raw .md and llms.txt files.
 */
import { CaretDown, ChatCircleText, ChatsCircle, Check, ClipboardText, FileText, ListBullets, Stack } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { docAsMarkdown, llmsFull, mdUrl, tokensOf, type Doc } from '../../lib/docs'
import { copyText, EASE } from '../../lib/hooks'

const k = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}k` : String(n))

export function CopyForAI({ doc }: { doc: Doc }) {
  const [done, setDone] = useState<null | string>(null)
  const [open, setOpen] = useState(false)
  const box = useRef<HTMLDivElement>(null)
  const page = docAsMarkdown(doc)
  const all = llmsFull()
  const prompt = encodeURIComponent(`Read ${mdUrl(doc)} (anyfmt docs: ${doc.title}) and help me with it.`)

  useEffect(() => {
    if (!open) return
    const out = (e: PointerEvent) => { if (!box.current?.contains(e.target as Node)) setOpen(false) }
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    document.addEventListener('pointerdown', out)
    document.addEventListener('keydown', esc)
    return () => { document.removeEventListener('pointerdown', out); document.removeEventListener('keydown', esc) }
  }, [open])
  useEffect(() => { if (!done) return; const t = window.setTimeout(() => setDone(null), 2200); return () => clearTimeout(t) }, [done])

  const copy = async (text: string, label: string) => { if (await copyText(text)) setDone(label); setOpen(false) }

  return (
    <div ref={box} className="relative inline-flex">
      <div className="flex h-11 items-center rounded-full bg-ink text-white">
          <button type="button" onClick={() => copy(page, `${k(tokensOf(page))} tokens`)} aria-live="polite"
            className="flex h-full items-center gap-2 rounded-l-full pl-4 pr-3 text-[15px] font-medium outline-none transition-colors hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-flare">
            <span className="relative flex h-4 w-4 items-center justify-center">
              <AnimatePresence mode="popLayout" initial={false}>
                {done ? (
                  <motion.span key="ok" initial={{ scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.4, opacity: 0 }} className="text-volt"><Check size={16} weight="bold" /></motion.span>
                ) : (
                  <motion.span key="copy" initial={{ scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.4, opacity: 0 }}><ClipboardText size={17} /></motion.span>
                )}
              </AnimatePresence>
            </span>
            <span className="relative grid overflow-hidden">
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span key={done ?? 'idle'} initial={{ y: 16, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -16, opacity: 0 }} transition={{ duration: 0.3, ease: EASE }} className="whitespace-nowrap">
                  {done ? `Copied · ${done}` : 'Copy for AI'}
                </motion.span>
              </AnimatePresence>
            </span>
          </button>
          <span aria-hidden className="h-5 w-px bg-white/20" />
          <button type="button" aria-haspopup="menu" aria-expanded={open} aria-label="More ways to give this page to an AI" onClick={() => setOpen((o) => !o)}
            className="flex h-full items-center rounded-r-full pl-2.5 pr-3.5 outline-none transition-colors hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-flare">
            <CaretDown size={14} weight="bold" className={`transition-transform duration-300 ${open ? 'rotate-180' : ''}`} />
          </button>
      </div>
      <AnimatePresence>
        {open && (
          <motion.div role="menu" initial={{ opacity: 0, y: -6, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: -6, scale: 0.98 }} transition={{ duration: 0.2, ease: EASE }}
            className="absolute left-0 top-full z-30 mt-2 w-[min(320px,calc(100vw-40px))] origin-top-left rounded-[20px] bg-white p-1.5 shadow-[0_24px_60px_-20px_rgba(0,0,0,.35)] ring-1 ring-black/10">
            <MenuItem icon={<ClipboardText size={18} />} title="Copy this page" sub={`Markdown with its source link · ${k(tokensOf(page))} tokens`} onClick={() => copy(page, `${k(tokensOf(page))} tokens`)} />
            <MenuItem icon={<Stack size={18} />} title="Copy all the docs" sub={`Every page in one paste · ${k(tokensOf(all))} tokens`} onClick={() => copy(all, `${k(tokensOf(all))} tokens`)} />
            <div className="my-1 h-px bg-line" />
            <MenuLink href={`https://claude.ai/new?q=${prompt}`} icon={<ChatsCircle size={18} />} title="Open in Claude" sub="Starts a chat that reads this page" />
            <MenuLink href={`https://chatgpt.com/?q=${prompt}`} icon={<ChatCircleText size={18} />} title="Open in ChatGPT" sub="Same, in ChatGPT" />
            <div className="my-1 h-px bg-line" />
            <MenuLink href={`/docs/${doc.slug}.md`} icon={<FileText size={18} />} title="View as Markdown" sub="The raw file this page is built from" />
            <MenuLink href="/llms.txt" icon={<ListBullets size={18} />} title="llms.txt" sub="The map of every page, for agents" />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

function MenuItem({ icon, title, sub, onClick }: { icon: React.ReactNode; title: string; sub: string; onClick: () => void }) {
  return (
    <button type="button" role="menuitem" onClick={onClick} className="flex w-full items-start gap-3 rounded-[14px] px-3 py-2.5 text-left outline-none transition-colors hover:bg-sand focus-visible:bg-sand focus-visible:ring-2 focus-visible:ring-flare">
      <span className="mt-0.5 shrink-0 text-mute">{icon}</span>
      <span className="min-w-0"><span className="block text-[15px] font-medium">{title}</span><span className="block text-[13px] leading-[1.4] text-mute-2">{sub}</span></span>
    </button>
  )
}

function MenuLink({ href, icon, title, sub }: { href: string; icon: React.ReactNode; title: string; sub: string }) {
  const external = href.startsWith('http')
  return (
    <a role="menuitem" href={href} target={external ? '_blank' : undefined} rel={external ? 'noreferrer' : undefined}
      className="flex w-full items-start gap-3 rounded-[14px] px-3 py-2.5 outline-none transition-colors hover:bg-sand focus-visible:bg-sand focus-visible:ring-2 focus-visible:ring-flare">
      <span className="mt-0.5 shrink-0 text-mute">{icon}</span>
      <span className="min-w-0"><span className="block text-[15px] font-medium">{title}</span><span className="block text-[13px] leading-[1.4] text-mute-2">{sub}</span></span>
    </a>
  )
}
