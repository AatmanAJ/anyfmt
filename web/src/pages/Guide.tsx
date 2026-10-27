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
import { Container, Eyebrow, FormatChip } from '../components/ui'
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

/** "HEIC to JPG", or for a tool the task in the guide's own words: "Compress images", "Trim a video". */
const pairLabel = (g: Guide) => (g.kind === 'tool' ? g.title.split(' on Mac')[0] : `${g.from.map(formatLabel).join(' / ')} to ${formatLabel(g.to)}`)

/** The gesture for this guide, as one line: drag the file, tap the key, drop on the target. */
function Gesture({ g }: { g: Guide }) {
  const target = g.kind === 'tool' ? toolOf(g.to)?.title ?? '' : formatLabel(g.to)
  const key = g.kind === 'tool' ? '⌘ Command' : '⇧ Shift'
  return (
    <p className="flex flex-wrap items-center gap-x-3 gap-y-2 text-[15px] font-medium">
      <span className="inline-flex h-10 items-center gap-2 rounded-full bg-white pl-4 pr-1.5 ring-1 ring-black/10">Drag {g.kind === 'tool' ? 'the file' : <FormatChip label={formatLabel(g.from[0])} kind={formatKind(g.from[0])} />}</span>
      <ArrowRight size={16} weight="bold" aria-hidden className="hidden text-mute-2 sm:block" />
      <kbd className="inline-flex h-10 items-center rounded-full bg-white px-4 font-sans ring-1 ring-black/10">Tap {key}</kbd>
      <ArrowRight size={16} weight="bold" aria-hidden className="hidden text-mute-2 sm:block" />
      <span className="inline-flex h-10 items-center rounded-full bg-ink px-4 text-white">Drop on {target}</span>
    </p>
  )
}

function Hero({ g }: { g: Guide }) {
  return (
    <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
      <Container className="grid items-start gap-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <div>
          <nav aria-label="Breadcrumb" className="flex items-center gap-3 text-[16px] sm:text-[18px]">
            <span className="h-2.5 w-2.5 shrink-0 bg-ink" />
            <Link to="/convert" className="link-line outline-none focus-visible:ring-2 focus-visible:ring-flare">Guides</Link>
            <span className="text-mute-2">/</span>
            <span className="text-mute-2">{pairLabel(g)}</span>
          </nav>
          <motion.h1 initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: EASE }}
            className="mt-6 text-[clamp(36px,3.9vw,58px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]">{/[.?!]$/.test(g.h1) ? g.h1 : `${g.h1}.`}</motion.h1>
          <p className="mt-7 max-w-[580px] text-[17px] leading-[1.6] text-mute">{g.answer}</p>
          <div className="mt-9"><DownloadButton /></div>
          {g.measured && (
            <ul className="mt-10 grid max-w-[600px] gap-x-10 gap-y-5 border-t border-line pt-6 sm:grid-cols-2">
              {g.measured.slice(0, 2).map((m) => (
                <li key={m.label}>
                  <span className="block text-[22px] font-semibold leading-none tracking-[-0.03em] tabular-nums">{m.value}</span>
                  <span className="mt-2 block text-[14px] leading-[1.4] text-mute-2">{m.label}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.9, ease: EASE, delay: 0.15 }} className="min-w-0"><GuideVisual g={g} /></motion.div>
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
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Step by step</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">How to do it.</h2>
          </div>
          <div>
          <div className="mb-8"><Gesture g={g} /></div>
          <ol className="border-t border-line">
            {g.steps.map((s, i) => (
              <li key={i} className="grid grid-cols-[32px_minmax(0,1fr)] items-baseline gap-3 border-b border-line py-6 sm:grid-cols-[48px_minmax(0,1fr)] sm:gap-4">
                <span className="text-[28px] font-semibold leading-none tracking-[-0.04em] tabular-nums">{i + 1}</span>
                <p className="text-[17px] leading-[1.55]">{s}</p>
              </li>
            ))}
          </ol>
          </div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Why people do this</Eyebrow>
            <ul className="mt-8 space-y-3">{g.why.map((w) => <li key={w} className="flex gap-3 text-[17px] leading-[1.55]"><span className="mt-[11px] h-1.5 w-1.5 shrink-0 bg-ink" />{w}</li>)}</ul>
          </div>
          <div className="overflow-hidden rounded-[28px] bg-white ring-1 ring-black/[.07]">
            <div className="hidden grid-cols-[minmax(0,0.8fr)_minmax(0,1fr)_minmax(0,1fr)] border-b border-line text-[15px] font-semibold sm:grid">
              <span className="px-6 py-4"><span className="sr-only">What changes</span></span>
              <span className="px-6 py-4">{g.kind === 'tool' ? 'Before' : fromL}</span>
              <span className="flex items-center gap-2 px-6 py-4"><span className="h-2 w-2 shrink-0 bg-flare" />{toL}</span>
            </div>
            <dl>
              {g.facts.map((f) => (
                <div key={f.label} className="grid grid-cols-2 border-b border-line text-[15px] last:border-0 sm:grid-cols-[minmax(0,0.8fr)_minmax(0,1fr)_minmax(0,1fr)]">
                  <dt className="col-span-2 px-5 pt-4 font-semibold sm:col-span-1 sm:px-6 sm:py-4 sm:font-normal sm:text-mute">{f.label}</dt>
                  <dd className="px-5 pb-4 pt-1.5 text-mute sm:px-6 sm:py-4"><span className="mb-0.5 block text-[12px] font-medium text-mute-2 sm:hidden">{g.kind === 'tool' ? 'Before' : fromL}</span>{f.from}</dd>
                  <dd className="px-5 pb-4 pt-1.5 sm:px-6 sm:py-4"><span className="mb-0.5 block text-[12px] font-medium text-mute-2 sm:hidden">{toL}</span>{f.to}</dd>
                </div>
              ))}
            </dl>
          </div>
        </Container>
      </section>

      {g.options.length > 0 && (
      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Options worth knowing</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The settings that matter.</h2>
            <p className="mt-6 max-w-[420px] text-[17px] leading-[1.55] text-mute">Hold ⌥ Option as you drop to open the options panel, or pick a preset chip on the segment. The defaults here come straight from the app.</p>
          </div>
          <ul className="border-t border-line">
            {g.options.map((o) => {
              const meta = describe(optionMeta(g, o.id))
              return (
                <li key={o.id} className="border-b border-line py-6">
                  <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                    <h3 className="text-[20px] font-semibold tracking-[-0.02em]">{o.label}</h3>
                    {meta && <p className="text-[14px] text-mute-2 tabular-nums">{meta}</p>}
                  </div>
                  <p className="mt-2 text-[16px] leading-[1.55] text-mute">{o.advice}</p>
                  <p className="mt-3 font-mono text-[13px] text-mute-2">--opt {o.id}=…</p>
                </li>
              )
            })}
          </ul>
        </Container>
      </section>
      )}

      <section className="bg-sand py-24 lg:py-28">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>From Terminal</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">{g.kind === 'tool' ? 'The same edit, scripted.' : 'The same conversion, scripted.'}</h2>
            <p className="mt-6 max-w-[420px] text-[17px] leading-[1.55] text-mute">The <Link to="/docs/cli" className="underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">anyfmt command</Link> runs the same route with the same options. Add <span className="font-mono text-[15px]">--json</span> for machine-readable progress.</p>
          </div>
          <div className="min-w-0 space-y-4">
            <CodeBlock code={g.cli} lang="bash" title="One file" />
            {g.batch && <CodeBlock code={g.batch} lang="bash" title="A batch" />}
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-28">
        <Container className="grid gap-16 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-12">
          <div>
            <Eyebrow>Good to know</Eyebrow>
            <ul className="mt-8 border-t border-line">
              {g.gotchas.map((w) => (
                <li key={w} className="flex gap-3.5 border-b border-line py-5 text-[16px] leading-[1.55]">
                  <span className="mt-[9px] h-2 w-2 shrink-0 bg-flare" />{w}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <Eyebrow>Questions</Eyebrow>
            <div className="mt-6"><Accordion items={g.faq} /></div>
          </div>
        </Container>
      </section>

      <section className="border-t border-line bg-white py-16 lg:py-20">
        <Container>
          <div className="flex flex-wrap items-end justify-between gap-6">
            <h2 className="text-[22px] font-semibold tracking-[-0.025em]">Related guides</h2>
          </div>
          <ul className="mt-6 grid border-t border-line sm:grid-cols-2 lg:grid-cols-3">
            {g.related.map((r) => G[r]).filter(Boolean).map((o) => (
              <li key={o.slug} className="border-b border-line">
                <Link to={`/convert/${o.slug}`} className="group flex h-full items-center justify-between gap-4 py-5 pr-2 outline-none focus-visible:ring-2 focus-visible:ring-flare sm:pr-6">
                  <span className="min-w-0">
                    <span className="block text-[18px] font-semibold tracking-[-0.02em]"><span className="link-line">{pairLabel(o)}</span></span>
                    <span className="mt-1 block truncate text-[14px] text-mute-2">{o.h1}</span>
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
      <section className="bg-sand pb-16 pt-36 lg:pb-20 lg:pt-44">
        <Container>
          <div className="grid items-end gap-x-12 gap-y-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
            <div>
              <Eyebrow>Guides</Eyebrow>
              <h1 className="mt-6 max-w-[900px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">How to convert files on a Mac.</h1>
            </div>
            <p className="max-w-[460px] text-[17px] leading-[1.55] text-mute lg:pb-3">{GUIDES.length} guides, each with the steps, the options that matter, the command line, and what you lose along the way. Useful even if you never install anyfmt.</p>
          </div>
          <label className="mt-12 flex h-14 max-w-[560px] items-center gap-3 rounded-full bg-white px-5 ring-1 ring-black/10 focus-within:ring-2 focus-within:ring-flare">
            <MagnifyingGlass size={19} className="shrink-0 text-mute-2" aria-hidden />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Find a guide: heic, gif, pdf, compress…" aria-label="Filter guides" className="h-full min-w-0 flex-1 bg-transparent text-[17px] outline-none placeholder:text-mute-2" />
          </label>
        </Container>
      </section>
      <section className="bg-white py-20 lg:py-24">
        <Container className="space-y-16">
          {GROUPS.map((grp) => {
            const list = shown.filter(grp.test)
            if (!list.length) return null
            return (
              <div key={grp.name} className="grid gap-6 lg:grid-cols-[240px_minmax(0,1fr)] lg:gap-10">
                <h2 className="text-[clamp(24px,2.4vw,32px)] font-semibold leading-[1.1] tracking-[-0.035em] lg:sticky lg:top-28 lg:self-start">{grp.name}<span className="mt-1.5 block text-[15px] font-normal tracking-normal text-mute-2">{list.length} {list.length === 1 ? 'guide' : 'guides'}</span></h2>
                <ul className="grid border-t border-line xl:grid-cols-2 xl:gap-x-10">
                  {list.map((g) => (
                    <li key={g.slug} className="border-b border-line">
                      <Link to={`/convert/${g.slug}`} className="group flex items-center gap-5 py-5 outline-none focus-visible:ring-2 focus-visible:ring-flare">
                        <span className="flex min-w-0 flex-1 flex-col gap-2.5 sm:flex-row sm:items-center sm:gap-5">
                        <span className="flex shrink-0 items-center gap-1.5 sm:min-w-[148px]">
                          {g.kind === 'tool' ? <span className="rounded-[7px] bg-ink px-2 py-1 text-[12px] font-semibold text-white">⌘ {toolOf(g.to)?.title}</span> : <>
                            <FormatChip label={formatLabel(g.from[0])} kind={formatKind(g.from[0])} /><ArrowRight size={13} weight="bold" aria-hidden className="text-mute-2" /><FormatChip label={formatLabel(g.to)} kind={formatKind(g.to)} />
                          </>}
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block text-[17px] font-semibold leading-[1.3] tracking-[-0.015em]"><span className="link-line">{g.h1}</span></span>
                        </span>
                        </span>
                        <ArrowRight size={16} weight="bold" aria-hidden className="shrink-0 transition-transform duration-300 group-hover:translate-x-1" />
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
          {!shown.length && <p className="py-10 text-center text-[17px] text-mute">No guide for “{q}” yet. <Link to="/formats" className="underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">Check the formats page</Link>: the route may well exist.</p>}
        </Container>
      </section>
    </Page>
  )
}
