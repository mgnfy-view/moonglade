import { Link } from 'react-router-dom'
import { ArrowRight, ArrowUpRight } from 'lucide-react'
import { PROOF_FILLS } from '../../content/landing'

export function ProofLedger() {
  return (
    <section
      id="proof"
      aria-labelledby="proof-heading"
      className="border-t border-hairline px-[var(--page-gutter)] py-16 md:py-24"
    >
      <div className="mx-auto max-w-[var(--container-max)]">
        <div className="mb-10 grid grid-cols-1 items-end gap-6 md:grid-cols-2">
          <div>
            <p className="mb-2 text-xs font-medium text-accent">
              2nd place · ETHGlobal Mumbai 2026
            </p>
            <h2
              id="proof-heading"
              className="text-[clamp(28px,3.2vw,44px)] font-medium leading-[1.12] text-ink"
            >
              Confirmed on Base mainnet.
            </h2>
          </div>
          <p className="text-[15px] leading-[1.65] text-ink-secondary">
            Real USDC, WETH, and mgNOTE transactions executed on Base mainnet. Each fill matched
            90-digit YieldSpace calculations with a 0.30% maker fee and Midnight tick rounding.
          </p>
        </div>

        <div className="border-t border-hairline">
          {PROOF_FILLS.map((item) => (
            <div
              key={item.txHash}
              className="grid grid-cols-1 items-baseline gap-2 border-b border-hairline py-4 transition-colors hover:bg-surface sm:grid-cols-[180px_minmax(0,1fr)_auto_auto] sm:gap-6 sm:px-3"
            >
              <span className="text-sm font-medium text-ink">{item.flow}</span>
              <span className="text-sm tabular-nums text-ink-secondary">{item.summary}</span>
              <span className="text-xs tabular-nums text-ink-muted">Block {item.block}</span>
              <a
                href={`https://basescan.org/tx/${item.txHash}`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex min-h-[36px] items-center gap-1.5 text-xs font-medium text-accent hover:underline hover:underline-offset-4"
              >
                <span>Basescan</span>
                <ArrowUpRight size={13} aria-hidden="true" />
              </a>
            </div>
          ))}
        </div>

        <div className="mt-6 flex flex-wrap items-center justify-between gap-4">
          <p className="max-w-[64ch] text-xs leading-relaxed text-ink-muted">
            Historical receipts verify those fills only and do not represent current desk balances,
            live liquidity, or future rates.
          </p>
          <Link to="/docs/mainnet-proof" className="swiss-btn-secondary">
            <span>Inspect math &amp; receipts</span>
            <ArrowRight size={15} aria-hidden="true" />
          </Link>
        </div>
      </div>
    </section>
  )
}
