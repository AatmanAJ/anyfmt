/**
 * Hero Shutter Text (21st.dev, by daiwiikharihar): each letter arrives through three
 * horizontal slices that sweep across in alternating directions.
 *
 * anyfmt changes: framer-motion → motion/react; cycles through `words` on a timer (and on
 * click); slice colours, size and the surrounding grid are props.
 */

import { AnimatePresence, motion, useReducedMotion } from "motion/react"
import { useEffect, useState } from "react"

export interface ShutterTextProps {
  words: string[]
  interval?: number
  /** Font size of each letter (CSS length). */
  size?: string
  color?: string
  sliceA?: string
  sliceB?: string
  className?: string
  onWord?: (word: string, index: number) => void
}

export default function ShutterText({
  words, interval = 2400, size = "15vw", color = "#111", sliceA = "#FF4D00", sliceB = "#555", className = "", onWord,
}: ShutterTextProps) {
  const [index, setIndex] = useState(0)
  const reduce = useReducedMotion()
  const word = words[index % words.length]

  useEffect(() => {
    if (reduce) return
    const t = setTimeout(() => setIndex((i) => i + 1), interval)
    return () => clearTimeout(t)
  }, [index, interval, reduce])
  useEffect(() => { onWord?.(word, index % words.length) }, [word, index, words.length, onWord])

  const letter = { fontSize: size, lineHeight: 0.86 }

  return (
    <button type="button" aria-live="polite" aria-label={`Format: ${word}. Next format`} onClick={() => setIndex((i) => i + 1)}
      className={`relative block cursor-pointer select-none outline-none focus-visible:ring-2 focus-visible:ring-offset-4 ${className}`}>
      <AnimatePresence mode="wait">
        <motion.div key={index} className="flex items-center justify-center" exit={{ opacity: 0, filter: "blur(8px)", transition: { duration: 0.25 } }}>
          {word.split("").map((char, i) => (
            <div key={i} className="relative overflow-hidden px-[0.04em]">
              <motion.span
                initial={reduce ? false : { opacity: 0, filter: "blur(10px)" }}
                animate={{ opacity: 1, filter: "blur(0px)" }}
                transition={{ delay: i * 0.04 + 0.12, duration: 0.45 }}
                className="block font-black tracking-[-0.06em]"
                style={{ ...letter, color }}
              >
                {char}
              </motion.span>
              {!reduce && (
                <>
                  <motion.span initial={{ x: "-100%", opacity: 0 }} animate={{ x: "100%", opacity: [0, 1, 0] }} transition={{ duration: 0.7, delay: i * 0.04, ease: "easeInOut" }}
                    className="pointer-events-none absolute inset-0 z-10 block font-black tracking-[-0.06em]" style={{ ...letter, color: sliceA, clipPath: "polygon(0 0, 100% 0, 100% 35%, 0 35%)" }}>{char}</motion.span>
                  <motion.span initial={{ x: "100%", opacity: 0 }} animate={{ x: "-100%", opacity: [0, 1, 0] }} transition={{ duration: 0.7, delay: i * 0.04 + 0.1, ease: "easeInOut" }}
                    className="pointer-events-none absolute inset-0 z-10 block font-black tracking-[-0.06em]" style={{ ...letter, color: sliceB, clipPath: "polygon(0 35%, 100% 35%, 100% 65%, 0 65%)" }}>{char}</motion.span>
                  <motion.span initial={{ x: "-100%", opacity: 0 }} animate={{ x: "100%", opacity: [0, 1, 0] }} transition={{ duration: 0.7, delay: i * 0.04 + 0.2, ease: "easeInOut" }}
                    className="pointer-events-none absolute inset-0 z-10 block font-black tracking-[-0.06em]" style={{ ...letter, color: sliceA, clipPath: "polygon(0 65%, 100% 65%, 100% 100%, 0 100%)" }}>{char}</motion.span>
                </>
              )}
            </div>
          ))}
        </motion.div>
      </AnimatePresence>
    </button>
  )
}
