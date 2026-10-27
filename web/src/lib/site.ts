/** One place for the facts the whole site repeats. Change a price or an address here only. */

export const SITE = {
  name: 'anyfmt',
  url: 'https://anyfmt.app',
  tagline: 'Any file, any format, one drag away.',
  description:
    'anyfmt is an open-source macOS menu bar app that converts files where they are. Drag a file, tap Shift, drop it on the format you want. 793 tested conversion routes, all on your Mac, nothing uploaded.',
  github: 'https://github.com/AatmanAJ/anyfmt',
  version: '0.1.0',
  released: false, // flips when the first public build ships; download copy reads from this
  dmgSize: '27 MB',
  appSize: '63 MB',
  requires: 'Apple silicon, macOS 13 Ventura or later',
  email: { hello: 'hello@anyfmt.app', support: 'support@anyfmt.app', sales: 'teams@anyfmt.app', press: 'press@anyfmt.app', security: 'security@anyfmt.app', legal: 'legal@anyfmt.app' },
  brew: { cask: 'brew install --cask aatmanaj/tap/anyfmt', cli: 'brew install aatmanaj/tap/anyfmt-cli' },
} as const

/** Prices are proposals until checkout exists; every page reads them from here. */
export const PRICES = {
  desktop: { once: 19, macs: 3 },
  pro: { monthly: 8, yearlyPerMonth: 6 },
  api: { perConversion: 0.01, perMediaMinute: 0.02 },
  donate: [3, 5, 10, 25],
  donateUrl: 'https://buymeacoffee.com/aiwithaj',
} as const

export const fmtUsd = (n: number) => (n < 1 ? `${Math.round(n * 100)}¢` : `$${Number.isInteger(n) ? n : n.toFixed(2)}`)
