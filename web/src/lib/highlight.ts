/**
 * A small syntax highlighter for the languages the docs use: bash, json, ts/js, yaml, http.
 * Not a parser; good enough to make examples easy to read, and the same on server and client.
 */
export type TokenKind = 'plain' | 'comment' | 'string' | 'number' | 'keyword' | 'key' | 'flag' | 'prompt' | 'punct' | 'fn' | 'var' | 'op'
export type Token = [TokenKind, string]

const KW_TS = new Set(['import', 'from', 'export', 'const', 'let', 'var', 'await', 'async', 'function', 'return', 'new', 'if', 'else', 'for', 'of', 'in', 'try', 'catch', 'throw', 'type', 'interface', 'default', 'true', 'false', 'null', 'undefined', 'class', 'extends', 'while', 'public', 'static', 'struct', 'enum', 'case', 'func', 'guard', 'self'])
const KW_SH = new Set(['export', 'if', 'then', 'fi', 'for', 'do', 'done', 'in', 'echo', 'cd', 'sudo'])

function run(src: string, rules: [TokenKind, RegExp][]): Token[] {
  const out: Token[] = []
  let i = 0
  const push = (k: TokenKind, v: string) => { const last = out[out.length - 1]; if (last && last[0] === k) last[1] += v; else out.push([k, v]) }
  outer: while (i < src.length) {
    for (const [kind, re] of rules) {
      re.lastIndex = i
      const m = re.exec(src)
      if (m && m.index === i && m[0].length) { push(kind, m[0]); i += m[0].length; continue outer }
    }
    push('plain', src[i]); i++
  }
  return out
}

const y = (s: string, flags = '') => new RegExp(s, 'y' + flags)

function ts(src: string): Token[] {
  return run(src, [
    ['comment', y('//[^\\n]*|/\\*[\\s\\S]*?\\*/')],
    ['string', y('`(?:\\\\.|[^`\\\\])*`|"(?:\\\\.|[^"\\\\\\n])*"|\'(?:\\\\.|[^\'\\\\\\n])*\'')],
    ['number', y('\\b\\d[\\d_.]*\\b')],
    ['fn', y('[A-Za-z_$][\\w$]*(?=\\s*\\()')],
    ['plain', y('[A-Za-z_$][\\w$]*')],
    ['punct', y('[{}()[\\];,.]')],
    ['op', y('=>|[=+\\-*/<>!?:&|]+')],
  ]).map(([k, v]) => (k === 'plain' && KW_TS.has(v) ? ['keyword', v] : k === 'fn' && KW_TS.has(v) ? ['keyword', v] : [k, v]))
}

function json(src: string): Token[] {
  return run(src, [
    ['comment', y('//[^\\n]*')],
    ['key', y('"(?:\\\\.|[^"\\\\])*"(?=\\s*:)')],
    ['string', y('"(?:\\\\.|[^"\\\\])*"')],
    ['number', y('-?\\b\\d[\\d.eE+-]*\\b')],
    ['keyword', y('\\b(?:true|false|null)\\b')],
    ['punct', y('[{}[\\],:]')],
  ])
}

function bash(src: string): Token[] {
  return run(src, [
    ['comment', y('(?<=^|\\s)#[^\\n]*', 'm')],
    ['prompt', y('^\\$ ', 'm')],
    ['string', y('"(?:\\\\.|[^"\\\\])*"|\'[^\']*\'')],
    ['var', y('\\$\\{?[A-Za-z_][\\w]*\\}?|\\$\\(')],
    ['flag', y('(?<=\\s)--?[A-Za-z][\\w-]*')],
    ['op', y('\\|\\||&&|[|>\\\\]')],
    ['plain', y('[A-Za-z_][\\w.-]*')],
  ]).map(([k, v]) => (k === 'plain' && KW_SH.has(v) ? ['keyword', v] : [k, v]))
}

function yaml(src: string): Token[] {
  return run(src, [
    ['comment', y('#[^\\n]*')],
    ['key', y('^\\s*[\\w.-]+(?=:)', 'm')],
    ['string', y('"(?:\\\\.|[^"\\\\])*"|\'[^\']*\'')],
    ['number', y('\\b\\d[\\d.]*\\b')],
    ['keyword', y('\\b(?:true|false|null)\\b')],
    ['punct', y('[{}[\\],:-]')],
  ])
}

function http(src: string): Token[] {
  return run(src, [
    ['keyword', y('^(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\\b', 'm')],
    ['key', y('^[A-Za-z-]+(?=:)', 'm')],
    ['string', y('"(?:\\\\.|[^"\\\\])*"')],
    ['number', y('\\b\\d{3}\\b')],
  ])
}

export function highlight(code: string, lang = ''): Token[] {
  const l = lang.toLowerCase()
  if (l === 'swift' || l === 'ts' || l === 'tsx' || l === 'js' || l === 'jsx' || l === 'javascript' || l === 'typescript' || l === 'mjs') return ts(code)
  if (l === 'json' || l === 'jsonc') return json(code)
  if (l === 'bash' || l === 'sh' || l === 'shell' || l === 'zsh' || l === 'console') return bash(code)
  if (l === 'yaml' || l === 'yml') return yaml(code)
  if (l === 'http') return http(code)
  return [['plain', code]]
}

/** Colours on the dark code surface. */
export const TOKEN_CLASS: Record<TokenKind, string> = {
  plain: 'text-[#EDEAE6]',
  comment: 'text-[#8A847D] italic',
  string: 'text-[#FFC27A]',
  number: 'text-[#FF8A5B]',
  keyword: 'text-[#FF6A3D]',
  key: 'text-[#E4FF3A]',
  flag: 'text-[#9FD3FF]',
  prompt: 'text-[#FF4A14] select-none',
  punct: 'text-[#A7A19A]',
  fn: 'text-[#FFFFFF]',
  var: 'text-[#C9F27A]',
  op: 'text-[#D6D0CA]',
}
