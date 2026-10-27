/**
 * Docs Markdown: GitHub-flavoured, with GitHub-style alert callouts ([!NOTE], [!TIP], [!WARNING],
 * [!PREVIEW]), titled code blocks with copy, anchored headings and scrollable tables.
 */
import { isValidElement, type ReactNode } from 'react'
import ReactMarkdown, { type Components } from 'react-markdown'
import { Link } from 'react-router-dom'
import remarkGfm from 'remark-gfm'
import { slugify } from '../../lib/docs'
import { highlight, TOKEN_CLASS } from '../../lib/highlight'
import { CopyButton } from '../ui'

/** mdast/hast nodes, typed loosely: the plugin and renderers only read a few fields. */
// biome-ignore lint: loose AST type
type Node = any
function remarkCallouts() {
  return (tree: Node) => {
    const walk = (node: Node) => {
      if (node.type === 'blockquote') {
        const p = node.children?.[0]
        const t = p?.type === 'paragraph' ? p.children?.[0] : null
        if (t?.type === 'text') {
          const m = /^\[!(NOTE|TIP|WARNING|PREVIEW|IMPORTANT|CAUTION)\]\s*/i.exec(t.value)
          if (m) {
            t.value = t.value.slice(m[0].length)
            if (!t.value) p.children.shift()
            if (!p.children.length) node.children.shift()
            node.data = { hName: 'aside', hProperties: { dataCallout: m[1].toLowerCase() } }
          }
        }
      }
      node.children?.forEach(walk)
    }
    walk(tree)
  }
}

const textOf = (n: ReactNode): string =>
  typeof n === 'string' || typeof n === 'number' ? String(n) : Array.isArray(n) ? n.map(textOf).join('') : isValidElement(n) ? textOf((n.props as { children?: ReactNode }).children) : ''

const CALLOUT: Record<string, { label: string; skin: string; dot: string }> = {
  note: { label: 'Note', skin: 'bg-sand text-ink-2', dot: 'bg-ink' },
  important: { label: 'Important', skin: 'bg-sand text-ink-2', dot: 'bg-flare' },
  tip: { label: 'Tip', skin: 'bg-[#F6FFC4] text-ink-2', dot: 'bg-[#6E8200]' },
  warning: { label: 'Careful', skin: 'bg-[#FFF0E8] text-ink-2', dot: 'bg-flare' },
  caution: { label: 'Careful', skin: 'bg-[#FFF0E8] text-ink-2', dot: 'bg-flare' },
  preview: { label: 'Preview', skin: 'bg-night text-white/80 [&_a]:text-white [&_strong]:text-white [&_code]:!bg-white/10 [&_code]:!text-white', dot: 'bg-volt' },
}

function Callout({ type, children }: { type: string; children: ReactNode }) {
  const c = CALLOUT[type] ?? CALLOUT.note
  return (
    <aside className={`not-prose my-7 rounded-[16px] px-5 py-4 text-[16px] leading-[1.6] ${c.skin}`}>
      <p className={`flex items-center gap-2 text-[14px] font-semibold ${type === 'preview' ? 'text-white' : 'text-ink'}`}><span aria-hidden className={`h-2 w-2 ${c.dot}`} />{c.label}</p>
      <div className="mt-1.5 [&>*+*]:mt-2 [&_a]:underline [&_a]:decoration-flare/60 [&_a]:underline-offset-2 [&_code]:rounded-[5px] [&_code]:bg-black/[.06] [&_code]:px-1 [&_code]:font-mono [&_code]:text-[0.88em]">{children}</div>
    </aside>
  )
}

const SHELL = /^(bash|sh|shell|zsh|console)$/
const LANG_NAME: Record<string, string> = { bash: 'Terminal', sh: 'Terminal', shell: 'Terminal', zsh: 'Terminal', console: 'Terminal', json: 'JSON', ts: 'TypeScript', typescript: 'TypeScript', js: 'JavaScript', javascript: 'JavaScript', swift: 'Swift', yaml: 'YAML', yml: 'YAML', http: 'HTTP', text: '', txt: '' }

/**
 * A one-line command sits on a single row with a prompt and a copy button. Anything longer gets
 * a title bar (its title, or the language) above it.
 */
export function CodeBlock({ code, lang = '', title }: { code: string; lang?: string; title?: string }) {
  const tokens = highlight(code, lang)
  const shell = SHELL.test(lang)
  const copy = shell ? code.replace(/^\$ /gm, '') : code
  const body = <code className="font-mono">{tokens.map(([k, v], i) => <span key={i} className={TOKEN_CLASS[k]}>{v}</span>)}</code>
  // a one-line command titled just "Terminal" says nothing the prompt doesn't
  if (!code.includes('\n') && (!title || (shell && title === 'Terminal'))) {
    return (
      <figure className="not-prose my-6 flex items-center gap-3 rounded-[16px] bg-night py-2 pl-4 pr-2">
        {shell && <span aria-hidden className="select-none font-mono text-[13.5px] text-flare">$</span>}
        <pre className="min-w-0 flex-1 overflow-x-auto py-1.5 text-[13.5px] leading-[1.6] text-white/90 [mask-image:linear-gradient(90deg,#000_calc(100%-24px),transparent)] sm:[mask-image:none]">{body}</pre>
        <CopyButton text={copy} tone="dark" />
      </figure>
    )
  }
  return (
    <figure className="not-prose my-6 overflow-hidden rounded-[16px] bg-night">
      <figcaption className="flex items-center justify-between gap-3 border-b border-white/[0.08] py-2 pl-4 pr-2">
        <span className="min-w-0 truncate font-mono text-[13px] text-white/60">{title ?? LANG_NAME[lang] ?? lang}</span>
        <CopyButton text={copy} tone="dark" />
      </figcaption>
      {/* on a phone the right edge fades, so a line that runs on reads as scrollable */}
      <pre className="overflow-x-auto px-4 py-4 text-[13.5px] leading-[1.7] text-white/90 [mask-image:linear-gradient(90deg,#000_calc(100%-32px),transparent)] sm:[mask-image:none]">{body}</pre>
    </figure>
  )
}

export function Markdown({ source }: { source: string }) {
  const seen = new Map<string, number>()
  const anchor = (children: ReactNode) => {
    let id = slugify(textOf(children))
    const n = seen.get(id) ?? 0
    seen.set(id, n + 1)
    return n ? `${id}-${n}` : id
  }
  const components: Components = {
    h2: ({ children }) => { const id = anchor(children); return <h2 id={id} className="group/h relative">{children}<a href={`#${id}`} aria-label="Link to this section" className="ml-2 align-middle text-[0.7em] text-mute-2 no-underline opacity-0 outline-none transition-opacity group-hover/h:opacity-100 focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-flare">#</a></h2> },
    h3: ({ children }) => { const id = anchor(children); return <h3 id={id} className="group/h relative">{children}<a href={`#${id}`} aria-label="Link to this section" className="ml-2 align-middle text-[0.75em] text-mute-2 no-underline opacity-0 outline-none transition-opacity group-hover/h:opacity-100 focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-flare">#</a></h3> },
    // short inline code (flags, file names) never splits across lines; long paths may still wrap
    code: ({ className, children }) => <code className={className ?? (textOf(children).length <= 24 ? '!whitespace-nowrap' : undefined)}>{children}</code>,
    aside: ({ node, children }) => <Callout type={String((node?.properties as Node)?.dataCallout ?? (node?.properties as Node)?.['data-callout'] ?? 'note')}>{children}</Callout>,
    pre: ({ node }) => {
      const code = node?.children?.[0] as Node
      const cls: string[] = code?.properties?.className ?? []
      const lang = (cls.find((c) => c.startsWith('language-')) ?? '').replace('language-', '')
      const meta: string = code?.data?.meta ?? ''
      const title = /title="([^"]+)"/.exec(meta)?.[1]
      const text = (code?.children ?? []).map((c: Node) => c.value ?? '').join('').replace(/\n$/, '')
      return <CodeBlock code={text} lang={lang} title={title} />
    },
    a: ({ href = '', children }) => href.startsWith('/') && !/\.(md|txt|xml)$/.test(href) ? <Link to={href}>{children}</Link> : href.startsWith('#') ? <a href={href}>{children}</a> : <a href={href} target="_blank" rel="noreferrer">{children}</a>,
    table: ({ children }) => (
      <div className="not-prose my-7 overflow-x-auto rounded-[16px] ring-1 ring-line">
        <table className="w-full border-collapse text-left text-[15px] leading-[1.5] text-ink-2 [&_code]:rounded-[5px] [&_code]:bg-sand-2 [&_code]:px-1 [&_code]:py-px [&_code]:font-mono [&_code]:text-[0.86em] [&_code]:!whitespace-nowrap [&_td]:border-t [&_td]:border-line [&_td]:px-4 [&_td]:py-3 [&_td]:align-top [&_th]:bg-sand [&_th]:px-4 [&_th]:py-3 [&_th]:text-[14px] [&_th]:font-semibold [&_th]:text-ink [&_th]:whitespace-nowrap">{children}</table>
      </div>
    ),
  }
  return (
    <div className="prose-flare">
      <ReactMarkdown remarkPlugins={[remarkGfm, remarkCallouts]} components={components}>{source}</ReactMarkdown>
    </div>
  )
}
