// Renders the Flare recording backgrounds (#/wallpaper/<id>) to PNG with headless Chrome on real WebGPU.
// Needs the dev server on :5199 and playwright-core (PW=/path/to/playwright-core if it is not installed here).
// usage: node scripts/render-wallpapers.cjs [id...]
const path = require('path')
const { chromium } = require(process.env.PW || 'playwright-core')

const ids = process.argv.slice(2).length ? process.argv.slice(2) : ['ember', 'molten', 'eclipse', 'night', 'paper']
const sizes = [[1920, 1200], [1920, 1080]] // CSS px at 2x: 3840×2400 (16:10, a Mac screen) and 3840×2160 (16:9)
const out = path.join(__dirname, '..', 'wallpapers')
const chrome = process.env.CHROME ||
  `${process.env.HOME}/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing`

;(async () => {
  require('fs').mkdirSync(out, { recursive: true })
  const browser = await chromium.launch({ executablePath: chrome, headless: true,
    args: ['--headless=new', '--enable-unsafe-webgpu', '--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist'] })
  for (const [w, h] of sizes) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 2 })
    for (const id of ids) {
      const page = await ctx.newPage()
      await page.goto(`http://localhost:5199/#/wallpaper/${id}`)
      await page.waitForSelector('[data-ready="1"] canvas', { timeout: 30000 })
      await page.waitForTimeout(2500) // let every pass settle; time is frozen, so frames are identical
      const file = path.join(out, `anyfmt-${id}-${w * 2}x${h * 2}.png`)
      await page.screenshot({ path: file })
      console.log(file)
      await page.close()
    }
    await ctx.close()
  }
  await browser.close()
})().catch((e) => { console.error(e); process.exit(1) })
