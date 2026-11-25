import { useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'
import { ArrowRight, ArrowUpRight, Menu, X } from 'lucide-react'
import { motion, useScroll } from 'motion/react'
import { Link, useLocation } from 'react-router-dom'
import { BrandWordmark } from '../../components/shared/BrandWordmark'
import { ThemeToggle } from '../../components/shared/ThemeToggle'
import { WalletSlot } from '../../components/shared/WalletSlot'
import { NAV_ITEMS } from '../../content/landing'
import type { VariantShellProps } from '../types'

const DESK_EXPLORER =
  'https://basescan.org/address/0x4c448fB2E4966d653F5A70Bb1eDd58EF926Cac1b'

const SHOW_SWITCHER =
  import.meta.env.DEV || import.meta.env.VITE_ENABLE_VARIANT_SWITCHER === 'true'

export default function V1Shell({ children }: VariantShellProps) {
  const { pathname } = useLocation()
  const [mobileOpen, setMobileOpen] = useState(false)
  const { scrollYProgress } = useScroll()
  const isLanding = pathname === '/'
  const isTradeRoute = ['/markets', '/makers', '/swap'].includes(pathname)

  return (
    <div className="flex min-h-svh flex-col bg-canvas text-ink">
      <header className="sticky top-0 z-40 border-b border-hairline bg-glass backdrop-blur-md">
        <div className="mx-auto flex h-[68px] max-w-[var(--container-max)] items-center justify-between gap-4 px-[var(--page-gutter)] md:grid md:h-[76px] md:grid-cols-[1fr_auto_1fr]">
          <div className="justify-self-start">
            <BrandWordmark />
          </div>

          <nav className="hidden items-center justify-center gap-7 md:flex" aria-label="Primary navigation">
            {NAV_ITEMS.map((item) => {
              const active =
                item.to === '/markets'
                  ? isTradeRoute
                  : pathname === item.to || pathname.startsWith(`${item.to}/`)
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  className={`relative inline-flex min-h-[44px] items-center whitespace-nowrap text-[13px] font-medium transition-colors ${
                    active ? 'text-ink' : 'text-ink-secondary hover:text-ink'
                  }`}
                >
                  {item.label}
                  {active && (
                    <span
                      aria-hidden="true"
                      className="absolute inset-x-0 bottom-0 h-0.5 bg-accent"
                    />
                  )}
                </Link>
              )
            })}
          </nav>

          <div className="flex items-center justify-end gap-2.5">
            <ThemeToggle compact />

            {isTradeRoute ? (
              <div className="hidden sm:inline-flex">
                <WalletSlot />
              </div>
            ) : !isLanding ? (
              <Link
                to="/markets"
                className="hidden min-h-[40px] items-center gap-2 rounded-[var(--radius-xs)] border border-ink bg-ink px-3.5 py-2 text-[13px] font-medium whitespace-nowrap text-canvas transition-colors hover:border-accent hover:bg-accent hover:text-accent-on md:inline-flex"
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
                  className="inline-flex h-10 w-10 items-center justify-center rounded-[var(--radius-xs)] border border-hairline bg-transparent text-ink md:hidden"
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
                    {NAV_ITEMS.map((item) => (
                      <Link
                        key={item.to}
                        to={item.to}
                        onClick={() => setMobileOpen(false)}
                        className="flex min-h-[48px] items-center justify-between border-b border-hairline px-2 text-base font-medium text-ink"
                      >
                        <span>{item.label}</span>
                        <ArrowRight size={15} aria-hidden="true" />
                      </Link>
                    ))}
                  </nav>

                  <div className="mt-auto">
                    <WalletSlot primary />
                  </div>
                </Dialog.Content>
              </Dialog.Portal>
            </Dialog.Root>
          </div>
        </div>

        {isLanding && (
          <motion.div
            aria-hidden="true"
            className="h-[2px] w-full origin-left bg-accent"
            style={{ scaleX: scrollYProgress }}
          />
        )}
      </header>

      <div id="content" className="min-w-0 flex-1">
        {children}
      </div>

      <footer className={`border-t border-hairline bg-canvas ${SHOW_SWITCHER ? 'pb-14' : ''}`}>
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
