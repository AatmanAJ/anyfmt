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
// Hydrate only HTML prerendered for this exact path and not re-formatted since. A host that falls
// back to another page's HTML, or rewrites it, gets a fresh render instead of a mismatch.
const here = location.pathname.replace(/\/$/, '') || '/'
// React's markup starts with its own node; a re-formatter puts whitespace text first
const first = root.firstChild
const reformatted = !!first && first.nodeType === Node.TEXT_NODE && !first.textContent?.trim()
const untouched = root.dataset.path === here && !reformatted
if (untouched && !import.meta.env.ARTIFACT) hydrateRoot(root, tree)
else { root.textContent = ''; createRoot(root).render(tree) }
