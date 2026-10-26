import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'

/** Renders a fixed-size stage scaled to the container's width (never above `max`). */
/** `min` lets narrow screens crop the stage's sides instead of shrinking it further. */
export function Scaled({ width, height, max = 1, min = 0, children, className }: { width: number; height: number; max?: number; min?: number; children: ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [k, setK] = useState(1)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const fit = () => setK(Math.max(min, Math.min(max, el.clientWidth / width)))
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    return () => ro.disconnect()
  }, [width, max, min])
  return (
    <div ref={ref} className={className} style={{ width: '100%', height: height * k, position: 'relative' }}>
      <div style={{ width, height, transform: `scale(${k})`, transformOrigin: '0 0', position: 'absolute', left: '50%', marginLeft: -(width * k) / 2, top: 0 }}>
        {children}
      </div>
    </div>
  )
}
