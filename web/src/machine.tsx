/**
 * Files written beside the HTML for crawlers, feed readers and agents: the changelog RSS, and
 * (from the docs) llms.txt, llms-full.txt and a Markdown twin of every docs page.
 */
import { renderToStaticMarkup } from 'react-dom/server'
import { AppIcon } from './components/AppIcon'
import { RELEASES } from './data/changelog'
import { DOCS, docAsMarkdown, llmsFull, llmsTxt } from './lib/docs'

function changelogFeed(site: string) {
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const items = RELEASES.filter((r) => r.date).map((r) => `    <item>
      <title>${esc(`${r.version}: ${r.title}`)}</title>
      <link>${site}/changelog#${r.version.toLowerCase().replace(/\s+/g, '-')}</link>
      <guid isPermaLink="false">anyfmt-${r.version.toLowerCase().replace(/\s+/g, '-')}</guid>
      <pubDate>${new Date(r.date + 'T12:00:00Z').toUTCString()}</pubDate>
      <description>${esc(r.summary + ' ' + r.entries.map((e) => `${e.title}.`).join(' '))}</description>
    </item>`).join('\n')
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>anyfmt changelog</title>
    <link>${site}/changelog</link>
    <description>Every anyfmt build, newest first.</description>
    <language>en</language>
${items}
  </channel>
</rss>
`
}

export function machineFiles(): Record<string, string> {
  const site = 'https://anyfmt.app'
  const files: Record<string, string> = { 'changelog.xml': changelogFeed(site), 'llms.txt': llmsTxt(), 'llms-full.txt': llmsFull() }
  for (const d of DOCS) files[`docs/${d.slug}.md`] = docAsMarkdown(d)
  files['brand/anyfmt-icon.svg'] = renderToStaticMarkup(AppIcon({ size: 1024, uid: 'icon' })).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ')
  return files
}
