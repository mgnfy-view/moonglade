// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Math } from "@openzeppelin-contracts/utils/math/Math.sol";

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade lending demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice USDC -> mgNOTE: a lender purchases credit shares, triggering just-in-time maker inventory.
/// @dev Uses actual fork token transfers with explicit fixture funding, collateral valuation, and market policy.
contract LendDemo is DemoBase {
    /// @notice Spend 10,000 USDC for notes and verify collateralized maker inventory and lender balances.
    /// @dev The quote binds minimum output; loan-token differences include the native settlement fee.
    function run() external {
        _setup();
        uint256 beforeRate = hook.currentRate();
        uint256 beforeLenderCash = USDC.balanceOf(lender);
        uint256 cash = 10_000 * UNIT;
        uint256 received = _swap(lender, true, cash);
        uint256 debt = midnight.debt(marketId, maker);
        uint256 collateral = midnight.collateral(marketId, maker, 0);
        _require(beforeLenderCash - USDC.balanceOf(lender) == cash, "Incorrect lender payment");
        _require(debt > 0 && collateral > 0, "JIT maker inventory was not collateralized");
        _require(midnight.debt(marketId, lender) == 0, "Lending created lender debt");
        _heading("02 / Lend: USDC -> mgNOTE");
        _value("Lender pays", _amount(cash, 6, "USDC"));
        _value("Lender receives", _amount(received, 6, "mgNOTE"));
        _value("Net face value", _amount(Math.mulDiv(received, note.payoutPerShare(), WAD), 6, "USDC"));
        _value("Maker debt created", _amount(debt, 6, "units"));
        _value("Maker collateral posted", _amount(collateral, 18, "WETH"));
        _value("Native settlement fee", _amount(BUDGET + cash - USDC.balanceOf(maker), 6, "USDC"));
        _value("Maker cash after fill", _amount(USDC.balanceOf(maker), 6, "USDC"));
        _rateChange(beforeRate);
        _check("Executed transfers equal the quote, with a minimum-output bound");
        _check("Inventory minted on demand; unused mint float returned to the maker");
        _check("The lender holds mgNOTE and has no borrower debt");
    }
}
