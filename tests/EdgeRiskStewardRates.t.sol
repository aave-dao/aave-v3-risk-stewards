// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskStewardRates} from 'src/contracts/EdgeRiskStewardRates.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import './RiskSteward.t.sol';

contract EdgeRiskStewardRates_Test is RiskSteward_Test {
  function setUp() public override {
    super.setUp();

    steward = new EdgeRiskStewardRates(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      riskCouncil,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      riskConfig
    );

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
  }

  /* ----------------------------- Caps Tests ----------------------------- */

  function test_updateCaps() public override {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateCaps(capUpdates);
  }

  function test_updateCaps_outOfRange() public override {}

  function test_updateCaps_debounceNotRespected() public override {}

  function test_updateCaps_allKeepCurrent() public override {}

  function test_updateCaps_sameUpdate() public override {}

  function test_updateCaps_assetUnlisted() public override {}

  function test_updateCaps_assetRestricted() public override {}

  function test_updateCaps_toValueZeroNotAllowed() public override {}

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
