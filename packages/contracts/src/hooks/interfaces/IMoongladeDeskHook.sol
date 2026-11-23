// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity ^0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IAqua } from "aqua/src/interfaces/IAqua.sol";
import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";
import { IBuyCallback } from "midnight/src/interfaces/ICallbacks.sol";
import { IMakerHooks } from "swap-vm/src/interfaces/IMakerHooks.sol";
import { ISwapVM } from "swap-vm/src/interfaces/ISwapVM.sol";

import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

import { MoongladeRouter } from "src/routers/MoongladeRouter.sol";

/// @title Moonglade desk hook interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice On-demand inventory management for one maker's wallet and Midnight position.
/// @dev The maker registers and docks strategies directly on Aqua; the hook requires no standing deposits.
interface IMoongladeDeskHook is IMakerHooks, IBuyCallback {
    /// @notice Maker-approved bounds for borrowing, temporary funding, and collateral management.
    struct RiskConfig {
        /// @notice Maximum total maker debt; zero permits only mints covered by existing credit.
        uint256 maxDebt;
        /// @notice Maximum gross loan-token float pulled for one inventory mint.
        uint256 maxMintFront;
        /// @notice Maximum net loan-token settlement fee for one inventory burn.
        uint256 maxBurnCost;
        /// @notice Market collateral index supplied or released by this hook.
        uint256 collateralIndex;
        /// @notice Target fraction of aggregate borrowing capacity, strictly between zero and 1e18.
        uint256 targetUtilization;
        /// @notice Maximum total selected collateral the hook may post in Midnight.
        uint256 maxCollateral;
        /// @notice Whether note-in swaps attempt debt cancellation after receiving inventory.
        bool autoBurn;
    }

    /// @notice The maker approved a new strategy for direct registration on Aqua.
    /// @param _strategyHash Canonical order hash that Aqua must register for the maker.
    event StrategyConfigured(bytes32 indexed _strategyHash);
    /// @notice The maker disabled this hook's current strategy.
    /// @param _strategyHash Disabled strategy, which the maker docks directly on Aqua.
    event StrategyDeactivated(bytes32 indexed _strategyHash);
    /// @notice New inventory was minted by consuming maker credit and borrowing any remainder.
    /// @param _shares Shares issued into the maker's wallet.
    /// @param _units Gross credit units processed; new maker debt may be smaller or zero.
    event InventoryMinted(uint256 _shares, uint256 _units);
    /// @notice Wallet inventory was burned to cancel the maker's debt.
    /// @param _shares Wallet shares burned.
    /// @param _units Debt units cancelled.
    /// @param _cost Net loan-token settlement fee paid by the maker.
    event InventoryBurned(uint256 _shares, uint256 _units, uint256 _cost);
    /// @notice Selected collateral moved between the maker's wallet and Midnight.
    /// @param _supplied Whether collateral was supplied rather than released.
    /// @param _assets Collateral amount moved.
    event CollateralAdjusted(bool _supplied, uint256 _assets);

    /// @notice The maker address is zero.
    error MoongladeDeskHook__InvalidMaker();
    /// @notice The note or router address is zero.
    error MoongladeDeskHook__InvalidDependencies();
    /// @notice An operation restricted to the fixed maker was called by another address.
    error MoongladeDeskHook__Unauthorized();
    /// @notice The selected strategy does not match the hook's fixed note market.
    error MoongladeDeskHook__InvalidStrategy();
    /// @notice The previous strategy must be deactivated and docked before reconfiguration.
    error MoongladeDeskHook__StrategyActive();
    /// @notice The hook has no configured active strategy.
    error MoongladeDeskHook__StrategyInactive();
    /// @notice A hook caller, maker, strategy hash, token pair, or phase is invalid.
    error MoongladeDeskHook__InvalidHook();
    /// @notice The market has entered its final day before maturity.
    error MoongladeDeskHook__MarketClosed();
    /// @notice A proposed mint would exceed the maker's debt limit.
    error MoongladeDeskHook__DebtLimit();
    /// @notice Risk limits contain an invalid index, utilization, or position bound.
    error MoongladeDeskHook__InvalidRiskLimits();
    /// @notice Required selected collateral exceeds the maker's configured cap.
    error MoongladeDeskHook__CollateralLimit();
    /// @notice Selected collateral has a zero oracle price or borrowing factor.
    error MoongladeDeskHook__InvalidOraclePrice();
    /// @notice An exact token transfer or temporary-balance invariant failed.
    error MoongladeDeskHook__InvalidTransfer();
    /// @notice A mint requires more temporary loan tokens than permitted.
    error MoongladeDeskHook__FrontExceedsLimit();
    /// @notice A required mint has no positive native execution price.
    error MoongladeDeskHook__InvalidPrice();
    /// @notice A Midnight callback does not match the single active debt-cancellation context.
    error MoongladeDeskHook__InvalidCallback();

    // ===== Configuration =====

    function configure(IMoongladeSwap.Config calldata _config, RiskConfig calldata _risk) external returns (bytes32);
    function deactivate() external;

    // ===== Views =====

    function maker() external view returns (address);
    function note() external view returns (IMoongladeNote);
    function loanToken() external view returns (IERC20);
    function midnight() external view returns (IMidnight);
    function aqua() external view returns (IAqua);
    function router() external view returns (MoongladeRouter);
    function active() external view returns (bool);
    function strategyHash() external view returns (bytes32);
    function order() external view returns (ISwapVM.Order memory);
    function curveConfig() external view returns (IMoongladeSwap.Config memory);
    function riskConfig() external view returns (RiskConfig memory);
    function tokens() external view returns (address[] memory);
    function isRegistered() external view returns (bool);
    function requiredCollateral(uint256 _debt) external view returns (uint256);
    function currentRate() external view returns (uint256);
}
