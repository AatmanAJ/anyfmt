import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  server: { port: 5199, strictPort: true },
  // Pre-bundle everything up front so adding a package never splits React into two copies mid-session.
  optimizeDeps: {
    include: ['react', 'react-dom', 'react-dom/client', 'react-router-dom', 'motion/react', 'lucide-react', '@paper-design/shaders-react', '@number-flow/react', 'sonner', 'lenis', 'ogl', 'canvas-confetti'],
  },
})
