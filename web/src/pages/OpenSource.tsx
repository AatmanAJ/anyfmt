/**
 * Open source: walk the repository, see which licence covers which folder, the rules the build
 * enforces, how to build it, and how a new format is one row of Swift.
 */
import { Folder, FolderOpen, GithubLogo } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useState } from 'react'
import { CodeBlock } from '../components/docs/Markdown'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { BUNDLED } from '../data/engines'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import { SITE } from '../lib/site'

type Lic = 'AGPL-3.0' | 'MIT' | 'Mixed' | 'Docs'
const LIC_SKIN: Record<Lic, string> = { 'AGPL-3.0': 'bg-ink text-white', MIT: 'bg-volt text-ink', Mixed: 'bg-flare text-white', Docs: 'bg-sand-2 text-ink' }

const TREE: { name: string; lic: Lic; what: string; children?: { name: string; what: string }[] }[] = [
  { name: 'Sources', lic: 'AGPL-3.0', what: 'The app: everything you see and everything that converts.', children: [
    { name: 'App', what: 'Launch, menu bar, onboarding, settings wiring' }, { name: 'Wheel', what: 'The three wheels, presets, options panel' },
    { name: 'Engine', what: 'The router and every engine adapter' }, { name: 'Jobs', what: 'Queue, progress cards, never-overwrite placement' },
    { name: 'Tools', what: 'The 26 tools and their editors' }, { name: 'Actions', what: 'AirDrop, Float, Copy, Move, Copy Path, Terminal' },
    { name: 'Cloud', what: 'The only folder allowed to touch the network' }, { name: 'CLI', what: 'The anyfmt command and the MCP server' },
    { name: 'Shared', what: 'Formats, options schemas, the capability table' },
  ] },
  { name: 'Packages/DragSense', lic: 'MIT', what: 'Global file-drag and modifier-tap detection that needs no permissions. Use it in your own app.' },
  { name: 'Packages/RadialMenu', lic: 'MIT', what: 'The wheel component: rings, paging, morphs, drop panel. Use it in your own app.' },
  { name: 'Engines', lic: 'Mixed', what: 'Scripts that build ffmpeg, its codecs and resvg from pinned, checksummed sources.' },
  { name: 'Server', lic: 'AGPL-3.0', what: 'The OpenAPI 3.1 contract the app and the API speak, and the server plan.' },
  { name: 'sdk/typescript', lic: 'AGPL-3.0', what: 'The TypeScript SDK for the HTTP API, generated from the contract.' },
  { name: 'Tests', lic: 'AGPL-3.0', what: 'Unit tests, golden CLI transcripts, the conversion matrix, and a mock server.' },
  { name: 'LICENSES', lic: 'Docs', what: 'Every bundled licence, a notice file and a written source offer.' },
  { name: 'docs', lic: 'Docs', what: 'Architecture, decisions, the matrix results, performance numbers.' },
]

function RepoExplorer() {
  const [sel, setSel] = useState(0)
  const [open, setOpen] = useState(true)
  const t = TREE[sel]
  return (
    <div className="grid overflow-hidden rounded-[28px] bg-night text-white lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      <ul className="border-b border-white/10 p-4 font-mono text-[14px] lg:border-b-0 lg:border-r">
        <li className="px-3 py-2 text-white/50">anyfmt/</li>
        {TREE.map((n, i) => (
          <li key={n.name}>
            <button type="button" onClick={() => { setSel(i); if (i === 0) setOpen((o) => !o) }} aria-pressed={sel === i}
              className={`flex w-full items-center gap-2.5 rounded-[10px] px-3 py-2 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${sel === i ? 'bg-white/10' : 'hover:bg-white/[0.05]'}`}>
              {i === 0 && open ? <FolderOpen size={17} weight="fill" className="text-amber" /> : <Folder size={17} weight="fill" className={n.lic === 'MIT' ? 'text-volt' : 'text-amber'} />}
              <span className="flex-1">{n.name}</span>
              <span className={`rounded-full px-2 py-0.5 font-sans text-[10.5px] font-semibold ${LIC_SKIN[n.lic]}`}>{n.lic}</span>
            </button>
            {i === 0 && (
              <AnimatePresence initial={false}>
                {open && (
                  <motion.ul initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.35, ease: EASE }} className="overflow-hidden pl-7">
                    {n.children!.map((c) => <li key={c.name} className="flex gap-3 px-3 py-1 text-[13px] text-white/55"><span className="text-white/80">{c.name}/</span><span className="hidden truncate font-sans sm:block">{c.what}</span></li>)}
                  </motion.ul>
                )}
              </AnimatePresence>
            )}
          </li>
        ))}
      </ul>
      <AnimatePresence mode="wait">
        <motion.div key={t.name} initial={{ opacity: 0, x: 12 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -8 }} transition={{ duration: 0.3, ease: EASE }} className="flex flex-col justify-between p-8 sm:p-10">
          <div>
            <span className={`rounded-full px-3 py-1 text-[12px] font-semibold ${LIC_SKIN[t.lic]}`}>{t.lic === 'Mixed' ? 'Each engine keeps its licence' : t.lic === 'Docs' ? 'Documentation' : t.lic}</span>
            <p className="mt-6 font-mono text-[15px] text-white/60">{t.name}/</p>
            <p className="mt-3 text-[clamp(24px,2.4vw,34px)] font-semibold leading-[1.15] tracking-[-0.03em]">{t.what}</p>
          </div>
          <p className="mt-10 text-[14.5px] leading-[1.55] text-white/55">
            {t.lic === 'MIT' ? 'MIT: copy it into anything, commercial or not. We want these two everywhere.' : t.lic === 'AGPL-3.0' ? 'AGPL-3.0: use it for anything. If you ship a modified version, or run one as a service, share your changes.' : t.lic === 'Mixed' ? 'GPL, LGPL, BSD and MIT, with the exact versions and build flags written down.' : 'Read it, quote it, link to it.'}
          </p>
        </motion.div>
      </AnimatePresence>
    </div>
  )
}

const RULES: [string, string, string][] = [
  ['Local is free, forever', 'Nothing that runs on the Mac may consult the entitlements gate.', 'scripts/check-entitlements.sh'],
  ['Never overwrite', 'Engines write to a temp folder; results are placed with an exclusive rename.', 'OutputPlacer'],
  ['No network outside Cloud', 'Only Sources/Cloud may open a connection; ffmpeg is built with --disable-network.', 'make netcheck'],
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
          <h1 className="mt-6 max-w-[1000px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.92] tracking-[-0.06em]">Read every line.</h1>
          <div className="mt-10 flex flex-wrap items-end justify-between gap-8">
            <ul className="flex flex-wrap gap-x-10 gap-y-4">
              {[['AGPL-3.0', 'the app'], ['MIT', 'drag sensor and wheel'], ['0', 'private APIs'], [String(catalog.counts.routes), 'tested routes']].map(([v, l]) => <li key={l}><p className="text-[36px] font-semibold leading-none tracking-[-0.04em]">{v}</p><p className="mt-1.5 text-[14px] text-mute">{l}</p></li>)}
            </ul>
            <div className="flex flex-wrap items-center gap-3 rounded-full bg-white py-2 pl-4 pr-2 ring-1 ring-black/10">
              <GithubLogo size={20} weight="fill" />
              <span className="font-mono text-[14px]">{SITE.github.replace('https://', '')}</span>
              <span className="rounded-full bg-sand-2 px-2.5 py-1 text-[12px] font-semibold">Public with the first release</span>
              <CopyButton text={SITE.github} label="Copy" />
            </div>
          </div>
          <div className="mt-16"><RepoExplorer /></div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Rules the build enforces</Eyebrow>
          <h2 className="mt-6 max-w-[880px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Promises we made checkable.</h2>
          <ul className="mt-14 grid gap-4 md:grid-cols-2">
            {RULES.map(([t, d, how], i) => (
              <motion.li key={t} initial={{ opacity: 0, y: 14 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.5 }} transition={{ duration: 0.6, ease: EASE, delay: i * 0.06 }}
                className="flex flex-col justify-between gap-8 rounded-[24px] bg-sand p-7">
                <div><p className="text-[22px] font-semibold tracking-[-0.03em]">{t}</p><p className="mt-2 text-[15.5px] leading-[1.55] text-mute">{d}</p></div>
                <p className="w-fit rounded-full bg-white px-3 py-1.5 font-mono text-[12.5px] ring-1 ring-black/10">✓ {how}</p>
              </motion.li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Build it</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Five commands to your own build.</h2>
            <p className="mt-6 max-w-[420px] text-[16.5px] leading-[1.55] text-mute">You need Xcode 16 or later and Rust. Building yourself is free forever, commercial use included; the <a href="/pricing" className="underline decoration-flare/60 underline-offset-4">Desktop licence</a> just saves you the trouble and signs it.</p>
          </div>
          <CodeBlock code={BUILD} lang="bash" title="Terminal" />
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Contribute</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">A new format is one row.</h2>
            <p className="mt-6 max-w-[440px] text-[16.5px] leading-[1.55] text-mute">Describe the format, add one capability row, and the router does the rest: every format that reaches PNG now reaches FOO within three hops. The wheel, the CLI and the matrix all read the same table.</p>
            <div className="mt-8 rounded-[22px] bg-sand p-6">
              <p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-mute-2">Before your first pull request</p>
              <ul className="mt-3 space-y-2 text-[15px] leading-[1.5]">
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />You accept a short contributor licence agreement, once.</li>
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />You keep ownership of your work.</li>
                <li className="flex gap-3"><span className="mt-2 h-1.5 w-1.5 shrink-0 bg-ink" />Your contribution always stays available under the AGPL or another open-source licence.</li>
              </ul>
            </div>
          </div>
          <CodeBlock code={ROW} lang="swift" title="Add a format" />
        </Container>
      </section>

      <section className="bg-night py-24 text-white lg:py-32">
        <Container>
          <Eyebrow tone="white">Standing on</Eyebrow>
          <h2 className="mt-6 max-w-[800px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">The engines that do the heavy lifting.</h2>
          <ul className="mt-14 grid grid-cols-2 gap-px overflow-hidden rounded-[24px] bg-white/10 sm:grid-cols-3 lg:grid-cols-4">
            {BUNDLED.map((e) => (
              <li key={e.name} className="bg-night p-6">
                <p className="text-[20px] font-semibold tracking-[-0.02em]">{e.name}</p>
                <p className="mt-1 font-mono text-[12.5px] text-white/50">{e.version} · {e.licence}</p>
                <p className="mt-3 text-[14px] text-white/65">{e.does}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>
    </Page>
  )
}
