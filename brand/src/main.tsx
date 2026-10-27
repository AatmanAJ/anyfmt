import { StrictMode, Suspense, lazy, useEffect, useMemo } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter, Route, Routes, useLocation, useParams } from 'react-router-dom'
import './index.css'
import { Hub } from './hub/Hub'
import { loaders } from './directions/registry'
import { DirectionBar } from './shared/DirectionBar'

const AnyfmtLanding = lazy(() => import('./anyfmt/Landing'))
const BlockPreview = lazy(() => import('./block/Preview'))
const BlockLanding = lazy(() => import('./block/Landing'))
const BlockBook = lazy(() => import('./block/BrandBook'))
const SheetLanding = lazy(() => import('./sheet/Landing'))
const SheetBook = lazy(() => import('./sheet/BrandBook'))
const SheetPreview = lazy(() => import('./sheet/Preview'))
const NovaLanding = lazy(() => import('./nova/Landing'))
const LiquidLanding = lazy(() => import('./liquid/Landing'))
const HeroIndex = lazy(() => import('./heroes/Heroes').then((m) => ({ default: m.HeroIndex })))
const HeroPage = lazy(() => import('./heroes/Heroes').then((m) => ({ default: m.HeroPage })))
const AnyfmtBook = lazy(() => import('./anyfmt/BrandBook'))
const RasterPage = lazy(() => import('./raster/Raster'))
const SitePage = lazy(() => import('./raster/Site'))

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
        <Route path="/heroes" element={<Suspense fallback={<div className="min-h-screen bg-[#0B0B0D]" />}><HeroIndex /></Suspense>} />
        <Route path="/heroes/:n" element={<Suspense fallback={<div className="min-h-screen bg-[#0B0B0D]" />}><HeroPage /></Suspense>} />
        <Route path="/site" element={<Suspense fallback={<div className="min-h-screen bg-[#0A0A0A]" />}><SitePage /></Suspense>} />
        <Route path="/raster" element={<Suspense fallback={<div className="min-h-screen bg-[#0A0A0A]" />}><RasterPage /></Suspense>} />
        <Route path="/raster/:n" element={<Suspense fallback={<div className="min-h-screen bg-[#0A0A0A]" />}><RasterPage /></Suspense>} />
        <Route path="/liquid" element={<Suspense fallback={<div className="min-h-screen bg-[#ECEAE6]" />}><LiquidLanding /></Suspense>} />
        <Route path="/nova" element={<Suspense fallback={<div className="min-h-screen bg-[#050507]" />}><NovaLanding /></Suspense>} />
        <Route path="/sheet" element={<Suspense fallback={<div className="min-h-screen bg-white" />}><SheetLanding /></Suspense>} />
        <Route path="/sheet/book" element={<Suspense fallback={<div className="min-h-screen bg-white" />}><SheetBook /></Suspense>} />
        <Route path="/sheet/preview" element={<Suspense fallback={null}><SheetPreview /></Suspense>} />
        <Route path="/block" element={<Suspense fallback={<div className="min-h-screen bg-[#0E0E10]" />}><BlockLanding /></Suspense>} />
        <Route path="/block/book" element={<Suspense fallback={<div className="min-h-screen bg-[#0E0E10]" />}><BlockBook /></Suspense>} />
        <Route path="/block/preview" element={<Suspense fallback={null}><BlockPreview /></Suspense>} />
        <Route path="/anyfmt" element={<Suspense fallback={<div className="min-h-screen bg-[#F7F7F7]" />}><AnyfmtLanding /></Suspense>} />
        <Route path="/anyfmt/book" element={<Suspense fallback={<div className="min-h-screen bg-[#F7F7F7]" />}><AnyfmtBook /></Suspense>} />
        <Route path="/d/:id" element={<DirectionPage view="book" />} />
        <Route path="/d/:id/landing" element={<DirectionPage view="landing" />} />
      </Routes>
    </HashRouter>
  </StrictMode>,
)
