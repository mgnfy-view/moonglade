// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin-contracts/utils/Strings.sol";

/// @title Moonglade demo output.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Deterministic, plain-text formatting shared by the fork demonstrations.
/// @dev Logs presentation data without changing chain state; amount display truncates below six decimals.
abstract contract DemoOutput {
    /// @notice Print a scene title after a blank line.
    /// @param _title Scene title shown in the console.
    function _heading(string memory _title) internal pure {
        console2.log("");
        console2.log(_title);
    }

    /// @notice Print one indented presentation line.
    /// @param _text Text to send to the Foundry console.
    function _line(string memory _text) internal pure {
        console2.log(string.concat("  ", _text));
    }

    /// @notice Print a check that the caller has already verified.
    /// @param _text Description of the completed check.
    function _check(string memory _text) internal pure {
        _line(string.concat("[OK] ", _text));
    }

    /// @notice Format a native token amount with grouped whole digits and six fractional digits.
    /// @dev Truncates smaller units without rounding.
    /// String-based placement also handles token decimal counts above uint256's power-of-ten range.
    /// @param _raw Native token amount to display.
    /// @param _decimals Number of decimal places used by the token.
    /// @param _symbol Optional token symbol appended after the number.
    /// @return Formatted amount with its optional token symbol.
    function _amount(uint256 _raw, uint8 _decimals, string memory _symbol) internal pure returns (string memory) {
        bytes memory digits = bytes(Strings.toString(_raw));
        uint256 wholeLength = digits.length > _decimals ? digits.length - _decimals : 0;
        bytes memory whole = new bytes(wholeLength == 0 ? 1 : wholeLength + (wholeLength - 1) / 3);
        if (wholeLength == 0) {
            whole[0] = "0";
        } else {
            uint256 cursor;
            for (uint256 i; i < wholeLength; ++i) {
                if (i != 0 && (wholeLength - i) % 3 == 0) whole[cursor++] = ",";
                whole[cursor++] = digits[i];
            }
        }

        bytes memory fraction = new bytes(6);
        for (uint256 i; i < fraction.length; ++i) {
            int256 source = int256(digits.length + i) - int256(uint256(_decimals));
            fraction[i] = source >= 0 && uint256(source) < digits.length ? digits[uint256(source)] : bytes1("0");
        }
        string memory number = string.concat(string(whole), ".", string(fraction));
        string memory amount = bytes(_symbol).length == 0 ? number : string.concat(number, " ", _symbol);

        return amount;
    }

    /// @notice Format a WAD rate as a percentage with two decimal places.
    /// @dev A fraction of 0.05e18 displays as 5.00%, rounded to the nearest basis point.
    /// @param _wad WAD rate to display.
    /// @return Percentage string, including the percent suffix.
    function _rate(uint256 _wad) internal pure returns (string memory) {
        uint256 basisPoints = _wad / 1e14;
        if (_wad % 1e14 >= 5e13) ++basisPoints;
        uint256 fraction = basisPoints % 100;
        string memory rate = string.concat(
            Strings.toString(basisPoints / 100), ".", fraction < 10 ? "0" : "", Strings.toString(fraction), "%"
        );

        return rate;
    }

    /// @notice Print a label and value in aligned presentation columns.
    /// @param _label Description shown before the value.
    /// @param _valueText Already formatted value to display.
    function _value(string memory _label, string memory _valueText) internal pure {
        uint256 length = bytes(_label).length;
        bytes memory padding = new bytes(length < 28 ? 28 - length : 2);
        for (uint256 i; i < padding.length; ++i) {
            padding[i] = " ";
        }
        _line(string.concat(_label, string(padding), _valueText));
    }
}
