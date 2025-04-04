// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskStewardCollateral} from 'src/contracts/EdgeRiskStewardCollateral.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import './RiskSteward.t.sol';

contract EdgeRiskStewardCollateral_Test is RiskSteward_Test {
  function setUp() public override {
    super.setUp();

    steward = new EdgeRiskStewardCollateral(
      address(AaveV3Ethereum.POOL),
      AaveV3Ethereum.CONFIG_ENGINE,
      riskCouncil,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      riskConfig
    );

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public virtual override {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 50, // 0.5% absolute increase
      liqThreshold: ltBefore + 50, // 0.5% absolute increase
      liqBonus: (lbBefore - 100_00) + 50, // 0.5% absolute increase
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.UNI_UNDERLYING
    );

    (, uint256 ltvAfter, uint256 ltAfter, uint256 lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    assertEq(ltvAfter, collateralUpdates[0].ltv);
    assertEq(ltAfter, collateralUpdates[0].liqThreshold);
    assertEq(lbAfter - 100_00, collateralUpdates[0].liqBonus);

    assertEq(lastUpdated.ltvLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationThresholdLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationBonusLastUpdated, block.timestamp);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 3 days + 1);

    (, ltvBefore, ltBefore, lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 50, // 0.5% absolute decrease
      liqThreshold: ltBefore - 50, // 0.5% absolute decrease
      liqBonus: (lbBefore - 100_00) - 50, // 0.5% absolute decrease
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();

    (, ltvAfter, ltAfter, lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    assertEq(ltvAfter, collateralUpdates[0].ltv);
    assertEq(ltAfter, collateralUpdates[0].liqThreshold);
    assertEq(lbAfter - 100_00, collateralUpdates[0].liqBonus);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.UNI_UNDERLYING);

    assertEq(lastUpdated.ltvLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationThresholdLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationBonusLastUpdated, block.timestamp);
  }

  function test_updateCollateralSide_outOfRange() public virtual override {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 12_00, // 12% absolute increase
      liqThreshold: ltBefore + 11_00, // 11% absolute increase
      liqBonus: (lbBefore - 100_00) + 3_00, // 3% absolute increase
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert();
    steward.updateCollateralSide(collateralUpdates);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 3 days + 1);

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 11_00, // 11% absolute decrease
      liqThreshold: ltBefore - 11_00, // 11% absolute decrease
      liqBonus: (lbBefore - 100_00) - 2_50, // 2.5% absolute decrease
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_liqProtocolFeeNotAllowed() public virtual override {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: 10_00
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_debtCeilingNotAllowed() public virtual {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: 1_000_000,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_toValueZeroNotAllowed() public virtual override {
    // set risk config to allow 100% collateral param change to 0
    IRiskSteward.RiskParamConfig memory collateralParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 100_00 // 100% relative change
    });

    riskConfig.collateralConfig.ltv = collateralParamConfig;
    riskConfig.collateralConfig.liquidationThreshold = collateralParamConfig;
    riskConfig.collateralConfig.liquidationBonus = collateralParamConfig;
    riskConfig.collateralConfig.debtCeiling = collateralParamConfig;

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(riskConfig);

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: 0,
      liqThreshold: 0,
      liqBonus: 0,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_updateCollaterals_sameUpdate() public virtual override {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    lbBefore = lbBefore - 100_00;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore,
      liqThreshold: ltBefore,
      liqBonus: lbBefore,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    (, uint256 ltvAfter, uint256 ltAfter, uint256 lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    lbAfter = lbAfter - 100_00;

    assertEq(ltvBefore, ltvAfter);
    assertEq(ltBefore, ltAfter);
    assertEq(lbBefore, lbAfter);
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

  /* ----------------------------- EMode Category Update Tests ----------------------------- */

  function test_updateEModeCategories() public override {
    IEngine.EModeCategoryUpdate[] memory eModeCategoryUpdates = new IEngine.EModeCategoryUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateEModeCategories(eModeCategoryUpdates);
  }

  function test_updateEModeCategories_outOfRange() public override {}

  function test_updateEModeCategories_debounceNotRespected() public override {}

  function test_updateEModeCategories_eModeDoesNotExist() public override {}

  function test_updateEModeCategories_eModeRestricted() public override {}

  function test_updateEModeCategories_toValueZeroNotAllowed() public override {}

  function test_updateEModeCategories_allKeepCurrent() public override {}

  function test_updateEModeCategories_sameUpdate() public override {}

  function test_updateEModeCategories_labelChangeNotAllowed() public override {}

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

  /* ----------------------------- Pendle Discount Rate Test ----------------------------- */

  function test_updatePendlePriceCap() public {
    IRiskSteward.DiscountRatePendleUpdate[]
      memory priceCapUpdates = new IRiskSteward.DiscountRatePendleUpdate[](1);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updatePendleDiscountRates(priceCapUpdates);
  }
}
