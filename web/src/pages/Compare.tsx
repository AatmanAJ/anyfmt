/**
 * Comparisons: a hub with every alternative in one table, and a page per product with its own
 * centrepiece, a spec sheet, an honest "choose them if", FAQ and dated sources.
 */
import { ArrowUpRight, Check } from '@phosphor-icons/react'
import { motion } from 'motion/react'
import { Link, useParams } from 'react-router-dom'
import { Accordion } from '../components/Accordion'
import { DownloadButton } from '../components/Buttons'
import { Clicks, Menu, Passthrough, Routes, Session, Terminal, Timeline, Upload } from '../components/compare/Centrepieces'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import { ANYFMT_FACTS, CHECKED, COMPETITOR, COMPETITORS, type Competitor } from '../data/compare'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import NotFound from './NotFound'

const FACT_ROWS: [keyof Competitor['facts'], string][] = [['price', 'Price'], ['platforms', 'Runs on'], ['processing', 'Where files are converted'], ['source', 'Source code'], ['scope', 'Scope'], ['cli', 'Command line'], ['mcp', 'MCP for agents'], ['macos', 'Oldest macOS']]

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

function SpecSheet({ c }: { c: Competitor }) {
  return (
    <div className="overflow-hidden rounded-[26px] ring-1 ring-line">
      <div className="grid grid-cols-[1fr_1fr] bg-sand text-[13px] font-semibold uppercase tracking-[0.12em] sm:grid-cols-[0.8fr_1fr_1fr]">
        <span className="hidden px-6 py-4 text-mute-2 sm:block" />
        <span className="px-5 py-4 text-flare sm:px-6">anyfmt</span>
        <span className="px-5 py-4 text-mute sm:px-6">{c.name}</span>
      </div>
      {FACT_ROWS.map(([k, label]) => (
        <div key={k} className="grid grid-cols-[1fr_1fr] border-t border-line sm:grid-cols-[0.8fr_1fr_1fr]">
          <span className="col-span-2 px-5 pt-4 text-[13px] font-medium text-mute-2 sm:col-span-1 sm:px-6 sm:py-4 sm:text-[14.5px] sm:text-ink">{label}</span>
          <span className="px-5 pb-4 pt-1 text-[15px] font-medium sm:px-6 sm:py-4">{ANYFMT_FACTS[k]}</span>
          <span className="px-5 pb-4 pt-1 text-[15px] text-mute sm:px-6 sm:py-4">{c.facts[k]}</span>
        </div>
      ))}
    </div>
  )
}

function Detail({ c }: { c: Competitor }) {
  return (
    <div className="overflow-x-auto rounded-[26px] bg-white ring-1 ring-black/5">
      <table className="w-full min-w-[560px] border-collapse text-left">
        <thead><tr className="border-b border-line text-[13px] font-semibold uppercase tracking-[0.12em]"><th className="px-6 py-4 text-mute-2" scope="col">&nbsp;</th><th className="px-6 py-4 text-flare" scope="col">anyfmt</th><th className="px-6 py-4 text-mute" scope="col">{c.name}</th></tr></thead>
        <tbody>
          {c.rows.map((r, i) => (
            <motion.tr key={r.label} initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} transition={{ delay: i * 0.03 }} className="border-b border-line last:border-0">
              <th scope="row" className="px-6 py-4 text-[15px] font-semibold">{r.label}</th>
              <td className="px-6 py-4 text-[15px]">{r.anyfmt}</td>
              <td className="px-6 py-4 text-[15px] text-mute">{r.them}</td>
            </motion.tr>
          ))}
        </tbody>
      </table>
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
        <Container className="grid items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)]">
          <div>
            <Eyebrow><Link to="/compare" className="hover:underline">Compare</Link> <span className="text-mute-2">/ anyfmt vs {c.name}</span></Eyebrow>
            <motion.h1 initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: EASE }}
              className="mt-6 text-[clamp(40px,5.2vw,82px)] font-semibold leading-[0.97] tracking-[-0.05em] [text-wrap:balance]">{c.h1}</motion.h1>
            <p className="mt-7 max-w-[600px] text-[17.5px] leading-[1.6] text-ink-2">{c.answer}</p>
            <p className="mt-6 text-[13px] text-mute-2">{c.name} by {c.maker} · facts checked {CHECKED}</p>
          </div>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.9, ease: EASE, delay: 0.15 }}><Centre c={c} /></motion.div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>At a glance</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">The spec sheet.</h2>
          </div>
          <SpecSheet c={c} />
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-28">
        <Container>
          <Eyebrow>Point by point</Eyebrow>
          <h2 className="mt-6 max-w-[800px] text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Where they differ, and where they don't.</h2>
          <div className="mt-12"><Detail c={c} /></div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container>
          <div className="grid gap-4 lg:grid-cols-2">
            <div className="rounded-[28px] bg-sand p-8 sm:p-10">
              <p className="text-[13px] font-semibold uppercase tracking-[0.14em] text-mute-2">Choose {c.name} if</p>
              <ul className="mt-6 space-y-4">{c.pickThem.map((t) => <li key={t} className="flex gap-3 text-[17px] leading-[1.5]"><Check size={18} weight="bold" className="mt-1 shrink-0" />{t}</li>)}</ul>
            </div>
            <div className="rounded-[28px] bg-night p-8 text-white sm:p-10">
              <p className="text-[13px] font-semibold uppercase tracking-[0.14em] text-volt">Choose anyfmt if</p>
              <ul className="mt-6 space-y-4">{c.pickUs.map((t) => <li key={t} className="flex gap-3 text-[17px] leading-[1.5]"><Check size={18} weight="bold" className="mt-1 shrink-0 text-flare" />{t}</li>)}</ul>
              <div className="mt-10"><DownloadButton tone="light" /></div>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white pb-24 lg:pb-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Questions</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Asked about {c.name}.</h2>
            <div className="mt-10 rounded-[22px] bg-sand p-6">
              <p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-mute-2">Sources, checked {CHECKED}</p>
              <ul className="mt-3 space-y-2">{c.sources.map((s) => <li key={s.url}><a href={s.url} target="_blank" rel="noreferrer" className="group inline-flex items-center gap-1.5 text-[15px] underline decoration-black/20 underline-offset-4 hover:decoration-flare">{s.label}<ArrowUpRight size={13} className="text-mute-2" /></a></li>)}</ul>
              <p className="mt-4 text-[13.5px] text-mute">Something here out of date? <Link to="/contact" className="underline decoration-flare/60 underline-offset-2">Tell us</Link> and we'll fix it.</p>
            </div>
          </div>
          <Accordion items={c.faq} />
        </Container>
      </section>

      <section className="bg-sand py-20">
        <Container>
          <p className="text-[14px] font-medium text-mute-2">More comparisons</p>
          <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {others.map((o) => (
              <Link key={o.slug} to={`/compare/${o.slug}`} className="group rounded-[20px] bg-white p-5 ring-1 ring-black/5 transition-transform duration-500 hover:-translate-y-1">
                <p className="text-[13px] text-mute-2">{o.kind}</p>
                <p className="mt-2 text-[19px] font-semibold tracking-[-0.02em]">anyfmt vs {o.name}</p>
              </Link>
            ))}
          </div>
        </Container>
      </section>
    </Page>
  )
}

const HUB_COLS: [keyof Competitor['facts'], string][] = [['price', 'Price'], ['processing', 'Converts'], ['source', 'Source'], ['mcp', 'MCP'], ['macos', 'macOS']]

export function CompareHub() {
  useHead({
    title: 'Compare anyfmt with other file converters',
    description: 'anyfmt next to Tangerine, convt, Permute, CloudConvert, Clop, HandBrake, FFmpeg and the converters built into macOS, with sourced facts and when each one is the better pick.',
    path: '/compare',
  })
  return (
    <Page>
      <section className="bg-sand pb-16 pt-36 lg:pt-44">
        <Container>
          <Eyebrow>Compare</Eyebrow>
          <h1 className="mt-6 max-w-[1100px] text-[clamp(44px,6.4vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Every alternative, with the receipts.</h1>
          <p className="mt-7 max-w-[600px] text-[18px] leading-[1.55] text-mute">Each page says plainly when the other app is the better choice. Every fact about another product links to where we found it, and the date we checked.</p>
          <div className="mt-14 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {COMPETITORS.map((c, i) => (
              <motion.div key={c.slug} initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, ease: EASE, delay: 0.1 + i * 0.04 }}>
                <Link to={`/compare/${c.slug}`} className="group flex h-full min-h-[200px] flex-col justify-between rounded-[24px] bg-white p-6 ring-1 ring-black/5 outline-none transition-transform duration-500 hover:-translate-y-1 focus-visible:ring-2 focus-visible:ring-flare">
                  <div className="flex items-center justify-between"><p className="text-[13px] text-mute-2">{c.kind}</p><ArrowUpRight size={18} className="text-mute-3 transition-[transform,color] duration-500 group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-flare" /></div>
                  <div>
                    <p className="text-[13px] font-medium text-mute">anyfmt vs</p>
                    <p className="text-[30px] font-semibold leading-none tracking-[-0.04em]">{c.name}</p>
                  </div>
                </Link>
              </motion.div>
            ))}
          </div>
        </Container>
      </section>
      <section className="bg-white py-24">
        <Container>
          <Eyebrow>All in one table</Eyebrow>
          <div className="mt-10 overflow-x-auto rounded-[26px] ring-1 ring-line">
            <table className="w-full min-w-[880px] border-collapse text-left text-[14.5px]">
              <thead className="bg-sand text-[12.5px] font-semibold uppercase tracking-[0.12em] text-mute-2">
                <tr><th className="px-5 py-4" scope="col">App</th>{HUB_COLS.map(([, l]) => <th key={l} className="px-5 py-4" scope="col">{l}</th>)}</tr>
              </thead>
              <tbody>
                <tr className="border-t border-line bg-[#FFF6F1]"><th scope="row" className="px-5 py-4 text-[16px] font-semibold text-flare">anyfmt</th>{HUB_COLS.map(([k]) => <td key={k} className="px-5 py-4 font-medium">{ANYFMT_FACTS[k]}</td>)}</tr>
                {COMPETITORS.map((c) => (
                  <tr key={c.slug} className="border-t border-line">
                    <th scope="row" className="px-5 py-4 text-[16px] font-semibold"><Link to={`/compare/${c.slug}`} className="underline decoration-black/15 underline-offset-4 hover:decoration-flare">{c.name}</Link></th>
                    {HUB_COLS.map(([k]) => <td key={k} className="px-5 py-4 text-mute">{c.facts[k]}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-4 text-[13px] text-mute-2">Facts checked {CHECKED}. Prices in US dollars unless stated.</p>
        </Container>
      </section>
    </Page>
  )
}
