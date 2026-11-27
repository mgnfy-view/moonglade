import { useQuery } from '@tanstack/react-query'
import { formatUnits, parseAbi } from 'viem'
import { erc20Abi, hookAbi, midnightAbi, noteAbi, oracleAbi } from '../lib/abis'
import { publicClient } from '../lib/client'
import { CONTRACTS, MARKET_ID, WAD } from '../lib/contracts'

const aquaReads = parseAbi([
  'function safeBalances(address maker, address app, bytes32 strategyHash, address token0, address token1) view returns (uint256 balance0, uint256 balance1)',
])

export interface ProtocolLiveStats {
  tvlUsd: number
  curveRatePct: number | null
  cashBudgetUsdc: number
  noteBudgetMgNote: number
  issuedNotes: number
  blockNumber: bigint
  isActive: boolean
  /** Requires historical/position indexer over Midnight and SwapVM events */
  openPositions: number | null
  uniqueWallets: number | null
  cumulativeVolumeUsd: number | null
}

async function fetchProtocolStats(): Promise<ProtocolLiveStats> {
  const block = await publicClient.getBlock()
  const at = { blockNumber: block.number }

  const [order, active, registered, strategyHash, market, totalSupply, rawPayout] =
    await Promise.all([
      publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'order', ...at }),
      publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'active', ...at }),
      publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'isRegistered', ...at }),
      publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'strategyHash', ...at }),
      publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'market', ...at }),
      publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'totalSupply', ...at }),
      publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'payoutPerShare', ...at }),
    ])

  const isDeskActive = active && registered
  const oracleAddress = market.collateralParams[0]?.oracle

  const [rateRaw, makerUsdc, makerWethCollateral, oraclePrice, budgets] = await Promise.all([
    isDeskActive
      ? publicClient.readContract({ address: CONTRACTS.hook, abi: hookAbi, functionName: 'currentRate', ...at })
      : Promise.resolve(0n),
    publicClient.readContract({ address: CONTRACTS.usdc, abi: erc20Abi, functionName: 'balanceOf', args: [order.maker], ...at }),
    publicClient.readContract({ address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'collateral', args: [MARKET_ID, order.maker, 0n], ...at }),
    oracleAddress
      ? publicClient.readContract({ address: oracleAddress, abi: oracleAbi, functionName: 'price', ...at })
      : Promise.resolve(0n),
    isDeskActive
      ? publicClient.readContract({
          address: CONTRACTS.aqua,
          abi: aquaReads,
          functionName: 'safeBalances',
          args: [order.maker, CONTRACTS.router, strategyHash, CONTRACTS.usdc, CONTRACTS.note],
          ...at,
        })
      : Promise.resolve([0n, 0n] as const),
  ])

  const effectivePayout = totalSupply === 0n ? WAD : rawPayout
  const backedCreditUsdc = (totalSupply * effectivePayout) / WAD
  const collateralUsd6 = (makerWethCollateral * oraclePrice) / 10n ** 36n
  const tvlUsd = Number(formatUnits(backedCreditUsdc + collateralUsd6 + makerUsdc, 6))

  return {
    tvlUsd,
    curveRatePct: isDeskActive ? Number(formatUnits(rateRaw, 18)) * 100 : null,
    cashBudgetUsdc: Number(formatUnits(budgets[0], 6)),
    noteBudgetMgNote: Number(formatUnits(budgets[1], 6)),
    issuedNotes: Number(formatUnits(totalSupply, 6)),
    blockNumber: block.number,
    isActive: isDeskActive,
    openPositions: null,
    uniqueWallets: null,
    cumulativeVolumeUsd: null,
  }
}

export function useProtocolStats() {
  return useQuery({
    queryKey: ['protocol-live-stats'],
    queryFn: fetchProtocolStats,
    staleTime: 20_000,
    refetchInterval: 30_000,
    retry: 1,
  })
}
