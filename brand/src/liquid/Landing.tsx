import { useEffect } from 'react'
import SculptureHero from '../components/ui/liquid-sculpture-hero'
import sculpture from './sculpture.webp'

/** anyfmt, hero only: the wheel as a chrome sculpture that turns liquid under the cursor. */
export default function Landing() {
  useEffect(() => { document.title = 'anyfmt' }, [])
  return (
    <SculptureHero
      src={sculpture}
      darkSrc={sculpture}
      mobileSrc={sculpture}
      mobileDarkSrc={sculpture}
      imageAlt="The anyfmt wheel as a chrome sculpture: eight wedges in a ring, one lifted out and unravelling into threads"
      loadFonts={false}
      headingFont="'Geist Variable', 'Helvetica Neue', Arial, sans-serif"
      bodyFont="'Geist Variable', 'Helvetica Neue', Arial, sans-serif"
      accentFont="'Instrument Serif', 'Times New Roman', serif"
      background="#ECEAE6"
      darkBackground="#0F0F0E"
      themeToggle
      brand="anyfmt"
      navLinks={[
        { label: 'How it works', href: '#' },
        { label: 'Formats', href: '#' },
        { label: 'Agents', href: '#' },
        { label: 'Pricing', href: '#' },
      ]}
      navCta={{ label: 'Download', href: '#' }}
      eyebrow="Free and open source, for macOS"
      headline={'Any file, any format.\nMid-drag.'}
      headlineAccent="Mid-drag."
      body="Drag a file, tap Shift, and a wheel of everything it can become opens under your pointer. Let go on one. It runs on your Mac, in milliseconds, and nothing is uploaded."
      primaryCta={{ label: 'Download for Mac', href: '#' }}
      secondaryCta={{ label: 'See how it works', href: '#' }}
      hint="Move across the wheel"
      hintTouch="Touch the wheel"
      backdropText="anyfmt"
      intro
      sculptureScale={0.92}
    />
  )
}
