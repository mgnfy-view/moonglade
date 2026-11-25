import { lazy, Suspense, useState } from 'react'
import { Link, Navigate, Route, Routes, useSearchParams } from 'react-router-dom'
import {
  ArrowDown,
  ArrowLeft,
  ArrowLeftRight,
  ArrowRight,
  CalendarDays,
  ExternalLink,
  Landmark,
  LoaderCircle,
  Percent,
  ShieldCheck,
  SlidersHorizontal,
  TrendingUp,
  type LucideIcon,
} from 'lucide-react'
import { formatUnits } from 'viem'
import { useMoonglade, type TradeMode } from './hooks/useMoonglade'
import MakersPage from './MakersPage'
import CompletionModal from './CompletionModal'
import { MAKERS, shortAddress, tradeMode, type ListedMaker } from './lib/makers'
import { WalletSlot } from './components/shared/WalletSlot'
import {
  MakerPlaceholderPage,
  PortfolioPlaceholderPage,
} from './components/shared/PlaceholderPages'
import { VariantProvider, useLandingVariant } from './variants/variantContext'
import { getLazyLanding, getLazyShell } from './variants/registry'
import { VariantSwitcher } from './variants/VariantSwitcher'

const DocsPage = lazy(() => import('./docs/DocsPage'))

function amountText(value: bigint | undefined, decimals = 6, maximumFractionDigits = 4) {
  if (value === undefined) return '—'
  const numericValue = Number(formatUnits(value, decimals))
  if (numericValue > 0 && numericValue < 0.0001) return '< 0.0001'
  return numericValue.toLocaleString('en-US', { maximumFractionDigits })
}

function DetailRow({
  label,
  value,
  emphasis = false,
  icon: Icon,
}: {
  label: string
  value: string
  emphasis?: boolean
  icon?: LucideIcon
}) {
  return (
    <div className={`detail-row ${emphasis ? 'detail-emphasis' : ''}`}>
      <span>
        {Icon && <Icon size={14} aria-hidden="true" />}
        {label}
      </span>
      <span>{value}</span>
    </div>
  )
}

function SelectedSwapPage() {
  const [params] = useSearchParams()
  const maker = MAKERS.find((entry) => entry.id === params.get('maker'))
  if (!maker) return <Navigate to={`/makers?mode=${tradeMode(params.get('mode'))}`} replace />
  return <SwapPage maker={maker} />
}

function SwapPage({ maker }: { maker: ListedMaker }) {
  const [searchParams] = useSearchParams()
  const [mode, setMode] = useState<TradeMode>(() => tradeMode(searchParams.get('mode')))
  const [amount, setAmount] = useState('')
  const [collateralAmount, setCollateralAmount] = useState('')
  const slippageBps = 50
  const desk = useMoonglade({ mode, amount, collateralAmount, slippageBps })
  const isBorrow = mode === 'borrow'
  const isSell = mode === 'sell'
  const inputAsset = isSell ? 'mgNOTE' : 'USDC'
  const outputAsset = isBorrow || isSell ? 'USDC' : 'mgNOTE'
  const maturity = desk.desk
    ? new Date(desk.desk.maturity * 1000).toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        timeZone: 'UTC',
      })
    : '—'
  const changeMode = (nextMode: TradeMode) => {
    if (desk.busy) return
    setMode(nextMode)
    setAmount('')
    setCollateralAmount('')
  }
  const inputBalance = isSell ? desk.balances.note : desk.balances.usdc
  const quoteAmount = desk.quote?.amountOut
  const maximumNewDebt = desk.quote
    ? desk.quote.projectedDebt > desk.balances.debt
      ? desk.quote.projectedDebt - desk.balances.debt
      : 0n
    : undefined
  const creditApplied =
    desk.quote && maximumNewDebt !== undefined ? desk.quote.borrowUnits - maximumNewDebt : 0n
  const canShowBalances = desk.isConnected && !desk.isLoading

  return (
    <main className="swap-page">
      <Link className="desk-back" to={`/makers?mode=${mode}`}>
        <ArrowLeft size={16} aria-hidden="true" />
        All makers
      </Link>
      <section className="trade-panel" aria-label="Credit swap">
        <div className="trade-heading">
          <h1 title={maker.address}>{shortAddress(maker.address)}</h1>
          <span className="network-label">
            <span />
            Base
          </span>
        </div>
        <p className="selected-market">
          {maker.loanSymbol} / {maker.noteSymbol} · {maker.collateralSymbol} collateral
        </p>
        <div className="trade-tabs" role="tablist" aria-label="Trade direction">
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'lend'}
            className={mode === 'lend' ? 'selected' : ''}
            onClick={() => changeMode('lend')}
            disabled={desk.busy}
          >
            <TrendingUp size={16} aria-hidden="true" />
            Lend
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'borrow'}
            className={mode === 'borrow' ? 'selected' : ''}
            onClick={() => changeMode('borrow')}
            disabled={desk.busy}
          >
            <Landmark size={16} aria-hidden="true" />
            Borrow
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'sell'}
            className={mode === 'sell' ? 'selected' : ''}
            onClick={() => changeMode('sell')}
            disabled={desk.busy}
          >
            <ArrowLeftRight size={16} aria-hidden="true" />
            Sell
          </button>
        </div>

        <div className="amount-section">
          <div className="amount-label">
            <label htmlFor="trade-amount">
              {isBorrow ? 'USDC to receive' : isSell ? 'Shares to sell' : 'You pay'}
            </label>
            {!isBorrow && (
              <span className="balance-label">
                Balance {canShowBalances ? amountText(inputBalance) : '—'}
              </span>
            )}
          </div>
          <div className="amount-input-row">
            <input
              id="trade-amount"
              inputMode="decimal"
              autoComplete="off"
              spellCheck={false}
              placeholder="0.00"
              value={amount}
              onChange={(event) => {
                if (/^\d*\.?\d*$/.test(event.target.value)) setAmount(event.target.value)
              }}
              disabled={desk.busy}
            />
            <span className="asset-label">
              <span className={`asset-symbol ${isSell ? 'note-symbol' : ''}`}>
                {isSell ? 'm' : '$'}
              </span>
              {inputAsset}
            </span>
          </div>
          <div className="preset-row">
            <div>
              {['0.25', '0.5', '1'].map((preset) => (
                <button
                  type="button"
                  key={preset}
                  onClick={() => setAmount(preset)}
                  disabled={desk.busy}
                >
                  {preset}
                </button>
              ))}
            </div>
          </div>
        </div>

        {isBorrow ? (
          <div className="collateral-section">
            <div className="amount-label">
              <label htmlFor="collateral-amount">Add WETH collateral</label>
              <span className="balance-label">
                Balance {canShowBalances ? amountText(desk.balances.weth, 18, 6) : '—'}
              </span>
            </div>
            <div className="collateral-input-row">
              <input
                id="collateral-amount"
                inputMode="decimal"
                placeholder="0.00"
                autoComplete="off"
                value={collateralAmount}
                onChange={(event) => {
                  if (/^\d*\.?\d*$/.test(event.target.value)) setCollateralAmount(event.target.value)
                }}
                disabled={desk.busy}
              />
              <span>
                <ShieldCheck size={16} aria-hidden="true" />
                WETH
              </span>
            </div>
          </div>
        ) : (
          <>
            <div className="amount-divider">
              <span>
                <ArrowDown size={17} aria-hidden="true" />
              </span>
            </div>
            <div className="output-section">
              <div className="amount-label">
                <span>You receive</span>
                {desk.isQuoting && (
                  <LoaderCircle size={14} className="spin" aria-label="Fetching quote" />
                )}
              </div>
              <div className="amount-output-row">
                <span className={desk.isQuoting ? 'quote-loading' : ''}>
                  {amountText(quoteAmount)}
                </span>
                <span className="asset-label">
                  <span className={`asset-symbol ${isSell ? '' : 'note-symbol'}`}>
                    {isSell ? '$' : 'm'}
                  </span>
                  {outputAsset}
                </span>
              </div>
            </div>
          </>
        )}

        <div className="trade-details">
          <DetailRow label="Maturity" value={maturity} icon={CalendarDays} />
          <DetailRow
            label={isBorrow ? 'Max. shares sold' : 'Minimum received'}
            value={
              desk.quote
                ? `${amountText(isBorrow ? desk.quote.maximumInput : desk.quote.minimumOutput)} ${isBorrow ? 'mgNOTE' : outputAsset}`
                : '—'
            }
            emphasis
          />
          {isBorrow && (
            <>
              <DetailRow
                label="New debt, up to"
                value={maximumNewDebt !== undefined ? `${amountText(maximumNewDebt)} USDC` : '—'}
              />
              {desk.balances.postedCollateral > 0n && (
                <DetailRow
                  label="Already posted"
                  value={`${amountText(desk.balances.postedCollateral, 18, 6)} WETH`}
                />
              )}
              {desk.balances.debt > 0n && (
                <DetailRow label="Current debt" value={`${amountText(desk.balances.debt)} USDC`} />
              )}
              {creditApplied > 0n && (
                <DetailRow label="Credit applied" value={`${amountText(creditApplied)} USDC`} />
              )}
            </>
          )}
          <DetailRow
            label="Swap fee"
            value={desk.desk ? `${(desk.desk.feeBps / 100).toFixed(2)}%` : '—'}
            icon={Percent}
          />
          <DetailRow
            label="Slippage"
            value={`${(slippageBps / 100).toFixed(2)}%`}
            icon={SlidersHorizontal}
          />
        </div>

        {desk.error && (
          <div className="trade-error" role="alert">
            {desk.error}
          </div>
        )}
        {desk.status && (
          <div className="trade-status" role="status">
            <span>{desk.status}</span>
          </div>
        )}
        {desk.txHash && (
          <a
            className="transaction-link"
            href={`https://basescan.org/tx/${desk.txHash}`}
            target="_blank"
            rel="noreferrer"
          >
            View transaction <ExternalLink size={13} aria-hidden="true" />
          </a>
        )}

        <div className="trade-action">
          {!desk.isConnected ? (
            <WalletSlot primary />
          ) : desk.isWrongChain ? (
            <button
              className="primary-button"
              onClick={() => desk.switchToBase()}
              type="button"
            >
              Switch to Base <ArrowRight size={17} aria-hidden="true" />
            </button>
          ) : (
            <button
              type="button"
              className="primary-button"
              disabled={!desk.canSubmit || desk.busy}
              onClick={() => void desk.execute()}
            >
              {desk.busy ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : null}
              {desk.actionLabel}
              <ArrowRight size={17} aria-hidden="true" />
            </button>
          )}
        </div>
      </section>
      {desk.completion && (
        <CompletionModal trade={desk.completion} onDismiss={desk.dismissCompletion} />
      )}
    </main>
  )
}

function RouteFallback() {
  return (
    <div
      style={{
        minHeight: '50vh',
        display: 'grid',
        placeItems: 'center',
        color: 'var(--text-muted)',
        fontSize: '13px',
      }}
    >
      Loading Moonglade…
    </div>
  )
}

function ActiveShellRoutes() {
  const { variant } = useLandingVariant()
  const Shell = getLazyShell(variant)
  const Landing = getLazyLanding(variant)

  return (
    <Suspense fallback={<RouteFallback />}>
      <Shell>
        <Suspense fallback={<RouteFallback />}>
          <Routes>
            <Route path="/" element={<Landing />} />
            <Route path="/markets" element={<MakersPage />} />
            <Route path="/makers" element={<MakersPage />} />
            <Route path="/swap" element={<SelectedSwapPage />} />
            <Route path="/portfolio" element={<PortfolioPlaceholderPage />} />
            <Route path="/maker" element={<MakerPlaceholderPage />} />
            <Route path="/docs" element={<DocsPage />} />
            <Route path="/docs/:slug" element={<DocsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </Shell>
      <VariantSwitcher />
    </Suspense>
  )
}

export default function App() {
  return (
    <VariantProvider>
      <a className="skip-link" href="#content">
        Skip to content
      </a>
      <ActiveShellRoutes />
    </VariantProvider>
  )
}
