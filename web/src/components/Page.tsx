import type { ReactNode } from 'react'
import { Footer } from './Footer'
import { Nav } from './Nav'

/** Every page: skip link, the nav (light or dark over its hero), content, footer. */
export function Page({ children, nav = 'light', className = 'bg-white' }: { children: ReactNode; nav?: 'light' | 'dark'; className?: string }) {
  return (
    <div className={`min-h-screen text-ink antialiased ${className}`}>
      <a href="#main" className="sr-only z-50 rounded-full bg-ink px-4 py-2 text-white focus:not-sr-only focus:fixed focus:left-4 focus:top-4">Skip to content</a>
      <Nav tone={nav} />
      <main id="main">{children}</main>
      <Footer />
    </div>
  )
}
