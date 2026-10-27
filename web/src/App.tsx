import { lazy, Suspense, useEffect } from 'react'
import { Route, Routes, useLocation } from 'react-router-dom'
import { prefersReducedMotion } from './lib/hooks'

const Home = lazy(() => import('./pages/Home'))
const NotFound = lazy(() => import('./pages/NotFound'))
const Pricing = lazy(() => import('./pages/Pricing'))
const Changelog = lazy(() => import('./pages/Changelog'))
const Docs = lazy(() => import('./pages/Docs'))
const Formats = lazy(() => import('./pages/Formats'))
const Download = lazy(() => import('./pages/Download'))
const Brand = lazy(() => import('./pages/Brand'))
const Contact = lazy(() => import('./pages/Contact'))
const CompareHub = lazy(() => import('./pages/Compare').then((m) => ({ default: m.CompareHub })))
const ComparePage = lazy(() => import('./pages/Compare').then((m) => ({ default: m.ComparePage })))
const GuidesHub = lazy(() => import('./pages/Guide').then((m) => ({ default: m.GuidesHub })))
const GuidePage = lazy(() => import('./pages/Guide').then((m) => ({ default: m.GuidePage })))
const OpenSource = lazy(() => import('./pages/OpenSource'))
const Privacy = lazy(() => import('./pages/Legal').then((m) => ({ default: m.Privacy })))
const Terms = lazy(() => import('./pages/Legal').then((m) => ({ default: m.Terms })))

function ScrollManager() {
  const { pathname, hash } = useLocation()
  useEffect(() => {
    if (hash) {
      const el = document.getElementById(decodeURIComponent(hash.slice(1)))
      if (el) { el.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth' }); return }
    }
    window.scrollTo(0, 0)
  }, [pathname, hash])
  return null
}

export function App() {
  return (
    <>
      <ScrollManager />
      <Suspense fallback={<div className="min-h-screen bg-white" />}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/download" element={<Download />} />
          <Route path="/brand" element={<Brand />} />
          <Route path="/contact" element={<Contact />} />
          <Route path="/compare" element={<CompareHub />} />
          <Route path="/compare/:slug" element={<ComparePage />} />
          <Route path="/convert" element={<GuidesHub />} />
          <Route path="/convert/:slug" element={<GuidePage />} />
          <Route path="/open-source" element={<OpenSource />} />
          <Route path="/privacy" element={<Privacy />} />
          <Route path="/terms" element={<Terms />} />
          <Route path="/formats" element={<Formats />} />
          <Route path="/pricing" element={<Pricing />} />
          <Route path="/changelog" element={<Changelog />} />
          <Route path="/docs" element={<Docs />} />
          <Route path="/docs/:slug" element={<Docs />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Suspense>
    </>
  )
}
