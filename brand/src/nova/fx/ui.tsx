import Lenis from 'lenis'
import { animate, motion, useMotionTemplate, useMotionValue, useReducedMotion, useSpring } from 'motion/react'
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'

/** Lenis smooth scrolling for the page (off for reduced motion and screenshots). */
export function useSmoothScroll() {
  const reduce = useReducedMotion()
  useEffect(() => {
    if (reduce || isShot) return
    const lenis = new Lenis({ lerp: 0.1, wheelMultiplier: 1 })
    let raf = 0
    const loop = (t: number) => { lenis.raf(t); raf = requestAnimationFrame(loop) }
    raf = requestAnimationFrame(loop)
    ;(window as unknown as { __lenis?: Lenis }).__lenis = lenis
    return () => { cancelAnimationFrame(raf); lenis.destroy() }
  }, [reduce])
}

export function scrollToId(id: string) {
  const el = document.getElementById(id)
  if (!el) return
  const lenis = (window as unknown as { __lenis?: Lenis }).__lenis
  if (lenis) lenis.scrollTo(el, { offset: -80, duration: 1.4 })
  else el.scrollIntoView({ behavior: 'smooth' })
}

type BtnProps = {
  children: ReactNode; onClick?: () => void; variant?: 'molten' | 'glass' | 'ghost'; size?: 'md' | 'lg'
  className?: string; beam?: boolean; href?: string; ariaLabel?: string
}

/**
 * The button. Leans toward the pointer, a light follows the cursor across its face,
 * it squashes on press and throws a ripple from where you clicked.
 */
export function Button({ children, onClick, variant = 'glass', size = 'md', className, beam, ariaLabel }: BtnProps) {
  const ref = useRef<HTMLButtonElement>(null)
  const x = useSpring(0, { stiffness: 260, damping: 18 }), y = useSpring(0, { stiffness: 260, damping: 18 })
  const lx = useMotionValue(-200), ly = useMotionValue(-200)
  const light = useMotionTemplate`radial-gradient(140px circle at ${lx}px ${ly}px, rgba(255,255,255,${variant === 'molten' ? 0.45 : 0.16}), transparent 60%)`
  const [ripples, setRipples] = useState<{ id: number; x: number; y: number }[]>([])
  const reduce = useReducedMotion()

  const move = (e: React.PointerEvent) => {
    const r = ref.current!.getBoundingClientRect()
    const px = e.clientX - r.left, py = e.clientY - r.top
    lx.set(px); ly.set(py)
    if (!reduce) { x.set((px - r.width / 2) * 0.22); y.set((py - r.height / 2) * 0.3) }
  }
  const leave = () => { x.set(0); y.set(0); lx.set(-200); ly.set(-200) }
  const down = (e: React.PointerEvent) => {
    const r = ref.current!.getBoundingClientRect()
    const id = Date.now() + Math.random()
    setRipples((rs) => [...rs, { id, x: e.clientX - r.left, y: e.clientY - r.top }])
    setTimeout(() => setRipples((rs) => rs.filter((q) => q.id !== id)), 700)
  }

  const base = size === 'lg' ? 'h-14 px-7 text-[16px] rounded-[16px]' : 'h-11 px-5 text-[14.5px] rounded-[13px]'
  const skin =
    variant === 'molten'
      ? 'text-[#160803] font-semibold [background:var(--nv-molten)] shadow-[0_0_0_1px_rgba(255,255,255,.25)_inset,0_10px_40px_-10px_rgba(255,90,31,.8),0_0_80px_-20px_rgba(255,46,99,.7)]'
      : variant === 'glass'
        ? 'text-[var(--nv-text)] font-medium bg-white/[.06] backdrop-blur-xl shadow-[0_0_0_1px_rgba(255,255,255,.12)_inset,0_1px_0_rgba(255,255,255,.15)_inset]'
        : 'text-[var(--nv-mute)] hover:text-[var(--nv-text)] font-medium'

  return (
    <motion.button ref={ref} type="button" aria-label={ariaLabel} onClick={onClick}
      onPointerMove={move} onPointerLeave={leave} onPointerDown={down}
      whileTap={{ scale: 0.96 }} style={{ x, y }}
      className={cn('group relative inline-flex select-none items-center justify-center gap-2.5 overflow-hidden whitespace-nowrap outline-none transition-[filter] duration-200 focus-visible:ring-2 focus-visible:ring-[var(--nv-ion)] focus-visible:ring-offset-2 focus-visible:ring-offset-black',
        base, skin, beam && 'nv-beam', variant === 'molten' && 'nv-shimmer hover:brightness-110', className)}>
      <motion.span aria-hidden className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100" style={{ background: light }} />
      {ripples.map((r) => (
        <motion.span key={r.id} aria-hidden className="pointer-events-none absolute rounded-full"
          style={{ left: r.x, top: r.y, width: 10, height: 10, marginLeft: -5, marginTop: -5, background: variant === 'molten' ? 'rgba(255,255,255,.6)' : 'rgba(255,194,75,.45)' }}
          initial={{ scale: 0, opacity: 0.9 }} animate={{ scale: 40, opacity: 0 }} transition={{ duration: 0.65, ease: [0.16, 1, 0.3, 1] }} />
      ))}
      <span className="relative z-10 inline-flex items-center gap-2.5">{children}</span>
    </motion.button>
  )
}

/** A card whose border and surface light up where the pointer is. */
export function GlowCard({ children, className, style, glow = 'rgba(255,90,31,.55)' }: { children: ReactNode; className?: string; style?: CSSProperties; glow?: string }) {
  const mx = useMotionValue(-400), my = useMotionValue(-400)
  const border = useMotionTemplate`radial-gradient(320px circle at ${mx}px ${my}px, ${glow}, transparent 55%)`
  const surface = useMotionTemplate`radial-gradient(520px circle at ${mx}px ${my}px, rgba(255,255,255,.05), transparent 45%)`
  return (
    <div className={cn('group relative overflow-hidden rounded-[22px] bg-[var(--nv-ink-1)]', className)} style={style}
      onPointerMove={(e) => { const r = e.currentTarget.getBoundingClientRect(); mx.set(e.clientX - r.left); my.set(e.clientY - r.top) }}
      onPointerLeave={() => { mx.set(-400); my.set(-400) }}>
      <div aria-hidden className="pointer-events-none absolute inset-0 rounded-[inherit] shadow-[inset_0_0_0_1px_var(--nv-line)]" />
      <motion.div aria-hidden className="pointer-events-none absolute inset-0 rounded-[inherit] p-px opacity-0 transition-opacity duration-300 group-hover:opacity-100"
        style={{ background: border, WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)', WebkitMaskComposite: 'xor', maskComposite: 'exclude' }} />
      <motion.div aria-hidden className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100" style={{ background: surface }} />
      <div className="relative">{children}</div>
    </div>
  )
}

const GLYPHS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

/** Cycles through words with a scramble between each (the "format" in the headline). */
export function Morph({ words, interval = 2200, className }: { words: string[]; interval?: number; className?: string }) {
  const [i, setI] = useState(0)
  const [text, setText] = useState(words[0])
  const reduce = useReducedMotion()
  useEffect(() => {
    if (isShot || reduce) return
    const t = setInterval(() => setI((n) => (n + 1) % words.length), interval)
    return () => clearInterval(t)
  }, [words.length, interval, reduce])
  useEffect(() => {
    const target = words[i]
    if (isShot || reduce) { setText(target); return }
    let frame = 0
    const total = 14
    const id = setInterval(() => {
      frame++
      const reveal = Math.floor((frame / total) * target.length)
      setText(target.split('').map((c, k) => (k < reveal ? c : GLYPHS[Math.floor(Math.random() * GLYPHS.length)])).join(''))
      if (frame >= total) { clearInterval(id); setText(target) }
    }, 38)
    return () => clearInterval(id)
  }, [i, words, reduce])
  return <span className={className}>{text}</span>
}

/** Splits a line into letters that rise and un-blur in sequence. */
export function Letters({ text, delay = 0, className, stagger = 0.028 }: { text: string; delay?: number; className?: string; stagger?: number }) {
  const reduce = useReducedMotion()
  return (
    <span className={className} aria-label={text}>
      {text.split('').map((ch, i) => (
        <motion.span key={i} aria-hidden className="inline-block whitespace-pre"
          initial={isShot || reduce ? false : { y: '0.5em', opacity: 0, filter: 'blur(12px)' }}
          animate={{ y: 0, opacity: 1, filter: 'blur(0px)' }}
          transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1], delay: delay + i * stagger }}>
          {ch}
        </motion.span>
      ))}
    </span>
  )
}

/** Fade-up on enter, once. */
export function Rise({ children, delay = 0, className }: { children: ReactNode; delay?: number; className?: string }) {
  const reduce = useReducedMotion()
  if (isShot) return <div className={className}>{children}</div>
  return (
    <motion.div className={className} initial={{ opacity: 0, y: reduce ? 0 : 28, filter: 'blur(8px)' }}
      whileInView={{ opacity: 1, y: 0, filter: 'blur(0px)' }} viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1], delay }}>
      {children}
    </motion.div>
  )
}

/** A keyboard key that presses when the real key does. */
export function LiveKey({ k, label, code, className }: { k: string; label: string; code: 'Shift' | 'Meta' | 'Control'; className?: string }) {
  const [down, setDown] = useState(false)
  useEffect(() => {
    const d = (e: KeyboardEvent) => { if (e.key === code) setDown(true) }
    const u = (e: KeyboardEvent) => { if (e.key === code) setDown(false) }
    window.addEventListener('keydown', d); window.addEventListener('keyup', u)
    return () => { window.removeEventListener('keydown', d); window.removeEventListener('keyup', u) }
  }, [code])
  return (
    <motion.span animate={{ y: down ? 2 : 0 }} transition={{ type: 'spring', stiffness: 800, damping: 30 }}
      className={cn('inline-flex h-8 min-w-8 flex-col items-center justify-center rounded-[8px] px-1.5 text-[13px] leading-none transition-colors', className)}
      style={{
        background: down ? 'var(--nv-molten)' : 'linear-gradient(180deg,#22222e,#15151d)', color: down ? '#160803' : 'var(--nv-text)',
        boxShadow: down ? '0 0 24px -4px rgba(255,90,31,.8), inset 0 1px 0 rgba(255,255,255,.4)' : 'inset 0 1px 0 rgba(255,255,255,.12), inset 0 -2px 0 rgba(0,0,0,.5), 0 0 0 1px rgba(255,255,255,.08)',
      }}>
      <span>{k}</span>
      <span className="nv-mono mt-0.5 text-[7.5px] uppercase opacity-60">{label}</span>
    </motion.span>
  )
}

/** Animates a number from 0 when the element mounts (used inside already-revealed blocks). */
export function useCountUp(target: number, run: boolean, duration = 1.6) {
  const [v, setV] = useState(isShot ? target : 0)
  useEffect(() => {
    if (!run || isShot) return
    const c = animate(0, target, { duration, ease: [0.16, 1, 0.3, 1], onUpdate: (n) => setV(n) })
    return () => c.stop()
  }, [run, target, duration])
  return v
}
