import { formatUnits, isAddressEqual, parseUnits, type Address } from 'viem';
import { erc20Abi, hookAbi, midnightAbi, noteAbi, oracleAbi, routerAbi } from './abis';
import { publicClient } from './client';
import { BPS, CHAIN, CONTRACTS, DEADLINE_SECONDS, MARKET_ID, MATURITY_BUFFER_SECONDS, MAX_UINT128, WAD, type TradeMode } from './contracts';
import { buildTakerTraits } from './traits';

export const EMPTY_BALANCES = { usdc: 0n, note: 0n, weth: 0n, postedCollateral: 0n, debt: 0n };

export function parseAmount(value: string, decimals: number): bigint {
  if (!value.trim()) return 0n;
  if (!new RegExp(`^(?:\\d+)(?:\\.\\d{0,${decimals}})?$`).test(value.trim())) {
    throw new Error(`Enter a positive amount with at most ${decimals} decimal places.`);
  }
  return parseUnits(value.trim(), decimals);
}

export async function loadSnapshot(account?: Address) {
  const block = await publicClient.getBlock();
  const at = { blockNumber: block.number };
  const [order, active, registered, rateConfig, market, maturity, rawPayout, strategyHash, totalSupply] = await Promise.all([
    publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'order', ...at }),
    publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'active', ...at }),
    publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'isRegistered', ...at }),
    publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'curveConfig', ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'market', ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'maturity', ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'payoutPerShare', ...at }),
    publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'strategyHash', ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'totalSupply', ...at }),
  ]);
  const selected = market.collateralParams[0];
  if (!selected || !isAddressEqual(selected.token, CONTRACTS.weth) || !isAddressEqual(market.loanToken, CONTRACTS.usdc)
    || !isAddressEqual(market.midnight, CONTRACTS.midnight) || market.chainId !== BigInt(CHAIN.id)
    || maturity !== market.maturity || !isAddressEqual(rateConfig.note, CONTRACTS.note)) {
    throw new Error('The live market no longer matches this application. Trading is disabled.');
  }
  if (rateConfig.data.length !== 38) throw new Error('The desk pricing format changed. Trading is disabled.');
  const [rate, oraclePrice, canonicalHash] = await Promise.all([
    active && registered ? publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'currentRate', ...at }) : Promise.resolve(0n),
    publicClient.readContract({ address: selected.oracle, abi: oracleAbi, functionName: 'price', ...at }),
    publicClient.readContract({ address: CONTRACTS.router, abi: routerAbi, functionName: 'hash', args: [order], ...at }),
  ]);
  if (canonicalHash !== strategyHash) throw new Error('The live strategy is inconsistent. Refresh before trading.');
  const desk = {
    rate: Number(formatUnits(rate, 18)),
    feeBps: parseInt(rateConfig.data.slice(-4), 16),
    maturity: Number(maturity),
    active: active && registered,
  };
  const payout = totalSupply === 0n ? WAD : rawPayout;
  const common = { order, market, desk, curve: rateConfig.curve, strategyHash, payout, oraclePrice, lltv: selected.lltv, timestamp: block.timestamp, blockNumber: block.number, loadedAt: Date.now() };
  if (!account) return { ...common, balances: EMPTY_BALANCES, usdcAllowance: 0n, noteAllowance: 0n, wethAllowance: 0n, credit: 0n, ratifierAuthorized: false, hookAuthorized: false, mintAllowance: [0n, 0] as const };
  const [usdc, note, weth, postedCollateral, debt, creditState, usdcAllowance, noteAllowance, wethAllowance, ratifierAuthorized, hookAuthorized, mintAllowance] = await Promise.all([
    publicClient.readContract({ address: CONTRACTS.usdc, abi: erc20Abi, functionName: 'balanceOf', args: [account], ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: erc20Abi, functionName: 'balanceOf', args: [account], ...at }),
    publicClient.readContract({ address: CONTRACTS.weth, abi: erc20Abi, functionName: 'balanceOf', args: [account], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'collateral', args: [MARKET_ID, account, 0n], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'debt', args: [MARKET_ID, account], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'updatePositionView', args: [market, MARKET_ID, account], ...at }),
    publicClient.readContract({ address: CONTRACTS.usdc, abi: erc20Abi, functionName: 'allowance', args: [account, CONTRACTS.router], ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: erc20Abi, functionName: 'allowance', args: [account, CONTRACTS.router], ...at }),
    publicClient.readContract({ address: CONTRACTS.weth, abi: erc20Abi, functionName: 'allowance', args: [account, CONTRACTS.midnight], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'isAuthorized', args: [account, CONTRACTS.ratifier], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'isAuthorized', args: [account, CONTRACTS.hook], ...at }),
    publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'borrowAllowances', args: [account, CONTRACTS.hook], ...at }),
  ]);
  return { ...common, balances: { usdc, note, weth, postedCollateral, debt }, credit: creditState[0], usdcAllowance, noteAllowance, wethAllowance, ratifierAuthorized, hookAuthorized, mintAllowance };
}

export type Snapshot = Awaited<ReturnType<typeof loadSnapshot>>;
export type Quote = {
  amountIn: bigint; amountOut: bigint; minimumOutput: bigint; maximumInput: bigint; borrowUnits: bigint;
  projectedDebt: bigint; capacity: bigint; deadline: bigint; createdAt: number;
};

export async function getQuote(snapshot: Snapshot, account: Address, mode: TradeMode, amount: bigint, slippageBps: number): Promise<Quote> {
  if (isAddressEqual(account, snapshot.order.maker)) throw new Error('This wallet operates the desk. Use a separate wallet to trade with it.');
  if (!snapshot.desk.active) throw new Error('The maker desk is inactive.');
  if (snapshot.timestamp >= BigInt(snapshot.desk.maturity - MATURITY_BUFFER_SECONDS)) throw new Error('Trading closes one day before maturity. This market is closed.');
  if (!Number.isInteger(slippageBps) || slippageBps < 0 || slippageBps > 1000) throw new Error('Slippage must be between 0 and 1,000 basis points.');
  if (amount <= 0n) throw new Error('Enter an amount greater than zero.');
  const exactIn = mode !== 'borrow';
  const tokenIn = mode === 'lend' ? CONTRACTS.usdc : CONTRACTS.note;
  const tokenOut = mode === 'lend' ? CONTRACTS.note : CONTRACTS.usdc;
  const deadline = snapshot.timestamp + BigInt(DEADLINE_SECONDS);
  const openThreshold = exactIn ? 0n : (1n << 256n) - 1n;
  const [amountIn, amountOut] = await publicClient.readContract({
    address: CONTRACTS.router, abi: routerAbi, functionName: 'quote', account,
    args: [snapshot.order, tokenIn, tokenOut, amount, buildTakerTraits(exactIn, openThreshold, deadline)], blockNumber: snapshot.blockNumber,
  });
  const bps = BigInt(slippageBps);
  const minimumOutput = exactIn ? amountOut * (BPS - bps) / BPS : amountOut;
  const maximumInput = exactIn ? amountIn : (amountIn * (BPS + bps) + BPS - 1n) / BPS;
  const shortfall = mode === 'borrow' && maximumInput > snapshot.balances.note ? maximumInput - snapshot.balances.note : 0n;
  const borrowUnits = shortfall > 0n ? await publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'previewMintUnits', args: [shortfall], blockNumber: snapshot.blockNumber }) : 0n;
  if (borrowUnits > MAX_UINT128) throw new Error('This mint exceeds the protocol unit limit.');
  const newDebt = borrowUnits > snapshot.credit ? borrowUnits - snapshot.credit : 0n;
  const capacity = snapshot.balances.postedCollateral * snapshot.oraclePrice / (10n ** 36n) * snapshot.lltv / WAD;
  return { amountIn, amountOut, minimumOutput, maximumInput, borrowUnits, projectedDebt: snapshot.balances.debt + newDebt, capacity, deadline, createdAt: Date.now() };
}

export function checkTrade(snapshot: Snapshot, quote: Quote, mode: TradeMode, collateralAmount: bigint): string | null {
  if (mode === 'lend' && snapshot.balances.usdc < quote.maximumInput) return 'Insufficient USDC balance.';
  if (mode === 'sell' && snapshot.balances.note < quote.maximumInput) return 'You can only sell notes you already own.';
  if (mode === 'borrow') {
    if (snapshot.balances.weth < collateralAmount) return 'Insufficient WETH. Wrap ETH separately before continuing.';
    if (snapshot.balances.postedCollateral + collateralAmount > MAX_UINT128) return 'Collateral exceeds the protocol limit.';
    if (snapshot.oraclePrice <= 0n) return 'The collateral oracle is unavailable.';
    const capacity = (snapshot.balances.postedCollateral + collateralAmount) * snapshot.oraclePrice / (10n ** 36n) * snapshot.lltv / WAD;
    // Keep ten percent of the liquidation capacity unused; other collateral is conservatively ignored.
    if (quote.projectedDebt * BPS > capacity * 9000n) return 'Add more WETH or borrow less. Keep at least 10% of collateral capacity unused.';
  }
  return null;
}
