import { useQuery } from '@tanstack/react-query'
import { ArrowUpRight, CalendarDays, LoaderCircle, Percent, SlidersHorizontal, TrendingUp, Wallet } from 'lucide-react'
import { Link, useSearchParams } from 'react-router-dom'
import { formatUnits } from 'viem'
import { CONTRACTS, QUOTE_FRESHNESS_MS } from './lib/contracts'
import { friendlyError } from './lib/errors'
import { loadMakerDetails, MAKERS, shortAddress, swapPath, tradeMode, type ListedMaker } from './lib/makers'

function cash(value: bigint) {
  return Number(formatUnits(value, 6)).toLocaleString('en-US', { maximumFractionDigits: 4 })
}

function MakerCard({ maker }: { maker: ListedMaker }) {
  const [params] = useSearchParams()
  const mode = tradeMode(params.get('mode'))
  const query = useQuery({
    queryKey: ['maker-details', maker.id],
    queryFn: () => loadMakerDetails(maker),
    staleTime: 10_000,
    refetchInterval: 15_000,
    retry: 1,
  })
  const live = query.data
  const usable = !!live && !query.isError && Date.now() - live.loadedAt < QUOTE_FRESHNESS_MS
  const maturity = live ? new Date(live.desk.maturity * 1000).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : '—'
  const status = query.isError ? 'Unavailable' : !live ? 'Loading' : live.open ? 'Active' : 'Closed'

  return <article className="maker-card" aria-labelledby={`maker-${maker.id}`}>
    <div className="maker-card-heading">
      <h2 id={`maker-${maker.id}`}><a className="maker-title-address" href={`https://basescan.org/address/${maker.address}`} title={maker.address} aria-label={`Maker ${maker.address}`} target="_blank" rel="noreferrer">{shortAddress(maker.address)} <ArrowUpRight size={16} aria-hidden="true" /></a></h2>
      <span className={`maker-status ${usable && live.open ? 'maker-status-active' : ''}`}>{query.isPending && <LoaderCircle size={13} className="spin" aria-hidden="true" />}{status}</span>
    </div>
    <div className="maker-market"><span>{maker.loanSymbol} / {maker.noteSymbol}</span><span>{maker.collateralSymbol} collateral · Base</span></div>
    <dl className="maker-metrics">
      <div><dt title="Annual discount rate from the curve, before trading fees"><TrendingUp size={15} aria-hidden="true" />Curve rate</dt><dd>{usable && live.desk.active ? `${(live.desk.rate * 100).toFixed(2)}%` : '—'}</dd></div>
      <div><dt><Percent size={15} aria-hidden="true" />Swap fee</dt><dd>{usable ? `${(live.desk.feeBps / 100).toFixed(2)}%` : '—'}</dd></div>
      <div><dt><CalendarDays size={15} aria-hidden="true" />Maturity</dt><dd>{maturity}</dd></div>
      <div><dt><SlidersHorizontal size={15} aria-hidden="true" />Pricing</dt><dd>{usable ? <a href={`https://basescan.org/address/${live.curve}`} target="_blank" rel="noreferrer">{live.curveName} <ArrowUpRight size={13} aria-hidden="true" /></a> : '—'}</dd></div>
    </dl>
    <dl className="maker-balances">
      <div><dt>Cash budget</dt><dd>{usable ? `${cash(live.cashBudget)} ${maker.loanSymbol}` : '—'}</dd></div>
      <div><dt>Note budget</dt><dd>{usable ? `${cash(live.noteBudget)} ${maker.noteSymbol}` : '—'}</dd></div>
      <div><dt><Wallet size={15} aria-hidden="true" />Wallet cash</dt><dd>{usable ? `${cash(live.walletCash)} ${maker.loanSymbol}` : '—'}</dd></div>
      <div><dt>Liquidation LTV</dt><dd>{usable ? `${(Number(formatUnits(live.lltv, 18)) * 100).toFixed(0)}%` : '—'}</dd></div>
    </dl>
    <p className="maker-budget-note">Budgets are virtual. Trades settle from the maker’s wallet.</p>
    {query.isError && <div className="trade-error" role="alert">{friendlyError(query.error)} <button type="button" onClick={() => void query.refetch()}>Retry</button></div>}
    <div className="maker-card-action"><a className="text-link" href={`https://basescan.org/address/${CONTRACTS.hook}`} target="_blank" rel="noreferrer">Desk contract <ArrowUpRight size={15} aria-hidden="true" /></a>{usable && live.open ? <Link className="primary-button" to={swapPath(maker, mode)}>Select desk <ArrowUpRight size={17} aria-hidden="true" /></Link> : <button type="button" className="primary-button" disabled>{query.isPending ? 'Loading desk' : 'Desk unavailable'}</button>}</div>
  </article>
}

export default function MakersPage() {
  return <main className="makers-page">
    <div className="makers-heading"><div><h1>Choose your maker.</h1><p>Compare the terms. Trade with the desk.</p></div><span>{MAKERS.length} maker</span></div>
    <div className="makers-list">{MAKERS.map(maker => <MakerCard key={maker.id} maker={maker} />)}</div>
  </main>
}
