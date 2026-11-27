export interface FlowSpec {
  id: 'lend' | 'borrow' | 'exit'
  label: string
  pathLabel: string
  summary: string
  route: string
  ctaLabel: string
}

export interface MakerPillar {
  index: string
  title: string
  body: string
}

export interface FaqEntry {
  question: string
  answer: string
}

export const APP_NAV_ITEMS = [
  { label: 'Markets', to: '/markets' },
  { label: 'Portfolio', to: '/portfolio' },
  { label: 'Make markets', to: '/maker' },
  { label: 'Docs', to: '/docs' },
] as const

export const HERO_COPY = {
  headlinePrimary: 'Fixed-rate credit.',
  headlineSecondary: 'One swap away.',
  description:
    'Lend at a fixed rate, borrow against your collateral, or exit early on Morpho Midnight.',
  primaryCta: 'Open app',
  primaryTo: '/markets',
  secondaryCta: 'Read docs',
  secondaryTo: '/docs',
} as const

export const FLOW_SPECS: readonly FlowSpec[] = [
  {
    id: 'lend',
    label: 'Lend',
    pathLabel: 'Loan asset → mgNOTE → Redeem',
    summary:
      'Swap into mgNOTE to lock a fixed rate until maturity, then redeem your share of repaid Midnight credit.',
    route: '/markets?mode=lend',
    ctaLabel: 'Lend',
  },
  {
    id: 'borrow',
    label: 'Borrow',
    pathLabel: 'Collateral → Loan asset → Repay',
    summary:
      'After posting collateral and setting a borrow limit, one swap opens a fixed-rate loan on your own Midnight account.',
    route: '/markets?mode=borrow',
    ctaLabel: 'Borrow',
  },
  {
    id: 'exit',
    label: 'Exit early',
    pathLabel: 'mgNOTE → Loan asset',
    summary:
      'Sell mgNOTE back to a live desk at its available quote before the one-day pre-maturity cutoff, subject to desk liquidity.',
    route: '/markets?mode=sell',
    ctaLabel: 'Sell mgNOTE',
  },
] as const

export const MATURITY_NOTE =
  'Holding to maturity? Call redeem on the note contract to withdraw your proportional share of repaid Midnight credit.'

export const MAKER_PILLARS: readonly MakerPillar[] = [
  {
    index: '01',
    title: 'Fees both ways',
    body: 'Quote both lenders and borrowers with one pricing curve. Each trade pays your spread while offsetting flow keeps net carry small.',
  },
  {
    index: '02',
    title: 'Nothing to pre-mint',
    body: 'Settlement hooks mint mgNOTE during the trade against your Midnight position and can burn incoming notes to cancel maker debt.',
  },
  {
    index: '03',
    title: 'Shared wallet capital',
    body: '1inch Aqua lets multiple desks share balances held in your wallet. Cash float, collateral, allowances, and risk limits still apply.',
  },
] as const

export const FAQ_ITEMS: readonly FaqEntry[] = [
  {
    question: 'Why use a desk instead of waiting on an order book?',
    answer:
      'Morpho Midnight’s order book requires someone actively quoting your size and rate. Moonglade adds an AMM desk beside it so lenders, borrowers, and exiting holders can settle immediately while arbitrage keeps rates aligned with Midnight’s book.',
  },
  {
    question: 'Does Moonglade only support USDC and WETH?',
    answer:
      'No. The current Base demo desk quotes a USDC market backed by WETH collateral, while the deployed contracts support eligible ungated Morpho Midnight markets across assets and maturities.',
  },
  {
    question: 'Is the marginal curve rate what I receive?',
    answer:
      'No. The execution rate includes the maker’s fee (30 bps on the Base demo desk), Midnight tick rounding, and trade-size impact along the curve. Always check the quoted output and bounds before signing.',
  },
  {
    question: 'How do early exits and maturity redemption differ?',
    answer:
      'Early exit sells mgNOTE into a live desk at its available quote before the 1-day pre-maturity cutoff (not guaranteed at par). At maturity, redeem mgNOTE directly on the note contract for its share of repaid Midnight credit.',
  },
  {
    question: 'How do makers provide liquidity without locking funds in a pool?',
    answer:
      'Makers register virtual budgets on 1inch Aqua while keeping balances in their own wallet. Cash and collateral move only during settlement, and the same wallet balance can back multiple strategies simultaneously.',
  },
] as const
