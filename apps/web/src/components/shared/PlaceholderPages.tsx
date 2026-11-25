import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'

export function PortfolioPlaceholderPage() {
  return (
    <main className="mx-auto max-w-[920px] px-[var(--page-gutter)] py-12 md:py-20">
      <h1 className="mb-4 text-[clamp(32px,4vw,48px)] font-medium leading-[1.1] text-ink">
        Portfolio &amp; maturity redemption.
      </h1>
      <p className="mb-9 max-w-[56ch] text-base leading-[1.65] text-ink-secondary">
        Portfolio aggregation across markets is coming soon. Today you can lend, borrow, or sell
        mgNOTE directly through the live Base desk.
      </p>

      <div className="grid grid-cols-1 border-t border-l border-hairline md:grid-cols-2">
        <article className="border-r border-b border-hairline bg-surface p-6">
          <h2 className="mb-2.5 text-lg font-medium text-ink">mgNOTE positions</h2>
          <p className="text-sm leading-relaxed text-ink-secondary">
            After maturity, call{' '}
            <code className="border border-hairline bg-canvas px-1.5 py-0.5 font-mono text-xs text-ink">
              MoongladeNote.redeem(shares, receiver)
            </code>{' '}
            to withdraw your proportional share of repaid Morpho Midnight credit.
          </p>
        </article>
        <article className="border-r border-b border-hairline bg-surface p-6">
          <h2 className="mb-2.5 text-lg font-medium text-ink">Borrowing &amp; collateral</h2>
          <p className="text-sm leading-relaxed text-ink-secondary">
            Collateral and fixed-rate debt stay on your own Morpho Midnight account, separate from
            any maker’s desk inventory.
          </p>
        </article>
      </div>

      <div className="mt-8 flex flex-wrap gap-3">
        <Link className="swiss-btn-primary" to="/markets">
          <span>Open markets</span>
          <ArrowRight size={16} aria-hidden="true" />
        </Link>
        <Link className="swiss-btn-secondary" to="/docs/overview">
          <span>Read overview</span>
          <ArrowRight size={16} aria-hidden="true" />
        </Link>
      </div>
    </main>
  )
}

export function MakerPlaceholderPage() {
  return (
    <main className="mx-auto max-w-[920px] px-[var(--page-gutter)] py-12 md:py-20">
      <h1 className="mb-4 text-[clamp(32px,4vw,48px)] font-medium leading-[1.1] text-ink">
        Make markets in fixed-rate loans.
      </h1>
      <p className="mb-9 max-w-[56ch] text-base leading-[1.65] text-ink-secondary">
        A browser desk-creation console is in progress. Today, makers deploy and configure desks
        with the Foundry scripts included in the repository.
      </p>

      <div className="grid grid-cols-1 border-t border-l border-hairline md:grid-cols-2">
        <article className="border-r border-b border-hairline bg-surface p-6">
          <h2 className="mb-2.5 text-lg font-medium text-ink">Ship once on 1inch Aqua</h2>
          <p className="text-sm leading-relaxed text-ink-secondary">
            Configure your YieldSpace curve, fee, and risk limits, then register virtual budgets via{' '}
            <code className="border border-hairline bg-canvas px-1.5 py-0.5 font-mono text-xs text-ink">
              Aqua.ship()
            </code>{' '}
            while funds remain in your wallet.
          </p>
        </article>
        <article className="border-r border-b border-hairline bg-surface p-6">
          <h2 className="mb-2.5 text-lg font-medium text-ink">Shared Midnight exposure</h2>
          <p className="text-sm leading-relaxed text-ink-secondary">
            Multiple desks operated by the same maker wallet on the same market share one Midnight
            credit and collateral position.
          </p>
        </article>
      </div>

      <div className="mt-8 flex flex-wrap gap-3">
        <Link className="swiss-btn-primary" to="/docs/overview#deploy-a-desk">
          <span>Deploy a desk guide</span>
          <ArrowRight size={16} aria-hidden="true" />
        </Link>
        <Link className="swiss-btn-secondary" to="/markets">
          <span>View live Base desk</span>
          <ArrowRight size={16} aria-hidden="true" />
        </Link>
      </div>
    </main>
  )
}
