import { useEffect, useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { ArrowRight, ArrowUpRight, Menu, Search, X } from 'lucide-react'
import { AnimatePresence, motion } from 'motion/react'
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

function routeLabel(pathname: string): string {
  if (pathname.startsWith('/docs')) return 'Docs'
  if (pathname === '/markets' || pathname === '/makers') return 'Markets'
  if (pathname === '/swap') return 'Trade'
  if (pathname === '/portfolio') return 'Portfolio'
  if (pathname === '/maker') return 'Make markets'
  return 'Moonglade'
}

export default function V1Shell({ children }: VariantShellProps) {
  const { pathname } = useLocation()
  const { activeSection, scrollProgress, scrollToSection } = useLandingScroll()
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)

  const isLanding = pathname === '/'
  const isDocs = pathname.startsWith('/docs')
  const isAppRoute = ['/markets', '/makers', '/swap', '/portfolio', '/maker'].includes(pathname)
  const isTradeRoute = ['/markets', '/makers', '/swap'].includes(pathname)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 120)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  const pillLabel = isLanding ? activeSection.label : routeLabel(pathname)

  return (
    <div className="flex min-h-svh flex-col bg-canvas text-ink">
      <header className="border-b border-hairline bg-canvas">
        <div className="mx-auto flex h-[68px] max-w-[var(--container-max)] items-center justify-between gap-4 px-[var(--page-gutter)] md:h-[76px]">
          <BrandWordmark />

          <nav className="hidden items-center gap-7 md:flex" aria-label="Primary navigation">
            {isLanding && (
              <>
                {LANDING_SECTIONS.filter((s) => s.id !== 'overview').map((sec) => {
                  const active = activeSection.id === sec.id
                  return (
                    <button
                      key={sec.id}
                      type="button"
                      onClick={() => scrollToSection(sec.id)}
                      className={`inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium transition-colors ${
                        active ? 'text-ink' : 'text-ink-secondary hover:text-ink'
                      }`}
                    >
                      {sec.label}
                    </button>
                  )
                })}
                <Link
                  to="/docs"
                  className="inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium text-ink-secondary transition-colors hover:text-ink"
                >
                  Docs
                </Link>
              </>
            )}

            {isAppRoute &&
              APP_NAV_ITEMS.map((item) => {
                const active =
                  item.to === '/markets'
                    ? isTradeRoute
                    : pathname === item.to || pathname.startsWith(`${item.to}/`)
                return (
                  <Link
                    key={item.to}
                    to={item.to}
                    className={`inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium transition-colors ${
                      active
                        ? 'text-ink underline decoration-accent decoration-2 underline-offset-8'
                        : 'text-ink-secondary hover:text-ink'
                    }`}
                  >
                    {item.label}
                  </Link>
                )
              })}

            {isDocs && (
              <>
                <Link
                  to="/"
                  className="inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium text-ink-secondary transition-colors hover:text-ink"
                >
                  Overview
                </Link>
                <Link
                  to="/docs"
                  className="inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium text-ink underline decoration-accent decoration-2 underline-offset-8"
                >
                  Docs
                </Link>
              </>
            )}
          </nav>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setPaletteOpen(true)}
              aria-label="Open quick jump command palette"
              className="inline-flex min-h-[40px] items-center gap-2 rounded-[var(--radius-xs)] border border-hairline bg-surface px-3 py-2 text-xs font-medium text-ink-secondary transition-colors hover:border-accent hover:text-ink"
            >
              <Search size={14} aria-hidden="true" />
              <span className="hidden sm:inline">Jump</span>
              <span className="border border-hairline bg-canvas px-1.5 py-0.5 font-mono text-[10px] text-ink">
                ⌘K
              </span>
            </button>

            <ThemeToggle compact />

            {isAppRoute ? (
              <div className="hidden sm:inline-flex">
                <WalletSlot />
              </div>
            ) : isDocs ? (
              <Link
                to="/markets"
                className="hidden min-h-[40px] items-center gap-2 rounded-[var(--radius-xs)] bg-ink px-3.5 py-2 text-[13px] font-medium whitespace-nowrap text-canvas transition-colors hover:bg-accent hover:text-accent-on md:inline-flex"
              >
                <span>Open app</span>
                <ArrowRight size={14} aria-hidden="true" />
              </Link>
            ) : null}

            <Dialog.Root open={mobileOpen} onOpenChange={setMobileOpen}>
              <Dialog.Trigger asChild>
                <button
                  type="button"
                  aria-label="Open navigation menu"
                  className="inline-flex h-10 w-10 items-center justify-center rounded-[var(--radius-xs)] border border-hairline text-ink md:hidden"
                >
                  <Menu size={18} aria-hidden="true" />
                </button>
              </Dialog.Trigger>
              <Dialog.Portal>
                <Dialog.Overlay className="fixed inset-0 z-50 bg-[#050129]/60" />
                <Dialog.Content
                  aria-describedby={undefined}
                  className="fixed inset-y-0 right-0 z-50 flex w-[min(320px,86vw)] flex-col gap-5 border-l border-hairline bg-canvas p-5 text-ink"
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
        </div>
      </header>

      <AnimatePresence>
        {scrolled && (
          <div className="pointer-events-none fixed inset-x-0 top-3.5 z-40 flex justify-center px-3">
            <motion.div
              initial={{ opacity: 0, y: -12 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -12 }}
              transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
              className="pointer-events-auto relative flex w-full max-w-[620px] items-center justify-between gap-3 overflow-hidden rounded-[var(--radius-sm)] border border-hairline-strong bg-glass px-3.5 py-2 shadow-lg backdrop-blur-md"
            >
              <div className="flex min-w-0 items-center gap-2.5">
                <Link to="/" className="whitespace-nowrap text-sm font-semibold text-ink">
                  Moonglade
                </Link>
                <span className="truncate text-xs text-ink-muted">/ {pillLabel}</span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setPaletteOpen(true)}
                  aria-label="Open command palette"
                  className="inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-xs)] border border-hairline bg-surface px-2.5 text-xs text-ink-secondary hover:border-accent hover:text-ink"
                >
                  <Search size={13} aria-hidden="true" />
                  <span className="font-mono text-[10px] text-ink">⌘K</span>
                </button>
                <ThemeToggle compact />
                {!isAppRoute && (
                  <Link
                    to="/markets"
                    className="inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-xs)] bg-ink px-3 text-xs font-medium whitespace-nowrap text-canvas hover:bg-accent hover:text-accent-on"
                  >
                    <span>Open app</span>
                    <ArrowRight size={13} aria-hidden="true" />
                  </Link>
                )}
              </div>

              {isLanding && (
                <div
                  aria-hidden="true"
                  className="absolute inset-x-0 bottom-0 h-[2px] origin-left bg-accent transition-transform duration-150 ease-out"
                  style={{ transform: `scaleX(${scrollProgress})` }}
                />
              )}
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      <CommandPalette open={paletteOpen} onOpenChange={setPaletteOpen} />

      <div id="content" className="min-w-0 flex-1">
        {children}
      </div>

      <footer
        data-landing-footer
        className={`border-t border-hairline bg-canvas ${SHOW_SWITCHER ? 'pb-14' : ''}`}
      >
        <div className="mx-auto flex max-w-[var(--container-max)] flex-wrap items-center justify-between gap-4 px-[var(--page-gutter)] py-6 text-xs text-ink-muted">
          <span>© {new Date().getFullYear()} Moonglade · ETHGlobal Mumbai 2026</span>
          <nav className="flex flex-wrap items-center gap-5" aria-label="Footer links">
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
  )
}
