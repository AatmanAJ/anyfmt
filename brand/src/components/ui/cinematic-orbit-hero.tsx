/**
 * Cinematic Orbit Hero (21st.dev, by daiwiikharihar): a stack of cards fans out into a 3D
 * elliptical orbit as you scroll, with depth scaling and pointer parallax.
 *
 * anyfmt changes: cards are any ReactNode, copy and colours are props, a call-to-action slot.
 */

import { motion, useMotionValue, useMotionValueEvent, useReducedMotion, useScroll, useSpring, useTransform, type MotionValue } from "motion/react"
import { useEffect, useRef, useState, type ReactNode } from "react"

type Orbit = {
  node: ReactNode
  /** Opacity at the end of the spread: the back of the orbit recedes behind the copy. */
  fade: number
  linearOffset: { x: number; y: number }
  linearRotate: number
  target: { x: number; y: number; rotate: number; scale: number; w: number; h: number }
  targetSm: { x: number; y: number; rotate: number; scale: number; w: number; h: number }
  z: number
}

function layout(nodes: ReactNode[]): Orbit[] {
  const radiusX = 42, radiusY = 17, total = nodes.length
  return nodes.map((node, i) => {
    // Half-step offset so no card parks dead centre over the headline or the buttons.
    const angle = ((i + 0.5) * (Math.PI * 2)) / total
    const x = Math.cos(angle - Math.PI / 2) * radiusX
    const y = Math.sin(angle - Math.PI / 2) * radiusY
    const depth = Math.sin(angle - Math.PI / 2)
    const scale = 0.8 + depth * 0.25
    const rotate = Math.cos(angle - Math.PI / 2) * 15
    return {
      node,
      fade: 0.3 + 0.7 * ((depth + 1) / 2) ** 0.6,
      linearOffset: { x: (i - total / 2) * 4, y: (i - total / 2) * 3 },
      linearRotate: (i - total / 2) * 3,
      target: { x, y: y + 12, rotate, scale, w: 12, h: 19 },
      targetSm: { x: x * 0.85, y: y * 1.9 + 8, rotate, scale, w: 22, h: 14 },
      z: Math.round((depth + 1) * 100),
    }
  })
}

const SPRING_CONFIG = { stiffness: 40, damping: 25, mass: 1 }
const PROGRESS_SPRING = { stiffness: 60, damping: 30, restDelta: 0.001 }

function usePointerParallax(active: boolean, enabled: boolean) {
  const rawX = useMotionValue(0), rawY = useMotionValue(0)
  const x = useSpring(rawX, SPRING_CONFIG), y = useSpring(rawY, SPRING_CONFIG)
  useEffect(() => {
    if (!enabled || !active) return
    const onMove = (e: PointerEvent) => {
      rawX.set((e.clientX / window.innerWidth - 0.5) * 2)
      rawY.set((e.clientY / window.innerHeight - 0.5) * 2)
    }
    window.addEventListener("pointermove", onMove, { passive: true })
    return () => window.removeEventListener("pointermove", onMove)
  }, [active, enabled, rawX, rawY])
  return { x, y }
}

function Card({ card, progress, pointer, isSpreadActive, isMobile }: {
  card: Orbit; progress: MotionValue<number>; pointer: { x: MotionValue<number>; y: MotionValue<number> }; isSpreadActive: boolean; isMobile: boolean
}) {
  const { linearOffset, linearRotate, z } = card
  const t = isMobile ? card.targetSm : card.target
  const depthFactor = 0.2 + z / 200
  const translate = useTransform([progress, pointer.x, pointer.y], ([p, px, py]: number[]) => {
    const e = p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2
    const tx = linearOffset.x + (t.x - linearOffset.x) * e
    const ty = linearOffset.y + (t.y - linearOffset.y) * e
    return `calc(-50% + ${tx - px * 5 * depthFactor * p}vw) calc(-50% + ${ty - py * 5 * depthFactor * p}vh)`
  })
  const rotate = useTransform(progress, [0, 1], [linearRotate, t.rotate])
  const scale = useTransform(progress, [0, 1], [0.6, t.scale])
  const opacity = useTransform(progress, [0, 1], [1, card.fade])
  return (
    <motion.div
      className="absolute left-1/2 top-1/2 cursor-pointer will-change-transform"
      style={{ width: `${t.w}vw`, height: `${t.h}vh`, zIndex: z, translate, rotate, scale, opacity }}
      whileHover={isSpreadActive ? { scale: t.scale * 1.15, zIndex: 999, opacity: 1, transition: SPRING_CONFIG } : undefined}
    >
      <div className="relative h-full w-full overflow-hidden rounded-2xl shadow-xl shadow-black/20 ring-1 ring-black/5 transition-shadow duration-500 hover:shadow-2xl hover:shadow-black/40">
        {card.node}
      </div>
    </motion.div>
  )
}

export interface CinematicOrbitHeroProps {
  cards: ReactNode[]
  title: ReactNode
  body?: ReactNode
  actions?: ReactNode
  background?: string
  foreground?: string
  glow?: string
  intro?: ReactNode
}

export default function CinematicOrbitHero({ cards, title, body, actions, background = "#F8FAFC", foreground = "#111", glow = "rgba(253,164,175,.4)", intro }: CinematicOrbitHeroProps) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const [isMobile, setIsMobile] = useState(false)
  const [orbit] = useState(() => layout(cards))

  useEffect(() => {
    const onResize = () => setIsMobile(window.innerWidth < 768)
    onResize()
    window.addEventListener("resize", onResize)
    return () => window.removeEventListener("resize", onResize)
  }, [])

  const { scrollYProgress } = useScroll({ target: wrapRef, offset: ["start start", "end end"] })
  const smooth = useSpring(scrollYProgress, PROGRESS_SPRING)
  const progress = useTransform(smooth, [0.1, 0.9], [0, 1])
  const [spread, setSpread] = useState(false)
  useMotionValueEvent(progress, "change", (p) => setSpread(p > 0.95))

  const pointer = usePointerParallax(spread, !reduce)
  const textScale = useTransform(progress, [0, 1], [0.85, 1])
  const textOpacity = useTransform(progress, [0.2, 0.8], [0, 1])
  const introOpacity = useTransform(progress, [0, 0.15], [1, 0])

  return (
    <section ref={wrapRef} className="relative h-[350vh] w-full" style={{ background, color: foreground }}>
      <div className="sticky top-0 flex h-[100svh] w-full items-center justify-center overflow-hidden">
        <motion.div className="pointer-events-none absolute inset-0 flex items-center justify-center blur-[110px]" style={{ scale: textScale }}>
          <div className="h-[60vw] w-[60vw] rounded-full md:h-[40vw] md:w-[40vw]" style={{ background: glow }} />
        </motion.div>
        {intro && <motion.div className="pointer-events-none absolute inset-x-0 bottom-[8vh] z-[6] flex justify-center" style={{ opacity: introOpacity }}>{intro}</motion.div>}
        {/* z 100 sits between the back of the orbit (z < 100) and the front (z > 100). */}
        <motion.div className="z-[100] mt-[-10vh] flex flex-col items-center px-6 text-center" style={{ opacity: textOpacity, scale: textScale }}>
          {title}
          {body}
          {actions && <div className="mt-8">{actions}</div>}
        </motion.div>
        <div className="pointer-events-none absolute inset-0 [&>*]:pointer-events-auto">
          {orbit.map((card, i) => <Card key={i} card={card} progress={progress} pointer={pointer} isSpreadActive={spread} isMobile={isMobile} />)}
        </div>
      </div>
    </section>
  )
}
