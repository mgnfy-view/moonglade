import { memo, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ExternalLink } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import rehypeAutolinkHeadings from 'rehype-autolink-headings'
import rehypeRaw from 'rehype-raw'
import rehypeSlug from 'rehype-slug'
import remarkGfm from 'remark-gfm'
import { CodeBlock } from './CodeBlock'
import { MermaidDiagram } from './MermaidDiagram'
import styles from './MarkdownRenderer.module.css'

function extractText(children: ReactNode): string {
  if (typeof children === 'string') return children
  if (Array.isArray(children)) return children.map(extractText).join('')
  if (children && typeof children === 'object' && 'props' in children) {
    return extractText((children as { props?: { children?: ReactNode } }).props?.children)
  }
  return ''
}

export const MarkdownRenderer = memo(function MarkdownRenderer({
  content,
}: {
  content: string
}) {
  return (
    <div className={styles.markdown}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        rehypePlugins={[
          rehypeRaw,
          rehypeSlug,
          [rehypeAutolinkHeadings, { behavior: 'wrap', test: ['h2', 'h3'] }],
        ]}
        components={{
          a({ href = '', children }) {
            const isInternal = href.startsWith('/') || href.startsWith('#')
            if (isInternal) {
              return (
                <Link className={styles.inlineLink} to={href}>
                  {children}
                </Link>
              )
            }
            return (
              <a
                className={styles.inlineLink}
                href={href}
                target="_blank"
                rel="noreferrer"
              >
                {children}
                <ExternalLink size={12} aria-hidden="true" />
              </a>
            )
          },
          pre({ children }) {
            const child = Array.isArray(children) ? children[0] : children
            if (
              child &&
              typeof child === 'object' &&
              'props' in child &&
              (child as { props?: { className?: string; children?: ReactNode } }).props
            ) {
              const props = (
                child as { props: { className?: string; children?: ReactNode } }
              ).props
              const className = props.className ?? ''
              const match = /language-([a-zA-Z0-9_-]+)/.exec(className)
              const language = match?.[1]
              const code = extractText(props.children).replace(/\n$/, '')
              if (language === 'mermaid') {
                return <MermaidDiagram chart={code} />
              }
              return <CodeBlock code={code} language={language} />
            }
            return <CodeBlock code={extractText(children)} />
          },
          table({ children }) {
            return (
              <div className={styles.tableWrap}>
                <table>{children}</table>
              </div>
            )
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  )
})
