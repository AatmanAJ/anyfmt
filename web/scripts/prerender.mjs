// Writes one real HTML file per route (dist/<path>/index.html) from the SSR bundle, plus the
// files crawlers and agents read: sitemap.xml, robots.txt, llms.txt, llms-full.txt, the docs as
// Markdown twins (/docs/<slug>.md) and the changelog feed.
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(root, 'dist')
const server = await import(pathToFileURL(join(root, 'dist-ssr', 'entry-server.js')).href)
const template = readFileSync(join(dist, 'index.html'), 'utf8')
const SITE = 'https://anyfmt.app'

const paths = server.allPaths()
let n = 0
for (const path of paths) {
  const { html, head } = await server.render(path)
  const page = template.replace('<!--head-->', head).replace('<div id="root"><!--app-->', `<div id="root" data-path="${path}">${html}`)
  const file = path === '/' ? join(dist, 'index.html') : join(dist, path.replace(/^\//, ''), 'index.html')
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, page)
  n++
}
// a 404 page for hosts that serve one
{
  const { html, head } = await server.render('/__not-found__')
  writeFileSync(join(dist, '404.html'), template.replace('<!--head-->', head).replace('<!--app-->', html))
}

const today = new Date().toISOString().slice(0, 10)
writeFileSync(join(dist, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${paths.map((p) => `  <url><loc>${SITE}${p === '/' ? '/' : p}</loc><lastmod>${today}</lastmod></url>`).join('\n')}\n</urlset>\n`)
writeFileSync(join(dist, 'robots.txt'), `# Crawlers and AI agents are welcome. Docs are also served as Markdown (append .md).\nUser-agent: *\nAllow: /\n\nSitemap: ${SITE}/sitemap.xml\n`)

if (server.machineFiles) {
  for (const [name, body] of Object.entries(server.machineFiles())) {
    const file = join(dist, name)
    mkdirSync(dirname(file), { recursive: true })
    writeFileSync(file, body)
  }
}
rmSync(join(root, 'dist-ssr'), { recursive: true, force: true })
console.log(`prerender: ${n} pages${existsSync(join(dist, 'llms.txt')) ? ', llms.txt' : ''}, sitemap.xml, robots.txt`)
