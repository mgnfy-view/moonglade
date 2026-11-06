// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DemoBase } from "demo/shared/DemoBase.sol";

/// @title Moonglade maturity demo.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Repay the maker's debt at maturity, redeem the lender's shares, and retire the strategy.
/// @dev Advances time only on the fork; repayment uses maker cash and redemption requires Midnight liquidity.
contract MaturityDemo is DemoBase {
    /// @notice Fund a lender position, repay its maker debt at maturity, and redeem shares for actual USDC.
    /// @dev Verifies share removal, collateral return, debt cancellation, and Aqua strategy deactivation.
    function run() external {
        _setup();
        uint256 openingCash = 10_000 * UNIT;
        (uint256 shares, SwapFees memory openingFees) = _swap(hook, lender, true, openingCash);
        vm.warp(market.maturity);
        uint256 debt = midnight.debt(marketId, maker);
        uint256 collateral = midnight.collateral(marketId, maker, 0);
        vm.startPrank(maker);
        hook.deactivate();
        AQUA.dock(address(router), hook.strategyHash(), hook.tokens());
        USDC.approve(address(midnight), debt);
        midnight.repay(market, debt, maker, address(0), "");
        midnight.withdrawCollateral(market, 0, collateral, maker, maker);
        vm.stopPrank();
        uint256 beforeCash = USDC.balanceOf(lender);
        vm.prank(lender);
        uint256 redeemed = note.redeem(shares, lender);
        _require(USDC.balanceOf(lender) == beforeCash + redeemed && note.balanceOf(lender) == 0, "Redemption mismatch");
        _require(
            midnight.debt(marketId, maker) == 0 && midnight.collateral(marketId, maker, 0) == 0, "Maker not settled"
        );
        _require(!hook.active() && !hook.isRegistered() && redeemed > openingCash, "Maturity flow incomplete");
        _heading("05 / Maturity and redemption");
        _value("Clock advanced", "180 days to maturity (fork-only time travel)");
        _value("Original lender payment", _amount(openingCash, 6, "USDC"));
        _showSwapFees("Opening swap fee", openingFees);
        _value("Shares redeemed", _amount(shares, 6, "mgNOTE"));
        _value("Lender receives", _amount(redeemed, 6, "USDC"));
        _value("Lender gain", _amount(redeemed - openingCash, 6, "USDC"));
        _value("Maker repayment", _amount(debt, 6, "USDC"));
        _value("Collateral returned", _amount(collateral, 18, "WETH"));
        _check("Actual repayment funded the lender's USDC redemption");
        _check("Maker debt cleared, collateral returned, and Aqua strategy docked");
    }
}
