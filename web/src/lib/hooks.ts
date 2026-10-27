import { useEffect, useState, useSyncExternalStore } from 'react'

/** False on the server and during hydration, true after: gates WebGPU and other browser-only work. */
export function useHydrated() {
  const [h, setH] = useState(false)
  useEffect(() => setH(true), [])
  return h
}

const mq = (q: string) => (cb: () => void) => {
  const m = window.matchMedia(q)
  m.addEventListener('change', cb)
  return () => m.removeEventListener('change', cb)
}
export function useMedia(q: string, server = false) {
  return useSyncExternalStore(mq(q), () => window.matchMedia(q).matches, () => server)
}

export const prefersReducedMotion = () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Copy text; returns whether it worked. Falls back to a hidden textarea where the API is refused. */
export async function copyText(text: string) {
  try { await navigator.clipboard.writeText(text); return true } catch { /* fall through */ }
  try {
    const t = document.createElement('textarea')
    t.value = text; t.setAttribute('readonly', ''); t.style.position = 'fixed'; t.style.opacity = '0'
    document.body.appendChild(t); t.select()
    const ok = document.execCommand('copy'); t.remove(); return ok
  } catch { return false }
}

export const EASE = [0.22, 1, 0.36, 1] as const
export const SNAP = 'cubic-bezier(0.785,0.135,0.15,0.86)'
