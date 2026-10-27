/**
 * Contact: every address on the first screen, one row per reason to write. Open a row to see
 * what to put in the message so the first reply can already help.
 */
import { CaretDown } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow } from '../components/ui'
import { EASE } from '../lib/hooks'
import { useHead } from '../lib/head'
import { SITE } from '../lib/site'

type Channel = { id: string; title: string; to: string; include: string[]; first: { to: string; label: string } | null; note?: string }

const CHANNELS: Channel[] = [
  { id: 'support', title: 'Something isn\'t working', to: SITE.email.support, include: ['What you dragged (the file type and roughly its size)', 'Which segment or tool you dropped it on', 'What you expected, and what happened', 'The output of `anyfmt doctor`, if you use the command line'], first: { to: '/docs/troubleshooting', label: 'Troubleshooting covers the common problems' } },
  { id: 'bugs', title: 'A conversion gave a bad file', to: SITE.email.support, include: ['The route, for example HEIC to PDF', 'A sample file, if you can share one', 'Your macOS version'], first: { to: '/formats', label: 'Check the route exists' } },
  { id: 'teams', title: 'Seats for a team', to: SITE.email.sales, include: ['How many people', 'Whether you need share links on your own domain', 'Whether you would rather self-host'], first: { to: '/pricing', label: 'See the plans' } },
  { id: 'press', title: 'Writing about anyfmt', to: SITE.email.press, include: ['Your publication and deadline', 'Whether you need a review build'], first: { to: '/brand', label: 'Logos, screenshots and copy' } },
  { id: 'security', title: 'A security problem', to: SITE.email.security, include: ['What you found and how to reproduce it', 'Which version', 'How you would like to be credited'], first: null, note: 'Please don\'t open a public issue for a security problem. We\'ll confirm we have it and keep you updated until it\'s fixed.' },
  { id: 'hello', title: 'Anything else', to: SITE.email.hello, include: ['Anything at all. Ideas for new formats are especially welcome.'], first: null },
]

/** Text with `code` spans. */
const withCode = (t: string) => t.split(/(`[^`]+`)/).map((p, i) => p.startsWith('`') ? <code key={i} className="whitespace-nowrap rounded-[6px] bg-sand-2 px-1.5 py-0.5 font-mono text-[0.88em]">{p.slice(1, -1)}</code> : p)

function Row({ c, open, onToggle }: { c: Channel; open: boolean; onToggle: () => void }) {
  const panel = `contact-${c.id}`
  return (
    <li className="border-t border-line first:border-t-0">
      <div className="grid gap-x-8 gap-y-3 px-6 py-5 sm:px-8 md:grid-cols-[minmax(0,1fr)_auto] md:items-center">
        <button type="button" aria-expanded={open} aria-controls={panel} onClick={onToggle}
          className="group -mx-2 flex items-center gap-3 rounded-[12px] px-2 py-1 text-left outline-none focus-visible:ring-2 focus-visible:ring-flare">
          <span className="text-[clamp(19px,1.6vw,22px)] font-semibold tracking-[-0.025em]">{c.title}</span>
          <CaretDown size={14} weight="bold" aria-hidden className={`shrink-0 text-mute-2 transition-transform duration-300 group-hover:text-ink ${open ? 'rotate-180' : ''}`} />
        </button>
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
          <a href={`mailto:${c.to}`} className="whitespace-nowrap font-mono text-[15px] font-medium underline decoration-black/20 underline-offset-[5px] outline-none transition-colors hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">{c.to}</a>
          <CopyButton text={c.to} label="Copy" />
        </div>
      </div>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div id={panel} initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.35, ease: EASE }} className="overflow-hidden">
            <div className="grid gap-x-10 gap-y-4 px-6 pb-7 sm:px-8 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
              <div>
                <p className="text-[14px] font-semibold text-mute-2">Worth including</p>
                <ul className="mt-3 space-y-2">
                  {c.include.map((t) => <li key={t} className="flex gap-3 text-[16px] leading-[1.5]"><span className="mt-[9px] h-1.5 w-1.5 shrink-0 bg-ink" /><span>{withCode(t)}</span></li>)}
                </ul>
              </div>
              {(c.first || c.note) && (
                <div className="md:pt-8">
                  {c.first && <p className="text-[15.5px] leading-[1.5] text-mute">Before you write: <Link to={c.first.to} className="font-medium text-ink underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">{c.first.label}</Link>.</p>}
                  {c.note && <p className="text-[15.5px] leading-[1.5] text-mute">{c.note}</p>}
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </li>
  )
}

export default function Contact() {
  const [open, setOpen] = useState('support')
  useHead({ title: 'Contact', description: 'Reach the person who builds anyfmt: help, broken conversions, team seats, press and security reports, each with its own address.', path: '/contact' })
  return (
    <Page>
      <section className="bg-sand pb-24 pt-36 lg:pb-32 lg:pt-44">
        <Container>
          <div className="grid items-end gap-x-12 gap-y-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
            <div>
              <Eyebrow>Contact</Eyebrow>
              <h1 className="mt-6 max-w-[820px] text-[clamp(44px,6.2vw,96px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Write to the person who builds anyfmt.</h1>
            </div>
            <p className="max-w-[440px] text-[17px] leading-[1.55] text-mute lg:pb-2">A person reads every message, and replies usually take a couple of days. Pick the address that fits, and open it to see what to include so the first reply can already help.</p>
          </div>
          <ul className="mt-12 overflow-hidden rounded-[28px] bg-white ring-1 ring-black/[.07] lg:mt-16">
            {CHANNELS.map((c) => <Row key={c.id} c={c} open={open === c.id} onToggle={() => setOpen(open === c.id ? '' : c.id)} />)}
          </ul>
          <dl className="mt-12 grid gap-x-10 gap-y-6 border-t border-line pt-8 md:grid-cols-3">
            {[['No ticket numbers', 'Just email. Reply to the same thread to add anything.'], ['No mailing list', 'Writing to us never signs you up for anything.'], ['In public, later', 'When the repository opens, bugs and ideas can go to GitHub issues too.']].map(([t, d]) => (
              <div key={t}><dt className="text-[17px] font-semibold tracking-[-0.02em]">{t}</dt><dd className="mt-1.5 text-[15px] leading-[1.55] text-mute">{d}</dd></div>
            ))}
          </dl>
        </Container>
      </section>
    </Page>
  )
}
