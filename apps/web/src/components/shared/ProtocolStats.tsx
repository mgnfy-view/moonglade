import { useProtocolStats } from '../../hooks/useProtocolStats'

function formatUsd(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) return 'N/A'
  return `$${value.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`
}

function formatToken(value: number | null | undefined, suffix: string): string {
  if (value === null || value === undefined || Number.isNaN(value)) return 'N/A'
  return `${value.toLocaleString('en-US', { maximumFractionDigits: 4 })} ${suffix}`
}

export function ProtocolStats() {
  const { data, isError, isPending } = useProtocolStats()

  const tvlDisplay = isPending
    ? 'Loading…'
    : isError || !data
      ? 'N/A'
      : formatUsd(data.tvlUsd)

  const cards = [
    {
      label: 'Total value locked',
      value: tvlDisplay,
      caption:
        isError || !data
          ? 'Base mainnet RPC unavailable'
          : 'Live Base · Note backing + WETH collateral + maker USDC',
    },
    {
      label: 'Open positions',
      value: 'N/A',
      caption: 'Requires Midnight position & note-holder indexer',
    },
    {
      label: 'Unique wallets',
      value: 'N/A',
      caption: 'Requires historical Transfer & Swapped event indexer',
    },
    {
      label: 'Cumulative volume',
      value: 'N/A',
      caption: 'Requires SwapVM Swapped event indexer',
    },
  ] as const

  return (
    <section
      id="metrics"
      data-landing-section="metrics"
      aria-labelledby="metrics-heading"
      className="flex min-h-[85svh] flex-col justify-center border-t border-hairline px-[var(--page-gutter)] py-20 md:min-h-[100svh]"
    >
      <div className="mx-auto w-full max-w-[var(--container-max)]">
        <div className="mb-12 grid grid-cols-1 items-end gap-6 md:grid-cols-2">
          <h2
            id="metrics-heading"
            className="text-[clamp(28px,3.4vw,46px)] font-medium leading-[1.12] text-ink"
          >
            Live protocol metrics.
          </h2>
          <p className="text-[15px] leading-[1.65] text-ink-secondary">
            Real-time state read directly from Base mainnet contracts. Metrics requiring historical
            event indexing explicitly display N/A.
          </p>
        </div>

        <div className="grid grid-cols-1 border-t border-l border-hairline sm:grid-cols-2 lg:grid-cols-4">
          {cards.map((card) => (
            <article
              key={card.label}
              className="border-r border-b border-hairline bg-surface p-6"
            >
              <div className="mb-4 text-xs font-medium text-ink-muted">{card.label}</div>
              <div className="mb-3 text-[clamp(26px,2.8vw,36px)] font-medium leading-none tabular-nums text-ink">
                {card.value}
              </div>
              <p className="text-xs leading-relaxed text-ink-secondary">{card.caption}</p>
            </article>
          ))}
        </div>

        <dl className="mt-6 grid grid-cols-2 gap-6 border-t border-hairline pt-6 sm:grid-cols-4">
          <div>
            <dt className="mb-1 text-xs text-ink-muted">Live curve rate</dt>
            <dd className="m-0 text-sm font-medium tabular-nums text-ink">
              {data?.curveRatePct !== null && data?.curveRatePct !== undefined
                ? `${data.curveRatePct.toFixed(2)}% APR`
                : 'N/A'}
            </dd>
          </div>
          <div>
            <dt className="mb-1 text-xs text-ink-muted">Aqua cash budget</dt>
            <dd className="m-0 text-sm font-medium tabular-nums text-ink">
              {formatToken(data?.cashBudgetUsdc, 'USDC')}
            </dd>
          </div>
          <div>
            <dt className="mb-1 text-xs text-ink-muted">Aqua note budget</dt>
            <dd className="m-0 text-sm font-medium tabular-nums text-ink">
              {formatToken(data?.noteBudgetMgNote, 'mgNOTE')}
            </dd>
          </div>
          <div>
            <dt className="mb-1 text-xs text-ink-muted">Base block</dt>
            <dd className="m-0 text-sm font-medium tabular-nums text-ink">
              {data ? data.blockNumber.toLocaleString('en-US') : 'N/A'}
            </dd>
          </div>
        </dl>
      </div>
    </section>
  )
}
