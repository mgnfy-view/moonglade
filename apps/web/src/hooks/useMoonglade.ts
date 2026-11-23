import { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAccount, useSwitchChain, useWalletClient } from 'wagmi';
import { decodeEventLog, isAddressEqual, parseAbi, type Abi, type Address, type Hex } from 'viem';
import { erc20Abi, midnightAbi, noteAbi, routerAbi } from '../lib/abis';
import { publicClient } from '../lib/client';
import { CHAIN, CONTRACTS, QUOTE_FRESHNESS_MS, type TradeMode } from '../lib/contracts';
import { friendlyError } from '../lib/errors';
import { checkTrade, EMPTY_BALANCES, getQuote, loadSnapshot, parseAmount, type Quote, type Snapshot } from '../lib/protocol';
import { buildTakerTraits } from '../lib/traits';

export type { TradeMode } from '../lib/contracts';

type Inputs = { mode: TradeMode; amount: string; collateralAmount: string; slippageBps: number };
type ContractCall = { address: Address; abi: Abi; functionName: string; args: readonly unknown[] };
export type CompletedTrade = { hash: Hex; mode: TradeMode; amountIn?: bigint; amountOut?: bigint };
const swapEvents = parseAbi([
  'event Swapped(bytes32 orderHash, address maker, address taker, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut)',
]);

export function useMoonglade({ mode, amount, collateralAmount, slippageBps }: Inputs) {
  const { address, chainId, isConnected } = useAccount();
  const { data: wallet } = useWalletClient();
  const { switchChainAsync } = useSwitchChain();
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<Hex>();
  const [completion, setCompletion] = useState<CompletedTrade>();
  const [completed, setCompleted] = useState<string[]>([]);
  const [now, setNow] = useState(Date.now());
  const lock = useRef(false);
  const context = `${address ?? ''}:${chainId ?? ''}:${mode}:${amount}:${collateralAmount}:${slippageBps}`;
  const latestContext = useRef(context);
  latestContext.current = context;
  const isWrongChain = isConnected && chainId !== CHAIN.id;

  useEffect(() => {
    setActionError(null);
    setStatus('');
    setTxHash(undefined);
    setCompletion(undefined);
    setCompleted([]);
  }, [context]);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 5000);
    return () => window.clearInterval(timer);
  }, []);

  const snapshotQuery = useQuery({
    queryKey: ['moonglade-state', address, chainId],
    queryFn: () => loadSnapshot(address),
    enabled: !busy,
    staleTime: 10_000,
    refetchInterval: 15_000,
    retry: 1,
  });
  const snapshot = snapshotQuery.data;
  const makerError = address && snapshot && isAddressEqual(address, snapshot.order.maker)
    ? 'This wallet operates the desk. Use a separate wallet to trade with it.' : null;
  let parsedAmount = 0n;
  let parsedCollateral = 0n;
  let inputError: string | null = null;
  try {
    parsedAmount = parseAmount(amount, 6);
    parsedCollateral = mode === 'borrow' ? parseAmount(collateralAmount, 18) : 0n;
  } catch (error) {
    inputError = friendlyError(error);
  }
  const quoteQuery = useQuery({
    queryKey: ['moonglade-quote', context, snapshot?.blockNumber.toString()],
    queryFn: () => getQuote(snapshot!, address!, mode, parsedAmount, slippageBps),
    enabled: !!snapshot && !!address && !isWrongChain && !busy && !inputError && !makerError && parsedAmount > 0n,
    staleTime: 10_000,
    retry: false,
  });
  const quote = quoteQuery.data;
  const stale = !!snapshot && now - snapshot.loadedAt > QUOTE_FRESHNESS_MS;
  const staleQuote = !!quote && now - quote.createdAt > QUOTE_FRESHNESS_MS;
  const tradeError = snapshot && quote ? checkTrade(snapshot, quote, mode, parsedCollateral) : null;
  const error = actionError || makerError || inputError || (snapshotQuery.error ? friendlyError(snapshotQuery.error) : null)
    || (quoteQuery.error ? friendlyError(quoteQuery.error) : null) || tradeError
    || (stale || staleQuote ? 'Market data is stale. Refresh before continuing.' : null);
  const balances = snapshot?.balances ?? EMPTY_BALANCES;
  const steps: Array<{ label: string; done: boolean }> = [];
  const addStep = (label: string, done: boolean) => steps.push({ label, done: done || (busy && completed.includes(label)) });
  if (snapshot && quote) {
    if (mode !== 'lend' && snapshot.hookAuthorized) addStep('Revoke blanket hook authority', false);
    if (mode === 'borrow') {
      if (parsedCollateral > 0n) {
        addStep('Approve WETH collateral', snapshot.wethAllowance >= parsedCollateral);
        addStep('Supply WETH collateral', false);
      }
      if (quote.borrowUnits > 0n) {
        addStep('Authorize shared ratifier', snapshot.ratifierAuthorized);
        addStep('Approve bounded note mint', snapshot.mintAllowance[0] === quote.borrowUnits && BigInt(snapshot.mintAllowance[1]) === quote.deadline);
      } else if (snapshot.mintAllowance[0] > 0n) addStep('Revoke unused mint consent', false);
    }
    if (mode === 'sell' && snapshot.mintAllowance[0] > 0n) addStep('Revoke unused mint consent', false);
    addStep(mode === 'lend' ? 'Approve USDC input' : 'Approve note input', (mode === 'lend' ? snapshot.usdcAllowance : snapshot.noteAllowance) >= quote.maximumInput);
    addStep(mode === 'lend' ? 'Lend USDC' : mode === 'borrow' ? 'Borrow USDC' : 'Sell notes', false);
  }
  const canSubmit = isConnected && !isWrongChain && !!wallet && !!snapshot && !!quote && !busy && !error && !quoteQuery.isFetching;

  const refresh = () => {
    setActionError(null);
    void snapshotQuery.refetch();
    if (snapshot && address && parsedAmount > 0n && !isWrongChain && !busy && !inputError) void quoteQuery.refetch();
  };

  async function execute(): Promise<void> {
    if (lock.current || !canSubmit || !wallet || !address || !snapshot || !quote) return;
    lock.current = true;
    setBusy(true);
    setActionError(null);
    setTxHash(undefined);
    setCompletion(undefined);
    setCompleted([]);
    const executionContext = context;
    const account = address;
    const approvedQuote = quote;
    const originalOrder = snapshot.order;
    const inputAmount = parsedAmount;
    const collateral = parsedCollateral;

    const assertWallet = async () => {
      if (latestContext.current !== executionContext) throw new Error('Wallet, chain, or trade inputs changed. Review a new quote before continuing.');
      const [connectedChain, accounts] = await Promise.all([wallet.getChainId(), wallet.getAddresses()]);
      if (connectedChain !== CHAIN.id || !accounts[0] || !isAddressEqual(accounts[0], account)) throw new Error('Wallet connection changed. Reconnect on Base and review a new quote.');
    };
    const send = async (label: string, call: ContractCall) => {
      await assertWallet();
      setStatus(`Checking: ${label}`);
      const { request } = await publicClient.simulateContract({ ...call, account });
      // Nested mint/settlement paths vary slightly as the next block changes pricing math.
      // A wallet that submits the RPC's exact estimate can otherwise run out of gas.
      const estimatedGas = await publicClient.estimateContractGas({ ...call, account });
      const gas = (estimatedGas * 130n + 99n) / 100n;
      await assertWallet();
      setStatus(`Confirm in wallet: ${label}`);
      const hash = await wallet.writeContract({ ...request, account, chain: CHAIN, gas });
      if (latestContext.current === executionContext) {
        setTxHash(hash);
        setStatus(`Waiting for confirmation: ${label}`);
      }
      const receipt = await publicClient.waitForTransactionReceipt({ hash, confirmations: 1 });
      if (receipt.status !== 'success') throw new Error(`${label} reverted. Refresh before retrying.`);
      await assertWallet();
      setCompleted((items) => [...items, label]);
      return receipt;
    };
    const currentSnapshot = async () => {
      await assertWallet();
      const current = await loadSnapshot(account);
      if (isAddressEqual(account, current.order.maker)) throw new Error('This wallet operates the desk. Use a separate wallet to trade with it.');
      if (current.order.data !== originalOrder.data || current.order.traits !== originalOrder.traits || !isAddressEqual(current.order.maker, originalOrder.maker)) throw new Error('The maker changed the strategy. Review a new quote.');
      return current;
    };
    const assertQuoteBounds = async (current: Snapshot, pendingCollateral: bigint) => {
      const latest = await getQuote(current, account, mode, inputAmount, slippageBps);
      if (mode === 'borrow' ? latest.amountIn > approvedQuote.maximumInput : latest.amountOut < approvedQuote.minimumOutput) throw new Error('The price moved beyond your slippage limit. Review a new quote.');
      let units = 0n;
      if (mode === 'borrow' && approvedQuote.maximumInput > current.balances.note) {
        units = await publicClient.readContract({ address: CONTRACTS.note, abi: noteAbi, functionName: 'previewMintUnits', args: [approvedQuote.maximumInput - current.balances.note], blockNumber: current.blockNumber });
      }
      if (units > approvedQuote.borrowUnits) throw new Error('Mint terms changed beyond your approved debt budget. Review a new quote.');
      const newDebt = units > current.credit ? units - current.credit : 0n;
      const guarded: Quote = { ...latest, maximumInput: approvedQuote.maximumInput, borrowUnits: units, projectedDebt: current.balances.debt + newDebt };
      const invalid = checkTrade(current, guarded, mode, pendingCollateral);
      if (invalid) throw new Error(invalid);
      if (current.timestamp >= approvedQuote.deadline) throw new Error('Your transaction deadline expired. Review a new quote.');
    };

    try {
      if (Date.now() - approvedQuote.createdAt > QUOTE_FRESHNESS_MS) throw new Error('The quote is stale. Refresh before proceeding.');
      let current = await currentSnapshot();
      await assertQuoteBounds(current, collateral);
      if (mode !== 'lend' && current.hookAuthorized) {
        await send('Revoke blanket hook authority', { address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'setIsAuthorized', args: [CONTRACTS.hook, false, account] });
        current = await currentSnapshot();
      }
      if (mode === 'borrow' && collateral > 0n) {
        if (current.wethAllowance < collateral) {
          await send('Approve WETH collateral', { address: CONTRACTS.weth, abi: erc20Abi, functionName: 'approve', args: [CONTRACTS.midnight, collateral] });
        }
        await send('Supply WETH collateral', { address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'supplyCollateral', args: [current.market, 0n, collateral, account] });
        current = await currentSnapshot();
      }
      if (mode === 'borrow' && approvedQuote.borrowUnits > 0n) {
        if (!current.ratifierAuthorized) {
          await send('Authorize shared ratifier', { address: CONTRACTS.midnight, abi: midnightAbi, functionName: 'setIsAuthorized', args: [CONTRACTS.ratifier, true, account] });
        }
        await send('Approve bounded note mint', { address: CONTRACTS.note, abi: noteAbi, functionName: 'approveMint', args: [CONTRACTS.hook, approvedQuote.borrowUnits, approvedQuote.deadline] });
      } else if (mode !== 'lend' && current.mintAllowance[0] > 0n) {
        await send('Revoke unused mint consent', { address: CONTRACTS.note, abi: noteAbi, functionName: 'approveMint', args: [CONTRACTS.hook, 0n, 0] });
      }
      const inputToken = mode === 'lend' ? CONTRACTS.usdc : CONTRACTS.note;
      const allowance = mode === 'lend' ? current.usdcAllowance : current.noteAllowance;
      if (allowance < approvedQuote.maximumInput) {
        await send(mode === 'lend' ? 'Approve USDC input' : 'Approve note input', { address: inputToken, abi: erc20Abi, functionName: 'approve', args: [CONTRACTS.router, approvedQuote.maximumInput] });
      }
      current = await currentSnapshot();
      await assertQuoteBounds(current, 0n);
      if (mode !== 'lend' && current.hookAuthorized) throw new Error('Blanket hook authority is still enabled. Revoke it before continuing.');
      if (mode === 'sell' && current.mintAllowance[0] > 0n) throw new Error('Mint consent is still enabled. Revoke it before selling owned notes.');
      const tokenOut = mode === 'lend' ? CONTRACTS.note : CONTRACTS.usdc;
      const exactIn = mode !== 'borrow';
      const threshold = exactIn ? approvedQuote.minimumOutput : approvedQuote.maximumInput;
      const takerData = buildTakerTraits(exactIn, threshold, approvedQuote.deadline);
      const receipt = await send(mode === 'lend' ? 'Lend USDC' : mode === 'borrow' ? 'Borrow USDC' : 'Sell notes', {
        address: CONTRACTS.router, abi: routerAbi, functionName: 'swap', args: [current.order, inputToken, tokenOut, inputAmount, takerData],
      });
      const confirmed: CompletedTrade = { hash: receipt.transactionHash, mode };
      for (const log of receipt.logs) {
        if (!isAddressEqual(log.address, CONTRACTS.router)) continue;
        try {
          const { args } = decodeEventLog({ abi: swapEvents, data: log.data, topics: log.topics });
          if (!isAddressEqual(args.taker, account) || !isAddressEqual(args.maker, current.order.maker)
            || !isAddressEqual(args.tokenIn, inputToken) || !isAddressEqual(args.tokenOut, tokenOut)) continue;
          confirmed.amountIn = args.amountIn;
          confirmed.amountOut = args.amountOut;
          break;
        } catch { /* Other router events do not describe this fill. */ }
      }
      setCompletion(confirmed);
      setStatus('Transaction confirmed. Balances are refreshing.');
      await snapshotQuery.refetch();
    } catch (failure) {
      if (latestContext.current === executionContext) {
        setActionError(friendlyError(failure));
        setStatus('Stopped. Confirmed preparation transactions remain on chain; refresh before retrying.');
      }
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }

  const actionLabel = !isConnected ? 'Connect wallet' : isWrongChain ? 'Switch to Base' : busy ? 'Transaction in progress'
    : steps.some((step, index) => !step.done && index < steps.length - 1) ? `Prepare & ${mode === 'lend' ? 'lend' : mode === 'borrow' ? 'borrow' : 'sell'}`
    : mode === 'lend' ? 'Lend USDC' : mode === 'borrow' ? 'Borrow USDC' : 'Sell notes';
  return {
    address, isConnected, isWrongChain, switchToBase: () => switchChainAsync({ chainId: CHAIN.id }),
    desk: snapshot?.desk, balances, quote, steps, actionLabel, canSubmit, busy,
    isLoading: snapshotQuery.isPending, isQuoting: quoteQuery.isFetching,
    status, error, txHash, execute, refresh, completion, dismissCompletion: () => setCompletion(undefined),
    risk: snapshot && quote ? {
      payoutPerShare: snapshot.payout, projectedDebt: quote.projectedDebt,
      capacity: (snapshot.balances.postedCollateral + parsedCollateral) * snapshot.oraclePrice / (10n ** 36n) * snapshot.lltv / (10n ** 18n),
    } : undefined,
  };
}
