import { StrictMode } from 'react'
import { createRoot, hydrateRoot } from 'react-dom/client'
import { BrowserRouter, HashRouter } from 'react-router-dom'
import { App } from './App'
import './index.css'

const Router = import.meta.env.ARTIFACT ? HashRouter : BrowserRouter
const tree = (
  <StrictMode>
    <Router><App /></Router>
  </StrictMode>
)
const root = document.getElementById('root')!
// Hydrate only HTML prerendered for this exact path; a host that falls back to another page's
// HTML (or the bare template) gets a fresh render instead of a mismatch.
const here = location.pathname.replace(/\/$/, '') || '/'
if (root.dataset.path === here && !import.meta.env.ARTIFACT) hydrateRoot(root, tree)
else { root.textContent = ''; createRoot(root).render(tree) }
