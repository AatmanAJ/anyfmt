/** Server entry for the prerenderer: renders one URL to HTML and reports the page's head tags. */
import { prerenderToNodeStream } from 'react-dom/static'
import { StaticRouter } from 'react-router'
import { App } from './App'
import { HeadContext, headTags, type HeadData } from './lib/head'

export { allPaths } from './paths'
export { machineFiles } from './machine'

export async function render(url: string) {
  const head: { current: HeadData | null } = { current: null }
  const { prelude } = await prerenderToNodeStream(
    <HeadContext.Provider value={head}>
      <StaticRouter location={url}><App /></StaticRouter>
    </HeadContext.Provider>,
  )
  let html = ''
  const decoder = new TextDecoder()
  for await (const chunk of prelude as unknown as AsyncIterable<Uint8Array | string>) html += typeof chunk === "string" ? chunk : decoder.decode(chunk, { stream: true })
  return { html, head: head.current ? headTags(head.current) : '', meta: head.current }
}
