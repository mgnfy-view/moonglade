// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Maker configuration script interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Compiler-compatible entry point and preflight failures for configuring an existing maker desk.
/// @dev Contains no concrete protocol imports so deployment checks can use either compiler graph.
interface IConfigureMaker {
    /// @notice The public maker input differs from the hook's fixed maker.
    /// @param _expected Maker fixed in the existing hook.
    /// @param _actual Maker supplied through the environment.
    error ConfigureMaker__WrongMaker(address _expected, address _actual);
    /// @notice The connected chain differs from the requested deployment chain.
    /// @param _expected Chain selected through the environment.
    /// @param _actual Connected chain.
    error ConfigureMaker__WrongChain(uint256 _expected, uint256 _actual);
    /// @notice Dependencies, market state, risk limits, or virtual reserves cannot configure a new desk strategy.
    error ConfigureMaker__InvalidConfiguration();

    function run() external returns (bytes32);
}
