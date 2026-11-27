import { useEffect, useId, useState } from 'react'
import { useTheme } from '../theme/ThemeProvider'

export function MermaidDiagram({ chart }: { chart: string }) {
  const { theme } = useTheme()
  const rawId = useId()
  const renderId = `moonglade-mermaid-${rawId.replace(/[^a-zA-Z0-9_-]/g, '')}-${theme}`
  const [svg, setSvg] = useState<string | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let active = true
    setFailed(false)

    import('mermaid')
      .then(async (mod) => {
        const mermaid = mod.default
        const isDark = theme === 'dark'
        mermaid.initialize({
          startOnLoad: false,
          securityLevel: 'strict',
          theme: 'base',
          fontFamily: 'Switzer, Arial, sans-serif',
          themeVariables: {
            background: isDark ? '#080156' : '#f2f1f9',
            primaryColor: isDark ? '#110a6b' : '#ffffff',
            primaryTextColor: isDark ? '#f2f1f9' : '#080156',
            primaryBorderColor: isDark ? '#7c71ff' : '#4030de',
            lineColor: isDark ? '#8e86e0' : '#4030de',
            secondaryColor: isDark ? '#0d0652' : '#ebe9f6',
            tertiaryColor: isDark ? '#160e7d' : '#faf9fd',
            edgeLabelBackground: isDark ? '#080156' : '#f2f1f9',
            nodeBorder: isDark ? '#8e86e0' : '#4030de',
            clusterBkg: isDark ? '#050129' : '#faf9fd',
            titleColor: isDark ? '#f2f1f9' : '#080156',
          },
        })

        const result = await mermaid.render(renderId, chart)
        if (active) setSvg(result.svg)
      })
      .catch(() => {
        if (active) setFailed(true)
      })

    return () => {
      active = false
    }
  }, [chart, theme, renderId])

  return (
    <figure className="my-6 overflow-hidden border border-hairline bg-surface">
      <div className="flex items-center justify-between border-b border-hairline bg-subtle px-3.5 py-2 text-[11px] font-medium uppercase tracking-[0.06em] text-ink-muted">
        <span>Architecture Diagram</span>
        <span>Mermaid</span>
      </div>
      {svg && !failed ? (
        <div
          className="flex justify-center overflow-x-auto px-4 py-5 [&_svg]:h-auto [&_svg]:max-w-full"
          dangerouslySetInnerHTML={{ __html: svg }}
        />
      ) : (
        <pre className="m-0 overflow-x-auto p-4 font-mono text-xs leading-relaxed text-ink-secondary">
          <code>{chart}</code>
        </pre>
      )}
    </figure>
  )
}
