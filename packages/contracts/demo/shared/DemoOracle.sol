// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IOracle } from "midnight/src/interfaces/IOracle.sol";

/// @title Moonglade demo collateral oracle.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Explicit demo fixture reporting $2,000 per WETH.
/// @dev Uses Midnight's oracle scale for 18-decimal WETH collateral and 6-decimal USDC debt; not a live feed.
contract DemoOracle is IOracle {
    /// @notice Return the fixed collateral valuation used by the fork scenes.
    /// @dev Pure fixture value; no external feed or freshness checks are used.
    /// @return Midnight-scaled USDC value per native WETH unit.
    function price() external pure returns (uint256) {
        uint256 oraclePrice = 2_000e24;

        return oraclePrice;
    }
}
