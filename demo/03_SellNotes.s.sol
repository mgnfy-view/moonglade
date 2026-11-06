// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade note sale demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice mgNOTE -> USDC: exit an existing position and let the desk cancel debt automatically.
/// @dev Creates inventory through a real fork swap, then advances the local clock by seven days before exiting.
contract SellNotesDemo is DemoBase {
    /// @notice Pre-sale quantities used to verify the automatic cancellation and collateral release.
    struct ExitSnapshot {
        /// @notice Lender shares received from the initial USDC purchase.
        uint256 shares;
        /// @notice WAD annual curve rate immediately before the exit.
        uint256 rate;
        /// @notice Maker debt before incoming inventory is cancelled.
        uint256 debt;
        /// @notice Selected collateral posted before the exit.
        uint256 collateral;
    }

    /// @notice Sell the lender's notes after seven local days and verify debt and collateral reductions.
    /// @dev Uses the desk's automatic burn path; no borrower debt is created for the exiting lender.
    function run() external {
        _setup();
        ExitSnapshot memory before;
        before.shares = _swap(lender, true, 10_000 * UNIT);
        vm.warp(block.timestamp + 7 days);
        before.rate = hook.currentRate();
        before.debt = midnight.debt(marketId, maker);
        before.collateral = midnight.collateral(marketId, maker, 0);
        uint256 received = _swap(lender, false, before.shares);
        uint256 afterDebt = midnight.debt(marketId, maker);
        uint256 afterCollateral = midnight.collateral(marketId, maker, 0);
        _require(note.balanceOf(lender) == 0 && midnight.debt(marketId, lender) == 0, "Exit left a lender position");
        _require(afterDebt < before.debt && afterCollateral < before.collateral, "Automatic cancellation did not run");
        _heading("03 / Sell notes: mgNOTE -> USDC");
        _value("Position age", "7 days; funded by the preceding real fork swap");
        _value("Lender sells", _amount(before.shares, 6, "mgNOTE"));
        _value("Lender receives", _amount(received, 6, "USDC"));
        _value("Maker debt cancelled", _amount(before.debt - afterDebt, 6, "units"));
        _value("Collateral returned", _amount(before.collateral - afterCollateral, 18, "WETH"));
        _value("Remaining maker debt", _amount(afterDebt, 6, "units"));
        _rateChange(before.rate);
        _check("The reverse swap transfers real USDC to the lender");
        _check("Purchased notes cancel maker debt and release surplus collateral");
        _check("The lender exits without borrowing");
    }
}
