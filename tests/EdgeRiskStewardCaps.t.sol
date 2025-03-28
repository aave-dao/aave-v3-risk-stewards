// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskStewardCaps} from 'src/contracts/EdgeRiskStewardCaps.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import './RiskSteward.t.sol';

contract EdgeRiskStewardCaps_Test is RiskSteward_Test {
  function setUp() public override {
    super.setUp();

    steward = new EdgeRiskStewardCaps(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      riskCouncil,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      riskConfig
    );

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
  }

  /* ----------------------------- Rates Tests ----------------------------- */

  function test_updateRates() public override {
    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateRates(rateUpdates);
  }

  function test_updateRates_outOfRange() public override {}

  function test_updateRates_debounceNotRespected() public override {}

  function test_updateRates_assetUnlisted() public override {}

  function test_updateRates_assetRestricted() public override {}

  function test_updateRates_allKeepCurrent() public override {}

  function test_updateRate_sameUpdate() public override {}

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public override {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_updateCollateralSide_outOfRange() public override {}

  function test_updateCollateralSide_debounceNotRespected() public override {}

  function test_updateCollateralSide_liqProtocolFeeNotAllowed() public override {}

  function test_updateCollateralSide_assetUnlisted() public override {}

  function test_updateCollateralSide_assetRestricted() public override {}

  function test_updateCollateralSide_toValueZeroNotAllowed() public override {}

  function test_updateCollaterals_allKeepCurrent() public override {}

  function test_updateCollaterals_sameUpdate() public override {}

  /* ----------------------------- LST Price Cap Tests ----------------------------- */

  function test_updateLstPriceCap() public {
    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  /* ----------------------------- Stable Price Cap Test ----------------------------- */

  function test_updateStablePriceCap() public {
    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateStablePriceCaps(priceCapUpdates);
  }
}
