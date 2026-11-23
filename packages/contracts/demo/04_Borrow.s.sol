// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade borrowing demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice A borrower with zero mgNOTE receives USDC through scoped mint consent and one swap.
/// @dev Uses explicit fork collateral and bounded gross-unit authorization; only the borrower acquires debt.
contract BorrowDemo is DemoBase {
    /// @notice Collateralize the borrower, authorize its exact mint budget, and swap the minted notes for USDC.
    /// @dev Verifies that consent is consumed exactly, borrower collateral is preserved, and no notes remain.
    function run() external {
        _setup();
        uint256 beforeRate = hook.currentRate();
        uint256 shares = 10_000 * UNIT;
        uint256 authorizedUnits = _prepareBorrower(shares);
        _require(note.balanceOf(borrower) == 0 && USDC.balanceOf(borrower) == 0, "Borrower did not start empty");
        (uint256 received, SwapFees memory fees) = _swap(hook, borrower, false, shares);
        (uint128 remaining,) = note.borrowAllowances(borrower, address(hook));
        uint256 debt = midnight.debt(marketId, borrower);
        _require(debt == authorizedUnits && remaining == 0, "Scoped consent was not consumed exactly");
        _require(note.balanceOf(borrower) == 0 && midnight.debt(marketId, maker) == 0, "Wrong inventory or debtor");
        _require(midnight.collateral(marketId, borrower, 0) == 100 ether, "Borrower collateral changed during swap");
        _heading("04 / Borrow USDC in one swap");
        _value("Starting mgNOTE", "0.000000 mgNOTE");
        _value("Collateral supplied", _amount(100 ether, 18, "WETH"));
        _value("Scoped mint budget", _amount(authorizedUnits, 6, "units"));
        _value("Borrower receives", _amount(received, 6, "USDC"));
        _showSwapFees("Maker trading fee", fees);
        _value("Borrower debt", _amount(debt, 6, "units"));
        _value("Unused mint consent", _amount(remaining, 6, "units"));
        _value("Maker note inventory", _amount(note.balanceOf(maker), 6, "mgNOTE"));
        _rateChange(beforeRate);
        _check("The hook mints the borrower's shortfall and the router sells it for USDC");
        _check("Debt belongs to the borrower; no mgNOTE remains in their wallet");
        _check("Only the exact approved gross-unit budget was consumed");
    }
}
