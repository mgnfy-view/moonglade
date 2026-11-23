// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade maker setup demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Register an Aqua strategy while keeping idle cash and collateral in the maker's wallet.
/// @dev Executes a fresh local fork setup with explicit funding, governance, and oracle fixtures.
contract MakerSetupDemo is DemoBase {
    /// @notice Configure the maker's Aqua strategy and verify its initial wallet and virtual balances.
    /// @dev Impersonates local fork actors and prints the resulting registration without broadcasting.
    function run() external {
        _setup();
        _heading("01 / Maker setup");
        (uint256 cash, uint256 notes) =
            AQUA.safeBalances(maker, address(router), hook.strategyHash(), address(USDC), address(note));
        _require(hook.active(), "Strategy is not active on Aqua");
        _require(cash == BUDGET && notes == VIRTUAL_NOTES, "Virtual budgets differ");
        _require(USDC.balanceOf(maker) == BUDGET && note.totalSupply() == 0, "Setup moved funds or minted notes");
        _require(midnight.collateral(marketId, maker, 0) == 0, "Setup posted collateral");
        _value("Maker", vm.toString(maker));
        _value("Strategy hash", vm.toString(hook.strategyHash()));
        _value("Maker cash", _amount(USDC.balanceOf(maker), 6, "USDC"));
        _value("Maker idle collateral", _amount(WETH.balanceOf(maker), 18, "WETH"));
        _value("Virtual cash budget", _amount(cash, 6, "USDC"));
        _value("Virtual note budget", _amount(notes, 6, "mgNOTE"));
        _value("Starting annual rate", _rate(hook.currentRate()));
        _value("Market maturity", string.concat(vm.toString(market.maturity), " / 180 days from fork"));
        _check("Aqua registration is active; all idle funds remain with the maker");
        _check("No notes or maker debt exist before the first fill");
    }
}
