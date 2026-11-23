// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IMidnight, Market } from "midnight/src/interfaces/IMidnight.sol";

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { MoongladeNoteFactory } from "src/note/MoongladeNoteFactory.sol";

/// @title Moonglade protocol deployment.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Deploy the protocol and an unconfigured maker desk for an existing Midnight market.
/// @dev Uses existing Aqua, Midnight, and wrapped-native contracts. Foundry simulates unless --broadcast is supplied;
/// signing uses CLI wallet options, and the script reads only public configuration.
contract DeployProtocol is Script {
    /// @notice Public signer, network, and dependency inputs.
    struct Config {
        /// @notice Chain the operator intends to deploy on.
        uint256 chainId;
        /// @notice Public address signing deployment transactions through the Foundry CLI.
        address deployer;
        /// @notice Wallet that will own the desk and separately approve its operations.
        address maker;
        /// @notice Existing Midnight deployment containing the selected market.
        IMidnight midnight;
        /// @notice Identifier of an existing, ungated market that has not matured.
        bytes32 marketId;
        /// @notice Existing Aqua shared-liquidity registry.
        address aqua;
        /// @notice Existing wrapped-native token used by SwapVM.
        address weth;
    }

    /// @notice Addresses produced by a successful deployment simulation or broadcast.
    struct Deployment {
        /// @notice Permissionless market-note registry.
        address factory;
        /// @notice Ratifier created automatically by the factory.
        address ratifier;
        /// @notice Registered ERC-20 share wrapper for the selected market.
        address note;
        /// @notice YieldSpace implementation with maker-configurable pricing fees.
        address curve;
        /// @notice SwapVM router extended with the Moonglade opcode.
        address router;
        /// @notice Desk bound to the maker, deployed without approvals or an active strategy.
        address hook;
    }

    /// @notice The connected chain differs from the configured deployment target.
    /// @param _expected Configured chain identifier.
    /// @param _actual Connected chain identifier.
    error DeployProtocol__WrongChain(uint256 _expected, uint256 _actual);
    /// @notice The deployer or maker is the zero address.
    error DeployProtocol__InvalidSigner();
    /// @notice An external dependency has no deployed bytecode on the connected chain.
    /// @param _dependency Invalid dependency address.
    error DeployProtocol__InvalidDependency(address _dependency);
    /// @notice The market is gated, matured, or bound to a different chain or Midnight instance.
    error DeployProtocol__InvalidMarket();
    /// @notice Creation from a compiled artifact failed.
    /// @param _artifact Artifact whose creation failed.
    error DeployProtocol__DeploymentFailed(string _artifact);

    /// @notice Deploy the factory, note, curve, router, and maker desk, then print their addresses.
    /// @dev Validates public dependencies and the existing market before starting the deployment transaction sequence.
    /// This step grants no authority over the maker's wallet or Midnight position and transfers no maker tokens.
    /// @return Addresses to review and supply to the separate maker configuration script.
    function run() external returns (Deployment memory) {
        Config memory config = _loadConfig();
        if (block.chainid != config.chainId) revert DeployProtocol__WrongChain(config.chainId, block.chainid);
        if (config.deployer == address(0) || config.maker == address(0)) revert DeployProtocol__InvalidSigner();
        _checkContract(address(config.midnight));
        _checkContract(config.aqua);
        _checkContract(config.weth);
        Market memory market = config.midnight.toMarket(config.marketId);
        if (
            market.chainId != block.chainid || market.midnight != address(config.midnight)
                || market.enterGate != address(0) || market.liquidatorGate != address(0)
                || market.maturity <= block.timestamp
        ) revert DeployProtocol__InvalidMarket();

        Deployment memory deployment;
        vm.startBroadcast(config.deployer);
        MoongladeNoteFactory factory = new MoongladeNoteFactory(config.midnight);
        deployment.factory = address(factory);
        deployment.ratifier = address(factory.ratifier());
        deployment.note = factory.create(market);
        deployment.curve = _deploy("YieldSpaceCurve.sol:YieldSpaceCurve", "");
        deployment.router = _deploy("MoongladeRouter.sol:MoongladeRouter", abi.encode(config.aqua, config.weth));
        deployment.hook = _deploy(
            "MoongladeDeskHook.sol:MoongladeDeskHook", abi.encode(config.maker, deployment.note, deployment.router)
        );
        vm.stopBroadcast();

        console2.log("Chain", block.chainid);
        console2.log("Deployer", config.deployer);
        console2.log("Maker", config.maker);
        console2.log("Aqua", config.aqua);
        console2.log("Midnight", address(config.midnight));
        console2.log("MoongladeNoteFactory", deployment.factory);
        console2.log("MoongladeNoteRatifier", deployment.ratifier);
        console2.log("MoongladeNote", deployment.note);
        console2.log("YieldSpaceCurve", deployment.curve);
        console2.log("MoongladeRouter", deployment.router);
        console2.log("MoongladeDeskHook", deployment.hook);

        return deployment;
    }

    /// @notice Require deployed bytecode for an external dependency.
    /// @param _dependency Existing protocol or token contract.
    function _checkContract(address _dependency) private view {
        if (_dependency.code.length == 0) revert DeployProtocol__InvalidDependency(_dependency);
    }

    /// @notice Create a contract using its compiled artifact and constructor arguments.
    /// @dev Artifact loading keeps the exact 0.8.30 SwapVM graph separate from this exact 0.8.34 factory graph.
    /// CREATE is recorded by the surrounding Foundry broadcast context; assembly is needed to deploy bytecode.
    /// @param _artifact Compiled contract identifier.
    /// @param _args ABI-encoded constructor arguments.
    /// @return Newly created contract.
    function _deploy(string memory _artifact, bytes memory _args) private returns (address) {
        bytes memory initCode = bytes.concat(vm.getCode(_artifact), _args);
        address deployed;
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        if (deployed == address(0)) revert DeployProtocol__DeploymentFailed(_artifact);

        return deployed;
    }

    /// @notice Load public deployment settings documented in .env.example.
    /// @return Deployment inputs; no private key is read by this script.
    function _loadConfig() private view returns (Config memory) {
        uint256 defaultChainId = 8453;
        Config memory config = Config({
            chainId: vm.envOr("DEPLOY_CHAIN_ID", defaultChainId),
            deployer: vm.envAddress("DEPLOYER_ADDRESS"),
            maker: vm.envAddress("MAKER_ADDRESS"),
            midnight: IMidnight(vm.envAddress("MIDNIGHT_ADDRESS")),
            marketId: vm.envBytes32("MARKET_ID"),
            aqua: vm.envAddress("AQUA_ADDRESS"),
            weth: vm.envAddress("WETH_ADDRESS")
        });

        return config;
    }
}
