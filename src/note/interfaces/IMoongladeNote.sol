// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IMidnight, Market, Offer } from "midnight/src/interfaces/IMidnight.sol";

/// @title Moonglade Note Interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Integration surface for ERC-20 shares of a single Midnight credit position.
/// @dev Typed getters match the public immutable variables in the note implementation.
interface IMoongladeNote is IERC20Metadata {
    /// @notice Borrower-set debt-unit budget for scoped share-targeted mints to the borrower only.
    struct BorrowAllowance {
        /// @notice Debt units still available to the spender across future originations.
        uint128 remainingUnits;
        /// @notice Latest timestamp at which the allowance may be consumed.
        uint40 deadline;
    }

    /// @notice A borrower replaced or revoked a spender's standing debt-unit allowance.
    /// @param _borrower Wallet whose new debt may be originated.
    /// @param _spender Delegate authorized to fund native issuance with every issued share sent to the borrower.
    /// @param _remainingUnits New debt-unit budget; zero revokes the delegation.
    /// @param _deadline Latest timestamp at which the new budget may be consumed.
    event BorrowApproval(
        address indexed _borrower, address indexed _spender, uint128 _remainingUnits, uint40 _deadline
    );
    /// @notice Shares issued against a borrower's newly created net credit.
    /// @param _borrower Wallet whose Midnight debt increased.
    /// @param _receiver Recipient of issued shares.
    /// @param _units Gross debt units borrowed.
    /// @param _shares Receiver shares issued.
    /// @param _front Gross cash float transferred for settlement.
    event Minted(address indexed _borrower, address indexed _receiver, uint256 _units, uint256 _shares, uint256 _front);
    /// @notice Shares burned to cancel the borrower's existing debt.
    /// @param _borrower Wallet whose Midnight debt decreased.
    /// @param _shares Shares burned.
    /// @param _units Gross debt units cancelled.
    /// @param _cost Actual net settlement fee.
    event Burned(address indexed _borrower, uint256 _shares, uint256 _units, uint256 _cost);
    /// @notice Shares issued against net credit bought from an external offer.
    /// @param _caller Caller funding the purchase.
    /// @param _receiver Recipient of issued shares.
    /// @param _units Gross credit units bought.
    /// @param _shares Receiver shares issued.
    /// @param _assets Loan tokens paid to settle the purchase.
    event Wrapped(address indexed _caller, address indexed _receiver, uint256 _units, uint256 _shares, uint256 _assets);
    /// @notice Shares burned to sell gross credit to an external offer.
    /// @param _caller Owner of burned shares.
    /// @param _receiver Recipient of loan tokens.
    /// @param _shares Shares burned.
    /// @param _units Gross credit units sold.
    /// @param _assets Loan tokens delivered to the receiver.
    event Unwrapped(
        address indexed _caller, address indexed _receiver, uint256 _shares, uint256 _units, uint256 _assets
    );
    /// @notice Matured shares redeemed against repaid credit.
    /// @param _caller Owner of burned shares.
    /// @param _receiver Recipient of withdrawn loan tokens.
    /// @param _shares Shares burned.
    /// @param _assets Loan tokens withdrawn.
    event Redeemed(address indexed _caller, address indexed _receiver, uint256 _shares, uint256 _assets);

    /// @notice Debt units are zero or exceed Midnight's uint128 position limit.
    error MoongladeNote__InvalidUnits();
    /// @notice New credit cannot be minted after market maturity.
    error MoongladeNote__MarketMatured();
    /// @notice The borrower already has credit in the market.
    error MoongladeNote__ExistingCredit();
    /// @notice Gross settlement float exceeds the caller's limit.
    error MoongladeNote__FrontExceedsLimit();
    /// @notice Net settlement fee exceeds the caller's limit.
    error MoongladeNote__CostExceedsLimit();
    /// @notice Shares are zero or issuance rounds to zero after the initial reserve.
    error MoongladeNote__ZeroShares();
    /// @notice Existing supply has no backing or the continuous fee consumes all new credit.
    error MoongladeNote__ZeroBacking();
    /// @notice Loan-token balances do not match the expected settlement transfers.
    error MoongladeNote__InvalidLoanTokenTransfer();
    /// @notice Actual settlement differs from the quoted amount or final balance.
    error MoongladeNote__QuoteChanged();
    /// @notice External offer direction, ratifier, or market is invalid.
    error MoongladeNote__InvalidOffer();
    /// @notice Redemption requires market maturity.
    error MoongladeNote__MarketNotMatured();
    /// @notice Share-targeted issuance requires more debt units than authorized.
    error MoongladeNote__UnitsExceedLimit();
    /// @notice Share-targeted issuance produced fewer shares than requested.
    error MoongladeNote__InsufficientIssuedShares();
    /// @notice A delegated debt operation specified the zero address as borrower.
    error MoongladeNote__InvalidBorrower();
    /// @notice The caller is not the borrower and has no borrower authorization on Midnight.
    /// @param _borrower Wallet whose debt operation was requested.
    /// @param _caller Caller requiring explicit Midnight authorization.
    error MoongladeNote__UnauthorizedBorrower(address _borrower, address _caller);
    /// @notice A borrow allowance specified the zero address as spender.
    error MoongladeNote__InvalidBorrowSpender();
    /// @notice The borrower-set standing allowance or its approval deadline has expired.
    error MoongladeNote__BorrowExpired();
    /// @notice The requested debt increase exceeds the borrower's remaining delegated units.
    error MoongladeNote__BorrowAllowanceExceeded();
    /// @notice A scoped borrow delegate attempted to mint shares to someone other than the borrower.
    /// @param _borrower Wallet whose debt would increase and which must receive all issued shares.
    /// @param _receiver Requested share recipient.
    error MoongladeNote__InvalidBorrowReceiver(address _borrower, address _receiver);

    // ==================== Configuration ====================

    function approveBorrow(address _spender, uint128 _units, uint40 _deadline) external;

    // ==================== User actions ====================

    function mintForSharesOnBehalf(
        uint256 _shares,
        uint256 _maxUnits,
        uint256 _maxFront,
        address _borrower,
        address _receiver,
        uint256 _tick
    ) external returns (uint256, uint256);
    function burn(uint256 _shares, uint256 _maxCost, address _borrower, uint256 _tick)
        external
        returns (uint256, uint256);
    function wrapFromOffer(Offer calldata _offer, bytes calldata _ratifierData, uint256 _units, address _receiver)
        external
        returns (uint256);
    function unwrapToOffer(uint256 _shares, Offer calldata _offer, bytes calldata _ratifierData, address _receiver)
        external
        returns (uint256);
    function redeem(uint256 _shares, address _receiver) external returns (uint256);

    // ==================== Views ====================

    function MINIMUM_SHARES() external view returns (uint256);
    function DEAD_SHARES() external view returns (address);
    function midnight() external view returns (IMidnight);
    function loanToken() external view returns (IERC20);
    function ratifier() external view returns (address);
    function activeOfferHash() external view returns (bytes32);
    function marketId() external view returns (bytes32);
    function maturity() external view returns (uint256);
    function borrowAllowances(address _borrower, address _spender) external view returns (uint128, uint40);
    function market() external view returns (Market memory);
    function payoutPerShare() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function previewMintUnits(uint256 _shares) external view returns (uint256);
    function previewBurn(uint256 _shares) external view returns (uint256, uint256);
}
