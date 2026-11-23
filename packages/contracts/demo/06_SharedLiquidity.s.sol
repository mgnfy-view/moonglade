// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMoongladeDeskHook } from "src/hooks/interfaces/IMoongladeDeskHook.sol";

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade shared liquidity demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Two independently registered Aqua strategies use the same maker wallet without duplicate deposits.
/// @dev Virtual allocations are independent budgets backed by one wallet; registration does not duplicate assets.
contract SharedLiquidityDemo is DemoBase {
    /// @notice Register a second desk and fill both strategies using the same maker wallet.
    /// @dev Verifies separate Aqua accounting and the absence of retained temporary hook cash.
    function run() external {
        _setup();
        IMoongladeDeskHook second = _newDesk();
        _register(second);
        _require(USDC.balanceOf(maker) == BUDGET, "Registering another strategy moved cash");
        uint256 cashPerFill = 10_000 * UNIT;
        (uint256 firstOutput, SwapFees memory firstFees) = _swap(hook, lender, true, cashPerFill);
        (uint256 secondOutput, SwapFees memory secondFees) = _swap(second, lender, true, cashPerFill);
        (uint256 firstCash,) =
            AQUA.safeBalances(maker, address(router), hook.strategyHash(), address(USDC), address(note));
        (uint256 secondCash,) =
            AQUA.safeBalances(maker, address(router), second.strategyHash(), address(USDC), address(note));
        _require(
            firstCash == BUDGET + cashPerFill && secondCash == BUDGET + cashPerFill, "Registry accounting mismatch"
        );
        _require(USDC.balanceOf(address(second)) == 0, "Second hook retained cash");
        _heading("06 / Aqua shared liquidity");
        _value("Opening maker cash", _amount(BUDGET, 6, "USDC"));
        _value("Registered strategies", "2 / same maker, same USDC wallet");
        _value("Initial combined budgets", _amount(2 * BUDGET, 6, "virtual USDC"));
        _value("First fill receives", _amount(firstOutput, 6, "mgNOTE"));
        _showSwapFees("First swap fee", firstFees);
        _value("Second fill receives", _amount(secondOutput, 6, "mgNOTE"));
        _showSwapFees("Second swap fee", secondFees);
        _value("Final maker wallet", _amount(USDC.balanceOf(maker), 6, "USDC"));
        _value("First virtual cash", _amount(firstCash, 6, "USDC"));
        _value("Second virtual cash", _amount(secondCash, 6, "USDC"));
        _check("Both strategies execute through official Aqua against one maker wallet");
        _check("Registration allocates virtual budgets without duplicating deposits");
    }
}
