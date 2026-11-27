import { useEffect, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'
import { ArrowUpRight, ChevronDown, PanelLeftClose, PanelLeftOpen } from 'lucide-react'
import { DOCS_ENTRIES, getDocBySlug, type DocsEntry } from 'virtual:moonglade-docs'
import { MarkdownRenderer } from './MarkdownRenderer'
import { WhitepaperViewer } from './WhitepaperViewer'

const GROUPS: readonly DocsEntry['group'][] = ['Protocol', 'Verification', 'Engineering']

export default function DocsPage() {
  const { slug } = useParams()
  const { hash } = useLocation()
  const activeDoc = getDocBySlug(slug)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [activeHeading, setActiveHeading] = useState<string>('')

  const hasToc = activeDoc.kind === 'markdown' && activeDoc.headings.length > 0
  const currentIdx = DOCS_ENTRIES.findIndex((entry) => entry.slug === activeDoc.slug)
  const prevDoc = currentIdx > 0 ? DOCS_ENTRIES[currentIdx - 1] : null
  const nextDoc = currentIdx < DOCS_ENTRIES.length - 1 ? DOCS_ENTRIES[currentIdx + 1] : null

  useEffect(() => {
    setMobileOpen(false)
  }, [activeDoc.slug])

  useEffect(() => {
    if (!hash) {
      window.scrollTo({ top: 0 })
      return
    }
    const targetId = hash.slice(1)
    const timer = window.setTimeout(() => {
      const element = document.getElementById(targetId)
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }, 60)
    return () => window.clearTimeout(timer)
  }, [activeDoc.slug, hash])

  useEffect(() => {
    if (!hasToc) {
      setActiveHeading('')
      return
    }

    const elements = activeDoc.headings
      .map((heading) => document.getElementById(heading.id))
      .filter((el): el is HTMLElement => el !== null)

    if (elements.length === 0) return

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((entry) => entry.isIntersecting)
        if (visible?.target.id) {
          setActiveHeading(visible.target.id)
        }
      },
      { rootMargin: '-90px 0px -70% 0px', threshold: 0.05 },
    )

    for (const el of elements) observer.observe(el)
    return () => observer.disconnect()
  }, [activeDoc.slug, activeDoc.headings, hasToc])

  const renderTree = () => (
    <>
      {GROUPS.map((group) => {
        const items = DOCS_ENTRIES.filter((entry) => entry.group === group)
        if (items.length === 0) return null
        return (
          <div key={group} className="mb-5">
            <div className="mb-2 text-[11px] font-medium uppercase tracking-[0.06em] text-ink-muted">
              {group}
            </div>
            <ul className="m-0 flex list-none flex-col gap-0.5 p-0">
              {items.map((entry) => {
                const isActive = entry.slug === activeDoc.slug
                return (
                  <li key={entry.slug}>
                    <Link
                      to={`/docs/${entry.slug}`}
                      aria-current={isActive ? 'page' : undefined}
                      className={`flex min-h-[38px] items-center border-l-2 px-2.5 py-1.5 text-[13px] transition-colors ${
                        isActive
                          ? 'border-accent bg-surface font-medium text-ink'
                          : 'border-transparent text-ink-secondary hover:bg-surface hover:text-ink'
                      }`}
                    >
                      {entry.title}
                    </Link>
                  </li>
                )
              })}
            </ul>
          </div>
        )
      })}
    </>
  )

  const gridColsClass = sidebarCollapsed
    ? hasToc
      ? 'md:grid-cols-[44px_minmax(0,1fr)] xl:grid-cols-[44px_minmax(0,1fr)_200px]'
      : 'md:grid-cols-[44px_minmax(0,1fr)]'
    : hasToc
      ? 'md:grid-cols-[232px_minmax(0,1fr)] xl:grid-cols-[232px_minmax(0,1fr)_200px]'
      : 'md:grid-cols-[232px_minmax(0,1fr)]'

  return (
    <main
      className={`mx-auto grid max-w-[var(--container-max)] grid-cols-1 items-start gap-8 px-[var(--page-gutter)] pt-6 pb-20 md:gap-10 md:pt-10 ${gridColsClass}`}
    >
      <aside
        aria-label="Documentation navigation"
        className={`hidden md:sticky md:top-24 md:block ${
          sidebarCollapsed ? '' : 'border-r border-hairline pr-5'
        }`}
      >
        <div className="mb-4 flex items-center justify-between gap-2">
          {!sidebarCollapsed && (
            <span className="text-[11px] font-medium uppercase tracking-[0.08em] text-ink-muted">
              Docs
            </span>
          )}
          <button
            type="button"
            onClick={() => setSidebarCollapsed((prev) => !prev)}
            aria-label={sidebarCollapsed ? 'Expand docs sidebar' : 'Collapse docs sidebar'}
            title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
            className="inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius-xs)] border border-hairline bg-surface text-ink hover:border-accent hover:text-accent"
          >
            {sidebarCollapsed ? <PanelLeftOpen size={15} /> : <PanelLeftClose size={15} />}
          </button>
        </div>
        {!sidebarCollapsed && renderTree()}
      </aside>

      <div className="md:hidden">
        <button
          type="button"
          aria-expanded={mobileOpen}
          onClick={() => setMobileOpen((prev) => !prev)}
          className="flex min-h-[46px] w-full items-center justify-between border border-hairline bg-surface px-3.5 py-2.5 text-sm font-medium text-ink"
        >
          <span>
            {activeDoc.group} / {activeDoc.title}
          </span>
          <ChevronDown size={16} aria-hidden="true" />
        </button>
        {mobileOpen && (
          <nav className="mt-2 border border-hairline bg-surface p-3.5">{renderTree()}</nav>
        )}
      </div>

      <article
        className={`min-w-0 w-full justify-self-center ${
          activeDoc.kind === 'pdf' ? '' : 'max-w-[78ch]'
        }`}
      >
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3 border-b border-hairline pb-4">
          <div className="flex items-center gap-2.5 text-xs text-ink-muted">
            <span className="border border-hairline bg-surface px-2 py-0.5 font-medium text-accent">
              {activeDoc.group}
            </span>
            <span className="tabular-nums">{activeDoc.repoPath}</span>
          </div>
          <a
            href={activeDoc.githubUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 text-xs text-ink-secondary hover:text-accent"
          >
            <span>Source on GitHub</span>
            <ArrowUpRight size={13} aria-hidden="true" />
          </a>
        </div>

        {activeDoc.kind === 'pdf' && activeDoc.pdfUrl ? (
          <WhitepaperViewer pdfUrl={activeDoc.pdfUrl} />
        ) : (
          <MarkdownRenderer content={activeDoc.content} />
        )}

        <nav
          aria-label="Document pagination"
          className="mt-14 grid grid-cols-1 gap-4 border-t border-hairline pt-6 sm:grid-cols-2"
        >
          {prevDoc ? (
            <Link
              to={`/docs/${prevDoc.slug}`}
              className="flex flex-col gap-1.5 border border-hairline bg-surface p-4 transition-colors hover:border-accent"
            >
              <span className="text-[11px] uppercase tracking-[0.06em] text-ink-muted">
                Previous
              </span>
              <span className="text-sm font-medium text-ink">{prevDoc.title}</span>
            </Link>
          ) : (
            <div />
          )}
          {nextDoc ? (
            <Link
              to={`/docs/${nextDoc.slug}`}
              className="flex flex-col items-end gap-1.5 border border-hairline bg-surface p-4 text-right transition-colors hover:border-accent"
            >
              <span className="text-[11px] uppercase tracking-[0.06em] text-ink-muted">Next</span>
              <span className="text-sm font-medium text-ink">{nextDoc.title}</span>
            </Link>
          ) : (
            <div />
          )}
        </nav>
      </article>

      {hasToc && (
        <aside
          aria-label="On this page"
          className="hidden border-l border-hairline pl-4 xl:sticky xl:top-24 xl:block"
        >
          <div className="mb-3 text-[11px] font-medium uppercase tracking-[0.08em] text-ink-muted">
            On this page
          </div>
          <ul className="m-0 flex list-none flex-col gap-1.5 p-0">
            {activeDoc.headings.map((heading) => {
              const isActive = activeHeading === heading.id
              return (
                <li key={heading.id}>
                  <a
                    href={`#${heading.id}`}
                    className={`block text-xs leading-[1.45] transition-colors ${
                      heading.depth === 3 ? 'pl-3' : ''
                    } ${
                      isActive ? 'font-medium text-accent' : 'text-ink-muted hover:text-accent'
                    }`}
                  >
                    {heading.text}
                  </a>
                </li>
              )
            })}
          </ul>
        </aside>
      )}
    </main>
  )
}
