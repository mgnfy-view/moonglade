import { useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { ArrowRight, ArrowUpRight, Menu, Search, X } from 'lucide-react'
import { Link, useLocation } from 'react-router-dom'
import { BrandWordmark } from '../../components/shared/BrandWordmark'
import { CommandPalette } from '../../components/shared/CommandPalette'
import { ThemeToggle } from '../../components/shared/ThemeToggle'
import { WalletSlot } from '../../components/shared/WalletSlot'
import { APP_NAV_ITEMS } from '../../content/landing'
import { LANDING_SECTIONS, useLandingScroll } from '../../hooks/useSectionScroll'
import type { VariantShellProps } from '../types'

const DESK_EXPLORER =
  'https://basescan.org/address/0x4c448fB2E4966d653F5A70Bb1eDd58EF926Cac1b'

const SHOW_SWITCHER =
  import.meta.env.DEV || import.meta.env.VITE_ENABLE_VARIANT_SWITCHER === 'true'

export default function V3Shell({ children }: VariantShellProps) {
  const { pathname } = useLocation()
  const { activeSection, scrollProgress, scrollToSection } = useLandingScroll()
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  const isLanding = pathname === '/'
  const isDocs = pathname.startsWith('/docs')
  const isAppRoute = ['/markets', '/makers', '/swap', '/portfolio', '/maker'].includes(pathname)
  const isTradeRoute = ['/markets', '/makers', '/swap'].includes(pathname)

  return (
    <div className="min-h-svh bg-canvas text-ink md:flex">
      {/* Desktop Left-Hand Architectural Nav Rail */}
      <aside
        aria-label="Primary sidebar navigation"
        className="hidden md:fixed md:inset-y-0 md:left-0 md:z-40 md:flex md:w-[228px] md:flex-col md:border-r md:border-hairline md:bg-canvas md:px-5 md:py-6"
      >
        <div className="border-b border-hairline pb-4">
          <BrandWordmark size="md" />
        </div>

        <div className="mt-6 flex-1 overflow-y-auto">
          {isLanding && (
            <nav aria-label="Page sections" className="relative pl-4">
              <div
                aria-hidden="true"
                className="absolute top-1 bottom-1 left-0 w-[2px] bg-hairline"
              >
                <div
                  className="h-full w-full origin-top bg-accent transition-transform duration-150 ease-out"
                  style={{ transform: `scaleY(${Math.max(0.06, scrollProgress)})` }}
                />
              </div>

              <div className="flex flex-col gap-1">
                {LANDING_SECTIONS.map((sec) => {
                  const active = activeSection.id === sec.id
                  return (
                    <button
                      key={sec.id}
                      type="button"
                      onClick={() => scrollToSection(sec.id)}
                      className={`flex min-h-[38px] w-full items-center gap-3 text-left text-[13px] transition-colors ${
                        active ? 'font-medium text-ink' : 'text-ink-muted hover:text-ink'
                      }`}
                    >
                      <span
                        className={`tabular-nums text-[11px] ${
                          active ? 'text-accent' : 'text-ink-muted'
                        }`}
                      >
                        {sec.index}
                      </span>
                      <span>{sec.label}</span>
                    </button>
                  )
                })}
              </div>

              <div className="mt-6 border-t border-hairline pt-4">
                <Link
                  to="/docs"
                  className="flex min-h-[40px] items-center justify-between text-[13px] font-medium text-ink-secondary hover:text-ink"
                >
                  <span>Docs</span>
                  <ArrowRight size={14} aria-hidden="true" />
                </Link>
              </div>
            </nav>
          )}

          {isAppRoute && (
            <nav aria-label="App navigation" className="flex flex-col gap-1">
              {APP_NAV_ITEMS.map((item) => {
                const active =
                  item.to === '/markets'
                    ? isTradeRoute
                    : pathname === item.to || pathname.startsWith(`${item.to}/`)
                return (
                  <Link
                    key={item.to}
                    to={item.to}
                    className={`flex min-h-[42px] items-center border-l-2 px-3 text-[13px] font-medium transition-colors ${
                      active
                        ? 'border-accent bg-surface text-ink'
                        : 'border-transparent text-ink-secondary hover:bg-surface hover:text-ink'
                    }`}
                  >
                    {item.label}
                  </Link>
                )
              })}
            </nav>
          )}

          {isDocs && (
            <nav aria-label="Documentation navigation" className="flex flex-col gap-1">
              <Link
                to="/"
                className="flex min-h-[42px] items-center border-l-2 border-transparent px-3 text-[13px] font-medium text-ink-secondary hover:bg-surface hover:text-ink"
              >
                Overview
              </Link>
              <Link
                to="/docs"
                className="flex min-h-[42px] items-center border-l-2 border-accent bg-surface px-3 text-[13px] font-medium text-ink"
              >
                Docs
              </Link>
            </nav>
          )}
        </div>

        <div className={`mt-auto flex flex-col gap-2.5 border-t border-hairline pt-4 ${SHOW_SWITCHER ? 'pb-12' : ''}`}>
          <button
            type="button"
            onClick={() => setPaletteOpen(true)}
            aria-label="Open quick jump command palette"
            className="inline-flex min-h-[40px] items-center justify-between rounded-[var(--radius-xs)] border border-hairline bg-surface px-3 py-2 text-xs font-medium text-ink-secondary hover:border-accent hover:text-ink"
          >
            <span className="inline-flex items-center gap-2">
              <Search size={14} aria-hidden="true" />
              <span>Jump</span>
            </span>
            <span className="border border-hairline bg-canvas px-1.5 py-0.5 font-mono text-[10px] text-ink">
              ⌘K
            </span>
          </button>

          {isAppRoute ? (
            <WalletSlot primary />
          ) : (
            <Link
              to="/markets"
              className="swiss-btn-primary min-h-[42px] px-3.5 py-2 text-[13px]"
            >
              <span>Open app</span>
              <ArrowRight size={14} aria-hidden="true" />
            </Link>
          )}

          <ThemeToggle />
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex min-w-0 flex-1 flex-col md:ml-[228px]">
        {/* Mobile Top Bar */}
        <header className="sticky top-0 z-40 flex h-16 items-center justify-between border-b border-hairline bg-glass px-[var(--page-gutter)] backdrop-blur-md md:hidden">
          <BrandWordmark size="sm" />

          <div className="flex items-center gap-2">
            <ThemeToggle compact />
            <Dialog.Root open={mobileOpen} onOpenChange={setMobileOpen}>
              <Dialog.Trigger asChild>
                <button
                  type="button"
                  aria-label="Open navigation menu"
                  className="inline-flex h-10 w-10 items-center justify-center rounded-[var(--radius-xs)] border border-hairline text-ink"
                >
                  <Menu size={18} aria-hidden="true" />
                </button>
              </Dialog.Trigger>
              <Dialog.Portal>
                <Dialog.Overlay className="fixed inset-0 z-50 bg-[#050129]/60" />
                <Dialog.Content
                  aria-describedby={undefined}
                  className="fixed inset-y-0 left-0 z-50 flex w-[min(300px,85vw)] flex-col gap-5 border-r border-hairline bg-canvas p-5 text-ink"
                >
                  <div className="flex items-center justify-between border-b border-hairline pb-3.5">
                    <Dialog.Title className="m-0 text-lg font-semibold">Moonglade</Dialog.Title>
                    <Dialog.Close asChild>
                      <button
                        type="button"
                        aria-label="Close menu"
                        className="inline-flex h-10 w-10 items-center justify-center border border-hairline text-ink"
                      >
                        <X size={18} aria-hidden="true" />
                      </button>
                    </Dialog.Close>
                  </div>

                  <nav className="flex flex-col" aria-label="Mobile navigation">
                    {isAppRoute ? (
                      APP_NAV_ITEMS.map((item) => (
                        <Link
                          key={item.to}
                          to={item.to}
                          onClick={() => setMobileOpen(false)}
                          className="flex min-h-[48px] items-center justify-between border-b border-hairline px-2 text-base font-medium"
                        >
                          <span>{item.label}</span>
                          <ArrowRight size={15} aria-hidden="true" />
                        </Link>
                      ))
                    ) : (
                      <>
                        {isLanding &&
                          LANDING_SECTIONS.filter((s) => s.id !== 'overview').map((sec) => (
                            <button
                              key={sec.id}
                              type="button"
                              onClick={() => {
                                setMobileOpen(false)
                                scrollToSection(sec.id)
                              }}
                              className="flex min-h-[48px] items-center justify-between border-b border-hairline px-2 text-left text-base font-medium"
                            >
                              <span>{sec.label}</span>
                              <ArrowRight size={15} aria-hidden="true" />
                            </button>
                          ))}
                        {isDocs && (
                          <Link
                            to="/"
                            onClick={() => setMobileOpen(false)}
                            className="flex min-h-[48px] items-center justify-between border-b border-hairline px-2 text-base font-medium"
                          >
                            <span>Overview</span>
                            <ArrowRight size={15} aria-hidden="true" />
                          </Link>
                        )}
                        <Link
                          to="/docs"
                          onClick={() => setMobileOpen(false)}
                          className="flex min-h-[48px] items-center justify-between border-b border-hairline px-2 text-base font-medium"
                        >
                          <span>Docs</span>
                          <ArrowRight size={15} aria-hidden="true" />
                        </Link>
                      </>
                    )}
                  </nav>

                  <div className="mt-auto">
                    {isAppRoute ? (
                      <WalletSlot primary />
                    ) : (
                      <Link
                        to="/markets"
                        onClick={() => setMobileOpen(false)}
                        className="swiss-btn-primary w-full"
                      >
                        <span>Open app</span>
                        <ArrowRight size={16} aria-hidden="true" />
                      </Link>
                    )}
                  </div>
                </Dialog.Content>
              </Dialog.Portal>
            </Dialog.Root>
          </div>
        </header>

        <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />

        <div id="content" className="min-w-0 flex-1">
          {children}
        </div>

        <footer
          data-landing-footer
          className={`border-t border-hairline bg-canvas ${SHOW_SWITCHER ? 'pb-14 md:pb-0' : ''}`}
        >
          <div className="mx-auto flex max-w-[var(--container-max)] flex-wrap items-center justify-between gap-4 px-[var(--page-gutter)] py-6 text-xs text-ink-muted">
            <span>© {new Date().getFullYear()} Moonglade · ETHGlobal Mumbai 2026</span>
            <nav className="flex flex-wrap items-center gap-5" aria-label="Resources">
              <Link to="/docs/overview" className="hover:text-ink">
                Docs
              </Link>
              <Link to="/docs/whitepaper" className="hover:text-ink">
                Whitepaper
              </Link>
              <a
                href="https://github.com/mgnfy-view/moonglade"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 hover:text-ink"
              >
                <span>GitHub</span>
                <ArrowUpRight size={12} aria-hidden="true" />
              </a>
              <a
                href={DESK_EXPLORER}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 hover:text-ink"
              >
                <span>Base Explorer</span>
                <ArrowUpRight size={12} aria-hidden="true" />
              </a>
            </nav>
          </div>
        </footer>
      </div>
    </div>
  )
}
