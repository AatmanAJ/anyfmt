/**
 * Conversion guides: /convert lists them, /convert/<slug> is one guide. Each opens with the
 * direct answer and its own visual, then steps, the differences, options with the real
 * defaults from the app's schema, the command line, caveats, FAQ and related guides.
 */
import { ArrowRight, MagnifyingGlass } from '@phosphor-icons/react'
import { motion } from 'motion/react'
import { useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Accordion } from '../components/Accordion'
import { DownloadButton } from '../components/Buttons'
import { CodeBlock } from '../components/docs/Markdown'
import { formatKind, formatLabel, GuideVisual } from '../components/guides/Visuals'
import { Page } from '../components/Page'
import { Container, Eyebrow, FormatChip, Keycap } from '../components/ui'
import type { Guide } from '../data/guide-types'
import { GUIDES } from '../data/guides'
import options from '../data/options.json'
import tools from '../data/tools.json'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import NotFound from './NotFound'

type Opt = { id: string; label: string; kind: string; default?: unknown; min?: number; max?: number; unit?: string; choices?: { id: string; label: string }[] }
const G = Object.fromEntries(GUIDES.map((g) => [g.slug, g])) as Record<string, Guide>
const toolOf = (id: string) => tools.find((t) => t.id === id)

function optionMeta(g: Guide, id: string): Opt | undefined {
  const list = g.kind === 'tool' ? (toolOf(g.to)?.options as Opt[] | undefined) : (options as Record<string, { options: Opt[] }>)[g.to]?.options
  return list?.find((o) => o.id === id)
}

function describe(o?: Opt) {
  if (!o) return null
  const d = o.default
  if (o.kind === 'choice' && o.choices) return `${o.choices.find((c) => c.id === String(d))?.label ?? d} · ${o.choices.length} choices`
  if (o.kind === 'toggle') return d ? 'On by default' : 'Off by default'
  if (o.kind === 'fileSize' && typeof d === 'number') return `${(d / 1_000_000).toFixed(d >= 1_000_000 ? 0 : 1)} MB default`
  if (typeof d === 'number' || typeof d === 'string') return `${d}${o.unit && o.unit !== 'bytes' ? ` ${o.unit}` : ''} default${o.min !== undefined && o.max !== undefined ? ` · ${o.min}–${o.max}` : ''}`
  return null
}

const pairLabel = (g: Guide) => (g.kind === 'tool' ? toolOf(g.to)?.title ?? g.to : `${g.from.map(formatLabel).join(' / ')} to ${formatLabel(g.to)}`)

function Hero({ g }: { g: Guide }) {
  const target = g.kind === 'tool' ? toolOf(g.to)?.title ?? '' : formatLabel(g.to)
  const key = g.kind === 'tool' ? { glyph: '⌘', name: 'Command' } : { glyph: '⇧', name: 'Shift' }
  return (
    <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
      <Container className="grid items-center gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div>
          <Eyebrow><Link to="/convert" className="hover:underline">Guides</Link> <span className="text-mute-2">/ {pairLabel(g)}</span></Eyebrow>
          <motion.h1 initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: EASE }}
            className="mt-6 text-[clamp(40px,5vw,78px)] font-semibold leading-[0.98] tracking-[-0.05em] [text-wrap:balance]">{g.h1}</motion.h1>
          <p className="mt-7 max-w-[580px] text-[17.5px] leading-[1.6] text-ink-2">{g.answer}</p>
          <div className="mt-8 flex flex-wrap items-center gap-3 text-[15px] font-medium">
            <span className="rounded-full bg-white px-3.5 py-2 ring-1 ring-black/10">Drag {g.kind === 'tool' ? 'the file' : <FormatChip label={formatLabel(g.from[0])} kind={formatKind(g.from[0])} size="sm" />}</span>
            <ArrowRight size={16} className="text-flare" />
            <Keycap glyph={key.glyph} size="sm" />
            <ArrowRight size={16} className="text-flare" />
            <span className="rounded-full bg-ink px-3.5 py-2 text-white">Drop on {target}</span>
          </div>
          {g.measured && (
            <ul className="mt-8 flex flex-wrap gap-2">
              {g.measured.map((m) => <li key={m.label} className="rounded-[14px] bg-white px-4 py-2.5 ring-1 ring-black/5"><span className="text-[22px] font-semibold tracking-[-0.03em]">{m.value}</span><span className="ml-2 text-[13px] text-mute">{m.label}</span></li>)}
            </ul>
          )}
        </div>
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.9, ease: EASE, delay: 0.15 }}><GuideVisual g={g} /></motion.div>
      </Container>
    </section>
  )
}

export function GuidePage() {
  const { slug = '' } = useParams()
  const g = G[slug]
  useHead(g ? {
    title: g.title, description: g.description, path: `/convert/${g.slug}`, type: 'article',
    jsonLd: [
      { '@context': 'https://schema.org', '@type': 'HowTo', name: g.title, description: g.answer, tool: [{ '@type': 'HowToTool', name: 'anyfmt for macOS' }], step: g.steps.map((s, i) => ({ '@type': 'HowToStep', position: i + 1, text: s })) },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: g.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  } : { title: 'Guide', description: '', path: `/convert/${slug}`, noindex: true })
  if (!g) return <NotFound />
  const fromL = g.from.map(formatLabel).join(' / ')
  const toL = g.kind === 'tool' ? 'After' : formatLabel(g.to)
  return (
    <Page>
      <Hero g={g} />

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>Step by step</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">How to do it.</h2>
          </div>
          <ol className="space-y-3">
            {g.steps.map((s, i) => (
              <motion.li key={i} initial={{ opacity: 0, x: 12 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true, amount: 0.6 }} transition={{ duration: 0.5, ease: EASE, delay: i * 0.05 }}
                className="flex gap-5 rounded-[22px] bg-sand p-6">
                <span className="font-wordmark text-[40px] font-bold leading-none tracking-[-0.04em] text-flare">{i + 1}</span>
                <p className="pt-1.5 text-[17px] leading-[1.55]">{s}</p>
              </motion.li>
            ))}
          </ol>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-28">
        <Container>
          <div className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
            <div>
              <Eyebrow>Why people do this</Eyebrow>
              <ul className="mt-8 space-y-3">{g.why.map((w) => <li key={w} className="flex gap-3 text-[16.5px] leading-[1.55]"><span className="mt-2.5 h-1.5 w-1.5 shrink-0 bg-ink" />{w}</li>)}</ul>
            </div>
            <div className="overflow-hidden rounded-[26px] bg-white ring-1 ring-black/5">
              <div className="grid grid-cols-[0.8fr_1fr_1fr] bg-white text-[12.5px] font-semibold uppercase tracking-[0.12em]">
                <span className="px-5 py-4 text-mute-2">&nbsp;</span><span className="px-5 py-4 text-mute">{g.kind === 'tool' ? 'Before' : fromL}</span><span className="px-5 py-4 text-flare">{toL}</span>
              </div>
              {g.facts.map((f) => (
                <div key={f.label} className="grid grid-cols-[0.8fr_1fr_1fr] border-t border-line text-[14.5px]">
                  <span className="px-5 py-3.5 font-semibold">{f.label}</span><span className="px-5 py-3.5 text-mute">{f.from}</span><span className="px-5 py-3.5">{f.to}</span>
                </div>
              ))}
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Options worth knowing</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">{g.options.length ? 'The settings that matter.' : 'Nothing to set.'}</h2>
            <p className="mt-5 max-w-[420px] text-[16px] leading-[1.55] text-mute">Hold ⌥ Option as you drop to open the options panel, or pick a preset chip on the segment. Defaults below come straight from the app.</p>
          </div>
          <div className="space-y-3">
            {g.options.map((o) => {
              const meta = describe(optionMeta(g, o.id))
              return (
                <div key={o.id} className="rounded-[22px] bg-sand p-6">
                  <div className="flex flex-wrap items-baseline justify-between gap-2"><p className="text-[18px] font-semibold tracking-[-0.02em]">{o.label}</p>{meta && <p className="font-mono text-[12.5px] text-mute-2">{meta}</p>}</div>
                  <p className="mt-2 text-[15.5px] leading-[1.55] text-mute">{o.advice}</p>
                  <p className="mt-3 font-mono text-[12px] text-mute-3">--opt {o.id}=…</p>
                </div>
              )
            })}
            {!g.options.length && <p className="rounded-[22px] bg-sand p-6 text-[16px] text-mute">This one has no options. Drop it and it's done.</p>}
          </div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>From Terminal</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">The same thing, scripted.</h2>
            <p className="mt-5 max-w-[420px] text-[16px] leading-[1.55] text-mute">The <Link to="/docs/cli" className="underline decoration-flare/60 underline-offset-4">anyfmt command</Link> runs the same route with the same options. Add <span className="font-mono text-[14px]">--json</span> for machine-readable progress.</p>
          </div>
          <div>
            <CodeBlock code={g.cli} lang="bash" title="One file" />
            {g.batch && <CodeBlock code={g.batch} lang="bash" title="A batch" />}
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Good to know</Eyebrow>
            <ul className="mt-8 space-y-4">{g.gotchas.map((w) => <li key={w} className="rounded-[18px] bg-[#FFF3EC] p-5 text-[15.5px] leading-[1.55] ring-1 ring-flare/15">{w}</li>)}</ul>
          </div>
          <div>
            <Eyebrow>Questions</Eyebrow>
            <div className="mt-6"><Accordion items={g.faq} /></div>
          </div>
        </Container>
      </section>

      <section className="bg-sand py-20">
        <Container>
          <div className="flex flex-wrap items-end justify-between gap-6">
            <p className="text-[clamp(28px,3vw,42px)] font-semibold tracking-[-0.04em]">Related guides</p>
            <DownloadButton />
          </div>
          <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
            {g.related.map((r) => G[r]).filter(Boolean).map((o) => (
              <Link key={o.slug} to={`/convert/${o.slug}`} className="group rounded-[20px] bg-white p-5 ring-1 ring-black/5 transition-transform duration-500 hover:-translate-y-1">
                <p className="text-[16.5px] font-semibold leading-[1.25] tracking-[-0.02em]">{pairLabel(o)}</p>
                <p className="mt-2 line-clamp-2 text-[13.5px] text-mute">{o.h1}</p>
              </Link>
            ))}
          </div>
        </Container>
      </section>
    </Page>
  )
}

const GROUPS: { name: string; test: (g: Guide) => boolean }[] = [
  { name: 'Photos and images', test: (g) => g.kind === 'convert' && ['image', 'vector'].includes(formatKind(g.from[0])) },
  { name: 'Video', test: (g) => g.kind === 'convert' && formatKind(g.from[0]) === 'video' && formatKind(g.to) !== 'audio' },
  { name: 'Audio', test: (g) => g.kind === 'convert' && formatKind(g.to) === 'audio' },
  { name: 'Documents, PDF and data', test: (g) => g.kind === 'convert' && ['pdf', 'document', 'ebook', 'spreadsheet', 'subtitle', 'archive'].includes(formatKind(g.from[0])) },
  { name: 'Tools', test: (g) => g.kind === 'tool' },
]

export function GuidesHub() {
  const [q, setQ] = useState('')
  useHead({ title: 'Conversion guides for Mac', description: 'Step-by-step guides for converting files on a Mac: HEIC to JPG, MOV to MP4, video to GIF, PDF to Word and more, offline and without uploading.', path: '/convert' })
  const shown = useMemo(() => GUIDES.filter((g) => !q || `${g.title} ${g.h1} ${g.from.join(' ')} ${g.to}`.toLowerCase().includes(q.toLowerCase())), [q])
  return (
    <Page>
      <section className="bg-sand pb-16 pt-36 lg:pt-44">
        <Container>
          <Eyebrow>Guides</Eyebrow>
          <h1 className="mt-6 max-w-[1000px] text-[clamp(44px,6.4vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em]">How to convert anything on a Mac.</h1>
          <p className="mt-6 max-w-[560px] text-[18px] leading-[1.55] text-mute">{GUIDES.length} guides, each with the steps, the options that matter, the command line, and what you lose along the way. Useful even if you never install anyfmt.</p>
          <label className="mt-10 flex h-14 max-w-[560px] items-center gap-3 rounded-full bg-white px-5 ring-1 ring-black/10 focus-within:ring-2 focus-within:ring-flare">
            <MagnifyingGlass size={19} className="text-mute-2" aria-hidden />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="heic, gif, pdf, compress…" aria-label="Filter guides" className="h-full flex-1 bg-transparent text-[17px] outline-none placeholder:text-mute-3" />
          </label>
        </Container>
      </section>
      <section className="bg-white py-20">
        <Container className="space-y-16">
          {GROUPS.map((grp) => {
            const list = shown.filter(grp.test)
            if (!list.length) return null
            return (
              <div key={grp.name} className="grid gap-6 border-t border-line pt-8 lg:grid-cols-[240px_minmax(0,1fr)] lg:gap-10">
                <h2 className="text-[clamp(24px,2.4vw,32px)] font-semibold tracking-[-0.035em] lg:sticky lg:top-28 lg:self-start">{grp.name}</h2>
                <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                  {list.map((g) => (
                    <li key={g.slug}>
                      <Link to={`/convert/${g.slug}`} className="group flex h-full flex-col justify-between gap-5 rounded-[22px] bg-sand p-5 outline-none transition-[transform,background-color] duration-500 hover:-translate-y-1 hover:bg-sand-2 focus-visible:ring-2 focus-visible:ring-flare">
                        <span className="flex flex-wrap items-center gap-2">
                          {g.kind === 'tool' ? <span className="rounded-[7px] bg-ink px-2 py-1 text-[12px] font-semibold text-white">⌘ {toolOf(g.to)?.title}</span> : <>
                            <FormatChip label={formatLabel(g.from[0])} kind={formatKind(g.from[0])} /><ArrowRight size={14} className="text-flare" /><FormatChip label={formatLabel(g.to)} kind={formatKind(g.to)} />
                          </>}
                        </span>
                        <span>
                          <span className="block text-[17px] font-semibold leading-[1.25] tracking-[-0.02em]">{g.h1}</span>
                          <span className="mt-1.5 line-clamp-2 block text-[14px] leading-[1.45] text-mute">{g.description}</span>
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
          {!shown.length && <p className="py-10 text-center text-[16px] text-mute">No guide for “{q}” yet. <Link to="/formats" className="underline decoration-flare/60 underline-offset-4">Check the formats page</Link>: the route may well exist.</p>}
        </Container>
      </section>
    </Page>
  )
}
