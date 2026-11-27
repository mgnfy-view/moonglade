import { useEffect, useState } from 'react'
import { Check, Copy } from 'lucide-react'
import { useTheme } from '../theme/ThemeProvider'

type HighlightedHighlighter = {
  codeToHtml: (code: string, options: { lang: string; theme: string }) => string
}

let highlighterPromise: Promise<HighlightedHighlighter> | null = null

const SUPPORTED_LANGS = new Set([
  'solidity',
  'sol',
  'bash',
  'sh',
  'shell',
  'typescript',
  'ts',
  'tsx',
  'json',
])

function normalizeLang(raw?: string): string {
  const lower = (raw ?? 'text').toLowerCase()
  if (lower === 'sol') return 'solidity'
  if (lower === 'sh' || lower === 'shell') return 'bash'
  if (lower === 'ts') return 'typescript'
  return lower
}

async function getHighlighter(): Promise<HighlightedHighlighter> {
  if (!highlighterPromise) {
    highlighterPromise = (async () => {
      const [
        { createHighlighterCore },
        { createJavaScriptRegexEngine },
        solidity,
        bash,
        typescript,
        tsx,
        json,
        githubLight,
        tokyoNight,
      ] = await Promise.all([
        import('shiki/core'),
        import('shiki/engine/javascript'),
        import('shiki/langs/solidity.mjs'),
        import('shiki/langs/bash.mjs'),
        import('shiki/langs/typescript.mjs'),
        import('shiki/langs/tsx.mjs'),
        import('shiki/langs/json.mjs'),
        import('shiki/themes/github-light.mjs'),
        import('shiki/themes/tokyo-night.mjs'),
      ])

      return createHighlighterCore({
        langs: [solidity.default, bash.default, typescript.default, tsx.default, json.default],
        themes: [githubLight.default, tokyoNight.default],
        engine: createJavaScriptRegexEngine(),
      })
    })()
  }
  return highlighterPromise
}

export function CodeBlock({ code, language }: { code: string; language?: string }) {
  const { theme } = useTheme()
  const lang = normalizeLang(language)
  const canHighlight = SUPPORTED_LANGS.has(lang)
  const [html, setHtml] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!canHighlight) {
      setHtml(null)
      return
    }
    let active = true
    getHighlighter()
      .then((highlighter) => {
        if (!active) return
        setHtml(
          highlighter.codeToHtml(code, {
            lang,
            theme: theme === 'dark' ? 'tokyo-night' : 'github-light',
          }),
        )
      })
      .catch(() => {
        if (active) setHtml(null)
      })
    return () => {
      active = false
    }
  }, [code, lang, theme, canHighlight])

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(code)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1600)
    } catch {
      // Ignore clipboard failures in restricted environments.
    }
  }

  return (
    <div className="my-5 overflow-hidden border border-hairline bg-surface">
      <div className="flex items-center justify-between gap-3 border-b border-hairline bg-subtle px-3.5 py-2 text-[11px] font-medium uppercase tracking-[0.06em] text-ink-muted">
        <span>{lang}</span>
        <button
          type="button"
          onClick={() => void handleCopy()}
          className="inline-flex min-h-[28px] items-center gap-1.5 rounded-[var(--radius-xs)] border border-hairline bg-elevated px-2 py-1 text-[11px] font-medium normal-case tracking-normal text-ink hover:border-accent hover:text-accent"
        >
          {copied ? <Check size={12} aria-hidden="true" /> : <Copy size={12} aria-hidden="true" />}
          <span>{copied ? 'Copied' : 'Copy'}</span>
        </button>
      </div>
      <div className="overflow-x-auto p-4 font-mono text-[13px] leading-[1.65] tabular-nums [&_pre]:m-0 [&_pre]:!bg-transparent [&_pre]:font-mono">
        {html ? (
          <div dangerouslySetInnerHTML={{ __html: html }} />
        ) : (
          <pre className="m-0 whitespace-pre text-ink">
            <code>{code}</code>
          </pre>
        )}
      </div>
    </div>
  )
}
