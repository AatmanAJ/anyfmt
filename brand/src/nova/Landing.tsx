import { motion, useMotionValueEvent, useScroll } from 'motion/react'
import { Download } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Toaster, toast } from 'sonner'
import { Wordmark } from './Logo'
import { Button, scrollToId, useSmoothScroll } from './fx/ui'
import { Hero } from './Hero'
import { Story } from './Story'
import { Agents, Cta, Faq, Features, Footer, FormatsMarquee, Playground, Pricing } from './Sections'
import './nova.css'

const LINKS = [['How it works', 'story'], ['Features', 'features'], ['Playground', 'play'], ['Agents', 'agents'], ['Pricing', 'pricing']] as const

function Nav() {
  const { scrollY } = useScroll()
  const [scrolled, setScrolled] = useState(false)
  const [hover, setHover] = useState<string | null>(null)
  useMotionValueEvent(scrollY, 'change', (v) => setScrolled(v > 40))
  return (
    <motion.header initial={{ y: -30, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.1, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
      className="fixed inset-x-0 top-0 z-50 flex justify-center px-3 pt-3">
      <nav className={`flex h-14 w-full max-w-[1100px] items-center justify-between rounded-[18px] pl-4 pr-2 transition-all duration-500 ${scrolled ? 'bg-[rgba(10,10,15,.72)] shadow-[inset_0_0_0_1px_var(--nv-line),0_20px_60px_-20px_rgba(0,0,0,.8)] backdrop-blur-2xl' : 'bg-transparent'}`}>
        <button className="rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-[var(--nv-ion)]" onClick={() => scrollToId('top')} aria-label="anyfmt, back to top"><Wordmark size={19} /></button>
        <ul className="relative hidden items-center md:flex" onPointerLeave={() => setHover(null)}>
          {LINKS.map(([label, id]) => (
            <li key={id} className="relative">
              {hover === id && <motion.span layoutId="nv-nav-pill" className="absolute inset-0 rounded-[11px] bg-white/[.07]" transition={{ type: 'spring', stiffness: 500, damping: 36 }} />}
              <button onPointerEnter={() => setHover(id)} onClick={() => scrollToId(id)}
                className="relative px-3.5 py-2 text-[14px] text-[var(--nv-mute)] outline-none transition-colors hover:text-[var(--nv-text)] focus-visible:text-[var(--nv-text)]">{label}</button>
            </li>
          ))}
        </ul>
        <Button variant="molten" onClick={() => toast('Download starts soon', { description: 'This button is a placeholder.' })}><Download size={16} strokeWidth={2.4} />Download</Button>
      </nav>
    </motion.header>
  )
}

export default function Landing() {
  useSmoothScroll()
  useEffect(() => { document.title = 'anyfmt: any file, mid-drag' }, [])
  return (
    <div className="nv nv-grain min-h-screen overflow-x-clip">
      <Toaster theme="dark" position="bottom-center" toastOptions={{ style: { background: 'rgba(16,16,24,.9)', border: '1px solid rgba(255,255,255,.1)', color: '#F3F1F7', backdropFilter: 'blur(16px)', fontFamily: 'Geist Variable, sans-serif' } }} />
      <Nav />
      <Hero />
      <FormatsMarquee />
      <Story />
      <Features />
      <Playground />
      <Agents />
      <Pricing />
      <Faq />
      <Cta />
      <Footer />
    </div>
  )
}
