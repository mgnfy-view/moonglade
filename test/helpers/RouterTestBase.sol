// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";
import { ISwapVM } from "swap-vm/src/interfaces/ISwapVM.sol";

import { CalldataPtrLib } from "@1inch/solidity-utils/contracts/libraries/CalldataPtr.sol";
import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import { Aqua } from "aqua/src/Aqua.sol";
import { Test } from "forge-std/Test.sol";
import { MakerTraitsLib } from "swap-vm/src/libs/MakerTraits.sol";
import { TakerTraitsLib } from "swap-vm/src/libs/TakerTraits.sol";
import { Context, ContextLib } from "swap-vm/src/libs/VM.sol";

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

import { YieldSpaceCurve } from "src/curves/YieldSpaceCurve.sol";
import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";
import { MoongladeProgram } from "src/libraries/MoongladeProgram.sol";
import { MoongladeOpcodes } from "src/opcodes/MoongladeOpcodes.sol";
import { MoongladeRouter } from "src/routers/MoongladeRouter.sol";

abstract contract RouterTestBase is Test {
    Aqua internal aqua;
    MoongladeRouter internal router;
    MoongladeOpcodeHarness internal opcodeHarness;
    RouterTestToken internal cashToken;
    RouterTestToken internal noteToken;
    IMoongladeSwap.Config internal pricingConfig;
    ISwapVM.Order internal order;
    address internal maker;
    address internal taker;
    uint256 internal maturity;
    uint256 internal cashReserve;
    uint256 internal noteReserve;

    function setUp() public virtual {
        uint256 currentTime = 1_700_000_000;
        uint256 timeUntilMaturity = 180 days;
        uint256 payoutPerShare = 1e18;
        uint256 takerFunding = 10_000e6;
        uint8 tickSpacing = 4;
        uint64 sensitivity = 0.1e18;
        uint64 rateFloor = 0.005e18;
        uint16 makerFeeBps = 30;
        uint64 strategySalt = 7;
        address midnight = makeAddr("Router Midnight metadata");
        bytes32 marketId = keccak256("router test market");

        vm.warp(currentTime);
        maturity = currentTime + timeUntilMaturity;
        cashReserve = 1000e6;
        noteReserve = 2225e6;
        maker = makeAddr("Router maker");
        taker = makeAddr("Router taker");
        cashToken = new RouterTestToken("Cash");
        noteToken = new RouterTestToken("Note");
        aqua = new Aqua();
        router = new MoongladeRouter(address(aqua), address(cashToken));
        opcodeHarness = new MoongladeOpcodeHarness(address(aqua));
        YieldSpaceCurve curve = new YieldSpaceCurve();
        IYieldSpaceCurve.Parameters memory parameters =
            IYieldSpaceCurve.Parameters({ sensitivity: sensitivity, rateFloor: rateFloor, feeBps: makerFeeBps });
        pricingConfig =
            IMoongladeSwap.Config(address(noteToken), address(curve), YieldSpaceCurveConfig.encode(parameters));

        // Use a real transferable token; mock only the note's credit-market metadata.
        vm.mockCall(address(noteToken), abi.encodeWithSelector(IMoongladeNote.maturity.selector), abi.encode(maturity));
        vm.mockCall(
            address(noteToken),
            abi.encodeWithSelector(IMoongladeNote.loanToken.selector),
            abi.encode(address(cashToken))
        );
        vm.mockCall(
            address(noteToken),
            abi.encodeWithSelector(IMoongladeNote.payoutPerShare.selector),
            abi.encode(payoutPerShare)
        );
        vm.mockCall(address(noteToken), abi.encodeWithSelector(IMoongladeNote.midnight.selector), abi.encode(midnight));
        vm.mockCall(address(noteToken), abi.encodeWithSelector(IMoongladeNote.marketId.selector), abi.encode(marketId));
        vm.mockCall(midnight, abi.encodeCall(IMidnight.tickSpacing, (marketId)), abi.encode(tickSpacing));

        cashToken.mint(maker, cashReserve);
        noteToken.mint(maker, noteReserve);
        cashToken.mint(taker, takerFunding);
        noteToken.mint(taker, takerFunding);
        MakerTraitsLib.Args memory makerArgs;
        makerArgs.maker = maker;
        makerArgs.useAquaInsteadOfSignature = true;
        makerArgs.program = MoongladeProgram.build(pricingConfig, strategySalt);
        order = MakerTraitsLib.build(makerArgs);

        uint256 tokenCount = 2;
        address[] memory tokens = new address[](tokenCount);
        uint256[] memory reserves = new uint256[](tokenCount);
        tokens[0] = address(cashToken);
        tokens[1] = address(noteToken);
        reserves[0] = cashReserve;
        reserves[1] = noteReserve;
        vm.startPrank(maker);
        cashToken.approve(address(aqua), type(uint256).max);
        noteToken.approve(address(aqua), type(uint256).max);
        aqua.ship(address(router), abi.encode(order), tokens, reserves);
        vm.stopPrank();
        vm.startPrank(taker);
        cashToken.approve(address(router), type(uint256).max);
        noteToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function _takerData(uint256 _minOutput) internal view returns (bytes memory) {
        TakerTraitsLib.Args memory args;
        args.taker = taker;
        args.isExactIn = true;
        args.isFirstTransferFromTaker = true;
        args.useTransferFromAndAquaPush = true;
        args.threshold = abi.encode(_minOutput);

        return TakerTraitsLib.build(args);
    }

    function _runProgram(bytes memory _program, uint256 _sharesIn) internal returns (uint256, uint256) {
        return opcodeHarness.run(_program, address(noteToken), address(cashToken), _sharesIn, noteReserve, cashReserve);
    }
}

contract RouterTestToken is ERC20 {
    uint8 private constant TOKEN_DECIMALS = 6;

    constructor(string memory _name) ERC20(_name, _name) { }

    function mint(address _recipient, uint256 _amount) external {
        _mint(_recipient, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }
}

contract MoongladeOpcodeHarness is MoongladeOpcodes {
    constructor(address _aqua) MoongladeOpcodes(_aqua) { }

    function run(
        bytes calldata _program,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _balanceIn,
        uint256 _balanceOut
    ) external returns (uint256, uint256) {
        Context memory ctx;
        ctx.vm.programPtr = CalldataPtrLib.from(_program);
        ctx.vm.opcodes = _opcodes();
        ctx.query.tokenIn = _tokenIn;
        ctx.query.tokenOut = _tokenOut;
        ctx.query.taker = msg.sender;
        ctx.query.isExactIn = true;
        ctx.swap.amountIn = _amountIn;
        ctx.swap.balanceIn = _balanceIn;
        ctx.swap.balanceOut = _balanceOut;

        return ContextLib.runLoop(ctx);
    }
}
