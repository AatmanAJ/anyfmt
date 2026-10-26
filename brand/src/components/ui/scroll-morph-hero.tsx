/**
 * Scroll Morph Hero (21st.dev, by prashantsom75): cards scatter, line up, close into a circle,
 * then a scroll morphs the circle into an arc you can shuffle through.
 *
 * anyfmt changes: framer-motion → motion/react; cards are any ReactNode instead of photos;
 * copy, colours and a call-to-action slot are props; the circle waits for the first scroll.
 */

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { motion, useMotionValue, useSpring, useTransform } from "motion/react"

export type AnimationPhase = "scatter" | "line" | "circle"

type Target = { x: number; y: number; rotation: number; scale: number; opacity: number }

const CARD_W = 72
const CARD_H = 100
const MAX_SCROLL = 3000

function FlipCard({ front, back, target }: { front: ReactNode; back: ReactNode; target: Target }) {
  return (
    <motion.div
      animate={{ x: target.x, y: target.y, rotate: target.rotation, scale: target.scale, opacity: target.opacity }}
      transition={{ type: "spring", stiffness: 40, damping: 15 }}
      style={{ position: "absolute", width: CARD_W, height: CARD_H, transformStyle: "preserve-3d", perspective: "1000px" }}
      className="group cursor-pointer"
    >
      <motion.div
        className="relative h-full w-full"
        style={{ transformStyle: "preserve-3d" }}
        transition={{ duration: 0.6, type: "spring", stiffness: 260, damping: 20 }}
        whileHover={{ rotateY: 180 }}
      >
        <div className="absolute inset-0 h-full w-full overflow-hidden rounded-xl shadow-lg" style={{ backfaceVisibility: "hidden" }}>
          {front}
        </div>
        <div
          className="absolute inset-0 flex h-full w-full flex-col items-center justify-center overflow-hidden rounded-xl bg-[#111] p-2 shadow-lg ring-1 ring-white/10"
          style={{ backfaceVisibility: "hidden", transform: "rotateY(180deg)" }}
        >
          {back}
        </div>
      </motion.div>
    </motion.div>
  )
}

const lerp = (a: number, b: number, t: number) => a * (1 - t) + b * t

export interface ScrollMorphHeroProps {
  cards: { key: string; front: ReactNode; back: ReactNode }[]
  introTitle: ReactNode
  introHint?: string
  arcTitle: ReactNode
  arcBody?: ReactNode
  arcActions?: ReactNode
  background?: string
  className?: string
}

export default function ScrollMorphHero({ cards, introTitle, introHint = "SCROLL TO EXPLORE", arcTitle, arcBody, arcActions, background = "#FAFAFA", className }: ScrollMorphHeroProps) {
  const total = cards.length
  const [introPhase, setIntroPhase] = useState<AnimationPhase>("scatter")
  const [containerSize, setContainerSize] = useState({ width: 0, height: 0 })
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!containerRef.current) return
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) setContainerSize({ width: entry.contentRect.width, height: entry.contentRect.height })
    })
    observer.observe(containerRef.current)
    setContainerSize({ width: containerRef.current.offsetWidth, height: containerRef.current.offsetHeight })
    return () => observer.disconnect()
  }, [])

  const virtualScroll = useMotionValue(0)
  const scrollRef = useRef(0)

  useEffect(() => {
    const container = containerRef.current
    if (!container) return
    const handleWheel = (e: WheelEvent) => {
      e.preventDefault()
      const next = Math.min(Math.max(scrollRef.current + e.deltaY, 0), MAX_SCROLL)
      scrollRef.current = next
      virtualScroll.set(next)
    }
    let touchStartY = 0
    const handleTouchStart = (e: TouchEvent) => { touchStartY = e.touches[0].clientY }
    const handleTouchMove = (e: TouchEvent) => {
      const touchY = e.touches[0].clientY
      const deltaY = touchStartY - touchY
      touchStartY = touchY
      const next = Math.min(Math.max(scrollRef.current + deltaY, 0), MAX_SCROLL)
      scrollRef.current = next
      virtualScroll.set(next)
    }
    container.addEventListener("wheel", handleWheel, { passive: false })
    container.addEventListener("touchstart", handleTouchStart, { passive: false })
    container.addEventListener("touchmove", handleTouchMove, { passive: false })
    return () => {
      container.removeEventListener("wheel", handleWheel)
      container.removeEventListener("touchstart", handleTouchStart)
      container.removeEventListener("touchmove", handleTouchMove)
    }
  }, [virtualScroll])

  const morphProgress = useTransform(virtualScroll, [0, 600], [0, 1])
  const smoothMorph = useSpring(morphProgress, { stiffness: 40, damping: 20 })
  const scrollRotate = useTransform(virtualScroll, [600, 3000], [0, 360])
  const smoothScrollRotate = useSpring(scrollRotate, { stiffness: 40, damping: 20 })

  const mouseX = useMotionValue(0)
  const smoothMouseX = useSpring(mouseX, { stiffness: 30, damping: 20 })
  useEffect(() => {
    const container = containerRef.current
    if (!container) return
    const handleMouseMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect()
      mouseX.set(((e.clientX - rect.left) / rect.width * 2 - 1) * 100)
    }
    container.addEventListener("mousemove", handleMouseMove)
    return () => container.removeEventListener("mousemove", handleMouseMove)
  }, [mouseX])

  useEffect(() => {
    const t1 = setTimeout(() => setIntroPhase("line"), 500)
    const t2 = setTimeout(() => setIntroPhase("circle"), 2500)
    return () => { clearTimeout(t1); clearTimeout(t2) }
  }, [])

  const scatterPositions = useMemo(() => cards.map(() => ({
    x: (Math.random() - 0.5) * 1500, y: (Math.random() - 0.5) * 1000, rotation: (Math.random() - 0.5) * 180, scale: 0.6, opacity: 0,
  })), [cards])

  const [morphValue, setMorphValue] = useState(0)
  const [rotateValue, setRotateValue] = useState(0)
  const [parallaxValue, setParallaxValue] = useState(0)
  useEffect(() => {
    const a = smoothMorph.on("change", setMorphValue)
    const b = smoothScrollRotate.on("change", setRotateValue)
    const c = smoothMouseX.on("change", setParallaxValue)
    return () => { a(); b(); c() }
  }, [smoothMorph, smoothScrollRotate, smoothMouseX])

  const contentOpacity = useTransform(smoothMorph, [0.8, 1], [0, 1])
  const contentY = useTransform(smoothMorph, [0.8, 1], [20, 0])

  return (
    <div ref={containerRef} className={`relative h-full w-full overflow-hidden ${className ?? ""}`} style={{ background }}>
      <div className="flex h-full w-full flex-col items-center justify-center" style={{ perspective: 1000 }}>
        <div className="pointer-events-none absolute top-1/2 z-0 flex -translate-y-1/2 flex-col items-center justify-center px-6 text-center">
          <motion.div
            initial={{ opacity: 0, y: 20, filter: "blur(10px)" }}
            animate={introPhase === "circle" && morphValue < 0.5 ? { opacity: 1 - morphValue * 2, y: 0, filter: "blur(0px)" } : { opacity: 0, filter: "blur(10px)" }}
            transition={{ duration: 1 }}
          >
            {introTitle}
          </motion.div>
          <motion.p
            initial={{ opacity: 0 }}
            animate={introPhase === "circle" && morphValue < 0.5 ? { opacity: 0.5 - morphValue } : { opacity: 0 }}
            transition={{ duration: 1, delay: 0.2 }}
            className="mt-4 text-xs font-bold tracking-[0.2em] opacity-60"
          >
            {introHint}
          </motion.p>
        </div>

        <motion.div style={{ opacity: contentOpacity, y: contentY }} className="absolute top-[9%] z-10 flex flex-col items-center justify-center px-4 text-center">
          {arcTitle}
          {arcBody}
          {arcActions && <div className="pointer-events-auto mt-6">{arcActions}</div>}
        </motion.div>

        <div className="relative flex h-full w-full items-center justify-center">
          {cards.map((card, i) => {
            let target: Target = { x: 0, y: 0, rotation: 0, scale: 1, opacity: 1 }
            if (introPhase === "scatter") {
              target = scatterPositions[i]
            } else if (introPhase === "line") {
              const spacing = CARD_W + 10
              target = { x: i * spacing - (total * spacing) / 2, y: 0, rotation: 0, scale: 1, opacity: 1 }
            } else {
              const isMobile = containerSize.width < 768
              const minDimension = Math.min(containerSize.width, containerSize.height)
              const circleRadius = Math.min(minDimension * 0.35, 350)
              const circleAngle = (i / total) * 360
              const circleRad = (circleAngle * Math.PI) / 180
              const circlePos = { x: Math.cos(circleRad) * circleRadius, y: Math.sin(circleRad) * circleRadius, rotation: circleAngle + 90 }

              const baseRadius = Math.min(containerSize.width, containerSize.height * 1.5)
              const arcRadius = baseRadius * (isMobile ? 1.4 : 1.1)
              const arcApexY = containerSize.height * (isMobile ? 0.35 : 0.25)
              const arcCenterY = arcApexY + arcRadius
              const spreadAngle = isMobile ? 100 : 130
              const startAngle = -90 - spreadAngle / 2
              const step = spreadAngle / (total - 1)
              const scrollProgress = Math.min(Math.max(rotateValue / 360, 0), 1)
              const boundedRotation = -scrollProgress * spreadAngle * 0.8
              const currentArcAngle = startAngle + i * step + boundedRotation
              const arcRad = (currentArcAngle * Math.PI) / 180
              const arcPos = {
                x: Math.cos(arcRad) * arcRadius + parallaxValue,
                y: Math.sin(arcRad) * arcRadius + arcCenterY,
                rotation: currentArcAngle + 90,
                scale: isMobile ? 1.4 : 1.8,
              }
              target = {
                x: lerp(circlePos.x, arcPos.x, morphValue),
                y: lerp(circlePos.y, arcPos.y, morphValue),
                rotation: lerp(circlePos.rotation, arcPos.rotation, morphValue),
                scale: lerp(1, arcPos.scale, morphValue),
                opacity: 1,
              }
            }
            return <FlipCard key={card.key} front={card.front} back={card.back} target={target} />
          })}
        </div>
      </div>
    </div>
  )
}
