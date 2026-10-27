/**
 * The flute shader, mounted only in the browser. Server HTML and the first client render show
 * the static CSS ribs, so prerendered pages paint instantly; WebGPU fades in over them.
 */
import { lazy, Suspense } from 'react'
import { useHydrated } from '../lib/hooks'
import type { FluteShaderProps } from './FluteShader'

const Shader = lazy(() => import('./FluteShader').then((m) => ({ default: m.FluteShader })))

export function Flutes({ className = '', variant = 'light', corner = 'tr', angle }: FluteShaderProps) {
  const hydrated = useHydrated() && typeof navigator !== 'undefined' && 'gpu' in navigator
  const still = variant === 'light' ? 'flutes-static' : 'flutes-static-dark'
  return (
    <div aria-hidden className={className}>
      <div className={`absolute inset-0 ${still}`} />
      {hydrated && (
        <Suspense fallback={null}>
          <div className="absolute inset-0 animate-[fadein_1.2s_ease_forwards] opacity-0">
            <Shader className="absolute inset-0" variant={variant} corner={corner} angle={angle} />
          </div>
        </Suspense>
      )}
      <style>{'@keyframes fadein{to{opacity:1}}'}</style>
    </div>
  )
}
