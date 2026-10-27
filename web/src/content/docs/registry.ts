/**
 * The docs, in reading order. Each slug is a Markdown file beside this one (`<slug>.md`, with
 * `title` and `description` front matter); `index` is /docs itself.
 */
export interface DocSection { title: string; items: [slug: string, label: string][] }

export const DOC_SECTIONS: DocSection[] = [
  { title: 'Start here', items: [['index', 'Overview'], ['install', 'Install'], ['first-conversion', 'Your first conversion'], ['permissions', 'Permissions']] },
  { title: 'The app', items: [['wheel', 'The wheel'], ['options-presets', 'Options and presets'], ['tools', 'Tools'], ['actions', 'Actions and Float'], ['keyboard', 'Keys and shortcuts'], ['routes', 'How routes work'], ['settings', 'Settings']] },
  { title: 'Command line and agents', items: [['cli', 'Command line'], ['cli-reference', 'Command reference'], ['json-output', 'JSON events and exit codes'], ['mcp', 'MCP server'], ['agent-recipes', 'Agent recipes']] },
  { title: 'HTTP API (preview)', items: [['api', 'API overview'], ['api-auth', 'Authentication'], ['api-files', 'Files'], ['api-conversions', 'Conversions'], ['api-formats', 'Formats and schema'], ['api-webhooks', 'Webhooks'], ['api-errors', 'Errors'], ['api-limits', 'Rate limits and retries'], ['sdk', 'TypeScript SDK']] },
  { title: 'Pro and self-hosting', items: [['pro', 'What Pro adds'], ['self-host', 'Self-host the server'], ['licence-keys', 'Licence keys']] },
  { title: 'Help', items: [['troubleshooting', 'Troubleshooting'], ['uninstall', 'Uninstall']] },
]

export const DOC_ORDER = DOC_SECTIONS.flatMap((s) => s.items.map(([slug, label]) => ({ slug, label, section: s.title })))
