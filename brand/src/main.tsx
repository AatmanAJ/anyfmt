import { StrictMode, Suspense, lazy, useEffect, useMemo } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter, Route, Routes, useLocation, useParams } from 'react-router-dom'
import './index.css'
import { Hub } from './hub/Hub'
import { loaders } from './directions/registry'
import { DirectionBar } from './shared/DirectionBar'

function ScrollTop() {
  const { pathname } = useLocation()
  useEffect(() => { if (!location.hash.includes('#', 1)) window.scrollTo(0, 0) }, [pathname])
  return null
}

function DirectionPage({ view }: { view: 'book' | 'landing' }) {
  const { id = '' } = useParams()
  const Page = useMemo(() => {
    const load = loaders[id]
    if (!load) return () => <div className="p-10">Unknown direction “{id}”.</div>
    return lazy(() => load().then((m) => ({ default: view === 'book' ? m.default.BrandBook : m.default.Landing })))
  }, [id, view])
  return (
    <>
      <Suspense fallback={<div className="min-h-screen bg-neutral-950" />}>
        <Page />
      </Suspense>
      <DirectionBar id={id} view={view} />
    </>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <HashRouter>
      <ScrollTop />
      <Routes>
        <Route path="/" element={<Hub />} />
        <Route path="/d/:id" element={<DirectionPage view="book" />} />
        <Route path="/d/:id/landing" element={<DirectionPage view="landing" />} />
      </Routes>
    </HashRouter>
  </StrictMode>,
)
