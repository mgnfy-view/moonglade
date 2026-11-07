import { BaseError, ContractFunctionRevertedError } from 'viem';

const remedies: Record<string, string> = {
  MoongladeRouter__MarketClosed: 'Trading closes one day before maturity. This market is closed.',
  MoongladeDeskHook__MarketClosed: 'This market has closed for new trades.',
  MoongladeDeskHook__StrategyInactive: 'The maker desk is inactive. Refresh before trying again.',
  MoongladeDeskHook__InvalidHook: 'The maker strategy changed. Refresh your quote.',
  MoongladeRouter__InsufficientLiquidity: 'The desk has insufficient liquidity. Try a smaller amount.',
  YieldSpaceCurve__InsufficientLiquidity: 'The desk has insufficient liquidity. Try a smaller amount.',
  YieldSpaceCurve__InsufficientPrecision: 'This amount is too small for the curve. Increase the amount.',
  YieldSpaceCurve__RateFloor: 'This trade reaches the maker’s rate floor. Try a smaller amount.',
  MoongladeDeskHook__FrontExceedsLimit: 'The maker cannot fund this mint. Try a smaller borrow.',
  MoongladeDeskHook__DebtLimit: 'The maker has reached its debt limit. Try a smaller trade.',
  MoongladeNote__BorrowExpired: 'Your scoped borrowing consent expired. Refresh and approve it again.',
  MoongladeNote__BorrowAllowanceExceeded: 'The mint exceeds your scoped consent. Refresh your quote.',
  MoongladeNote__UnitsExceedLimit: 'Mint terms moved beyond your limit. Refresh your quote.',
  UnhealthyBorrower: 'The resulting debt exceeds collateral capacity. Add WETH or borrow less.',
  Unauthorized: 'A required scoped permission is missing. Refresh the preparation steps.',
  ERC20InsufficientBalance: 'The wallet or maker has insufficient tokens. Refresh balances.',
  ERC20InsufficientAllowance: 'The token approval is insufficient. Refresh the approval step.',
  TakerTraitsInsufficientMinOutputAmount: 'The price moved beyond your minimum output. Request a new quote.',
  TakerTraitsExceedingMaxInputAmount: 'The price moved beyond your maximum note input. Request a new quote.',
  TakerTraitsDeadlineExpired: 'The quote expired. Request a new quote.',
};

export function friendlyError(error: unknown): string {
  if (error instanceof BaseError) {
    const reverted = error.walk((cause) => cause instanceof ContractFunctionRevertedError);
    if (reverted instanceof ContractFunctionRevertedError && reverted.data?.errorName) {
      const name = reverted.data.errorName;
      return remedies[name] || `The contract rejected this action (${name}). Refresh the quote and limits.`;
    }
    if (/rejected|denied/i.test(error.shortMessage)) return 'Wallet request cancelled. No further transaction was sent.';
    return error.shortMessage;
  }
  return error instanceof Error ? error.message : 'The request failed. Refresh and try again.';
}
