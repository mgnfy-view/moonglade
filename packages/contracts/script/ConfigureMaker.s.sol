// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IAqua } from "aqua/src/interfaces/IAqua.sol";
import { IMidnight, Market } from "midnight/src/interfaces/IMidnight.sol";

import { SafeERC20 } from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin-contracts/utils/math/SafeCast.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { IConfigureMaker } from "script/interfaces/IConfigureMaker.sol";
import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";
import { IMoongladeDeskHook } from "src/hooks/interfaces/IMoongladeDeskHook.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";
import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";

/// @title Maker configuration script.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Authorize an existing maker desk and register its wallet-funded strategy directly on Aqua.
/// @dev Reads public configuration only. The maker supplies signing credentials through Foundry's signer options.
contract ConfigureMaker is Script, IConfigureMaker {
    /// @notice Scale used by payout factors and target utilization.
    uint256 private constant WAD = 1e18;

    /// @notice Public signer, pricing settings, virtual reserves, risk limits, and allowance caps.
    struct Config {
        /// @notice Intended chain identifier.
        uint256 chainId;
        /// @notice Public wallet address that owns the deployed desk.
        address maker;
        /// @notice Existing, inactive desk to configure.
        IMoongladeDeskHook hook;
        /// @notice Pricing model and maker-selected opaque parameters.
        IMoongladeSwap.Config curve;
        /// @notice Maker's debt, settlement, collateral, and utilization limits.
        IMoongladeDeskHook.RiskConfig risk;
        /// @notice Initial loan-token budget registered on Aqua, without depositing funds.
        uint256 virtualLoanBalance;
        /// @notice Initial mgNOTE share budget registered on Aqua, without minting notes.
        uint256 virtualNoteBalance;
        /// @notice Maximum loan-token allowance granted to Aqua.
        uint256 aquaLoanAllowance;
        /// @notice Maximum mgNOTE allowance granted to Aqua.
        uint256 aquaNoteAllowance;
        /// @notice Maximum loan-token allowance granted to the hook.
        uint256 hookLoanAllowance;
        /// @notice Maximum mgNOTE allowance granted to the hook.
        uint256 hookNoteAllowance;
        /// @notice Maximum selected-collateral allowance granted to the hook.
        uint256 hookCollateralAllowance;
    }

    /// @notice Validate the public inputs, then grant maker permissions, configure the desk, and register its order.
    /// @dev All preflight calls happen before broadcasting. Omitted allowance caps default to uint256.max.
    /// These are separate maker transactions; their public simulation must be reviewed before broadcasting.
    /// Aqua keys the strategy by its caller, so ship is called directly by the maker rather than by the hook.
    /// @return Canonical hash of the registered maker strategy.
    function run() external returns (bytes32) {
        Config memory config = _loadConfig();
        if (block.chainid != config.chainId) revert ConfigureMaker__WrongChain(config.chainId, block.chainid);
        if (address(config.hook).code.length == 0) revert ConfigureMaker__InvalidConfiguration();
        address expectedMaker = config.hook.maker();
        if (config.maker != expectedMaker) revert ConfigureMaker__WrongMaker(expectedMaker, config.maker);
        if (config.maker == address(0) || config.hook.active() || config.hook.isRegistered()) {
            revert ConfigureMaker__InvalidConfiguration();
        }

        IMoongladeNote note = config.hook.note();
        IMidnight midnight = config.hook.midnight();
        IERC20 loan = config.hook.loanToken();
        IAqua aqua = config.hook.aqua();
        address router = address(config.hook.router());
        address hook = address(config.hook);
        address ratifier = note.ratifier();
        Market memory market = note.market();
        config.curve.note = address(note);
        if (
            market.chainId != block.chainid || market.midnight != address(midnight) || market.loanToken != address(loan)
                || address(midnight).code.length == 0 || address(aqua).code.length == 0 || router.code.length == 0
                || address(loan).code.length == 0 || ratifier.code.length == 0
        ) revert ConfigureMaker__InvalidConfiguration();
        _validateConfiguration(config, market);
        IERC20 collateral = IERC20(market.collateralParams[config.risk.collateralIndex].token);
        if (address(collateral).code.length == 0) revert ConfigureMaker__InvalidConfiguration();
        address[] memory tokens = config.hook.tokens();
        if (tokens.length != 2 || tokens[0] != address(loan) || tokens[1] != address(note)) {
            revert ConfigureMaker__InvalidConfiguration();
        }
        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = config.virtualLoanBalance;
        amounts[1] = config.virtualNoteBalance;

        vm.startBroadcast(config.maker);
        midnight.setIsAuthorized(hook, true, config.maker);
        midnight.setIsAuthorized(ratifier, true, config.maker);
        _approve(loan, config.maker, address(aqua), config.aquaLoanAllowance);
        _approve(IERC20(address(note)), config.maker, address(aqua), config.aquaNoteAllowance);
        _approve(loan, config.maker, hook, config.hookLoanAllowance);
        _approve(IERC20(address(note)), config.maker, hook, config.hookNoteAllowance);
        _approve(collateral, config.maker, hook, config.hookCollateralAllowance);
        config.hook.configure(config.curve, config.risk);
        bytes32 strategyHash = aqua.ship(router, abi.encode(config.hook.order()), tokens, amounts);
        vm.stopBroadcast();

        console2.log("Maker", config.maker);
        console2.log("Desk hook", hook);
        console2.log("Pricing curve", config.curve.curve);
        console2.log("Strategy hash");
        console2.logBytes32(strategyHash);

        return strategyHash;
    }

    /// @notice Set the requested maker allowance without first attempting an invalid nonzero-to-nonzero approval.
    /// @dev Caught reverts still become recorded broadcast transactions, so reset existing allowances explicitly.
    /// @param _token Token whose allowance is being configured.
    /// @param _maker Wallet signing the approval transactions.
    /// @param _spender Aqua or the maker's desk hook.
    /// @param _amount Requested allowance in native token units.
    function _approve(IERC20 _token, address _maker, address _spender, uint256 _amount) private {
        uint256 currentAllowance = _token.allowance(_maker, _spender);
        if (currentAllowance == _amount) return;
        if (currentAllowance != 0 && _amount != 0) SafeERC20.forceApprove(_token, _spender, 0);
        SafeERC20.forceApprove(_token, _spender, _amount);
    }

    /// @notice Reject invalid market timing, risk limits, and initial curve inputs before granting authority.
    /// @param _config Maker-selected configuration bound to the hook's actual note.
    /// @param _market Actual note market used to select collateral and remaining maturity.
    function _validateConfiguration(Config memory _config, Market memory _market) private view {
        if (
            _config.curve.curve.code.length == 0 || _market.maturity <= MoongladeSwap.MATURITY_BUFFER
                || block.timestamp >= _market.maturity - MoongladeSwap.MATURITY_BUFFER
                || _config.risk.collateralIndex >= _market.collateralParams.length
                || _config.risk.targetUtilization == 0 || _config.risk.targetUtilization >= WAD
                || _config.risk.maxDebt > type(uint128).max || _config.risk.maxCollateral > type(uint128).max
                || _config.virtualLoanBalance == 0 || _config.virtualNoteBalance == 0
                || _config.virtualLoanBalance > type(uint248).max || _config.virtualNoteBalance > type(uint248).max
        ) revert ConfigureMaker__InvalidConfiguration();
        MoongladeSwap.validate(_config.curve);
        IMoongladeNote note = IMoongladeNote(_config.curve.note);
        if (note.maturity() != _market.maturity) revert ConfigureMaker__InvalidConfiguration();
        IMoongladeCurve.MarketState memory pricingState = IMoongladeCurve.MarketState({
            note: address(note),
            cashBalance: _config.virtualLoanBalance,
            noteBalance: _config.virtualNoteBalance,
            timeLeft: _market.maturity - block.timestamp,
            payout: note.totalSupply() == 0 ? WAD : note.payoutPerShare()
        });
        // Model reads reject malformed opaque settings and unsupported initial reserve or maturity inputs.
        IMoongladeCurve(_config.curve.curve).rate(pricingState, _config.curve.data);
        IMoongladeCurve(_config.curve.curve).marginalPrice(pricingState, _config.curve.data);
    }

    /// @notice Read public addresses, native-unit risk limits and virtual reserves, pricing settings, and approvals.
    /// @dev Raw PRICING_CURVE_DATA overrides the typed YieldSpace defaults without interpreting a custom model's data.
    /// @return Public maker configuration; no private key or password is read.
    function _loadConfig() private view returns (Config memory) {
        uint256 defaultChainId = 8453;
        uint256 defaultSensitivity = 0.1e18;
        uint256 defaultRateFloor = 0.005e18;
        uint256 defaultFeeBps = 30;
        uint256 defaultTargetUtilization = 0.8e18;
        Config memory config;
        config.chainId = vm.envOr("DEPLOY_CHAIN_ID", defaultChainId);
        config.maker = vm.envAddress("MAKER_ADDRESS");
        config.hook = IMoongladeDeskHook(vm.envAddress("MOONGLADE_DESK_HOOK_ADDRESS"));
        config.curve.curve = vm.envAddress("PRICING_CURVE_ADDRESS");
        if (vm.envExists("PRICING_CURVE_DATA")) {
            config.curve.data = vm.envBytes("PRICING_CURVE_DATA");
        } else {
            IYieldSpaceCurve.Parameters memory parameters = IYieldSpaceCurve.Parameters({
                sensitivity: SafeCast.toUint64(vm.envOr("YIELDSPACE_SENSITIVITY", defaultSensitivity)),
                rateFloor: SafeCast.toUint64(vm.envOr("RATE_FLOOR", defaultRateFloor)),
                feeBps: SafeCast.toUint16(vm.envOr("TRADE_FEE_BPS", defaultFeeBps))
            });
            config.curve.data = YieldSpaceCurveConfig.encode(parameters);
        }
        config.risk = IMoongladeDeskHook.RiskConfig({
            maxDebt: vm.envUint("MAX_DEBT"),
            maxMintFront: vm.envUint("MAX_MINT_FRONT"),
            maxBurnCost: vm.envUint("MAX_BURN_COST"),
            collateralIndex: vm.envUint("COLLATERAL_INDEX"),
            targetUtilization: vm.envOr("TARGET_UTILIZATION", defaultTargetUtilization),
            maxCollateral: vm.envUint("MAX_COLLATERAL"),
            autoBurn: vm.envOr("AUTO_BURN", true)
        });
        config.virtualLoanBalance = vm.envUint("VIRTUAL_LOAN_BALANCE");
        config.virtualNoteBalance = vm.envUint("VIRTUAL_NOTE_BALANCE");
        config.aquaLoanAllowance = vm.envOr("AQUA_LOAN_ALLOWANCE", type(uint256).max);
        config.aquaNoteAllowance = vm.envOr("AQUA_NOTE_ALLOWANCE", type(uint256).max);
        config.hookLoanAllowance = vm.envOr("HOOK_LOAN_ALLOWANCE", type(uint256).max);
        config.hookNoteAllowance = vm.envOr("HOOK_NOTE_ALLOWANCE", type(uint256).max);
        config.hookCollateralAllowance = vm.envOr("HOOK_COLLATERAL_ALLOWANCE", type(uint256).max);

        return config;
    }
}
