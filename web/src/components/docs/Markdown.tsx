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
            node.data = { hName: 'aside', hProperties: { 'data-callout': m[1].toLowerCase() } }
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
  tip: { label: 'Tip', skin: 'bg-[#F6FFC4] text-ink-2', dot: 'bg-[#8FA800]' },
  warning: { label: 'Careful', skin: 'bg-[#FFF0E8] text-ink-2 ring-1 ring-flare/25', dot: 'bg-flare' },
  caution: { label: 'Careful', skin: 'bg-[#FFF0E8] text-ink-2 ring-1 ring-flare/25', dot: 'bg-flare' },
  preview: { label: 'Preview', skin: 'bg-night text-white/80 [&_a]:text-white [&_strong]:text-white [&_code]:!bg-white/10 [&_code]:!text-white', dot: 'bg-volt' },
}

function Callout({ type, children }: { type: string; children: ReactNode }) {
  const c = CALLOUT[type] ?? CALLOUT.note
  return (
    <aside className={`not-prose my-7 rounded-[18px] px-5 py-4 text-[15.5px] leading-[1.6] ${c.skin}`}>
      <p className={`flex items-center gap-2 text-[12px] font-semibold uppercase tracking-[0.14em] ${type === 'preview' ? 'text-white' : 'text-ink'}`}><span className={`h-2 w-2 ${c.dot}`} />{c.label}</p>
      <div className="mt-2 [&>*+*]:mt-2 [&_a]:underline [&_a]:decoration-flare/60 [&_a]:underline-offset-2">{children}</div>
    </aside>
  )
}

export function CodeBlock({ code, lang = '', title }: { code: string; lang?: string; title?: string }) {
  const tokens = highlight(code, lang)
  const copy = /^(bash|sh|shell|zsh|console)$/.test(lang) ? code.replace(/^\$ /gm, '') : code
  return (
    <figure className="not-prose group/code my-6 overflow-hidden rounded-[18px] bg-night">
      <figcaption className="flex items-center justify-between gap-3 border-b border-white/[0.08] py-2 pl-4 pr-2">
        <span className="flex min-w-0 items-center gap-2.5 font-mono text-[12px] text-white/55">
          {lang && <span className="rounded-[5px] bg-white/10 px-1.5 py-0.5 text-[10.5px] uppercase tracking-wide text-white/70">{lang === 'bash' ? 'sh' : lang}</span>}
          {title && <span className="truncate">{title}</span>}
        </span>
        <CopyButton text={copy} tone="dark" />
      </figcaption>
      <pre className="overflow-x-auto px-4 py-4 text-[13px] leading-[1.7]"><code className="font-mono">{tokens.map(([k, v], i) => <span key={i} className={TOKEN_CLASS[k]}>{v}</span>)}</code></pre>
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
    h2: ({ children }) => { const id = anchor(children); return <h2 id={id} className="group/h relative">{children}<a href={`#${id}`} aria-label="Link to this section" className="ml-2 align-middle text-[0.7em] text-mute-3 opacity-0 transition-opacity group-hover/h:opacity-100 focus:opacity-100">#</a></h2> },
    h3: ({ children }) => { const id = anchor(children); return <h3 id={id} className="group/h relative">{children}<a href={`#${id}`} aria-label="Link to this section" className="ml-2 align-middle text-[0.75em] text-mute-3 opacity-0 transition-opacity group-hover/h:opacity-100 focus:opacity-100">#</a></h3> },
    aside: ({ node, children }) => <Callout type={String((node?.properties as Node)?.dataCallout ?? 'note')}>{children}</Callout>,
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
        <table className="w-full border-collapse text-left text-[14.5px] leading-[1.5] [&_code]:rounded [&_code]:bg-sand-2 [&_code]:px-1 [&_code]:py-px [&_code]:font-mono [&_code]:text-[0.88em] [&_code]:whitespace-nowrap [&_td]:border-t [&_td]:border-line [&_td]:px-4 [&_td]:py-3 [&_td]:align-top [&_th]:bg-sand [&_th]:px-4 [&_th]:py-3 [&_th]:font-semibold [&_th]:text-ink">{children}</table>
      </div>
    ),
  }
  return (
    <div className="prose-flare">
      <ReactMarkdown remarkPlugins={[remarkGfm, remarkCallouts]} components={components}>{source}</ReactMarkdown>
    </div>
  )
}
