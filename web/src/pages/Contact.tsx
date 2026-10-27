/**
 * Contact, as a wheel. Drag the note onto a segment (or just pick one) and the right address
 * opens with what to include. Same gesture as the app, aimed at a person.
 */
import { AnimatePresence, motion } from 'motion/react'
import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow } from '../components/ui'
import { EASE } from '../lib/hooks'
import { useHead } from '../lib/head'
import { SITE } from '../lib/site'

const CHANNELS = [
  { id: 'support', label: 'Help', to: SITE.email.support, title: 'Something isn\'t working', include: ['What you dragged (the file type and roughly its size)', 'Which segment or tool you dropped it on', 'What you expected, and what happened', 'The output of `anyfmt doctor`, if you use the CLI'], first: { to: '/docs/troubleshooting', label: 'Troubleshooting covers the common ones' } },
  { id: 'teams', label: 'Teams', to: SITE.email.sales, title: 'Seats for a team', include: ['How many people', 'Whether you need shared links on your own domain', 'Whether you would rather self-host'], first: { to: '/pricing', label: 'See plans first' } },
  { id: 'press', label: 'Press', to: SITE.email.press, title: 'Writing about anyfmt', include: ['Your publication and deadline', 'Whether you need a review build'], first: { to: '/brand', label: 'Logos, screenshots and copy' } },
  { id: 'security', label: 'Security', to: SITE.email.security, title: 'A security problem', include: ['What you found and how to reproduce it', 'Which version', 'How you would like to be credited'], first: null },
  { id: 'bugs', label: 'Bugs', to: SITE.email.support, title: 'A route gave a bad file', include: ['The route, for example HEIC → PDF', 'A sample file if you can share one', 'Your macOS version'], first: { to: '/formats', label: 'Check the route exists' } },
  { id: 'hello', label: 'Hello', to: SITE.email.hello, title: 'Just saying hi', include: ['Anything. Ideas for formats are especially welcome.'], first: null },
] as const

const R0 = 58, R1 = 168

function wedge(i: number, n: number) {
  const gap = 0.03, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(1)},${(Math.sin(a) * r).toFixed(1)}`
  return { d: `M${p(R1, a0)} A${R1},${R1} 0 0 1 ${p(R1, a1)} L${p(R0, a1)} A${R0},${R0} 0 0 0 ${p(R0, a0)} Z`, mid: (a0 + a1) / 2 }
}

function ContactWheel({ sel, setSel }: { sel: number; setSel: (i: number) => void }) {
  const svg = useRef<SVGSVGElement>(null)
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null)
  const [aim, setAim] = useState(-1)
  const n = CHANNELS.length
  const local = (e: React.PointerEvent) => {
    const r = svg.current!.getBoundingClientRect()
    const s = (R1 + 20) * 2 / r.width
    return { x: (e.clientX - r.left) * s - (R1 + 20), y: (e.clientY - r.top) * s - (R1 + 20) }
  }
  const segAt = (x: number, y: number) => {
    const d = Math.hypot(x, y)
    if (d < R0 || d > R1 + 30) return -1
    const a = Math.atan2(y, x) + Math.PI / 2 + Math.PI / n
    return Math.floor((((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)) / ((Math.PI * 2) / n))
  }
  return (
    <div className="relative mx-auto w-full max-w-[460px] select-none [touch-action:none]">
      <svg ref={svg} viewBox={`${-R1 - 20} ${-R1 - 20} ${(R1 + 20) * 2} ${(R1 + 20) * 2}`} className="w-full"
        onPointerMove={(e) => { if (!drag) return; const p = local(e); setDrag(p); setAim(segAt(p.x, p.y)) }}
        onPointerUp={() => { if (drag && aim >= 0) setSel(aim); setDrag(null); setAim(-1) }}
        onPointerCancel={() => { setDrag(null); setAim(-1) }}>
        <defs><linearGradient id="c-heat" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stopColor="#E8160C" /><stop offset="0.6" stopColor="#FF4A14" /><stop offset="1" stopColor="#FF9A3C" /></linearGradient></defs>
        {CHANNELS.map((c, i) => {
          const { d, mid } = wedge(i, n)
          const on = aim === i || (aim < 0 && sel === i)
          return (
            <g key={c.id} role="button" tabIndex={0} aria-pressed={sel === i} aria-label={c.title} onClick={() => setSel(i)} onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); setSel(i) } }} className="cursor-pointer outline-none [&:focus-visible>path]:stroke-ink [&:focus-visible>path]:stroke-[3]">
              <path d={d} fill={on ? 'url(#c-heat)' : '#FFFFFF'} stroke="rgba(10,10,10,.08)" style={{ transition: 'fill .2s' }} />
              <text x={Math.cos(mid) * ((R0 + R1) / 2)} y={Math.sin(mid) * ((R0 + R1) / 2)} textAnchor="middle" dominantBaseline="central" fontSize="17" fontWeight="600" fill={on ? '#fff' : '#0A0A0A'} style={{ pointerEvents: 'none' }}>{c.label}</text>
            </g>
          )
        })}
        <circle r={R0 - 7} fill="#0A0A0A" />
        {!drag && (
          <g onPointerDown={(e) => { e.preventDefault(); try { svg.current?.setPointerCapture(e.pointerId) } catch { /* capture is optional */ } setDrag(local(e)) }} className="cursor-grab" role="presentation">
            <rect x={-20} y={-25} width={40} height={50} rx={6} fill="#fff" />
            <rect x={-12} y={-14} width={20} height={3} rx={1.5} fill="#E1DDD8" /><rect x={-12} y={-7} width={24} height={3} rx={1.5} fill="#E1DDD8" /><rect x={-12} y={0} width={16} height={3} rx={1.5} fill="#E1DDD8" />
            <rect x={-12} y={10} width={24} height={9} rx={2.5} fill="#FF4A14" /><text y={14.8} textAnchor="middle" fontSize="6.5" fontWeight="700" fill="#fff" dominantBaseline="central">TXT</text>
          </g>
        )}
        {drag && (
          <g transform={`translate(${drag.x} ${drag.y}) rotate(-8)`} style={{ pointerEvents: 'none' }}>
            <rect x={-20} y={-25} width={40} height={50} rx={6} fill="#fff" stroke="rgba(0,0,0,.12)" />
            <rect x={-12} y={10} width={24} height={9} rx={2.5} fill="#FF4A14" /><text y={14.8} textAnchor="middle" fontSize="6.5" fontWeight="700" fill="#fff" dominantBaseline="central">TXT</text>
          </g>
        )}
      </svg>
      <p className="mt-4 text-center text-[13.5px] text-mute-2">Drag the note onto a segment, or pick one.</p>
    </div>
  )
}

export default function Contact() {
  const [sel, setSel] = useState(0)
  const c = CHANNELS[sel]
  useHead({ title: 'Contact', description: 'Reach the people who make anyfmt: help, team seats, press, security reports and bugs, each with its own address.', path: '/contact' })
  return (
    <Page>
      <section className="bg-sand pb-24 pt-36 lg:pb-32 lg:pt-44">
        <Container>
          <Eyebrow>Contact</Eyebrow>
          <h1 className="mt-6 max-w-[900px] text-[clamp(44px,6.4vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em]">Drop us a line.</h1>
          <div className="mt-16 grid items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
            <ContactWheel sel={sel} setSel={setSel} />
            <AnimatePresence mode="wait">
              <motion.div key={c.id} initial={{ opacity: 0, y: 14, filter: 'blur(6px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.45, ease: EASE }}
                className="rounded-[28px] bg-white p-7 ring-1 ring-black/5 sm:p-9" aria-live="polite">
                <p className="text-[13px] font-semibold uppercase tracking-[0.14em] text-flare">{c.label}</p>
                <h2 className="mt-3 text-[clamp(28px,3vw,40px)] font-semibold leading-[1.05] tracking-[-0.04em]">{c.title}</h2>
                <div className="mt-6 flex flex-wrap items-center gap-3 rounded-[18px] bg-sand p-3 pl-5">
                  <span className="min-w-0 flex-1 break-all font-mono text-[16px] font-medium">{c.to}</span>
                  <CopyButton text={c.to} label="Copy address" />
                </div>
                <p className="mt-7 text-[13px] font-semibold uppercase tracking-[0.12em] text-mute-2">Worth including</p>
                <ul className="mt-3 space-y-2">
                  {c.include.map((t) => <li key={t} className="flex gap-3 text-[16px] leading-[1.5]"><span className="mt-2.5 h-1.5 w-1.5 shrink-0 bg-ink" />{t.split(/(`[^`]+`)/).map((p, i) => p.startsWith('`') ? <code key={i} className="rounded bg-sand-2 px-1 font-mono text-[0.9em]">{p.slice(1, -1)}</code> : p)}</li>)}
                </ul>
                {c.first && <p className="mt-7 text-[15px] text-mute">Before you write: <Link to={c.first.to} className="font-medium text-ink underline decoration-flare/60 underline-offset-4">{c.first.label}</Link>.</p>}
                {c.id === 'security' && <p className="mt-7 text-[15px] leading-[1.55] text-mute">Please don't open a public issue for security problems. We'll confirm receipt and keep you updated until it's fixed.</p>}
              </motion.div>
            </AnimatePresence>
          </div>
        </Container>
      </section>
      <section className="bg-white py-20">
        <Container className="grid gap-6 md:grid-cols-3">
          {[['We read everything', 'A person reads every message. Replies usually take a couple of days.'], ['No ticket numbers', 'Just email. Reply to the thread to add anything.'], ['In public, later', 'When the repository opens, bugs and ideas can go to GitHub issues too.']].map(([t, d]) => (
            <div key={t} className="rounded-[22px] bg-sand p-6"><p className="text-[18px] font-semibold tracking-[-0.02em]">{t}</p><p className="mt-2 text-[15px] leading-[1.55] text-mute">{d}</p></div>
          ))}
        </Container>
      </section>
    </Page>
  )
}
