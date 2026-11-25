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

export interface ProofFill {
  flow: string
  block: string
  txHash: string
  summary: string
}

export interface FaqEntry {
  question: string
  answer: string
}

export const NAV_ITEMS = [
  { label: 'Markets', to: '/markets' },
  { label: 'Portfolio', to: '/portfolio' },
  { label: 'Make markets', to: '/maker' },
  { label: 'Docs', to: '/docs' },
] as const

export const STACK_ITEMS = [
  '1inch Aqua',
  'SwapVM',
  'Morpho Midnight',
  '2nd place · ETHGlobal Mumbai',
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

export const PROOF_FILLS: readonly ProofFill[] = [
  {
    flow: 'Maker strategy shipped',
    block: '54,083,327',
    txHash: '0x41d1b8b13b099b369e0c9bdbde6ce258b58de13763b4fb631b6a72a2072a2330',
    summary: 'Shipped 10 USDC / 22.255409 mgNOTE virtual budgets on Aqua',
  },
  {
    flow: 'Lend',
    block: '54,116,329',
    txHash: '0x4ad8fb40fe0fb439ffc71360c97f15d7b32900dbc0ce503af89c6fbe49604e5f',
    summary: '0.100000 USDC → 0.100753 mgNOTE (tick 4352)',
  },
  {
    flow: 'Exit early',
    block: '54,117,004',
    txHash: '0x2b99035044ec4fc310d1ea9c10abc245e84a8d14a0e4a6f03467499d1fd9110d',
    summary: '0.100750 mgNOTE → 0.099386 USDC (135s later)',
  },
  {
    flow: 'Borrow',
    block: '54,118,781',
    txHash: '0x8b8689edca1edcfb10f2a7d359b7b093f9c65f2e23d2964438b68f15f84a5110',
    summary: '0.100000 USDC received · 0.101397 debt against WETH',
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
] as const
