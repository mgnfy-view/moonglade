import { useEffect, useMemo, useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { CornerDownLeft, Search } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { DOCS_ENTRIES } from 'virtual:moonglade-docs'
import { NAV_ITEMS } from '../../content/landing'
import { useTheme } from '../../theme/ThemeProvider'

interface PaletteCommand {
  id: string
  title: string
  subtitle: string
  kind: 'Route' | 'Doc' | 'Section' | 'Action'
  action: () => void
}

export function V3CommandPalette({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (next: boolean) => void
}) {
  const navigate = useNavigate()
  const { theme, toggleTheme } = useTheme()
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)

  const commands = useMemo<PaletteCommand[]>(() => {
    const list: PaletteCommand[] = [
      {
        id: 'route-home',
        title: 'Home',
        subtitle: '/',
        kind: 'Route',
        action: () => navigate('/'),
      },
      ...NAV_ITEMS.map((item) => ({
        id: `route-${item.to}`,
        title: item.label,
        subtitle: item.to,
        kind: 'Route' as const,
        action: () => navigate(item.to),
      })),
      {
        id: 'action-theme',
        title: `Switch to ${theme === 'dark' ? 'Light' : 'Dark'} theme`,
        subtitle: 'Toggle color appearance',
        kind: 'Action',
        action: toggleTheme,
      },
    ]

    for (const doc of DOCS_ENTRIES) {
      list.push({
        id: `doc-${doc.slug}`,
        title: doc.title,
        subtitle: `${doc.group} · ${doc.repoPath}`,
        kind: 'Doc',
        action: () => navigate(`/docs/${doc.slug}`),
      })

      for (const heading of doc.headings) {
        list.push({
          id: `sec-${doc.slug}-${heading.id}`,
          title: heading.text,
          subtitle: `${doc.title} · #${heading.id}`,
          kind: 'Section',
          action: () => navigate(`/docs/${doc.slug}#${heading.id}`),
        })
      }
    }

    return list
  }, [navigate, theme, toggleTheme])

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return commands.slice(0, 14)
    return commands
      .filter(
        (cmd) =>
          cmd.title.toLowerCase().includes(needle) ||
          cmd.subtitle.toLowerCase().includes(needle),
      )
      .slice(0, 18)
  }, [commands, query])

  useEffect(() => {
    setSelectedIndex(0)
  }, [query, open])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        onOpenChange(!open)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [open, onOpenChange])

  const execute = (cmd: PaletteCommand | undefined) => {
    if (!cmd) return
    cmd.action()
    onOpenChange(false)
    setQuery('')
  }

  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-[#050129]/65 backdrop-blur-[4px]" />
        <Dialog.Content
          aria-describedby={undefined}
          onKeyDown={(event) => {
            if (event.key === 'ArrowDown') {
              event.preventDefault()
              setSelectedIndex((prev) =>
                filtered.length === 0 ? 0 : (prev + 1) % filtered.length,
              )
            } else if (event.key === 'ArrowUp') {
              event.preventDefault()
              setSelectedIndex((prev) =>
                filtered.length === 0 ? 0 : (prev - 1 + filtered.length) % filtered.length,
              )
            } else if (event.key === 'Enter') {
              event.preventDefault()
              execute(filtered[selectedIndex])
            }
          }}
          className="fixed top-[14vh] left-1/2 z-50 flex max-h-[70vh] w-[min(600px,calc(100vw-32px))] -translate-x-1/2 flex-col overflow-hidden border border-hairline-strong bg-elevated text-ink shadow-2xl"
        >
          <Dialog.Title className="sr-only">Quick jump command palette</Dialog.Title>

          <div className="flex items-center gap-3 border-b border-hairline px-4 py-3.5">
            <Search size={16} className="shrink-0 text-ink-muted" aria-hidden="true" />
            <label htmlFor="moonglade-cmd-search" className="sr-only">
              Search routes and documentation headings
            </label>
            <input
              id="moonglade-cmd-search"
              name="command-search"
              type="text"
              placeholder="Jump to Markets, Docs, or headings..."
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              autoFocus
              className="min-w-0 flex-1 border-0 bg-transparent text-[15px] text-ink outline-none placeholder:text-ink-muted focus-visible:outline-none"
            />
            <span className="border border-hairline px-1.5 py-0.5 font-mono text-[11px] text-ink-muted">
              ESC
            </span>
          </div>

          <div
            role="listbox"
            aria-label="Search results"
            className="flex flex-col gap-0.5 overflow-y-auto p-2"
          >
            {filtered.length === 0 ? (
              <div className="py-7 text-center text-xs text-ink-muted">
                No matching routes or documentation headings.
              </div>
            ) : (
              filtered.map((cmd, idx) => {
                const selected = idx === selectedIndex
                return (
                  <button
                    key={cmd.id}
                    type="button"
                    role="option"
                    aria-selected={selected}
                    onMouseEnter={() => setSelectedIndex(idx)}
                    onClick={() => execute(cmd)}
                    className={`flex w-full items-center justify-between gap-3 border-l-2 px-3 py-2.5 text-left transition-colors ${
                      selected
                        ? 'border-accent bg-surface text-ink'
                        : 'border-transparent text-ink hover:bg-surface'
                    }`}
                  >
                    <div className="min-w-0 flex flex-col gap-0.5">
                      <span className="truncate text-sm font-medium">{cmd.title}</span>
                      <span className="truncate text-[11px] text-ink-muted">{cmd.subtitle}</span>
                    </div>
                    <span className="shrink-0 border border-hairline px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-[0.06em] text-accent">
                      {selected ? <CornerDownLeft size={11} aria-hidden="true" /> : cmd.kind}
                    </span>
                  </button>
                )
              })
            )}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
