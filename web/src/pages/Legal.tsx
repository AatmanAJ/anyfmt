/**
 * Privacy and Terms. Long-form text with a sticky contents list, and an "in short" summary beside
 * every section (above it on a phone), so the plain-English version is never more than a glance
 * away. Privacy opens with a ledger of every byte that can leave your Mac.
 */
import { Check, CursorClick, Power } from '@phosphor-icons/react'
import { motion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow } from '../components/ui'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import { PRICES, SITE } from '../lib/site'

const UPDATED = '27 October 2026'

interface Section { id: string; title: string; short: string; body: ReactNode }

function useSpy(ids: string[]) {
  const [on, setOn] = useState(ids[0])
  useEffect(() => {
    const f = () => { let cur = ids[0]; for (const id of ids) { const el = document.getElementById(id); if (el && el.getBoundingClientRect().top < 160) cur = id } setOn(cur) }
    f(); window.addEventListener('scroll', f, { passive: true }); return () => window.removeEventListener('scroll', f)
  }, [ids])
  return on
}

function LegalBody({ sections }: { sections: Section[] }) {
  const on = useSpy(sections.map((s) => s.id))
  return (
    <div className="grid gap-12 lg:grid-cols-[220px_minmax(0,1fr)] xl:gap-16">
      <nav aria-label="Sections" className="hidden lg:block">
        <ol className="sticky top-28 flex flex-col gap-0.5 border-l border-line">
          {sections.map((s, i) => (
            <li key={s.id} className="relative">
              {on === s.id && <motion.span layoutId="legal-bar" className="absolute -left-px bottom-1 top-1 w-[2px] bg-flare" />}
              <a href={`#${s.id}`} aria-current={on === s.id ? 'location' : undefined}
                className={`flex gap-2.5 rounded-r-md py-1.5 pl-4 pr-2 text-[14px] leading-[1.35] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${on === s.id ? 'font-medium text-ink' : 'text-mute-2 hover:text-ink'}`}>
                <span className="w-5 shrink-0 text-[13px] leading-[1.6] tabular-nums">{String(i + 1).padStart(2, '0')}</span>{s.title}
              </a>
            </li>
          ))}
        </ol>
      </nav>
      <div className="min-w-0">
        {sections.map((s, i) => (
          <section key={s.id} id={s.id} className="grid scroll-mt-28 gap-x-12 gap-y-6 border-t border-line py-12 first:border-0 first:pt-0 xl:grid-cols-[minmax(0,34rem)_17rem] xl:justify-between">
            <h2 className="flex items-baseline gap-3.5 text-[clamp(26px,2.6vw,34px)] font-semibold leading-[1.1] tracking-[-0.035em] xl:col-span-2">
              <span className="text-[15px] font-normal tabular-nums tracking-normal text-mute-2">{String(i + 1).padStart(2, '0')}</span>{s.title}
            </h2>
            {/* the summary comes first on a phone, and sits beside the text from xl up */}
            <aside className="h-fit border-l-2 border-flare pl-5 xl:sticky xl:top-28 xl:col-start-2 xl:row-start-2">
              <p className="text-[14px] font-semibold text-mute-2">In short</p>
              <p className="mt-1.5 text-[17px] font-medium leading-[1.45] text-ink">{s.short}</p>
            </aside>
            <div className="prose-flare min-w-0 max-w-[34rem] xl:col-start-1 xl:row-start-2">{s.body}</div>
          </section>
        ))}
      </div>
    </div>
  )
}

/** The one thing to do on a legal page: ask about it. */
function AskLegal({ what }: { what: string }) {
  return (
    <div className="mt-8 flex flex-wrap items-center gap-x-4 gap-y-3">
      <p className="text-[15px] text-mute">{what} <a href={`mailto:${SITE.email.legal}`} className="font-medium text-ink underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">{SITE.email.legal}</a></p>
      <CopyButton text={SITE.email.legal} label="Copy address" />
    </div>
  )
}

/* ── Privacy ───────────────────────────────────────────────── */

type When = 'never' | 'opt-in' | 'you-ask'
type Row = { when: string; sends: string; to: string; on: When; cloud?: true }
const LEDGER: Row[] = ([
  { when: 'Converting, editing, any action', sends: 'Nothing', to: 'Nowhere. The bundled ffmpeg is built without network support.', on: 'never' },
  { when: 'Using the CLI or the MCP server', sends: 'Nothing', to: 'Neither opens a socket or a port.', on: 'never' },
  { when: 'Update checks', sends: 'A request for the release feed, once a day', to: 'Our update server. No identifier is attached.', on: 'opt-in' },
  { when: 'Installing an optional engine pack', sends: 'Nothing from anyfmt', to: 'Your browser downloads it; anyfmt verifies the checksum.', on: 'you-ask' },
  { when: 'Validating a server URL', sends: 'One health check', to: 'The server you typed, only when you press Validate.', on: 'you-ask', cloud: true },
  { when: 'Activating a licence key', sends: 'The key, a random install id, the Mac\'s name', to: 'Our licence server. Never a hardware serial.', on: 'you-ask', cloud: true },
  { when: 'Pro: share links, cloud jobs, sync, inbox', sends: 'The files and settings you choose', to: 'Our servers, or yours if you set a Server URL.', on: 'you-ask', cloud: true },
] as Row[]).filter((row) => SITE.cloud || !row.cloud)

/** "Never" is the one highlight; the other defaults are said in words. */
function Status({ on, className = '' }: { on: When; className?: string }) {
  if (on === 'never') return <span className={`w-fit shrink-0 items-center gap-1.5 rounded-full bg-volt px-3 py-1 text-[13px] font-semibold text-ink ${className}`}><Check size={13} weight="bold" aria-hidden />Never</span>
  return (
    <span className={`shrink-0 items-center gap-1.5 text-[14px] font-medium text-ink ${className}`}>
      {on === 'opt-in' ? <Power size={14} weight="bold" aria-hidden className="shrink-0" /> : <CursorClick size={14} weight="bold" aria-hidden className="shrink-0" />}
      {on === 'opt-in' ? 'Off until you turn it on' : 'Only when you ask'}
    </span>
  )
}

/** Sections about the hosted service, shown once it exists (`SITE.cloud`). */
const CLOUD_SECTIONS = new Set(['pro', 'api', 'use', 'self-host'])
const local = (sections: Section[]) => sections.filter((x) => SITE.cloud || !CLOUD_SECTIONS.has(x.id))

const PRIVACY: Section[] = local([
  { id: 'app', title: 'The app', short: 'The app collects nothing. No analytics, no crash reporting, no account.', body: <>
    <p>anyfmt converts, edits and moves your files on your Mac. It does not collect analytics, usage data, crash reports or identifiers, and it does not need an account. The table above is the complete list of what can leave your Mac and when.</p>
    <p>Your files, presets and recent-conversion list stay in your home folder (<code>~/Library/Application Support/anyfmt</code>). Deleting the app and that folder removes everything anyfmt kept.</p>
  </> },
  { id: 'pro', title: 'Pro and the server features', short: 'Only what you send, only when you send it, deleted on a schedule.', body: <>
    <p>Pro features run on a server. When you use one, anyfmt sends what that feature needs and nothing more:</p>
    <ul>
      <li><strong>Sign-in:</strong> your email address, to send a sign-in link. Access tokens are stored hashed.</li>
      <li><strong>Share links:</strong> the file you share, plus the expiry, password and download limit you set. Link statistics are counts only: no viewer IP addresses or fingerprints.</li>
      <li><strong>Cloud jobs:</strong> the file to convert. Inputs and results are deleted when the result expires.</li>
      <li><strong>Sync:</strong> your presets, wheel order and settings, as documents tied to your account.</li>
      <li><strong>Inbox:</strong> files you send from your phone or browser, deleted after they land on your Mac.</li>
    </ul>
    <p>The first upload always tells you which server it's going to. If you point anyfmt at your own server, none of this reaches us.</p>
  </> },
  { id: 'api', title: 'The HTTP API', short: 'Files you upload are deleted after 24 hours by default.', body: <>
    <p>If you use the API, we process the files and URLs you send to perform the conversion. Inputs and outputs expire, 24 hours by default, and are then deleted. We keep usage records (counts, sizes, media minutes) for billing.</p>
  </> },
  { id: 'website', title: 'This website', short: 'No analytics or tracking scripts from us. No cookies of ours.', body: <>
    <p>This site doesn't run analytics or advertising scripts, and doesn't set cookies of its own. Fonts are served from this site, not from a third party. Like any web server, our host keeps standard request logs (IP address, browser, the page requested) for security and reliability.</p>
    <p>“Copy for AI” works in your browser and sends nothing to us. “Open in Claude” and “Open in ChatGPT” take you to those services with a link to the page; their privacy policies apply there.</p>
  </> },
  { id: 'payments', title: 'Payments and donations', short: 'A payment provider handles cards. We never see your card number.', body: <>
    <p>Purchases are handled by a payment provider. We receive the name and email address you give at checkout, your country and what you bought, so we can issue your licence and answer support questions. We never see or store your card details.</p>
    <p>Donations go through <a href={PRICES.donateUrl}>Buy Me a Coffee</a>, whose privacy policy applies to the donation itself.</p>
  </> },
  { id: 'email', title: 'When you email us', short: 'We use your email to reply, and keep it as long as the conversation needs it.', body: <>
    <p>If you write to us, we use your message and address to reply. We don't add you to a mailing list.</p>
  </> },
  { id: 'rights', title: 'Your rights', short: 'Ask to see, export or delete what we hold about you, and we will.', body: <>
    <p>Wherever you live, you can ask us what personal data we hold about you, ask for a copy, ask us to correct it, or ask us to delete it. Write to <strong>{SITE.email.legal}</strong>. If you're in the UK or the EU you also have the right to complain to your data protection authority, in the UK the ICO.</p>
    <p>{SITE.cloud ? 'Deleting your Pro account deletes your synced documents, share links and inbox items. ' : ''}Records we must keep by law, such as invoices, are kept for as long as the law requires.</p>
  </> },
  { id: 'changes', title: 'Changes', short: 'If this changes, the date at the top changes, and big changes get announced.', body: <>
    <p>We'll update this page if what anyfmt does with data changes, and note anything significant in the <Link to="/changelog">changelog</Link>. This policy takes effect with the first public release.</p>
  </> },
])

export function Privacy() {
  useHead({ title: 'Privacy', description: 'anyfmt collects nothing from the app: no analytics, no account, no uploads. Here is exactly what can leave your Mac, when, and why.', path: '/privacy' })
  return (
    <Page>
      <section className="bg-sand pb-16 pt-36 lg:pb-24 lg:pt-44">
        <Container>
          <div className="grid items-end gap-x-16 gap-y-8 lg:grid-cols-[auto_minmax(0,1fr)]">
            <motion.p aria-hidden initial={{ opacity: 0, scale: 0.92 }} animate={{ opacity: 1, scale: 1 }} transition={{ duration: 1, ease: EASE }}
              className="text-[clamp(112px,24vw,360px)] font-semibold leading-[0.78] tracking-[-0.08em]">0<span className="text-flare">.</span></motion.p>
            <div className="lg:pb-4">
              <Eyebrow>Privacy</Eyebrow>
              <h1 className="mt-5 max-w-[640px] text-[clamp(36px,4.4vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]"><span className="sr-only">Zero </span>Bytes the app sends about you.</h1>
              <p className="mt-5 max-w-[520px] text-[17px] leading-[1.55] text-mute">No analytics, no crash reports, no account. The table is every situation in which anything leaves your Mac at all. Updated {UPDATED}.</p>
              <AskLegal what="Questions about your data:" />
            </div>
          </div>
          <div className="mt-16 overflow-hidden rounded-[28px] bg-white ring-1 ring-black/[.07]">
            <div className="hidden grid-cols-[minmax(0,1.15fr)_minmax(0,1fr)_minmax(0,1.35fr)_196px] gap-6 border-b border-line px-8 py-4 text-[14px] font-semibold text-mute-2 md:grid">
              <span>When</span><span>What leaves your Mac</span><span>Where it goes</span><span>Default</span>
            </div>
            <ul className="divide-y divide-line">
              {LEDGER.map((r, i) => (
                <motion.li key={r.when} initial={{ opacity: 0, y: 6 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.5, ease: EASE, delay: i * 0.04 }}
                  className="grid gap-x-6 gap-y-1.5 px-6 py-5 md:grid-cols-[minmax(0,1.15fr)_minmax(0,1fr)_minmax(0,1.35fr)_196px] md:items-baseline md:px-8">
                  <span className="flex flex-col items-start gap-2 md:block">
                    <span className="text-[16px] font-semibold leading-[1.4]">{r.when}</span>
                    <Status on={r.on} className="flex md:hidden" />
                  </span>
                  <span className={`text-[15.5px] leading-[1.45] ${r.sends === 'Nothing' ? 'font-semibold text-ink' : 'text-ink'}`}><span className="text-mute-2 md:hidden">Sends: </span>{r.sends}</span>
                  <span className="text-[15px] leading-[1.45] text-mute"><span className="text-mute-2 md:hidden">To: </span>{r.to}</span>
                  <Status on={r.on} className="hidden md:flex" />
                </motion.li>
              ))}
            </ul>
          </div>
        </Container>
      </section>
      <section className="bg-white py-20 lg:py-28"><Container><LegalBody sections={PRIVACY} /></Container></section>
    </Page>
  )
}

/* ── Terms ─────────────────────────────────────────────────── */

const TERMS: Section[] = local([
  { id: 'who', title: 'Who these terms are with', short: 'You and the people who make anyfmt.', body: <>
    <p>These terms cover the anyfmt app, the anyfmt website{SITE.cloud ? ', the Desktop licence, the Pro subscription and the HTTP API' : ' and the Desktop licence'}. “We” means the maintainer of anyfmt. You can reach us at <strong>{SITE.email.legal}</strong>.</p>
  </> },
  { id: 'licence', title: 'The software licence', short: 'The code is AGPL-3.0. Nothing here takes away your rights under it.', body: <>
    <p>anyfmt's source code is licensed under the <a href="https://www.gnu.org/licenses/agpl-3.0.html">GNU Affero General Public License, version 3</a>. Two packages, DragSense and RadialMenu, are MIT. The bundled engines keep their own licences, listed inside the app and on the <Link to="/download">download page</Link>.</p>
    <p>You may build, run, modify and share anyfmt under those licences, including for commercial work. These terms don't restrict any right the AGPL gives you. If you distribute a modified anyfmt, or run a modified server that other people use, the AGPL asks you to offer them your source.</p>
  </> },
  { id: 'desktop', title: 'The Desktop licence', short: `$${PRICES.desktop.once} once: the signed app, every update, up to ${PRICES.desktop.macs} of your Macs.`, body: <>
    <p>A Desktop licence gives one person the signed and notarized anyfmt app, every future update of it, and email support, on up to {PRICES.desktop.macs} Macs they use. It's a one-time payment and doesn't expire.</p>
    <p>{SITE.cloud
      ? 'A licence key never limits anything that runs locally; it only records that you bought the app. Keys verify offline. Please don\'t share yours: deactivate a Mac in the app to move a seat to another.'
      : 'The licence never limits anything that runs locally: the app does the same whether you bought it or built it yourself. Please don\'t share your download link.'}</p>
  </> },
  { id: 'pro', title: 'Pro', short: 'Monthly or yearly, cancel any time, keeps working until the period ends.', body: <>
    <p>Pro is a subscription that adds features running on our servers: share links, cloud conversions, sync, the inbox and GPU tools. It includes everything in the Desktop licence. You can pay monthly or yearly, and cancel at any time; Pro then stays active until the end of the period you paid for.</p>
    <p>When Pro ends, everything on your Mac keeps working. Share links you made expire on their normal schedule, sync stops, and your synced data is deleted after 30 days unless you subscribe again. We'll give at least 30 days' notice of any price change, and it applies from your next renewal.</p>
  </> },
  { id: 'refunds', title: 'Refunds', short: '14 days, full refund, no questions.', body: <>
    <p>If anyfmt isn't for you, email us within 14 days of a purchase or a renewal and we'll refund it in full. This doesn't affect any rights you have under consumer law where you live.</p>
  </> },
  { id: 'use', title: 'Using the server features', short: 'Your files stay yours. Don\'t use share links for anything illegal or harmful.', body: <>
    <p>You keep every right in the files you upload. You give us permission to store, process and serve them only as needed to provide the feature you used, and only for as long as that feature keeps them.</p>
    <p>Don't use share links, the inbox or the API to distribute malware, material that infringes someone else's rights, or anything illegal, and never material that sexually exploits children. We may remove links, refuse jobs and suspend accounts that do, and we report illegal material where the law requires. Report abuse to <strong>{SITE.email.security}</strong>.</p>
  </> },
  { id: 'api', title: 'The HTTP API', short: 'Pay per successful conversion. Keep your keys secret.', body: <>
    <p>API usage is billed per successful conversion, plus media minutes for audio and video, at the prices on the <Link to="/pricing">pricing page</Link>. Failed conversions are free. You're responsible for keeping your API keys secret and for activity on them; revoke a key the moment you think it has leaked. Rate limits apply and may change; they're returned in every response.</p>
  </> },
  { id: 'self-host', title: 'Self-hosting', short: 'Your server, your responsibility.', body: <>
    <p>If you run the anyfmt server yourself, you are the operator: you're responsible for its security, its data and its users. We don't see your server or anything on it.</p>
  </> },
  { id: 'donations', title: 'Donations', short: 'A gift. It doesn\'t buy anything, and it isn\'t refundable unless it was a mistake.', body: <>
    <p>Donations are voluntary and don't come with goods, services or extra features. If you donated by mistake, write to us and we'll sort it out.</p>
  </> },
  { id: 'warranty', title: 'No warranty, limited liability', short: 'anyfmt never overwrites your files, but keep backups anyway.', body: <>
    <p>anyfmt is designed never to overwrite an original, and every conversion is tested before release. Even so, the software is provided “as is”, as the AGPL says, without warranty of any kind. Keep backups of files that matter.</p>
    <p>To the extent the law allows, we aren't liable for indirect or consequential losses, and our total liability to you is limited to what you paid us in the 12 months before the claim. Nothing here limits liability that can't be limited by law.</p>
  </> },
  { id: 'changes', title: 'Changes and law', short: 'We\'ll tell you before terms change. Northern Irish law applies.', body: <>
    <p>We may update these terms. For material changes we'll give notice on this site{SITE.cloud ? ' and, for Pro subscribers, by email,' : ''} before they take effect. These terms are governed by the laws of Northern Ireland, and its courts have jurisdiction, without taking away protections your local consumer law gives you. Last updated {UPDATED}; they take effect with the first public release.</p>
  </> },
])

export function Terms() {
  useHead({ title: 'Terms', description: `The terms for the anyfmt app${SITE.cloud ? ', Desktop licence, Pro subscription and API' : ' and the Desktop licence'}, with a plain-English summary beside every section.`, path: '/terms' })
  return (
    <Page>
      <section className="bg-sand pb-16 pt-36 lg:pb-20 lg:pt-44">
        <Container>
          <Eyebrow>Terms</Eyebrow>
          <h1 className="mt-6 max-w-[1040px] text-[clamp(44px,6vw,92px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">The terms, with a plain summary of every section.</h1>
          <p className="mt-6 max-w-[560px] text-[17px] leading-[1.55] text-mute">Read the summaries for the gist and the full text for the detail. If the two ever seem to disagree, the full text wins. Updated {UPDATED}.</p>
          <AskLegal what="Questions about these terms:" />
        </Container>
      </section>
      <section className="bg-white py-20 lg:py-28"><Container><LegalBody sections={TERMS} /></Container></section>
    </Page>
  )
}
