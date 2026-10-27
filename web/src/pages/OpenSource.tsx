/**
 * Open source: walk the repository, see which licence covers which folder, the rules the build
 * enforces, how to build it, and how a new format is one row of Swift.
 */
import { Check, Folder, FolderOpen } from '@phosphor-icons/react'
import { GitHubMark } from '../components/Marks'
import { AnimatePresence, motion } from 'motion/react'
import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { CodeBlock } from '../components/docs/Markdown'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { BUNDLED } from '../data/engines'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import { SITE } from '../lib/site'

type Lic = 'AGPL-3.0' | 'MIT' | 'Mixed' | 'Docs'
/** MIT is the one filled badge: those two packages are meant to be lifted into other apps. */
const LIC_SKIN: Record<Lic, string> = { 'AGPL-3.0': 'text-white/85 ring-1 ring-white/25', MIT: 'bg-volt text-ink', Mixed: 'text-amber ring-1 ring-amber/50', Docs: 'text-white/70 ring-1 ring-white/15' }
const LIC_NAME: Record<Lic, string> = { 'AGPL-3.0': 'AGPL-3.0', MIT: 'MIT', Mixed: 'Each engine its own', Docs: 'Docs' }
const LIC_NOTE: Record<Lic, string> = {
  'AGPL-3.0': 'AGPL-3.0: use it for anything, commercial work included. If you ship a modified version, or run one as a service for other people, share your changes.',
  MIT: 'MIT: copy it into anything, commercial or not. These two packages are meant to end up in other apps.',
  Mixed: 'GPL, LGPL, BSD and MIT, with the exact versions and build flags written down beside each one.',
  Docs: 'Read it, quote it, link to it.',
}

const TREE: { name: string; lic: Lic; what: string; children?: { name: string; what: string }[] }[] = [
  { name: 'Sources', lic: 'AGPL-3.0', what: 'The app: everything you see and everything that converts.', children: [
    { name: 'App', what: 'Launch, menu bar, onboarding, settings' }, { name: 'Wheel', what: 'The three wheels, presets, options panel' },
    { name: 'Engine', what: 'The router and every engine adapter' }, { name: 'Jobs', what: 'Queue, progress, never-overwrite placement' },
    { name: 'Tools', what: `The ${catalog.counts.tools} tools and their editors` }, { name: 'Actions', what: 'AirDrop, Float, Copy, Move, Copy Path, Terminal' },
    { name: 'Cloud', what: 'The only folder allowed to touch the network' }, { name: 'CLI', what: 'The anyfmt command and the MCP server' },
    { name: 'Shared', what: 'Formats, option schemas, the capability table' },
  ] },
  { name: 'Packages/DragSense', lic: 'MIT', what: 'Global file-drag and modifier-tap detection that needs no permissions.' },
  { name: 'Packages/RadialMenu', lic: 'MIT', what: 'The wheel component: rings, paging, morphs and the drop panel.' },
  { name: 'Engines', lic: 'Mixed', what: 'Scripts that build ffmpeg, its codecs and resvg from pinned, checksummed sources.' },
  { name: 'Server', lic: 'AGPL-3.0', what: 'The OpenAPI 3.1 contract the app and the API speak, and the server plan.' },
  { name: 'sdk/typescript', lic: 'AGPL-3.0', what: 'The TypeScript SDK for the HTTP API, generated from the contract.' },
  { name: 'Tests', lic: 'AGPL-3.0', what: 'Unit tests, golden CLI transcripts, the conversion matrix and a mock server.' },
  { name: 'LICENSES', lic: 'Docs', what: 'Every bundled licence, a notice file and a written source offer.' },
  { name: 'docs', lic: 'Docs', what: 'Architecture, decisions, the matrix results and performance numbers.' },
]

function LicBadge({ lic, long = false }: { lic: Lic; long?: boolean }) {
  return <span className={`inline-flex h-6 shrink-0 items-center rounded-full px-2.5 font-sans text-[12px] font-semibold ${LIC_SKIN[lic]}`}>{long ? LIC_NAME[lic] : lic}</span>
}

function Detail({ t, inline = false }: { t: (typeof TREE)[number]; inline?: boolean }) {
  return (
    <div className="flex h-full flex-col">
      {!inline && <div className="mb-5 flex flex-wrap items-center gap-3"><LicBadge lic={t.lic} long /><span className="font-mono text-[14px] text-white/60">{t.name}/</span></div>}
      <p className="max-w-[560px] text-[clamp(22px,2.2vw,30px)] font-semibold leading-[1.2] tracking-[-0.03em] [text-wrap:balance]">{t.what}</p>
      {t.children && (
        <ul className="mt-7 grid gap-x-8 gap-y-2.5 sm:grid-cols-2">
          {t.children.map((c) => <li key={c.name} className="text-[14.5px] leading-[1.45]"><span className="font-mono text-white">{c.name}/</span><span className="block text-white/60">{c.what}</span></li>)}
        </ul>
      )}
      <div className="min-h-8 flex-1" />
      <p className="border-t border-white/10 pt-5 text-[15px] leading-[1.55] text-white/70">{LIC_NOTE[t.lic]}</p>
    </div>
  )
}

/** A folder list and what the chosen folder holds. On a phone the details open under the row you tapped. */
function RepoExplorer() {
  const [sel, setSel] = useState(0)
  const t = TREE[sel]
  return (
    <div className="grid overflow-hidden rounded-[28px] bg-night text-white lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]">
      <ul className="p-3 sm:p-4 lg:border-r lg:border-white/10">
        <li className="px-3 py-2 font-mono text-[14px] text-white/60">anyfmt/</li>
        {TREE.map((n, i) => (
          <li key={n.name}>
            <button type="button" onClick={() => setSel(i)} aria-pressed={sel === i}
              className={`flex w-full items-center gap-3 rounded-[12px] px-3 py-2.5 text-left font-mono text-[14px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${sel === i ? 'bg-white/10' : 'hover:bg-white/[0.05]'}`}>
              {sel === i ? <FolderOpen size={18} weight="fill" aria-hidden className="text-white" /> : <Folder size={18} weight="fill" aria-hidden className="text-white/45" />}
              <span className="min-w-0 flex-1 truncate">{n.name}</span>
              <LicBadge lic={n.lic} />
            </button>
            <AnimatePresence initial={false}>
              {sel === i && (
                <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.3, ease: EASE }} className="overflow-hidden lg:hidden">
                  <div className="px-3 pb-6 pt-3"><Detail t={n} inline /></div>
                </motion.div>
              )}
            </AnimatePresence>
          </li>
        ))}
      </ul>
      <AnimatePresence mode="wait">
        <motion.div key={t.name} initial={{ opacity: 0, x: 10 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -6 }} transition={{ duration: 0.3, ease: EASE }} className="hidden p-10 lg:block">
          <Detail t={t} />
        </motion.div>
      </AnimatePresence>
    </div>
  )
}

const RULES: [string, ReactNode, string][] = [
  ['Local is free, forever', 'Nothing that runs on the Mac may consult the entitlements gate.', 'scripts/check-entitlements.sh'],
  ['Never overwrite', 'Engines write to a temp folder; results are placed with an exclusive rename.', 'OutputPlacer'],
  ['No network outside Cloud', <>Only <code className="font-mono text-[0.9em]">Sources/Cloud</code> may open a connection, and ffmpeg is built with <code className="whitespace-nowrap font-mono text-[0.9em]">--disable-network</code>.</>, 'make netcheck'],
  ['No private APIs, no copied code', 'Reading other projects for ideas is fine. Copying isn\'t.', 'code review'],
]

const BUILD = `git clone ${SITE.github} && cd anyfmt
make bootstrap   # build-machine tools: xcodegen, meson, ninja, nasm
make engines     # ffmpeg, ffprobe and resvg from pinned sources (~10 min, once)
make build       # generates the Xcode project and builds
make test        # package tests, unit tests and policy checks
make matrix      # every conversion on a real file, validated`

const ROW = `// Sources/Shared/FormatCatalog.swift: describe the format once
public static let foo: FormatID = "foo"
Format(foo, kind: .image, label: "FOO", name: L("Foo image"), extensions: ["foo"], types: ["org.example.foo"], order: 180),

// Sources/Engine/Image/ImageRoutes.swift: one capability row
Capability(Formats.png, Formats.foo, EngineIDs.imageIO, schema: StandardSchemas.imageLossy),`

export default function OpenSource() {
  useHead({ title: 'Open source', description: 'anyfmt is AGPL-3.0, with its drag sensor and wheel as MIT packages. Walk the repository, see the rules the build enforces, and build it yourself.', path: '/open-source' })
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
        <Container>
          <Eyebrow>Open source</Eyebrow>
          <h1 className="mt-6 max-w-[1000px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Every line of anyfmt is open source, from the first release.</h1>
          <div className="mt-10 flex flex-wrap items-end justify-between gap-8">
            <dl className="flex flex-wrap gap-x-10 gap-y-5">
              {[['AGPL-3.0', 'the app'], ['MIT', 'drag sensor and wheel'], ['0', 'private APIs'], [String(catalog.counts.routes), 'tested routes']].map(([v, l]) => <div key={l} className="flex flex-col-reverse"><dt className="mt-1.5 text-[14px] text-mute">{l}</dt><dd className="text-[36px] font-semibold leading-none tracking-[-0.04em]">{v}</dd></div>)}
            </dl>
            <div className="flex w-full flex-col gap-3 rounded-[20px] bg-white p-4 ring-1 ring-black/[.07] sm:w-auto sm:flex-row sm:items-center sm:rounded-full sm:py-2 sm:pl-5 sm:pr-2">
              <span className="flex min-w-0 items-center gap-2.5"><GitHubMark size={20} /><span className="truncate font-mono text-[14px]">{SITE.github.replace('https://', '')}</span></span>
              <span className="flex items-center gap-2">
                <span className="whitespace-nowrap rounded-full bg-sand-2 px-2.5 py-1 text-[12.5px] font-medium">Public with the first release</span>
                <CopyButton text={SITE.github} label="Copy" />
              </span>
            </div>
          </div>
          <div className="mt-16"><RepoExplorer /></div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Rules the build enforces</Eyebrow>
          <h2 className="mt-6 max-w-[880px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Four promises, and how each one is checked.</h2>
          <ul className="mt-14 grid gap-x-12 md:grid-cols-2">
            {RULES.map(([t, d, how]) => (
              <li key={t} className="flex flex-col gap-5 border-t border-line py-8">
                <div><p className="text-[22px] font-semibold tracking-[-0.025em]">{t}</p><p className="mt-2 max-w-[520px] text-[16px] leading-[1.55] text-mute">{d}</p></div>
                <p className="flex w-fit items-center gap-2 rounded-full bg-sand px-3 py-1.5 font-mono text-[13px]"><Check size={13} weight="bold" aria-hidden className="text-ink" />{how}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Build it</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">Six commands to a build of your own.</h2>
            <p className="mt-6 max-w-[420px] text-[16.5px] leading-[1.55] text-mute">You need Xcode 16 or later and Rust. Building it yourself is free, commercial use included. The <Link to="/pricing" className="font-medium text-ink underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">Desktop licence</Link> saves you the build and comes signed by Apple.</p>
          </div>
          <div className="min-w-0 self-start [&>figure]:my-0"><CodeBlock code={BUILD} lang="bash" title="Terminal" /></div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Contribute</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">A new format is one row.</h2>
            <p className="mt-6 max-w-[440px] text-[16.5px] leading-[1.55] text-mute">Describe the format, add one capability row, and the router does the rest: every format that reaches PNG now reaches FOO within three hops. The wheel, the CLI and the matrix all read the same table.</p>
            <div className="mt-10 border-t border-line pt-6">
              <p className="text-[15px] font-semibold">Before your first pull request</p>
              <ul className="mt-3 space-y-2 text-[15.5px] leading-[1.5] text-mute">
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />You accept a short contributor licence agreement, once.</li>
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />You keep ownership of your work.</li>
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />Your contribution always stays available under the AGPL or another open-source licence.</li>
              </ul>
            </div>
          </div>
          <div className="min-w-0 self-start [&>figure]:my-0"><CodeBlock code={ROW} lang="swift" title="Add a format" /></div>
        </Container>
      </section>

      <section className="bg-night py-24 text-white lg:py-32">
        <Container>
          <Eyebrow tone="white">Standing on</Eyebrow>
          <h2 className="mt-6 max-w-[800px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The open-source engines inside anyfmt.</h2>
          <ul className="mt-14 grid gap-x-10 sm:grid-cols-2 lg:grid-cols-4">
            {BUNDLED.map((e) => (
              <li key={e.name} className="border-t border-white/12 py-6">
                <p className="text-[20px] font-semibold tracking-[-0.02em]">{e.name}</p>
                <p className="mt-1 font-mono text-[13px] text-white/60">{e.version} · {e.licence}</p>
                <p className="mt-2.5 text-[15px] text-white/75">{e.does}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>
    </Page>
  )
}
