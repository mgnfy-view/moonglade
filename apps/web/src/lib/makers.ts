import { isAddressEqual, parseAbi, type Address } from 'viem'
import { erc20Abi } from './abis'
import { publicClient } from './client'
import { CONTRACTS, MATURITY_BUFFER_SECONDS, type TradeMode } from './contracts'
import { loadSnapshot } from './protocol'

// The directory intentionally lists only our deployed desk.
export const MAKERS = [{
  id: 'moonglade',
  address: '0x51eb5C81066de005965Be0fA3958627B77005282',
  loanSymbol: 'USDC',
  collateralSymbol: 'WETH',
  noteSymbol: 'mgNOTE',
  yieldSpace: '0xE266e34d51b43684429B6081E8E522eD1D3fDafc',
}] as const

export type ListedMaker = typeof MAKERS[number]

export function shortAddress(address: Address): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`
}

const aquaReads = parseAbi([
  'function safeBalances(address maker, address app, bytes32 strategyHash, address token0, address token1) view returns (uint256 balance0, uint256 balance1)',
])

export function tradeMode(value: string | null): TradeMode {
  return value === 'borrow' || value === 'sell' ? value : 'lend'
}

export function swapPath(maker: ListedMaker, mode: TradeMode): string {
  return `/swap?${new URLSearchParams({ maker: maker.id, mode })}`
}

export async function loadMakerDetails(maker: ListedMaker) {
  const snapshot = await loadSnapshot()
  if (!isAddressEqual(snapshot.order.maker, maker.address)) throw new Error('The listed maker does not match the live desk.')
  const at = { blockNumber: snapshot.blockNumber }
  const [budgets, walletCash] = await Promise.all([
    snapshot.desk.active
      ? publicClient.readContract({ address: CONTRACTS.aqua, abi: aquaReads, functionName: 'safeBalances', args: [snapshot.order.maker, CONTRACTS.router, snapshot.strategyHash, CONTRACTS.usdc, CONTRACTS.note], ...at })
      : Promise.resolve([0n, 0n] as const),
    publicClient.readContract({ address: CONTRACTS.usdc, abi: erc20Abi, functionName: 'balanceOf', args: [snapshot.order.maker], ...at }),
  ])
  return {
    ...snapshot,
    cashBudget: budgets[0],
    noteBudget: budgets[1],
    walletCash,
    open: snapshot.desk.active && snapshot.timestamp < BigInt(snapshot.desk.maturity - MATURITY_BUFFER_SECONDS),
    curveName: isAddressEqual(snapshot.curve, maker.yieldSpace) ? 'YieldSpace' : 'Custom curve',
  }
}
