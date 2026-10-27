/**
 * Comparisons: a hub that lists every alternative with the one difference that matters, then all
 * the facts in one table; and a page per product with its own centrepiece, one side-by-side
 * table, an honest "choose them if", questions and dated sources.
 */
import { ArrowRight, ArrowUpRight, Check } from '@phosphor-icons/react'
import { motion } from 'motion/react'
import { Link, useParams } from 'react-router-dom'
import { Accordion } from '../components/Accordion'
import { ArrowLink, DownloadButton } from '../components/Buttons'
import { Clicks, Menu, Passthrough, Routes, Session, Terminal, Timeline, Upload } from '../components/compare/Centrepieces'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import { ANYFMT_FACTS, CHECKED, COMPETITOR, COMPETITORS, type Competitor } from '../data/compare'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import NotFound from './NotFound'

type FactKey = keyof Competitor['facts']

/** The standard facts, each with the words that mean a curated row already covers it. */
const FACTS: [FactKey, string, RegExp][] = [
  ['price', 'Price', /price|cost/i],
  ['platforms', 'Runs on', /runs on|platform|windows/i],
  ['processing', 'Where files are converted', /where|upload|offline|server|cloud/i],
  ['source', 'Source code', /source/i],
  ['scope', 'Scope', /route|format|scope/i],
  ['cli', 'Command line', /command line|cli/i],
  ['mcp', 'MCP for agents', /mcp/i],
  ['macos', 'Oldest macOS', /macos/i],
]

function Centre({ c }: { c: Competitor }) {
  switch (c.centrepiece) {
    case 'routes': return <Routes them={c.name} theirs={275} />
    case 'clicks': return <Clicks them={c.name} />
    case 'timeline': return <Timeline them={`${c.name} 4`} from="26" />
    case 'upload': return <Upload />
    case 'session': return <Session them={c.name} />
    case 'passthrough': return <Passthrough />
    case 'terminal': return <Terminal />
    case 'menu': return <Menu />
  }
}

/** One table: the rows written for this pair first, then any standard fact they don't already cover. */
function SideBySide({ c }: { c: Competitor }) {
  const extra = FACTS.filter(([, , re]) => !c.rows.some((r) => re.test(r.label)))
    .map(([k, label]) => ({ label, anyfmt: ANYFMT_FACTS[k], them: c.facts[k] }))
  const rows = [...c.rows, ...extra]
  return (
    <div className="overflow-hidden rounded-[28px] bg-white ring-1 ring-black/[.07]">
      <div className="hidden grid-cols-[minmax(0,0.8fr)_minmax(0,1fr)_minmax(0,1fr)] border-b border-line sm:grid">
        <span className="px-7 py-5" />
        <span className="flex items-center gap-2.5 px-7 py-5 text-[17px] font-semibold tracking-[-0.02em]"><span className="h-2 w-2 bg-flare" />anyfmt</span>
        <span className="px-7 py-5 text-[17px] font-semibold tracking-[-0.02em]">{c.name}</span>
      </div>
      <dl>
        {rows.map((r) => (
          <div key={r.label} className="grid grid-cols-2 border-b border-line last:border-0 sm:grid-cols-[minmax(0,0.8fr)_minmax(0,1fr)_minmax(0,1fr)]">
            <dt className="col-span-2 px-5 pt-4 text-[14px] font-semibold sm:col-span-1 sm:px-7 sm:py-4 sm:text-[15px] sm:font-normal sm:text-mute">{r.label}</dt>
            <dd className="px-5 pb-4 pt-1.5 text-[15px] sm:px-7 sm:py-4">
              <span className="mb-0.5 block text-[12px] font-medium text-mute-2 sm:hidden">anyfmt</span>{r.anyfmt}
            </dd>
            <dd className="px-5 pb-4 pt-1.5 text-[15px] text-mute sm:px-7 sm:py-4">
              <span className="mb-0.5 block text-[12px] font-medium text-mute-2 sm:hidden">{c.name}</span>{r.them}
            </dd>
          </div>
        ))}
      </dl>
    </div>
  )
}

export function ComparePage() {
  const { slug = '' } = useParams()
  const c = COMPETITOR[slug]
  useHead(c ? {
    title: c.title, description: c.description, path: `/compare/${c.slug}`, type: 'article',
    jsonLd: [
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: [[`anyfmt or ${c.name}: which should I use?`, c.answer], ...c.faq].map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
      { '@context': 'https://schema.org', '@type': 'WebPage', name: c.title, description: c.description, dateModified: '2026-10-27', about: [{ '@type': 'SoftwareApplication', name: 'anyfmt' }, { '@type': 'SoftwareApplication', name: c.name, url: c.site }] },
    ],
  } : { title: 'Compare', description: '', path: `/compare/${slug}`, noindex: true })
  if (!c) return <NotFound />
  const others = COMPETITORS.filter((o) => o.slug !== c.slug).slice(0, 4)
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
        <Container className="grid items-start gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
          <div>
            <nav aria-label="Breadcrumb" className="flex items-center gap-3 text-[16px] sm:text-[18px]">
              <span className="h-2.5 w-2.5 shrink-0 bg-ink" />
              <Link to="/compare" className="link-line outline-none focus-visible:ring-2 focus-visible:ring-flare">Compare</Link>
              <span className="text-mute-2">/</span>
              <span className="text-mute-2">{c.name}</span>
            </nav>
            <motion.h1 initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: EASE }}
              className="mt-6 text-[clamp(36px,3.9vw,58px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]">{c.h1}</motion.h1>
            <p className="mt-7 max-w-[600px] text-[17px] leading-[1.6] text-mute">{c.answer}</p>
            <div className="mt-9 flex flex-wrap items-center gap-x-6 gap-y-4">
              <DownloadButton />
              <ArrowLink to="/formats" className="text-[16px]">See every format</ArrowLink>
            </div>
            <p className="mt-8 text-[14px] text-mute-2">{c.name} by {c.maker}. Facts checked {CHECKED}, with sources below.</p>
          </div>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.9, ease: EASE, delay: 0.15 }} className="min-w-0"><Centre c={c} /></motion.div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container>
          <Eyebrow>Side by side</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">anyfmt and {c.name}, line by line.</h2>
          <div className="mt-12"><SideBySide c={c} /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-28">
        <Container>
          <div className="grid gap-5 lg:grid-cols-2">
            <div className="rounded-[28px] bg-white p-8 ring-1 ring-black/[.07] sm:p-10">
              <h2 className="text-[22px] font-semibold tracking-[-0.025em]">Choose {c.name} if</h2>
              <ul className="mt-6 space-y-4">{c.pickThem.map((t) => <li key={t} className="flex gap-3 text-[17px] leading-[1.5]"><Check size={18} weight="bold" aria-hidden className="mt-1 shrink-0" />{t}</li>)}</ul>
            </div>
            <div className="flex flex-col rounded-[28px] bg-night p-8 text-white sm:p-10">
              <h2 className="text-[22px] font-semibold tracking-[-0.025em]">Choose anyfmt if</h2>
              <ul className="mt-6 space-y-4">{c.pickUs.map((t) => <li key={t} className="flex gap-3 text-[17px] leading-[1.5]"><Check size={18} weight="bold" aria-hidden className="mt-1 shrink-0 text-volt" />{t}</li>)}</ul>
              <div className="mt-auto pt-10"><DownloadButton tone="light" /></div>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Questions</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Asked about {c.name}.</h2>
            <div className="mt-12 border-t border-line pt-6">
              <h3 className="text-[15px] font-semibold">Sources, checked {CHECKED}</h3>
              <ul className="mt-4 space-y-2.5">
                {c.sources.map((s) => (
                  <li key={s.url}>
                    <a href={s.url} target="_blank" rel="noreferrer" className="group inline-flex items-center gap-1.5 text-[15px] underline decoration-black/20 underline-offset-4 outline-none transition-[text-decoration-color] hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">
                      {s.label}<ArrowUpRight size={13} aria-hidden className="text-mute-2" />
                    </a>
                  </li>
                ))}
              </ul>
              <p className="mt-5 text-[14px] text-mute">Something here out of date? <Link to="/contact" className="underline decoration-flare/60 underline-offset-2 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">Tell us</Link> and we'll fix it.</p>
            </div>
          </div>
          <Accordion items={c.faq} />
        </Container>
      </section>

      <section className="border-t border-line bg-white py-16 lg:py-20">
        <Container>
          <h2 className="text-[22px] font-semibold tracking-[-0.025em]">More comparisons</h2>
          <ul className="mt-6 grid border-t border-line sm:grid-cols-2 lg:grid-cols-4">
            {others.map((o) => (
              <li key={o.slug} className="border-b border-line">
                <Link to={`/compare/${o.slug}`} className="group flex h-full items-center justify-between gap-4 py-5 pr-2 outline-none focus-visible:ring-2 focus-visible:ring-flare sm:pr-6">
                  <span>
                    <span className="block text-[14px] text-mute-2">{o.kind}</span>
                    <span className="mt-1 block text-[19px] font-semibold tracking-[-0.02em]"><span className="link-line">anyfmt vs {o.name}</span></span>
                  </span>
                  <ArrowRight size={16} weight="bold" aria-hidden className="shrink-0 transition-transform duration-300 group-hover:translate-x-1" />
                </Link>
              </li>
            ))}
          </ul>
        </Container>
      </section>
    </Page>
  )
}

const HUB_COLS: [FactKey, string][] = [['price', 'Price'], ['processing', 'Converts'], ['source', 'Source'], ['mcp', 'MCP'], ['macos', 'macOS']]

export function CompareHub() {
  useHead({
    title: 'Compare anyfmt with other file converters',
    description: 'anyfmt next to Tangerine, convt, Permute, CloudConvert, Clop, HandBrake, FFmpeg and the converters built into macOS, with sourced facts and when each one is the better pick.',
    path: '/compare',
  })
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
        <Container>
          <div className="grid items-end gap-x-12 gap-y-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
            <div>
              <Eyebrow>Compare</Eyebrow>
              <h1 className="mt-6 max-w-[900px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">anyfmt next to {COMPETITORS.length} other converters.</h1>
            </div>
            <p className="max-w-[460px] text-[17px] leading-[1.55] text-mute lg:pb-3">Each page says plainly when the other app is the better choice. Every fact about another product links to where we found it, and the date we checked.</p>
          </div>
          <ul className="mt-14 border-t border-line lg:mt-20">
            {COMPETITORS.map((c) => (
              <li key={c.slug} className="border-b border-line">
                <Link to={`/compare/${c.slug}`} className="group grid items-center gap-x-8 gap-y-1 py-6 outline-none focus-visible:ring-2 focus-visible:ring-flare md:grid-cols-[minmax(0,4fr)_minmax(0,7fr)_auto]">
                  <span>
                    <span className="block text-[14px] text-mute-2">{c.kind}</span>
                    <span className="mt-1 block text-[clamp(26px,2.6vw,36px)] font-semibold leading-[1.05] tracking-[-0.035em]"><span className="link-line">{c.name}</span></span>
                  </span>
                  <span className="text-[16px] leading-[1.5] text-mute">{c.h1}</span>
                  <span className="hidden h-11 w-11 items-center justify-center rounded-full bg-white text-ink ring-1 ring-black/10 transition-colors duration-300 group-hover:bg-ink group-hover:text-white md:flex">
                    <ArrowRight size={16} weight="bold" aria-hidden />
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </Container>
      </section>
      <section className="bg-white py-24 lg:py-28">
        <Container>
          <Eyebrow>All in one table</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The facts that decide it, for all {COMPETITORS.length + 1}.</h2>
          <div className="mt-12 overflow-x-auto rounded-[28px] ring-1 ring-black/[.07]">
            <table className="w-full min-w-[880px] border-collapse text-left text-[15px]">
              <thead>
                <tr className="border-b border-line">
                  <th className="px-6 py-5 text-[14px] font-semibold" scope="col">App</th>
                  {HUB_COLS.map(([, l]) => <th key={l} className="px-6 py-5 text-[14px] font-semibold" scope="col">{l}</th>)}
                </tr>
              </thead>
              <tbody>
                <tr className="border-b border-line bg-sand">
                  <th scope="row" className="px-6 py-4 text-[16px] font-semibold"><span className="flex items-center gap-2.5"><span className="h-2 w-2 shrink-0 bg-flare" />anyfmt</span></th>
                  {HUB_COLS.map(([k]) => <td key={k} className="px-6 py-4">{ANYFMT_FACTS[k]}</td>)}
                </tr>
                {COMPETITORS.map((c) => (
                  <tr key={c.slug} className="border-b border-line last:border-0">
                    <th scope="row" className="px-6 py-4 text-[16px] font-semibold"><Link to={`/compare/${c.slug}`} className="underline decoration-black/20 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">{c.name}</Link></th>
                    {HUB_COLS.map(([k]) => <td key={k} className="px-6 py-4 text-mute">{c.facts[k]}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-5 text-[14px] text-mute-2">Facts checked {CHECKED}. Prices in US dollars unless stated.</p>
        </Container>
      </section>
    </Page>
  )
}
