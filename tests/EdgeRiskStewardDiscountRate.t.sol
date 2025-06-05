// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskStewardDiscountRate} from '../src/contracts/EdgeRiskStewardDiscountRate.sol';
import './RiskStewardCapo.t.sol';

contract EdgeRiskStewardDiscountRate_Test is RiskSteward_Capo_Test {
  using SafeCast for uint256;
  using SafeCast for int256;

  function setUp() public override {
    super.setUp();

    steward = new EdgeRiskStewardDiscountRate(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      riskCouncil,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      riskConfig
    );

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
  }

  /* ----------------------------- LST Price Cap Tests ----------------------------- */

  function test_updateLstPriceCap() public override {
    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );

    vm.prank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCaps_debounceNotRespected() public override {}

  function test_updateLstPriceCap_invalidRatio() public override {}

  function test_updateLstPriceCap_outOfRange() public override {}

  function test_updateLstPriceCap_isCapped() public override {}

  function test_updateLstPriceCap_toValueZeroNotAllowed() public override {}

  function test_updateLstPriceCap_oracleRestricted() public override {}

  function test_updateLstPriceCap_noSameUpdate() public override {}

  /* ----------------------------- Stable Price Cap Tests ----------------------------- */

  function test_updateStablePriceCap() public override {}

  function test_updateStablePriceCap_debounceNotRespected() public override {}

  function test_updateStablePriceCap_outOfRange() public override {}

  function test_updateStablePriceCap_keepCurrent_revert() public override {}

  function test_updateStablePriceCap_toValueZeroNotAllowed() public override {}

  function test_updateStablePriceCap_oracleRestricted() public override {}

  function test_updateStablePriceCap_sameUpdates() public override {}

  /* ----------------------------- Rates Tests ----------------------------- */

  function test_updateRates() public {
    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateRates(rateUpdates);
  }

  /* ----------------------------- Caps Tests ----------------------------- */

  function test_updateCaps() public {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateCaps(capUpdates);
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateCollateralSide(collateralUpdates);
  }

  /* ----------------------------- EMode Category Update Tests ----------------------------- */

  function test_updateEModeCategories() public {
    IEngine.EModeCategoryUpdate[] memory eModeCategoryUpdates = new IEngine.EModeCategoryUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateEModeCategories(eModeCategoryUpdates);
  }
}
