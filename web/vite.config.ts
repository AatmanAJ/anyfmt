import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// `--mode artifact` builds a single-origin bundle with hash routing, for previews hosted as a Claude artifact.
export default defineConfig(({ mode }) => ({
  base: mode === 'artifact' ? './' : '/',
  plugins: [react(), tailwindcss()],
  define: { 'import.meta.env.ARTIFACT': JSON.stringify(mode === 'artifact') },
  server: { port: 5310, strictPort: true },
  ssr: { noExternal: ['shaders', '@number-flow/react', 'number-flow', 'react-markdown', 'remark-gfm'] },
}))
