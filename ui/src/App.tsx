import { useState } from 'react'
import { Link, Navigate, Route, Routes, useLocation, useSearchParams } from 'react-router-dom'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { ArrowDown, ArrowLeft, ArrowLeftRight, ArrowRight, ArrowUpRight, Blocks, CalendarDays, ExternalLink, Landmark, Layers, LoaderCircle, LogOut, Percent, Scale, ShieldCheck, SlidersHorizontal, TrendingUp, Wallet, type LucideIcon } from 'lucide-react'
import { formatUnits } from 'viem'
import { useMoonglade, type TradeMode } from './hooks/useMoonglade'
import MakersPage from './MakersPage'
import CompletionModal from './CompletionModal'
import { MAKERS, shortAddress, tradeMode, type ListedMaker } from './lib/makers'
import './styles.css'

const deskExplorer = 'https://basescan.org/address/0x4c448fB2E4966d653F5A70Bb1eDd58EF926Cac1b'

function Brand() {
  return <Link to="/" className="brand" aria-label="Moonglade home">
    <span>Moonglade</span>
  </Link>
}

function WalletButton({ primary = false }: { primary?: boolean }) {
  return <ConnectButton.Custom>{({ account, chain, mounted, openAccountModal, openChainModal, openConnectModal }) => {
    const connected = mounted && account && chain
    return <button className={primary ? 'primary-button' : 'wallet-button'} onClick={!connected ? openConnectModal : chain?.unsupported ? openChainModal : openAccountModal} type="button">
      <span className="wallet-label">{!connected ? 'Connect wallet' : chain?.unsupported ? 'Switch network' : account?.displayName}</span>
      <ArrowUpRight size={16} aria-hidden="true" />
    </button>
  }}</ConnectButton.Custom>
}

function Header() {
  const swapPage = ['/makers', '/swap'].includes(useLocation().pathname)
  return <header className={`site-header ${swapPage ? 'site-header-dark' : ''}`}>
    <Brand />
    <nav aria-label="Main navigation">
      {swapPage ? <WalletButton /> : <Link className="header-launch" to="/makers">Makers <ArrowUpRight size={16} aria-hidden="true" /></Link>}
    </nav>
  </header>
}

function HeroGraphic() {
  return <div className="hero-art" aria-hidden="true">
    <img src="/brand/moonglade-art.svg" width="560" height="560" alt="" decoding="async" fetchPriority="high" />
  </div>
}

function LandingPage() {
  return <main className="landing">
    <section className="hero" aria-labelledby="hero-heading">
      <div className="hero-copy">
        <h1 id="hero-heading">Fixed-rate<br />credit.<br /><span className="heading-secondary">One swap away.</span></h1>
        <p className="hero-description">Lock a rate. Borrow against collateral. Exit any time.<br />Every move is one swap, quoted instantly.</p>
        <Link className="primary-button hero-cta" to="/makers">Open app <ArrowUpRight size={19} aria-hidden="true" /></Link>
      </div>
      <HeroGraphic />
    </section>

    <section className="integration-strip" aria-label="Protocol integrations">
      <div className="integration-names"><span className="integration-label">Built on</span><span>1inch Aqua</span><span>SwapVM</span><span>Morpho Midnight</span></div>
    </section>

    <section id="how-it-works" className="landing-flows" aria-labelledby="flows-heading">
      <h2 id="flows-heading">Fixed-rate loans.<br />Swap-simple.</h2>
      <div className="flow-grid">
        <article>
          <h3><TrendingUp className="label-icon" aria-hidden="true" />Lend.</h3>
          <div className="token-flow" aria-label="Swap loan assets for mgNOTE"><span>Assets</span><ArrowRight aria-hidden="true" /><span>mgNOTE</span></div>
          <p>Lock today’s rate until maturity. Your position is a token: hold it, send it, sell it.</p>
          <Link to="/makers?mode=lend">Lend <ArrowUpRight size={17} aria-hidden="true" /></Link>
        </article>
        <article>
          <h3><Landmark className="label-icon" aria-hidden="true" />Borrow.</h3>
          <div className="token-flow" aria-label="Collateral backs a loan"><span>Collateral</span><ArrowRight aria-hidden="true" /><span>Assets</span></div>
          <p>Set a borrow limit once. One swap opens a fixed-rate loan on your own Midnight account.</p>
          <Link to="/makers?mode=borrow">Borrow <ArrowUpRight size={17} aria-hidden="true" /></Link>
        </article>
        <article>
          <h3><LogOut className="label-icon" aria-hidden="true" />Exit early.</h3>
          <div className="token-flow" aria-label="Swap mgNOTE back to loan assets"><span>mgNOTE</span><ArrowRight aria-hidden="true" /><span>Assets</span></div>
          <p>No lock-in. Sell back at the live quote, any time before maturity.</p>
          <Link to="/makers?mode=sell">Sell mgNOTE <ArrowUpRight size={17} aria-hidden="true" /></Link>
        </article>
      </div>
      <p className="redemption-note">Holding to maturity? Redeem mgNOTE for its share of repaid Midnight credit.</p>
    </section>

    <section className="desk-section" aria-labelledby="desk-heading">
      <div className="desk-pitch">
        <h2 id="desk-heading">Make markets<br />in real loans.</h2>
        <p>Run a fixed-rate bond desk from your wallet. Ship a curve once and earn on every lend, borrow and exit. No bots.</p>
        <div className="desk-links"><a className="text-link" href="https://github.com/mgnfy-view/moonglade#deploy-a-desk" target="_blank" rel="noreferrer">Build a desk <ArrowUpRight size={17} aria-hidden="true" /></a><a className="text-link" href="/Moonglade-Whitepaper.pdf" target="_blank" rel="noreferrer">Whitepaper <ArrowUpRight size={17} aria-hidden="true" /></a></div>
      </div>
      <div className="desk-features">
        <article><h3><ArrowLeftRight className="label-icon" aria-hidden="true" />Fees both ways.</h3><p>You’re the counterparty for lenders and borrowers alike. Your curve nudges flow back into balance. Collect fees while balanced flow offsets carry.</p></article>
        <article><h3><Layers className="label-icon" aria-hidden="true" />Inventory on demand.</h3><p>Hooks mint notes inside the trade, each backed by real Midnight credit. Nothing to pre-fund.</p></article>
        <article><h3><Wallet className="label-icon" aria-hidden="true" />One wallet, many desks.</h3><p>Aqua lets every strategy share one balance. Capital stays in your wallet until a trade settles.</p></article>
        <article><h3><SlidersHorizontal className="label-icon" aria-hidden="true" />Your curve. Your price.</h3><p>Plug in any pricing contract and fee. Our SwapVM opcode snaps every quote to Midnight’s tick grid.</p></article>
        <article><h3><Scale className="label-icon" aria-hidden="true" />Priced with the market.</h3><p>Arbitrage between desks and Midnight’s order book keeps every quote honest.</p></article>
      </div>
    </section>

    <section className="credit-band" aria-labelledby="credit-heading">
      <h2 id="credit-heading"><Blocks className="label-icon" aria-hidden="true" />Credit that moves.</h2>
      <p>mgNOTE turns Midnight credit into an ERC-20.<br />Trade it, transfer it, build on it.</p>
    </section>

  </main>
}

function amountText(value: bigint | undefined, decimals = 6, maximumFractionDigits = 4) {
  if (value === undefined) return '—'
  const numericValue = Number(formatUnits(value, decimals))
  if (numericValue > 0 && numericValue < 0.0001) return '< 0.0001'
  return numericValue.toLocaleString('en-US', { maximumFractionDigits })
}

function DetailRow({ label, value, emphasis = false, icon: Icon }: { label: string; value: string; emphasis?: boolean; icon?: LucideIcon }) {
  return <div className={`detail-row ${emphasis ? 'detail-emphasis' : ''}`}><span>{Icon && <Icon size={14} aria-hidden="true" />}{label}</span><span>{value}</span></div>
}

function SelectedSwapPage() {
  const [params] = useSearchParams()
  const maker = MAKERS.find(entry => entry.id === params.get('maker'))
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
  const maturity = desk.desk ? new Date(desk.desk.maturity * 1000).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : '—'
  const changeMode = (nextMode: TradeMode) => {
    if (desk.busy) return
    setMode(nextMode)
    setAmount('')
    setCollateralAmount('')
  }
  const inputBalance = isSell ? desk.balances.note : desk.balances.usdc
  const quoteAmount = desk.quote?.amountOut
  const maximumNewDebt = desk.quote
    ? desk.quote.projectedDebt > desk.balances.debt ? desk.quote.projectedDebt - desk.balances.debt : 0n
    : undefined
  const creditApplied = desk.quote && maximumNewDebt !== undefined ? desk.quote.borrowUnits - maximumNewDebt : 0n
  const canShowBalances = desk.isConnected && !desk.isLoading

  return <main className="swap-page">
    <Link className="desk-back" to={`/makers?mode=${mode}`}><ArrowLeft size={16} aria-hidden="true" />All makers</Link>
    <section className="trade-panel" aria-label="Credit swap">
      <div className="trade-heading"><h1 title={maker.address}>{shortAddress(maker.address)}</h1><span className="network-label"><span />Base</span></div>
      <p className="selected-market">{maker.loanSymbol} / {maker.noteSymbol} · {maker.collateralSymbol} collateral</p>
      <div className="trade-tabs" role="tablist" aria-label="Trade direction">
        <button type="button" role="tab" aria-selected={mode === 'lend'} className={mode === 'lend' ? 'selected' : ''} onClick={() => changeMode('lend')} disabled={desk.busy}><TrendingUp size={16} aria-hidden="true" />Lend</button>
        <button type="button" role="tab" aria-selected={mode === 'borrow'} className={mode === 'borrow' ? 'selected' : ''} onClick={() => changeMode('borrow')} disabled={desk.busy}><Landmark size={16} aria-hidden="true" />Borrow</button>
        <button type="button" role="tab" aria-selected={mode === 'sell'} className={mode === 'sell' ? 'selected' : ''} onClick={() => changeMode('sell')} disabled={desk.busy}><ArrowLeftRight size={16} aria-hidden="true" />Sell</button>
      </div>

      <div className="amount-section">
        <div className="amount-label"><label htmlFor="trade-amount">{isBorrow ? 'USDC to receive' : isSell ? 'Shares to sell' : 'You pay'}</label>{!isBorrow && <span className="balance-label">Balance {canShowBalances ? amountText(inputBalance) : '—'}</span>}</div>
        <div className="amount-input-row"><input id="trade-amount" inputMode="decimal" autoComplete="off" spellCheck={false} placeholder="0.00" value={amount} onChange={(event) => { if (/^\d*\.?\d*$/.test(event.target.value)) setAmount(event.target.value) }} disabled={desk.busy} /><span className="asset-label"><span className={`asset-symbol ${isSell ? 'note-symbol' : ''}`}>{isSell ? 'm' : '$'}</span>{inputAsset}</span></div>
        <div className="preset-row"><div>{['0.25', '0.5', '1'].map((preset) => <button type="button" key={preset} onClick={() => setAmount(preset)} disabled={desk.busy}>{preset}</button>)}</div></div>
      </div>

      {isBorrow ? <div className="collateral-section">
        <div className="amount-label"><label htmlFor="collateral-amount">Add WETH collateral</label><span className="balance-label">Balance {canShowBalances ? amountText(desk.balances.weth, 18, 6) : '—'}</span></div>
        <div className="collateral-input-row"><input id="collateral-amount" inputMode="decimal" placeholder="0.00" autoComplete="off" value={collateralAmount} onChange={(event) => { if (/^\d*\.?\d*$/.test(event.target.value)) setCollateralAmount(event.target.value) }} disabled={desk.busy} /><span><ShieldCheck size={16} aria-hidden="true" />WETH</span></div>
      </div> : <>
        <div className="amount-divider"><span><ArrowDown size={17} aria-hidden="true" /></span></div>
        <div className="output-section"><div className="amount-label"><span>You receive</span>{desk.isQuoting && <LoaderCircle size={14} className="spin" aria-label="Fetching quote" />}</div><div className="amount-output-row"><span className={desk.isQuoting ? 'quote-loading' : ''}>{amountText(quoteAmount)}</span><span className="asset-label"><span className={`asset-symbol ${isSell ? '' : 'note-symbol'}`}>{isSell ? '$' : 'm'}</span>{outputAsset}</span></div></div>
      </>}

      <div className="trade-details">
        <DetailRow label="Maturity" value={maturity} icon={CalendarDays} />
        <DetailRow label={isBorrow ? 'Max. shares sold' : 'Minimum received'} value={desk.quote ? `${amountText(isBorrow ? desk.quote.maximumInput : desk.quote.minimumOutput)} ${isBorrow ? 'mgNOTE' : outputAsset}` : '—'} emphasis />
        {isBorrow && <><DetailRow label="New debt, up to" value={maximumNewDebt !== undefined ? `${amountText(maximumNewDebt)} USDC` : '—'} />{desk.balances.postedCollateral > 0n && <DetailRow label="Already posted" value={`${amountText(desk.balances.postedCollateral, 18, 6)} WETH`} />}{desk.balances.debt > 0n && <DetailRow label="Current debt" value={`${amountText(desk.balances.debt)} USDC`} />}{creditApplied > 0n && <DetailRow label="Credit applied" value={`${amountText(creditApplied)} USDC`} />}</>}
        <DetailRow label="Swap fee" value={desk.desk ? `${(desk.desk.feeBps / 100).toFixed(2)}%` : '—'} icon={Percent} />
        <DetailRow label="Slippage" value={`${(slippageBps / 100).toFixed(2)}%`} icon={SlidersHorizontal} />
      </div>

      {desk.error && <div className="trade-error" role="alert">{desk.error}</div>}
      {desk.status && <div className="trade-status" role="status"><span>{desk.status}</span></div>}
      {desk.txHash && <a className="transaction-link" href={`https://basescan.org/tx/${desk.txHash}`} target="_blank" rel="noreferrer">View transaction <ExternalLink size={13} aria-hidden="true" /></a>}

      <div className="trade-action">{!desk.isConnected ? <WalletButton primary /> : desk.isWrongChain ? <button className="primary-button" onClick={() => desk.switchToBase()} type="button">Switch to Base <ArrowRight size={17} aria-hidden="true" /></button> : <button type="button" className="primary-button" disabled={!desk.canSubmit || desk.busy} onClick={() => void desk.execute()}>{desk.busy ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : null}{desk.actionLabel}<ArrowRight size={17} aria-hidden="true" /></button>}</div>
    </section>
    {desk.completion && <CompletionModal trade={desk.completion} onDismiss={desk.dismissCompletion} />}
  </main>
}

function Footer() {
  const swapPage = ['/makers', '/swap'].includes(useLocation().pathname)
  return <footer className={`site-footer ${swapPage ? 'site-footer-dark' : ''}`}><span>© {new Date().getFullYear()} Moonglade · Built at ETHGlobal Mumbai</span><nav aria-label="Resources"><a href="https://github.com/mgnfy-view/moonglade#how-it-works" target="_blank" rel="noreferrer">Docs</a><a href="https://github.com/mgnfy-view/moonglade" target="_blank" rel="noreferrer">GitHub <ArrowUpRight size={13} aria-hidden="true" /></a><a href={deskExplorer} target="_blank" rel="noreferrer">Explorer <ArrowUpRight size={13} aria-hidden="true" /></a></nav></footer>
}

export default function App() {
  const swapPage = ['/makers', '/swap'].includes(useLocation().pathname)
  return <div className={swapPage ? 'app-shell app-shell-dark' : 'app-shell'}><a className="skip-link" href="#content">Skip to content</a><Header /><div id="content"><Routes><Route path="/" element={<LandingPage />} /><Route path="/makers" element={<MakersPage />} /><Route path="/swap" element={<SelectedSwapPage />} /><Route path="*" element={<LandingPage />} /></Routes></div><Footer /></div>
}
