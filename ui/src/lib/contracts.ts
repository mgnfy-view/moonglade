import type { Address } from 'viem';
import { base } from 'viem/chains';

export const CHAIN = base;
export const CONTRACTS = {
  hook: '0x4c448fB2E4966d653F5A70Bb1eDd58EF926Cac1b',
  router: '0x0E55412F919a61B95070cE1D8afdA366910A4806',
  note: '0x1c98484DD2F116219fE919af98A7DC1568f1c7b1',
  midnight: '0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A',
  aqua: '0x1111113CCf1426A8E30e2bfF5E005d929bF6a90a',
  usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  weth: '0x4200000000000000000000000000000000000006',
  ratifier: '0x03F4b7cC154C52f19C4218efb55358Cf9B20A852',
} as const satisfies Record<string, Address>;
export const MARKET_ID = '0x2231090fb0a9859a42ec77b8db118af2f725d06471390e326fbe5eeb9724af02' as const;
export const WAD = 10n ** 18n;
export const BPS = 10_000n;
export const MAX_UINT128 = (1n << 128n) - 1n;
export const DEFAULT_SLIPPAGE_BPS = 50;
export const DEADLINE_SECONDS = 20 * 60;
export const MATURITY_BUFFER_SECONDS = 24 * 60 * 60;
export const QUOTE_FRESHNESS_MS = 60_000;

export type TradeMode = 'lend' | 'borrow' | 'sell';
