# BASE44 BUILD PROMPT: exact clone of the "anyfmt" landing page

> Paste this whole message into the Base44 builder chat (Build mode) as one message. Do every step in order, then reply in the format at the end.

---

## NON-NEGOTIABLE GUARDRAILS (read before anything else)

This is a **verbatim clone**, not a design brief. The code below is final, tested and working on React 18 + Vite + Tailwind 3 + framer-motion. Your job is to put it in place exactly.

1. Copy every file **character for character**. Do NOT rewrite, refactor, reformat, rename, reorder, split, merge, "clean up" or "improve" any line.
2. Do NOT convert to TypeScript. Do NOT convert to shadcn components. Do NOT add props, comments, wrappers or error boundaries.
3. Do NOT replace hardcoded colours (for example `#0A0A0A`, `#FF4A14`, `#E4FF3A`, `#F4F2EF`, `#EFEFEF`) with design tokens or CSS variables. This page intentionally uses literal values. Do NOT add them to `tailwind.config.js`.
4. Do NOT replace the inline SVG icons (Apple mark, GitHub mark, star, arrows) with lucide-react or any other icon library. They are plain SVG on purpose, so no icon package is needed.
5. Do NOT swap `framer-motion` for anything else, and do NOT change any animation value (durations, easings, delays, springs, transforms).
6. Do NOT replace the `shaders` package, its components or any of their prop values. Do NOT replace it with CSS, canvas or three.js.
7. Do NOT change any copy (text), font, font size, spacing, radius, shadow or breakpoint.
8. Do NOT add a header, sidebar, footer, padding, max-width, background or any other chrome from the app Layout around this page. The page renders full-bleed and brings its own nav and footer.
9. Do NOT create entities, backend functions, integrations, auth gates or analytics. This is a static, public marketing page.
10. If a step seems to conflict with a Base44 default, follow THIS prompt. If something truly cannot be done, stop and tell me exactly what and why instead of improvising.

---

## ROLE

You are a senior Base44 front-end engineer doing a pixel-exact port of a finished React page into this Base44 app.

## PRIMARY GOAL

When you are done, the app's home page (`/`) is the "anyfmt" landing page below, identical in layout, copy, typography, colour, animation, interaction and responsive behaviour to the reference implementation, with zero deviations.

## WHAT THE PAGE IS (for your understanding only; the code below is the source of truth)

- **Hero:** light background with a live WebGPU shader built from the `shaders` package: Swirl + RadialGradient glows + ChromaFlow + FlutedGlass (flutes at 31 degrees, diagonal) + FilmGrain. An orange colour mass sits in the top right corner and breathes continuously. On mouse hover a hot spot follows the pointer and ChromaFlow paints liquid colour; the glass sharpens. On portrait screens the glow tucks into the top corner. Browsers without WebGPU get a static CSS gradient fallback.
- **Nav:** condensed "anyfmt." wordmark (Bricolage Grotesque, width 75), links, a glass "Star on GitHub" button with a spinning conic border and star burst, and a white "Download" pill with letter roll. Mobile: "Menu" opens a bottom sheet.
- **Hero copy:** lime badge, two-line headline, paragraph, black "Download for Mac" pill whose lime fill floods from the arrow on hover and which morphs through states on click, a "Try the gesture here" link, and an "Engines inside" row with hover tooltips.
- **Statement:** a huge centered sentence whose words darken one by one on scroll.
- **Try it:** an interactive playground. Press a file, drag, tap Shift (or hold still) and a radial format wheel opens; release on a wedge and a "new copy" lands in the tray. Fully keyboard operable.
- **Three keys:** three cards with keycaps that press on hover and light up their chips.
- **Numbers:** 793 / 26 / 0 counting up with `@number-flow/react` when scrolled into view.
- **FAQ:** accordion.
- **Final CTA:** black rounded panel with the same shader in dark mode from the bottom left corner.
- **Footer:** wordmark column with Download pill, three labelled columns, base bar with "Back to top".

---

# BUILD STEPS

## BASE44 PLATFORM RULES FOR THIS TASK

- Stack assumed: React 18 + Vite + Tailwind CSS 3 + react-router-dom + framer-motion (already in Base44). Files are `.jsx`. The `@/` alias points to `src/`.
- Install exactly these two extra npm packages, pinned, nothing else:
  - `shaders@4.0.4`
  - `@number-flow/react@0.6.2`
- `framer-motion` is already installed in Base44 apps. If it is somehow missing, install `framer-motion@11.18.2`. Do not upgrade or downgrade an existing install.
- Fonts load via Google Fonts `@import` at the very top of `src/index.css` (Base44 convention). No font packages.
- Do not touch any other existing file except `src/index.css` (append-only as described) and the router (Step 5).

## STEP 1: Install packages

Add `shaders@4.0.4` and `@number-flow/react@0.6.2` to the app's dependencies with those exact versions (no caret).

## STEP 2: `src/index.css`

Put this font import as the **first line** of `src/index.css`, above `@tailwind base;` (keep everything else that is already in the file):

```css
@import url('https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wdth,wght@12..96,75..100,200..800&family=Inter+Tight:wght@100..900&display=swap');
```

Then append these rules at the **end** of `src/index.css`:

```css
html { scroll-behavior: smooth; }
body {
  margin: 0;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

Do not remove or edit any existing token, `:root`, `.dark` or `@layer` rule in that file.

## STEP 3: Create the three components

Create the folder `src/components/flare/` and these three files.

### FILE: `src/components/flare/FluteShader.jsx`

Create this file with exactly this content, character for character:

```jsx
/**
 * The page's shader, built on the `shaders` package (shaders.com, MIT): Swirl, ChromaFlow,
 * FlutedGlass and FilmGrain, with the flutes cut diagonally so a warm colour mass anchored in one
 * corner streaks away across the canvas.
 *
 * Always: the orange breathes. On hover: a hot spot of light rides the pointer and ChromaFlow
 * paints liquid by direction; the flutes drag both into diagonal streaks and the glass sharpens
 * its aberration. `light` multiplies colour into white, `dark` screens it onto black.
 * WebGPU only; elsewhere a static CSS gradient stands in.
 */
import { useEffect, useRef, useState } from 'react'
import { ChromaFlow, FilmGrain, FlutedGlass, RadialGradient, Shader, Swirl } from 'shaders/react'
const at = (corner, x, y) => (corner === 'tr' ? { x, y } : { x: 1 - x, y: 1 - y })
function Fallback({ variant, corner }) {
  const pos = corner === 'tr' ? '88% 8%' : '12% 92%'
  const base = variant === 'light' ? '#EFEFEF' : '#0A0A0A'
  return (
    <div
      aria-hidden
      className="absolute inset-0"
      style={{
        background: `repeating-linear-gradient(121deg, transparent 0 34px, rgba(255,255,255,${variant === 'light' ? 0.32 : 0.08}) 36px, transparent 44px),
        radial-gradient(ellipse 70% 80% at ${pos}, #ff2e00 0%, #ff5f03 22%, rgba(255,140,60,.55) 45%, transparent 70%), ${base}`,
      }}
    />
  )
}
export function FluteShader({ className = '', variant = 'light', corner = 'tr', angle = 31 }) {
  const [unavailable, setUnavailable] = useState(false)
  const [f, setF] = useState({ t: 0, h: 0, x: 0.7, y: 0.3, portrait: false })
  const target = useRef(0)
  const host = useRef(null)
  const ptr = useRef({ x: 0.7, y: 0.3 })
  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let raf = 0,
      last = 0,
      h = 0,
      x = 0.7,
      y = 0.3,
      inView = true
    const start = performance.now()
    const onMove = (e) => {
      const r = host.current?.getBoundingClientRect()
      if (!r || !r.width) return
      const nx = (e.clientX - r.left) / r.width,
        ny = (e.clientY - r.top) / r.height
      ptr.current = { x: nx, y: ny }
      // hover is derived from position, so it works with content stacked over the canvas
      target.current = e.pointerType === 'mouse' && nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 ? 1 : 0
    }
    const onOut = (e) => {
      if (!e.relatedTarget) target.current = 0
    }
    const tick = (now) => {
      raf = requestAnimationFrame(tick)
      if (!inView || now - last < 33) return // ~30 updates a second is plenty for a breath
      last = now
      h += (target.current - h) * 0.08
      x += (ptr.current.x - x) * 0.14
      y += (ptr.current.y - y) * 0.14
      const r = host.current?.getBoundingClientRect()
      setF({ t: reduce ? 1.2 : (now - start) / 1000, h, x, y, portrait: !!r && r.width / Math.max(1, r.height) < 0.85 })
    }
    const io = new IntersectionObserver(([e]) => {
      inView = e.isIntersecting
    })
    if (host.current) io.observe(host.current)
    window.addEventListener('pointermove', onMove, { passive: true })
    document.addEventListener('pointerout', onOut)
    raf = requestAnimationFrame(tick)
    return () => {
      cancelAnimationFrame(raf)
      io.disconnect()
      window.removeEventListener('pointermove', onMove)
      document.removeEventListener('pointerout', onOut)
    }
  }, [])
  if (unavailable)
    return (
      <div className={className}>
        <Fallback variant={variant} corner={corner} />
      </div>
    )
  const { t, h, x, y, portrait } = f
  const breath = 0.5 + 0.5 * Math.sin(t * 1.25) // ~5 s
  const breath2 = 0.5 + 0.5 * Math.sin(t * 0.9 + 2.1)
  const light = variant === 'light'
  const blend = light ? 'multiply' : 'screen'
  const edge = light ? '#ffffff' : '#000000'
  // the mass sits in the corner and reaches toward the middle; on portrait screens it stays tighter
  const main = portrait
    ? { c: at(corner, 0.98, 0.0), r: 0.26 + breath * 0.07, a: 1.0 }
    : { c: at(corner, 0.92, 0.08), r: 0.7 + breath * 0.14, a: 1.45 }
  const side = portrait ? { c: at(corner, 0.35, 0.02), r: 0.14 } : { c: at(corner, 0.62, 0.05), r: 0.3 }
  return (
    <div ref={host} className={className}>
      <Shader disableTelemetry onUnavailable={() => setUnavailable(true)} style={{ width: '100%', height: '100%' }}>
        <Swirl colorA={light ? '#ffffff' : '#0a0a0a'} colorB={light ? '#f0f0f0' : '#141414'} detail={1.7} />
        {/* always on: the orange breathes */}
        <RadialGradient
          blendMode={blend}
          center={main.c}
          radius={main.r + h * 0.05}
          aspect={main.a}
          opacity={0.86 + breath * 0.14}
          stops={[
            { color: '#ee1200', position: 0 },
            { color: '#ff2600', position: 0.28 },
            { color: '#ff5a0a', position: 0.5 },
            { color: light ? '#ffae7a' : '#5a1a06', position: 0.74 },
            { color: edge, position: 1 },
          ]}
        />
        <RadialGradient
          blendMode={blend}
          center={side.c}
          radius={side.r + breath2 * 0.1}
          aspect={1.6}
          opacity={0.45 + breath2 * 0.35}
          stops={[
            { color: '#ff6a10', position: 0 },
            { color: light ? '#ffb070' : '#4a1806', position: 0.5 },
            { color: edge, position: 1 },
          ]}
        />
        {/* on hover: a hot spot rides the pointer */}
        <RadialGradient
          blendMode={blend}
          center={{ x, y }}
          opacity={h}
          radius={0.15 + h * 0.06}
          aspect={1.8}
          stops={[
            { color: '#e8160c', position: 0 },
            { color: '#ff4a0a', position: 0.25 },
            { color: light ? '#ffc27a' : '#3a1206', position: 0.6 },
            { color: edge, position: 1 },
          ]}
        />
        {/* and paints liquid by direction, in a warm spectrum */}
        <ChromaFlow
          blendMode={blend}
          baseColor={edge}
          upColor="#ff2a0e"
          downColor="#ff5f03"
          leftColor="#ff8a1f"
          rightColor="#ffb23e"
          momentum={13}
          radius={3.5}
          intensity={1.1}
          opacity={0.3 + h * 0.7}
        />
        <FlutedGlass
          shape="rounded"
          angle={angle}
          frequency={9}
          softness={1}
          speed={0.15}
          refraction={4 + h * 2}
          aberration={0.61 + h * 0.7}
          highlight={0.12 + h * 0.08}
          highlightSoftness={0}
          lightAngle={-90}
        />
        <FilmGrain strength={0.05} />
      </Shader>
    </div>
  )
}
```

### FILE: `src/components/flare/Buttons.jsx`

Create this file with exactly this content, character for character:

```jsx
/**
 * Call-to-action buttons for the Flare page. Starting points on 21st.dev: Arrow Fill Button
 * (hyperiux), Download Button (bidyut10) and Star On Github (socolled); rebuilt for anyfmt.
 */
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
const EASE = [0.22, 1, 0.36, 1]
const SNAP = 'cubic-bezier(0.785,0.135,0.15,0.86)'
const Apple = ({ size = 16 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
    <path d="M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.76 2.28-1.6 2.78-.41 6.89 1.15 9.15.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.78.74 2.99.72 1.24-.02 2.02-1.12 2.77-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.66ZM14.1 5.86c.63-.77 1.06-1.83.94-2.89-.91.04-2.02.61-2.67 1.37-.58.67-1.1 1.76-.96 2.8 1.02.08 2.06-.52 2.69-1.28Z" />
  </svg>
)
const GitHubMark = ({ size = 18 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
    <path d="M12 .5C5.65.5.5 5.65.5 12a11.5 11.5 0 0 0 7.86 10.92c.58.1.79-.25.79-.56v-2c-3.2.7-3.87-1.37-3.87-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.19 1.76 1.19 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.68 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.41-2.69 5.39-5.26 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
  </svg>
)
const StarPath = 'M12 2.6l2.83 5.74 6.33.92-4.58 4.47 1.08 6.3L12 17.05l-5.66 2.98 1.08-6.3L2.84 9.26l6.33-.92L12 2.6Z'
/** Letters that roll up and are replaced by a copy from below, staggered. */
export function RollText({ children, className = '' }) {
  return (
    <span className={`roll relative inline-flex overflow-hidden ${className}`} aria-label={children}>
      {[...children].map((ch, i) => (
        <span key={i} aria-hidden className="roll-ch relative inline-block" style={{ transitionDelay: `${i * 18}ms` }}>
          <span className="block">{ch === ' ' ? '\u00a0' : ch}</span>
          <span className="absolute left-0 top-full block">{ch === ' ' ? '\u00a0' : ch}</span>
        </span>
      ))}
    </span>
  )
}
/** Nav pill: white, letter roll, arrow leaves up-right and a new one arrives from bottom-left. */
export function NavDownload({ href = '#download', onClick }) {
  return (
    <a
      href={href}
      onClick={(e) => {
        if (onClick) {
          e.preventDefault()
          onClick()
        }
      }}
      className="group inline-flex h-12 items-center gap-3 rounded-full bg-white pl-6 pr-2 text-[15px] font-medium text-[#0A0A0A] shadow-[0_1px_0_rgba(0,0,0,.04),0_8px_24px_-8px_rgba(0,0,0,.18)] outline-none ring-1 ring-black/5 transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black"
    >
      <RollText>Download</RollText>
      <span className="relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-[#0A0A0A] text-white">
        {[0, 1].map((k) => (
          <svg
            key={k}
            width="14"
            height="14"
            viewBox="0 0 14 14"
            aria-hidden
            className={`absolute transition-transform duration-500 ${k === 0 ? 'group-hover:translate-x-5 group-hover:-translate-y-5' : '-translate-x-5 translate-y-5 group-hover:translate-x-0 group-hover:translate-y-0'}`}
            style={{ transitionTimingFunction: SNAP }}
          >
            <path
              d="M3.5 10.5l7-7M5 3.5h5.5V9"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        ))}
      </span>
    </a>
  )
}
/** Hero download: black pill. Hover floods lime out of the arrow; click runs the honest morph. */
export function DownloadButton({ tone = 'dark', label = 'Download for Mac' }) {
  const [phase, setPhase] = useState('idle')
  const [p, setP] = useState(0)
  const reduce = useReducedMotion()
  const timers = useRef([])
  useEffect(() => () => timers.current.forEach(clearTimeout), [])
  const run = () => {
    if (phase !== 'idle') return
    setPhase('busy')
    const start = performance.now(),
      dur = reduce ? 0 : 1300
    const tick = () => {
      const k = dur ? Math.min(1, (performance.now() - start) / dur) : 1
      setP(1 - (1 - k) ** 2)
      if (k < 1) requestAnimationFrame(tick)
      else {
        setPhase('done')
        timers.current.push(
          window.setTimeout(() => {
            setPhase('idle')
            setP(0)
          }, 3200),
        )
      }
    }
    requestAnimationFrame(tick)
  }
  const dark = tone === 'dark'
  const base = dark ? 'bg-[#0A0A0A] text-white' : 'bg-white text-[#0A0A0A]'
  const fill = '#E4FF3A'
  const text = phase === 'busy' ? 'Packing anyfmt.dmg' : phase === 'done' ? 'First release lands soon' : label
  return (
    <button
      type="button"
      onClick={run}
      aria-live="polite"
      className={`group relative inline-flex h-14 items-center overflow-hidden rounded-full pl-6 pr-2 text-base font-medium outline-none transition-[transform] duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-offset-2 ${dark ? 'focus-visible:ring-black' : 'focus-visible:ring-white focus-visible:ring-offset-black'} ${base}`}
    >
      {/* lime flood, grows out of the icon circle */}
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 rounded-full transition-[clip-path] duration-500 [clip-path:circle(20px_at_calc(100%-28px)_50%)] group-hover:[clip-path:circle(150%_at_calc(100%-28px)_50%)]"
        style={{ background: fill, transitionTimingFunction: SNAP }}
      />
      <span
        className="relative flex items-center gap-2.5 pr-4 transition-colors duration-500 group-hover:text-[#0A0A0A]"
        style={{ transitionTimingFunction: SNAP }}
      >
        <Apple size={18} />
        <span className="relative grid">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span
              key={text}
              initial={{ y: 18, opacity: 0, filter: 'blur(4px)' }}
              animate={{ y: 0, opacity: 1, filter: 'blur(0px)' }}
              exit={{ y: -18, opacity: 0, filter: 'blur(4px)' }}
              transition={{ duration: 0.45, ease: EASE }}
              className="whitespace-nowrap"
            >
              {text}
            </motion.span>
          </AnimatePresence>
        </span>
      </span>
      <span className="relative flex h-10 w-10 items-center justify-center rounded-full text-[#0A0A0A]">
        {phase === 'idle' && (
          <span className="relative flex h-5 w-5 items-center justify-center overflow-hidden">
            <svg
              width="16"
              height="16"
              viewBox="0 0 16 16"
              aria-hidden
              className="absolute transition-transform duration-500 group-hover:translate-y-5"
              style={{ transitionTimingFunction: SNAP }}
            >
              <path
                d="M8 2.5v10M3.5 8.5 8 13l4.5-4.5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.9"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <svg
              width="16"
              height="16"
              viewBox="0 0 16 16"
              aria-hidden
              className="absolute -translate-y-5 transition-transform duration-500 group-hover:translate-y-0"
              style={{ transitionTimingFunction: SNAP }}
            >
              <path
                d="M8 2.5v10M3.5 8.5 8 13l4.5-4.5"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.9"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </span>
        )}
        {phase === 'busy' && (
          <svg width="26" height="26" viewBox="0 0 26 26" aria-hidden className="-rotate-90">
            <circle cx="13" cy="13" r="10" fill="none" stroke="rgba(0,0,0,.15)" strokeWidth="2.5" />
            <circle
              cx="13"
              cy="13"
              r="10"
              fill="none"
              stroke="#0A0A0A"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeDasharray={62.8}
              strokeDashoffset={62.8 * (1 - p)}
            />
          </svg>
        )}
        {phase === 'done' && (
          <motion.svg
            initial={{ scale: 0.6, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ type: 'spring', stiffness: 500, damping: 22 }}
            width="18"
            height="18"
            viewBox="0 0 18 18"
            aria-hidden
          >
            <motion.path
              d="M4 9.5 7.5 13 14 5.5"
              fill="none"
              stroke="#0A0A0A"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
              initial={{ pathLength: 0 }}
              animate={{ pathLength: 1 }}
              transition={{ duration: 0.4, ease: EASE }}
            />
          </motion.svg>
        )}
      </span>
    </button>
  )
}
/** Glass pill with a conic streak border on hover; a click bursts the star and rolls the label. */
export function GitHubButton({ compact = false }) {
  const [starred, setStarred] = useState(false)
  const [burst, setBurst] = useState(0)
  const [tip, setTip] = useState(false)
  const click = () => {
    setStarred((s) => !s)
    if (!starred) setBurst((b) => b + 1)
  }
  return (
    <span className="relative inline-flex" onPointerEnter={() => setTip(true)} onPointerLeave={() => setTip(false)}>
      <button
        type="button"
        onClick={click}
        aria-pressed={starred}
        onFocus={() => setTip(true)}
        onBlur={() => setTip(false)}
        className="gh group relative inline-flex h-12 items-center gap-2.5 rounded-full p-[1.5px] text-[15px] font-medium text-[#0A0A0A] outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black"
      >
        <span aria-hidden className="gh-ring pointer-events-none absolute inset-0 rounded-full" />
        <span className="relative flex h-full items-center gap-2.5 rounded-full bg-white/80 px-4 backdrop-blur-xl">
          <GitHubMark size={18} />
          {!compact && (
            <span className="relative grid h-5 overflow-hidden">
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.span
                  key={String(starred)}
                  initial={{ y: 20 }}
                  animate={{ y: 0 }}
                  exit={{ y: -20 }}
                  transition={{ duration: 0.4, ease: EASE }}
                  className="whitespace-nowrap leading-5"
                >
                  {starred ? 'Starred, thank you' : 'Star on GitHub'}
                </motion.span>
              </AnimatePresence>
            </span>
          )}
          <span className="relative flex h-6 w-6 items-center justify-center">
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              aria-hidden
              className="transition-[transform,color] duration-500 group-hover:rotate-[72deg]"
              style={{ transitionTimingFunction: SNAP, color: starred ? '#FF4A14' : undefined }}
            >
              <path
                d={StarPath}
                fill={starred ? 'currentColor' : 'none'}
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinejoin="round"
                className="transition-[fill] duration-300 group-hover:fill-[#FFB23E] group-hover:stroke-[#FF6A1F]"
              />
            </svg>
            <AnimatePresence>
              {burst > 0 &&
                starred &&
                Array.from({ length: 10 }, (_, i) => {
                  const a = (i / 10) * Math.PI * 2
                  return (
                    <motion.span
                      key={`${burst}-${i}`}
                      aria-hidden
                      className="pointer-events-none absolute h-1.5 w-1.5 rounded-full"
                      style={{ background: i % 2 ? '#FF4A14' : '#FFB23E' }}
                      initial={{ x: 0, y: 0, scale: 1, opacity: 1 }}
                      animate={{ x: Math.cos(a) * 26, y: Math.sin(a) * 26, scale: 0, opacity: 0 }}
                      transition={{ duration: 0.7, ease: EASE }}
                    />
                  )
                })}
            </AnimatePresence>
          </span>
        </span>
      </button>
      <AnimatePresence>
        {tip && (
          <motion.span
            role="tooltip"
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            transition={{ duration: 0.2, ease: EASE }}
            className="pointer-events-none absolute left-1/2 top-full z-20 mt-2 -translate-x-1/2 whitespace-nowrap rounded-lg bg-[#0A0A0A] px-3 py-1.5 text-xs font-medium text-white"
          >
            The repo goes public with the first release
          </motion.span>
        )}
      </AnimatePresence>
    </span>
  )
}
/** Lime announcement pill with a sheen pass and a nudging arrow. */
export function Badge({ children, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="badge group relative inline-flex h-10 items-center gap-2 overflow-hidden rounded-full bg-[#E4FF3A] px-4 text-[15px] font-medium text-[#0A0A0A] outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-black"
    >
      <span aria-hidden className="badge-sheen pointer-events-none absolute inset-y-0 -left-1/2 w-1/3 skew-x-[-20deg] bg-white/70" />
      <span className="relative">{children}</span>
      <svg
        width="16"
        height="16"
        viewBox="0 0 16 16"
        aria-hidden
        className="relative transition-transform duration-500 group-hover:translate-x-1"
        style={{ transitionTimingFunction: SNAP }}
      >
        <path
          d="M2.5 8h10M8.5 3.5 13 8l-4.5 4.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </button>
  )
}
export function ButtonStyles() {
  return (
    <style>{`
      .roll-ch { transition: transform .5s ${SNAP}; }
      .group:hover .roll-ch, .group:focus-visible .roll-ch { transform: translateY(-100%); }
      @property --gh-a { syntax: '<angle>'; inherits: false; initial-value: 0deg; }
      .gh-ring { background: rgba(10,10,10,.12); }
      .gh:hover .gh-ring, .gh:focus-visible .gh-ring {
        background: conic-gradient(from var(--gh-a), #FF2A0E, #FF7A1F, #FFC24A, #FFF1D6, #FF7A1F, #FF2A0E);
        animation: gh-spin 2.4s linear infinite;
      }
      @keyframes gh-spin { to { --gh-a: 360deg; } }
      .badge-sheen { transform: translateX(-120%) skewX(-20deg); }
      .badge:hover .badge-sheen { transition: transform .9s ${SNAP}; transform: translateX(520%) skewX(-20deg); }
      @media (prefers-reduced-motion: reduce) {
        .roll-ch, .group:hover .roll-ch { transform: none; transition: none; }
        .gh:hover .gh-ring { animation: none; }
      }
    `}</style>
  )
}
```

### FILE: `src/components/flare/Playground.jsx`

Create this file with exactly this content, character for character:

```jsx
/**
 * The gesture, for real: press a file, drag, tap Shift (or hold still), the format wheel opens
 * around the pointer, let go on a format and a new copy lands in the output tray.
 * Keyboard: focus a file, Enter opens the wheel, arrows choose, Enter applies, Escape cancels.
 */
import { AnimatePresence, motion } from 'framer-motion'
import { useCallback, useEffect, useRef, useState } from 'react'
const EASE = [0.22, 1, 0.36, 1]
const FILES = [
  { name: 'clip', ext: 'mov', kind: 'video', size: '48.2 MB' },
  { name: 'IMG_2041', ext: 'heic', kind: 'image', size: '3.4 MB' },
  { name: 'interview', ext: 'm4a', kind: 'audio', size: '22.1 MB' },
  { name: 'notes', ext: 'docx', kind: 'doc', size: '184 KB' },
]
const TARGETS = {
  video: ['GIF', 'MP4', 'WEBM', 'MKV', 'AVI', 'MP3', 'M4A', 'WMV'],
  image: ['JPG', 'PNG', 'WEBP', 'PDF', 'TIFF', 'AVIF', 'GIF', 'BMP'],
  audio: ['MP3', 'WAV', 'FLAC', 'OGG', 'OPUS', 'AIFF'],
  doc: ['PDF', 'MD', 'HTML', 'RTF', 'TXT', 'ODT', 'EPUB'],
}
const R0 = 52,
  R1 = 132
function FileGlyph({ kind, ext, active }) {
  const tint = { video: '#FF4A14', image: '#FF8A2A', audio: '#E8213A', doc: '#0A0A0A' }[kind]
  return (
    <span
      className={`relative flex h-[92px] w-[74px] flex-col justify-end rounded-[12px] bg-white p-2 shadow-[0_1px_0_rgba(0,0,0,.04),0_10px_24px_-12px_rgba(0,0,0,.25)] ring-1 ring-black/5 transition-transform duration-300 ${active ? 'scale-95 opacity-40' : ''}`}
    >
      <span aria-hidden className="absolute right-0 top-0 h-5 w-5 rounded-bl-[8px] rounded-tr-[12px] bg-[#F1EEEA]" />
      <span aria-hidden className="absolute left-2 top-3 flex flex-col gap-1">
        {[30, 22, 26].map((w, i) => (
          <span key={i} className="h-[3px] rounded-full bg-black/10" style={{ width: w }} />
        ))}
      </span>
      <span
        className="w-fit rounded-[5px] px-1.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-white"
        style={{ background: tint }}
      >
        {ext}
      </span>
    </span>
  )
}
function wedge(i, n) {
  const gap = 0.025,
    a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap,
    a1 = a0 + (Math.PI * 2) / n - gap * 2
  const p = (r, a) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  return `M${p(R1, a0)} A${R1},${R1} 0 0 1 ${p(R1, a1)} L${p(R0, a1)} A${R0},${R0} 0 0 0 ${p(R0, a0)} Z`
}
export function Playground() {
  const box = useRef(null)
  const [drag, setDrag] = useState(null)
  const [wheel, setWheel] = useState(null)
  const [hot, setHot] = useState(-1)
  const wheelRef = useRef(null)
  wheelRef.current = wheel
  const [busy, setBusy] = useState(null)
  const [out, setOut] = useState([])
  const still = useRef(0)
  const last = useRef({ x: 0, y: 0 })
  const idRef = useRef(0)
  const rel = (e) => {
    const r = box.current.getBoundingClientRect()
    return { x: e.clientX - r.left, y: e.clientY - r.top }
  }
  const clampCenter = (x, y) => {
    const r = box.current.getBoundingClientRect()
    return { x: Math.min(Math.max(x, R1 + 8), r.width - R1 - 8), y: Math.min(Math.max(y, R1 + 8), r.height - R1 - 8) }
  }
  const openWheel = useCallback((i, x, y) => {
    clearTimeout(still.current) // a pending hold-still must not reopen and reset the aim
    const c = clampCenter(x, y)
    setWheel({ i, ...c })
    setHot(-1)
  }, [])
  const aim = (x, y, w) => {
    const n = TARGETS[FILES[w.i].kind].length
    const dx = x - w.x,
      dy = y - w.y
    if (Math.hypot(dx, dy) < R0 * 0.6) {
      setHot(-1)
      return
    }
    const a = Math.atan2(dy, dx) + Math.PI / 2 + Math.PI / n
    setHot(Math.floor((((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)) / ((Math.PI * 2) / n)))
  }
  const convert = useCallback((i, fmt, at) => {
    const f = FILES[i]
    setBusy({ ...at, label: `${f.name}.${f.ext} → ${fmt.toLowerCase()}` })
    window.setTimeout(() => {
      setBusy(null)
      setOut((o) =>
        [{ id: ++idRef.current, name: `${f.name}.${fmt.toLowerCase()}`, kind: f.kind, ext: fmt.toLowerCase() }, ...o].slice(0, 4),
      )
    }, 1100)
  }, [])
  // Shift opens the wheel mid drag, like the app
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Shift' && drag && !wheel) openWheel(drag.i, drag.x, drag.y)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [drag, wheel, openWheel])
  const down = (i) => (e) => {
    if (busy) return
    e.preventDefault()
    try {
      box.current.setPointerCapture(e.pointerId)
    } catch {
      /* pointer already gone: the drag still works without capture */
    }
    const p = rel(e)
    last.current = p
    setDrag({ i, ...p })
    setWheel(null)
    clearTimeout(still.current)
    still.current = window.setTimeout(
      () =>
        setDrag((d) => {
          if (d && !wheelRef.current) openWheel(d.i, d.x, d.y)
          return d
        }),
      750,
    )
  }
  const move = (e) => {
    if (!drag) return
    const p = rel(e)
    setDrag({ ...drag, ...p })
    if (wheel) aim(p.x, p.y, wheel)
    else if (Math.hypot(p.x - last.current.x, p.y - last.current.y) > 6) {
      last.current = p
      clearTimeout(still.current)
      still.current = window.setTimeout(
        () =>
          setDrag((d) => {
            if (d && !wheelRef.current) openWheel(d.i, d.x, d.y)
            return d
          }),
        750,
      )
    }
  }
  const up = () => {
    clearTimeout(still.current)
    if (drag && wheel && hot >= 0) convert(drag.i, TARGETS[FILES[drag.i].kind][hot], { x: wheel.x, y: wheel.y })
    setDrag(null)
    setWheel(null)
    setHot(-1)
  }
  // keyboard path
  const keyOn = (i) => (e) => {
    const n = TARGETS[FILES[i].kind].length
    if (!wheel && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault()
      const r = e.currentTarget.getBoundingClientRect(),
        b = box.current.getBoundingClientRect()
      openWheel(i, r.left - b.left + r.width / 2, r.top - b.top + r.height / 2)
      setHot(0)
    } else if (wheel && wheel.i === i) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault()
        setHot((h) => (h + 1) % n)
      } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        e.preventDefault()
        setHot((h) => (h - 1 + n) % n)
      } else if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        if (hot >= 0) convert(i, TARGETS[FILES[i].kind][hot], { x: wheel.x, y: wheel.y })
        setWheel(null)
        setHot(-1)
      } else if (e.key === 'Escape') {
        setWheel(null)
        setHot(-1)
      }
    }
  }
  const targets = wheel ? TARGETS[FILES[wheel.i].kind] : []
  const dragging = drag ? FILES[drag.i] : null
  return (
    <div
      ref={box}
      onPointerMove={move}
      onPointerUp={up}
      onPointerCancel={up}
      className="relative h-[620px] w-full select-none overflow-hidden rounded-[32px] bg-[#F4F2EF] [touch-action:none] md:h-[560px]"
      style={{ backgroundImage: 'radial-gradient(rgba(10,10,10,.07) 1px, transparent 1px)', backgroundSize: '24px 24px' }}
    >
      {/* desktop files */}
      <div className="absolute left-6 top-6 grid grid-cols-2 gap-x-6 gap-y-5 md:left-10 md:top-10">
        {FILES.map((f, i) => (
          <button
            key={f.name}
            type="button"
            onPointerDown={down(i)}
            onKeyDown={keyOn(i)}
            aria-label={`${f.name}.${f.ext}, ${f.size}. Press Enter to choose a format.`}
            className="group flex cursor-grab flex-col items-center gap-2 rounded-2xl p-2 outline-none transition-colors duration-300 hover:bg-black/[0.03] focus-visible:ring-2 focus-visible:ring-[#FF4A14] active:cursor-grabbing"
          >
            <FileGlyph kind={f.kind} ext={f.ext} active={drag?.i === i} />
            <span className="text-center text-[13px] font-medium leading-tight text-[#0A0A0A]">
              {f.name}.{f.ext}
              <span className="block text-[11px] font-normal text-black/40">{f.size}</span>
            </span>
          </button>
        ))}
      </div>

      {/* output tray */}
      <div className="absolute bottom-6 right-6 w-[220px] rounded-[24px] bg-white/70 p-4 ring-1 ring-black/5 backdrop-blur-md md:right-10 md:top-10 md:bottom-auto md:w-[240px]">
        <p className="text-xs font-medium uppercase tracking-[0.12em] text-black/40">New copies</p>
        <ul className="mt-3 flex min-h-[44px] flex-col gap-2">
          <AnimatePresence initial={false}>
            {out.length === 0 && (
              <motion.li
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="text-[13px] leading-snug text-black/45"
              >
                Converted files land here, beside their originals.
              </motion.li>
            )}
            {out.map((o) => (
              <motion.li
                key={o.id}
                layout
                initial={{ opacity: 0, y: -10, filter: 'blur(6px)' }}
                animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.5, ease: EASE }}
                className="flex items-center justify-between rounded-xl bg-white px-3 py-2 text-[13px] font-medium text-[#0A0A0A] ring-1 ring-black/5"
              >
                <span className="truncate">{o.name}</span>
                <span className="ml-2 rounded-md bg-[#E4FF3A] px-1.5 py-0.5 text-[10px] font-semibold uppercase">new</span>
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
      </div>

      {/* hint */}
      <p className="pointer-events-none absolute bottom-6 left-6 max-w-[46%] text-[13px] leading-snug text-black/50 md:left-10 md:max-w-none">
        Press a file and drag. Tap{' '}
        <kbd className="rounded-md bg-white px-1.5 py-0.5 font-sans text-[12px] font-semibold text-black shadow-[0_1px_0_rgba(0,0,0,.12)] ring-1 ring-black/10">
          ⇧ Shift
        </kbd>{' '}
        or hold still, then let go on a format.
      </p>

      {/* wheel */}
      <AnimatePresence>
        {wheel && (
          <motion.svg
            key="wheel"
            width={R1 * 2 + 16}
            height={R1 * 2 + 16}
            viewBox={`${-R1 - 8} ${-R1 - 8} ${R1 * 2 + 16} ${R1 * 2 + 16}`}
            className="pointer-events-none absolute z-10"
            style={{ left: wheel.x - R1 - 8, top: wheel.y - R1 - 8 }}
            initial={{ scale: 0.6, opacity: 0, rotate: -14 }}
            animate={{ scale: 1, opacity: 1, rotate: 0 }}
            exit={{ scale: 0.5, opacity: 0, transition: { duration: 0.2 } }}
            transition={{ type: 'spring', stiffness: 420, damping: 28 }}
          >
            <defs>
              <linearGradient id="hot" x1="0" y1="1" x2="1" y2="0">
                <stop offset="0" stopColor="#E8160C" />
                <stop offset="0.6" stopColor="#FF4A14" />
                <stop offset="1" stopColor="#FF9A3C" />
              </linearGradient>
            </defs>
            <circle r={R1 + 6} fill="rgba(255,255,255,.55)" />
            {targets.map((t, i) => {
              const n = targets.length,
                a = (i / n) * Math.PI * 2 - Math.PI / 2,
                on = i === hot
              return (
                <motion.g key={t} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.02 }}>
                  <path
                    d={wedge(i, n)}
                    fill={on ? 'url(#hot)' : '#FFFFFF'}
                    stroke={on ? 'none' : 'rgba(10,10,10,.08)'}
                    style={{ transition: 'fill .2s' }}
                  />
                  <text
                    x={Math.cos(a) * ((R0 + R1) / 2)}
                    y={Math.sin(a) * ((R0 + R1) / 2)}
                    textAnchor="middle"
                    dominantBaseline="central"
                    fontSize="14"
                    fontWeight="600"
                    fontFamily="Inter Tight, sans-serif"
                    fill={on ? '#FFFFFF' : '#0A0A0A'}
                  >
                    {t}
                  </text>
                </motion.g>
              )
            })}
            <circle r={R0 - 6} fill="#0A0A0A" />
            <text y="-6" textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.55)" fontFamily="Inter Tight, sans-serif">
              convert to
            </text>
            <text y="10" textAnchor="middle" fontSize="13" fontWeight="600" fill="#fff" fontFamily="Inter Tight, sans-serif">
              {hot >= 0 ? targets[hot] : '…'}
            </text>
          </motion.svg>
        )}
      </AnimatePresence>

      {/* dragged ghost */}
      {drag && dragging && (
        <div className="pointer-events-none absolute z-20 -translate-x-1/2 -translate-y-[60%]" style={{ left: drag.x, top: drag.y }}>
          <div className="rotate-[-6deg] scale-90 drop-shadow-[0_18px_30px_rgba(0,0,0,.25)]">
            <FileGlyph kind={dragging.kind} ext={dragging.ext} />
          </div>
          {!wheel && (
            <motion.span
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-2 block whitespace-nowrap rounded-full bg-[#0A0A0A] px-3 py-1 text-center text-[12px] font-medium text-white"
            >
              Tap ⇧ Shift
            </motion.span>
          )}
        </div>
      )}

      {/* progress */}
      <AnimatePresence>
        {busy && (
          <motion.div
            initial={{ opacity: 0, y: 8, filter: 'blur(4px)' }}
            animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.35, ease: EASE }}
            className="absolute z-20 w-[240px] -translate-x-1/2 -translate-y-1/2 rounded-2xl bg-[#0A0A0A] p-3 text-white"
            style={{ left: busy.x, top: busy.y }}
          >
            <p className="text-[12.5px] font-medium">{busy.label}</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/15">
              <motion.div
                className="h-full rounded-full bg-gradient-to-r from-[#E8160C] via-[#FF4A14] to-[#FF9A3C]"
                initial={{ width: '0%' }}
                animate={{ width: '100%' }}
                transition={{ duration: 1, ease: [0.65, 0, 0.35, 1] }}
              />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
```

## STEP 4: Create the page

### FILE: `src/pages/Home.jsx`

Create this file with exactly this content, character for character:

```jsx
/**
 * Flare: anyfmt in a bright editorial layout. Hero background is the `shaders` stack turned
 * diagonal (FluteShader), in light for the hero and dark for the final call to action.
 */
import NumberFlow from '@number-flow/react'
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform } from 'framer-motion'
import { Fragment, useEffect, useRef, useState } from 'react'
import { Badge, ButtonStyles, DownloadButton, GitHubButton, NavDownload } from '@/components/flare/Buttons'
import { FluteShader } from '@/components/flare/FluteShader'
import { Playground } from '@/components/flare/Playground'
const EASE = [0.22, 1, 0.36, 1]
const go = (id) =>
  document
    .getElementById(id)
    ?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
const rise = (i) => ({
  initial: { opacity: 0, y: 14, filter: 'blur(6px)' },
  animate: { opacity: 1, y: 0, filter: 'blur(0px)' },
  transition: { duration: 0.9, ease: EASE, delay: 0.25 + i * 0.08 },
})
function Logo({ className = '' }) {
  return (
    <span
      className={`font-['Bricolage_Grotesque',sans-serif] text-[32px] font-bold leading-none tracking-[-0.04em] text-[#0A0A0A] [font-variation-settings:'wdth'_75] ${className}`}
    >
      anyfmt<span className="text-[#FF4A14]">.</span>
    </span>
  )
}
/* ───────────────────────────── Nav ───────────────────────────── */
const LINKS = [
  ['Try it', 'try'],
  ['Keys', 'keys'],
  ['Formats', 'numbers'],
  ['FAQ', 'faq'],
]
function Nav() {
  const [open, setOpen] = useState(false)
  return (
    <header className="absolute inset-x-0 top-0 z-30">
      <nav className="mx-auto flex max-w-[1440px] items-center justify-between px-5 pt-6 sm:px-10 lg:px-14 lg:pt-8">
        <div className="flex items-center gap-12">
          <a
            href="#"
            onClick={(e) => {
              e.preventDefault()
              window.scrollTo({ top: 0, behavior: 'smooth' })
            }}
            aria-label="anyfmt home"
          >
            <Logo />
          </a>
          <ul className="hidden items-center gap-9 md:flex">
            {LINKS.map(([l, id]) => (
              <li key={id}>
                <button
                  type="button"
                  onClick={() => go(id)}
                  className="link-line relative py-1 text-[16px] text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black"
                >
                  {l}
                </button>
              </li>
            ))}
          </ul>
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden lg:inline-flex">
            <GitHubButton />
          </span>
          <span className="hidden sm:inline-flex">
            <NavDownload onClick={() => go('download')} />
          </span>
          <button
            type="button"
            onClick={() => setOpen(true)}
            aria-label="Open menu"
            className="flex h-12 items-center gap-2 rounded-full bg-[#0A0A0A] px-5 text-[15px] font-medium text-white sm:hidden"
          >
            Menu
          </button>
        </div>
      </nav>
      <AnimatePresence>
        {open && (
          <motion.div className="fixed inset-0 z-50 sm:hidden" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <button type="button" aria-label="Close menu" onClick={() => setOpen(false)} className="absolute inset-0 bg-black/50" />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
              className="absolute inset-x-3 bottom-3 rounded-[28px] bg-white p-6"
            >
              <div className="flex items-center justify-between">
                <Logo className="text-[28px]" />
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  className="rounded-full bg-[#F1EEEA] px-4 py-2 text-[14px] font-medium"
                >
                  Close
                </button>
              </div>
              <ul className="mt-8 flex flex-col gap-2">
                {LINKS.map(([l, id], i) => (
                  <motion.li
                    key={id}
                    initial={{ opacity: 0, y: 16 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.5, ease: EASE, delay: 0.1 + i * 0.05 }}
                  >
                    <button
                      type="button"
                      onClick={() => {
                        setOpen(false)
                        setTimeout(() => go(id), 300)
                      }}
                      className="py-1 text-[32px] font-medium tracking-[-0.03em]"
                    >
                      {l}
                    </button>
                  </motion.li>
                ))}
              </ul>
              <div className="mt-8 flex flex-col gap-3">
                <DownloadButton />
                <GitHubButton />
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  )
}
/* ───────────────────────────── Hero ───────────────────────────── */
const ENGINES = [
  ['ffmpeg', 'Video and audio'],
  ['pandoc', 'Documents and ebooks'],
  ['ImageIO', 'Photos and images'],
  ['AVFoundation', 'Apple media'],
  ['VideoToolbox', 'Hardware encoding'],
  ['Vision', 'Backgrounds and QR'],
]
function Hero() {
  const [tip, setTip] = useState(-1)
  return (
    <section className="relative flex min-h-[100svh] flex-col overflow-hidden bg-[#EFEFEF]">
      <FluteShader className="pointer-events-none absolute inset-0" />
      <Nav />
      <div className="relative z-10 mx-auto flex w-full max-w-[1440px] flex-1 flex-col justify-center px-5 pb-10 pt-36 sm:px-10 lg:px-14">
        <motion.div {...rise(0)}>
          <Badge onClick={() => go('try')}>Free and open source, for macOS</Badge>
        </motion.div>
        <h1 className="mt-7 max-w-[860px] text-[clamp(44px,6.6vw,104px)] font-semibold leading-[0.97] tracking-[-0.05em] text-[#0A0A0A] [text-wrap:balance]">
          <motion.span {...rise(1)} className="block">
            Any file, any format,
          </motion.span>
          <motion.span {...rise(2)} className="block">
            one drag away.
          </motion.span>
        </h1>
        <motion.p
          {...rise(3)}
          className="mt-7 max-w-[560px] text-[clamp(17px,1.45vw,21px)] leading-[1.5] text-[#1A1A1A] [text-wrap:pretty]"
        >
          Drag a file, tap Shift, and drop it on the format you want. anyfmt converts it right there on your Mac, offline, and leaves the
          original untouched.
        </motion.p>
        <motion.div {...rise(4)} className="mt-10 flex flex-wrap items-center gap-4">
          <DownloadButton />
          <button
            type="button"
            onClick={() => go('try')}
            className="group flex h-14 items-center gap-2 rounded-full px-4 text-base font-medium text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black"
          >
            <span className="link-line relative">Try the gesture here</span>
            <svg
              width="14"
              height="14"
              viewBox="0 0 14 14"
              aria-hidden
              className="transition-transform duration-500 group-hover:translate-y-1"
            >
              <path
                d="M7 2v10M3 8l4 4 4-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.7"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        </motion.div>
      </div>
      <motion.div {...rise(6)} className="relative z-10 mx-auto w-full max-w-[1440px] px-5 pb-10 sm:px-10 lg:px-14">
        <p className="text-[15px] text-[#3A3A3A]">Engines inside, nothing to install</p>
        <ul className="mt-5 flex flex-wrap items-center gap-x-10 gap-y-4">
          {ENGINES.map(([e, d], i) => (
            <li key={e} className="relative" onPointerEnter={() => setTip(i)} onPointerLeave={() => setTip(-1)}>
              <span
                className={`text-[22px] font-semibold tracking-[-0.03em] transition-colors duration-300 ${tip === i ? 'text-[#0A0A0A]' : 'text-[#0A0A0A]/45'}`}
              >
                {e}
              </span>
              <AnimatePresence>
                {tip === i && (
                  <motion.span
                    initial={{ opacity: 0, y: 6, filter: 'blur(4px)' }}
                    animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
                    exit={{ opacity: 0, y: 4 }}
                    transition={{ duration: 0.3, ease: EASE }}
                    className="absolute bottom-full left-0 mb-2 whitespace-nowrap rounded-full bg-[#0A0A0A] px-3 py-1 text-[12px] font-medium text-white"
                  >
                    {d}
                  </motion.span>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </motion.div>
    </section>
  )
}
/* ───────────────────────────── Statement ───────────────────────────── */
const STATEMENT = 'Other converters want your file before they help. anyfmt meets it where it already is.'
function W({ children, p, i, n }) {
  const s = (i / n) * 0.8
  const color = useTransform(p, [s, s + 0.12], ['#CFCBC6', '#0A0A0A'])
  return <motion.span style={{ color }}>{children}</motion.span>
}
function Statement() {
  const ref = useRef(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 85%', 'end 45%'] })
  const words = STATEMENT.split(' ')
  return (
    <section className="bg-white px-5 pb-24 pt-28 sm:px-10 lg:pb-32 lg:pt-40">
      <p className="flex items-center justify-center gap-3 text-[18px] text-[#0A0A0A]">
        <span className="h-2.5 w-2.5 bg-[#0A0A0A]" />
        What it does
      </p>
      <div ref={ref} className="mx-auto mt-8 max-w-[1240px]">
        <p
          className="text-center text-[clamp(36px,5.6vw,88px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]"
          aria-label={STATEMENT}
        >
          {words.map((w, i) => (
            <Fragment key={i}>
              {reduce ? (
                <span>{w}</span>
              ) : (
                <W p={scrollYProgress} i={i} n={words.length}>
                  {w}
                </W>
              )}
              {i < words.length - 1 ? ' ' : ''}
            </Fragment>
          ))}
        </p>
      </div>
    </section>
  )
}
/* ───────────────────────────── Try it ───────────────────────────── */
function TrySection() {
  return (
    <section id="try" className="scroll-mt-6 bg-white px-5 pb-24 sm:px-10 lg:px-14 lg:pb-32">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-10 flex flex-wrap items-end justify-between gap-6">
          <h2 className="max-w-[640px] text-[clamp(32px,3.8vw,56px)] font-semibold leading-[1.02] tracking-[-0.04em]">
            Go on, try the gesture.
          </h2>
          <p className="max-w-[420px] text-[17px] leading-[1.5] text-[#3A3A3A]">
            This is the real interaction, minus your files. On a keyboard, focus a file and press Enter, then the arrow keys.
          </p>
        </div>
        <Playground />
      </div>
    </section>
  )
}
/* ───────────────────────────── Keys ───────────────────────────── */
const KEYS = [
  { k: '⇧', name: 'Shift', verb: 'Convert', items: ['GIF', 'MP4', 'PDF', 'JPG', 'MP3', 'WEBP', 'EPUB', 'PNG'] },
  { k: '⌘', name: 'Command', verb: 'Edit', items: ['Compress', 'Trim', 'Crop', 'Resize', 'Remove background', 'Strip metadata'] },
  { k: '⌃', name: 'Control', verb: 'Act', items: ['AirDrop', 'Float', 'Copy', 'Move', 'Copy path', 'Terminal'] },
]
function KeysSection() {
  const [on, setOn] = useState(-1)
  return (
    <section id="keys" className="scroll-mt-6 bg-[#F4F2EF] px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto max-w-[1440px]">
        <p className="flex items-center gap-3 text-[18px]">
          <span className="h-2.5 w-2.5 bg-[#0A0A0A]" />
          Three keys
        </p>
        <h2 className="mt-6 max-w-[900px] text-[clamp(36px,4.6vw,72px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">
          One drag. Three keys. Every file you own.
        </h2>
        <div className="mt-16 grid gap-5 md:grid-cols-3">
          {KEYS.map((k, i) => (
            <div
              key={k.name}
              onPointerEnter={() => setOn(i)}
              onPointerLeave={() => setOn(-1)}
              className="group rounded-[28px] bg-white p-8"
            >
              <div
                className={`flex h-[140px] w-[200px] flex-col justify-between rounded-[22px] bg-[#FBFAF8] p-5 ring-1 ring-black/5 transition-[transform,box-shadow] duration-200 ${on === i ? 'translate-y-[5px] shadow-[0_1px_0_#D9D4CE,0_2px_6px_rgba(0,0,0,.06)]' : 'shadow-[0_6px_0_#D9D4CE,0_16px_30px_-12px_rgba(0,0,0,.18)]'}`}
              >
                <span className="text-[40px] leading-none">{k.k}</span>
                <span className="text-[15px] font-medium text-[#3A3A3A]">{k.name}</span>
              </div>
              <p className="mt-8 text-[30px] font-semibold tracking-[-0.03em]">{k.verb}</p>
              <ul className="mt-4 flex flex-wrap gap-2">
                {k.items.map((t, j) => (
                  <li
                    key={t}
                    className="rounded-full px-3 py-1.5 text-[14px] font-medium ring-1 ring-black/10 transition-[background-color,color,transform] duration-300"
                    style={{
                      transitionDelay: on === i ? `${j * 40}ms` : '0ms',
                      background: on === i ? '#0A0A0A' : 'transparent',
                      color: on === i ? '#fff' : '#0A0A0A',
                      transform: on === i ? 'translateY(-2px)' : 'none',
                    }}
                  >
                    {t}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
/* ───────────────────────────── Numbers ───────────────────────────── */
function Numbers() {
  const ref = useRef(null)
  const seen = useInView(ref, { once: true, amount: 0.4 })
  const stats = [
    [793, 'Conversion routes', 'Each run on a real file and checked before it ships.'],
    [26, 'Editing tools', 'Compress to a target size, trim, crop, redact, merge.'],
    [0, 'Uploads', 'Everything happens on your Mac, offline.'],
  ]
  return (
    <section id="numbers" ref={ref} className="scroll-mt-6 bg-white px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 md:grid-cols-3 md:gap-0">
        {stats.map(([n, l, d], i) => (
          <div key={l} className={`md:px-10 ${i > 0 ? 'md:border-l md:border-black/10' : 'md:pl-0'}`}>
            <p className="text-[clamp(72px,8vw,128px)] font-semibold leading-none tracking-[-0.06em]">
              <NumberFlow
                value={seen ? n : 0}
                transformTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }}
                spinTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }}
              />
            </p>
            <p className="mt-4 text-[20px] font-semibold tracking-[-0.02em]">{l}</p>
            <p className="mt-2 max-w-[320px] text-[16px] leading-[1.5] text-[#3A3A3A]">{d}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
/* ───────────────────────────── FAQ ───────────────────────────── */
const FAQ = [
  ['Is it really free?', 'Yes. Every conversion, tool and action that runs on your Mac is free, commercial use included.'],
  [
    'Does it upload my files?',
    'No. Work happens on your Mac, offline. Share links are the only thing that leaves, and only when you make one.',
  ],
  ['Will it overwrite my original?', 'Never. Every conversion and edit writes a new copy beside the file you started with.'],
  ['What do I need?', 'A Mac with Apple silicon on macOS 13 Ventura or later. The engines ship inside the app.'],
  ['Can I script it?', 'Yes. The anyfmt command in Terminal runs the same routes the wheel does.'],
]
function Faq() {
  const [open, setOpen] = useState(0)
  return (
    <section id="faq" className="scroll-mt-6 bg-[#F4F2EF] px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
        <div>
          <p className="flex items-center gap-3 text-[18px]">
            <span className="h-2.5 w-2.5 bg-[#0A0A0A]" />
            Questions
          </p>
          <h2 className="mt-6 text-[clamp(36px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Short answers.</h2>
        </div>
        <ul className="divide-y divide-black/10 border-y border-black/10">
          {FAQ.map(([q, a], i) => (
            <li key={q}>
              <button
                type="button"
                aria-expanded={open === i}
                onClick={() => setOpen(open === i ? -1 : i)}
                className="group flex w-full items-center justify-between gap-6 py-6 text-left text-[clamp(19px,1.6vw,24px)] font-medium tracking-[-0.02em] outline-none focus-visible:ring-2 focus-visible:ring-black"
              >
                {q}
                <span
                  className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition-[background-color,transform] duration-500 ${open === i ? 'rotate-45 bg-[#FF4A14] text-white' : 'bg-white text-black group-hover:bg-[#E4FF3A]'}`}
                >
                  <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden>
                    <path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                  </svg>
                </span>
              </button>
              <AnimatePresence initial={false}>
                {open === i && (
                  <motion.p
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.45, ease: EASE }}
                    className="max-w-[620px] overflow-hidden text-[17px] leading-[1.55] text-[#3A3A3A]"
                  >
                    <span className="block pb-6">{a}</span>
                  </motion.p>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}
/* ───────────────────────────── Final CTA ───────────────────────────── */
function FinalCta() {
  return (
    <section id="download" className="bg-white p-3 sm:p-5">
      <div className="relative overflow-hidden rounded-[32px] bg-[#0A0A0A]">
        <FluteShader variant="dark" corner="bl" className="pointer-events-none absolute inset-0" />
        <div className="relative mx-auto flex min-h-[640px] max-w-[1440px] flex-col items-end justify-center px-6 py-24 text-right sm:px-14">
          <h2 className="max-w-[820px] text-[clamp(44px,6vw,96px)] font-semibold leading-[0.97] tracking-[-0.05em] text-white [text-wrap:balance]">
            Your next drag already knows the way.
          </h2>
          <p className="mt-6 max-w-[460px] text-[18px] leading-[1.5] text-white/70">
            Free, no account, open source. Install it once and every file you touch learns a new trick.
          </p>
          <div className="mt-10 flex flex-wrap justify-end gap-3">
            <GitHubButton />
            <DownloadButton tone="light" />
          </div>
        </div>
      </div>
    </section>
  )
}
function FooterCol({ title, children }) {
  return (
    <div>
      <p className="flex items-center gap-2.5 text-[14px] text-[#6A6A6A]">
        <span className="h-2 w-2 bg-[#0A0A0A]" />
        {title}
      </p>
      <ul className="mt-5 flex flex-col gap-3 text-[16px]">{children}</ul>
    </div>
  )
}
function Footer() {
  return (
    <footer className="bg-white px-5 pb-8 pt-20 sm:px-10 lg:px-14">
      <div className="mx-auto max-w-[1440px]">
        <div className="grid gap-12 border-t border-black/10 pt-12 sm:grid-cols-2 lg:grid-cols-[minmax(0,1.5fr)_repeat(3,minmax(0,1fr))]">
          <div>
            <Logo />
            <p className="mt-5 max-w-[340px] text-[16px] leading-[1.5] text-[#3A3A3A]">
              Any file, any format, one drag away. Free and open source, for macOS.
            </p>
            <div className="mt-7">
              <NavDownload onClick={() => go('download')} />
            </div>
          </div>
          <FooterCol title="On this page">
            {LINKS.map(([l, id]) => (
              <li key={id}>
                <button type="button" onClick={() => go(id)} className="link-line relative">
                  {l}
                </button>
              </li>
            ))}
          </FooterCol>
          <FooterCol title="Project">
            <li>
              <button type="button" onClick={() => go('download')} className="link-line relative">
                Download
              </button>
            </li>
            <li className="flex items-center gap-2 text-[#0A0A0A]/45">
              Source on GitHub<span className="rounded-full bg-[#E4FF3A] px-2 py-0.5 text-[11px] font-semibold text-[#0A0A0A]">Soon</span>
            </li>
            <li>
              <a href="https://www.gnu.org/licenses/agpl-3.0.html" target="_blank" rel="noreferrer" className="link-line relative">
                Licence: AGPL 3.0
              </a>
            </li>
          </FooterCol>
          <FooterCol title="Requirements">
            <li className="text-[#3A3A3A]">Mac with Apple silicon</li>
            <li className="text-[#3A3A3A]">macOS 13 Ventura or later</li>
            <li className="text-[#3A3A3A]">No account, no uploads</li>
          </FooterCol>
        </div>
        <div className="mt-16 flex flex-wrap items-center justify-between gap-4 border-t border-black/10 pt-6 text-[14px] text-[#6A6A6A]">
          <span>© 2026 anyfmt</span>
          <button
            type="button"
            onClick={() =>
              window.scrollTo({ top: 0, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
            }
            className="group flex items-center gap-2 text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black"
          >
            <span className="link-line relative">Back to top</span>
            <span className="relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-[#F1EEEA] transition-colors duration-300 group-hover:bg-[#0A0A0A] group-hover:text-white">
              {[0, 1].map((k) => (
                <svg
                  key={k}
                  width="12"
                  height="12"
                  viewBox="0 0 12 12"
                  aria-hidden
                  className={`absolute transition-transform duration-500 ${k === 0 ? 'group-hover:-translate-y-6' : 'translate-y-6 group-hover:translate-y-0'}`}
                  style={{ transitionTimingFunction: 'cubic-bezier(0.785,0.135,0.15,0.86)' }}
                >
                  <path
                    d="M6 10.5v-9M2 5.5l4-4 4 4"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.6"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              ))}
            </span>
          </button>
        </div>
      </div>
    </footer>
  )
}
export default function FlareLanding() {
  useEffect(() => {
    document.title = 'anyfmt: any file, any format, one drag away'
  }, [])
  return (
    <div className="min-h-screen bg-white font-['Inter_Tight',ui-sans-serif,system-ui,sans-serif] text-[#0A0A0A] antialiased">
      <ButtonStyles />
      <style>{`
        .link-line::after { content:""; position:absolute; left:0; right:0; bottom:-2px; height:1.5px; background:currentColor; transform:scaleX(0); transform-origin:right; transition:transform .5s cubic-bezier(.785,.135,.15,.86); }
        .link-line:hover::after, button:focus-visible .link-line::after, .group:hover .link-line::after { transform:scaleX(1); transform-origin:left; }
      `}</style>
      <Hero />
      <main>
        <Statement />
        <TrySection />
        <KeysSection />
        <Numbers />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
    </div>
  )
}
```

If the app already has a `src/pages/Home.jsx`, replace its entire content with the code above.

## STEP 5: Routing and layout

1. Make `Home` the app's main page, served at `/`. Edit `src/App.jsx` (or the pages config) surgically; do not rewrite the router.
2. This page must render **without the app Layout chrome**: no Layout header, nav, sidebar, container padding, max-width, background colour or footer around it. If the app uses a `Layout.jsx` wrapper, make it return `children` unchanged for this page (for example: `if (currentPageName === 'Home') return children;` at the top of the Layout component), or register the route outside the Layout. The page must touch all four viewport edges.
3. The page is public: no login gate, no redirect.
4. Do not add a `<Toaster />`, cookie banner, or any other global overlay on top of this page.

## STEP 6: Self-check before you reply (SUCCESS CRITERIA)

Verify each of these at 1440px, 1280px, 1024px, 768px, 390px and 375px wide. The clone is complete only when every line is true:

- [ ] No horizontal scrolling at any width.
- [ ] The headline reads "Any file, any format," on line one and "one drag away." on line two at 1440px, in Inter Tight 600, black.
- [ ] The wordmark "anyfmt." renders in condensed Bricolage Grotesque (narrow, bold) with an orange full stop.
- [ ] The hero background shows diagonal glassy flutes with an orange to red colour mass in the top right corner that slowly breathes; moving the mouse over the hero adds a light that follows the pointer.
- [ ] On a phone (390px) the orange stays in the top right corner and the headline sits on a light background.
- [ ] Hovering "Download for Mac" floods it lime from the arrow circle and the label turns black; clicking shows a progress ring, then "First release lands soon", then returns to normal.
- [ ] Hovering "Star on GitHub" shows a spinning orange conic border, rotates the star, and shows the tooltip "The repo goes public with the first release"; clicking bursts sparks and rolls the label to "Starred, thank you". It does not navigate anywhere.
- [ ] In "Go on, try the gesture." pressing a file and dragging, then pressing Shift or holding still, opens the radial wheel; releasing on a wedge adds a "new" file to the "New copies" tray.
- [ ] The numbers count up to 793, 26 and 0 when scrolled into view.
- [ ] The final call to action is a black rounded panel with the shader burning orange from the bottom left corner.
- [ ] The footer shows the wordmark column, "On this page", "Project" (with a lime "Soon" tag on "Source on GitHub") and "Requirements" columns, and a base bar with "© 2026 anyfmt" and "Back to top".
- [ ] No console errors. No layout chrome from the app around the page.

## STEP 7: Reply format

1. **Packages:** installed names and exact versions.
2. **Files:** every file created or edited, with one line on what changed in each edited file.
3. **Routing:** exactly how `/` now renders `Home` without Layout chrome.
4. **Self-check:** the checklist above with each item marked pass or fail, and for any fail, the exact reason.
5. **Deviations:** "None", or a precise list of anything you could not do verbatim and why.

## NOTES

- The shader runs on WebGPU (current Chrome, Edge, Safari). Where WebGPU is unavailable the component renders its own CSS gradient fallback automatically; do not "fix" this.
- `disableTelemetry` on the `Shader` component is intentional. Keep it.
- The JavaScript bundle is large because of the `shaders` package. That is expected; do not try to code-split or remove it.
