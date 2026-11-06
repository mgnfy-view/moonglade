// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IMidnight, Market, Offer, CollateralParams } from "midnight/src/interfaces/IMidnight.sol";
import { IOracle } from "midnight/src/interfaces/IOracle.sol";
import { IRatifier } from "midnight/src/interfaces/IRatifier.sol";

import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import { Test } from "forge-std/Test.sol";
import { Midnight } from "midnight/src/Midnight.sol";
import { CALLBACK_SUCCESS } from "midnight/src/libraries/ConstantsLib.sol";
import { IdLib } from "midnight/src/libraries/IdLib.sol";
import { MAX_TICK } from "midnight/src/libraries/TickLib.sol";

import { MoongladeNote } from "src/note/MoongladeNote.sol";
import { MoongladeNoteFactory } from "src/note/MoongladeNoteFactory.sol";

abstract contract MoongladeNoteTestBase is Test {
    uint256 internal constant UNIT = 1e6;

    address internal alice;
    address internal bob;
    Midnight internal midnight;
    NoteTestToken internal loan;
    NoteTestToken internal collateral;
    MoongladeNoteFactory internal factory;
    MoongladeNote internal note;
    Market internal market;
    bytes32 internal marketId;

    function setUp() public virtual {
        uint256 initialTimestamp = 1_800_000_000;
        uint256 loanToValue = 0.8e18;
        uint256 liquidationCursor = 0.3e18;
        uint256 annualContinuousFee = 0.005e18;
        uint256 marketDuration = 180 days;
        uint256 oneDaySettlementFee = 14e12;
        uint256 sevenDaySettlementFee = 98e12;
        uint256 thirtyDaySettlementFee = 417e12;
        uint256 longTermSettlementFee = 500e12;

        vm.warp(initialTimestamp);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        // Run the actual pinned Midnight implementation without a fork or a settlement mock.
        midnight = Midnight(deployCode("Midnight.sol:Midnight"));
        loan = new NoteTestToken("USDC");
        collateral = new NoteTestToken("COLLATERAL");
        midnight.setFeeSetter(address(this));
        midnight.enableLltv(loanToValue);
        midnight.enableLiquidationCursor(liquidationCursor);
        midnight.setDefaultContinuousFee(address(loan), annualContinuousFee / 365 days);
        uint256[7] memory fees = [
            oneDaySettlementFee,
            oneDaySettlementFee,
            sevenDaySettlementFee,
            thirtyDaySettlementFee,
            longTermSettlementFee,
            longTermSettlementFee,
            longTermSettlementFee
        ];
        for (uint256 i; i < fees.length; ++i) {
            midnight.setDefaultSettlementFee(address(loan), i, fees[i]);
        }

        CollateralParams[] memory params = new CollateralParams[](1);
        params[0] = CollateralParams(address(collateral), loanToValue, liquidationCursor, address(new NoteTestOracle()));
        market = Market(
            block.chainid,
            address(midnight),
            address(loan),
            params,
            block.timestamp + marketDuration,
            0,
            address(0),
            address(0)
        );
        marketId = IdLib.toId(market);
        factory = new MoongladeNoteFactory(IMidnight(address(midnight)));
        note = MoongladeNote(factory.create(market));
        _prepare(alice);
        _prepare(bob);
    }

    function _prepare(address _user) internal {
        uint256 openingCash = 1_000_000 * UNIT;
        uint256 postedCollateral = 100_000 * UNIT;
        loan.mint(_user, openingCash);
        collateral.mint(_user, postedCollateral);
        vm.startPrank(_user);
        loan.approve(address(note), type(uint256).max);
        loan.approve(address(midnight), type(uint256).max);
        collateral.approve(address(midnight), type(uint256).max);
        midnight.setIsAuthorized(address(factory.ratifier()), true, _user);
        midnight.supplyCollateral(market, 0, postedCollateral, _user);
        vm.stopPrank();
    }

    function _mint(address _borrower, uint256 _shares) internal returns (uint256, uint256) {
        uint256 maxUnits = type(uint256).max;
        uint256 maxFront = type(uint256).max;
        vm.prank(_borrower);
        (uint256 units, uint256 shares) =
            note.mintFromPosition(_shares, maxUnits, maxFront, _borrower, _borrower, MAX_TICK);
        return (units, shares);
    }

    function _externalOffer(bool _buy, uint256 _units, address _maker) internal returns (Offer memory) {
        NoteTestRatifier externalRatifier = new NoteTestRatifier();
        vm.prank(_maker);
        midnight.setIsAuthorized(address(externalRatifier), true, _maker);
        Offer memory offer;
        offer.market = market;
        offer.buy = _buy;
        offer.maker = _maker;
        offer.expiry = type(uint256).max;
        offer.tick = MAX_TICK;
        offer.maxUnits = uint128(_units);
        offer.receiverIfMakerIsSeller = _buy ? address(0) : _maker;
        offer.ratifier = address(externalRatifier);
        offer.continuousFeeCap = type(uint256).max;
        return offer;
    }
}

contract NoteTestToken is ERC20 {
    constructor(string memory _symbol) ERC20(_symbol, _symbol) { }

    function decimals() public pure override returns (uint8) {
        uint8 tokenDecimals = 6;
        return tokenDecimals;
    }

    function mint(address _receiver, uint256 _amount) external {
        _mint(_receiver, _amount);
    }
}

contract NoteTestOracle is IOracle {
    function price() external pure returns (uint256) {
        uint256 collateralPrice = 1e36;
        return collateralPrice;
    }
}

// Authorizes wallet-made offers for the external credit and wrap/unwrap scenarios.
contract NoteTestRatifier is IRatifier {
    function isRatified(Offer memory, bytes memory, address) external pure returns (bytes32) {
        return CALLBACK_SUCCESS;
    }
}
