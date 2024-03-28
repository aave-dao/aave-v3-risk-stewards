// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskSteward, IRiskSteward, RiskStewardErrors, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {DeploymentLibrary, UpgradePayload} from 'protocol-v3.1-upgrade/scripts/Deploy.s.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {GovV3Helpers} from 'aave-helpers/GovV3Helpers.sol';
import {ConfigEngineDeployer} from './utils/ConfigEngineDeployer.sol';

contract RiskSteward_Test is Test {
  address public constant riskCouncil = address(42);
  RiskSteward public steward;
  IRiskSteward.Config public riskConfig;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 19055256);

    // update protocol to v3.1
    address v3_1_updatePayload = DeploymentLibrary._deployEthereum();
    GovV3Helpers.executePayload(vm, v3_1_updatePayload);

    // deploy new config engine
    address configEngine = ConfigEngineDeployer.deployEngine(address(UpgradePayload(v3_1_updatePayload).DEFAULT_IR()));

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 10_00 // 10%
    });
    IRiskSteward.RiskParamConfig memory liquidationBonusParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 2_00 // 2%
    });

    riskConfig = IRiskSteward.Config({
      ltv: defaultRiskParamConfig,
      liquidationThreshold: defaultRiskParamConfig,
      liquidationBonus: liquidationBonusParamConfig,
      supplyCap: defaultRiskParamConfig,
      borrowCap: defaultRiskParamConfig,
      debtCeiling: defaultRiskParamConfig,
      baseVariableBorrowRate: defaultRiskParamConfig,
      variableRateSlope1: defaultRiskParamConfig,
      variableRateSlope2: defaultRiskParamConfig,
      optimalUsageRatio: defaultRiskParamConfig
    });

    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward = new RiskSteward(
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER,
      IEngine(configEngine),
      riskCouncil,
      riskConfig
    );
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
    vm.stopPrank();
  }

  /* ----------------------------- Caps Tests ----------------------------- */

  function test_updateCaps() public {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 110) / 100, // 10% relative increase
      (daiBorrowCapBefore * 110) / 100 // 10% relative increase
    );

    vm.startPrank(riskCouncil);
    steward.updateCaps(capUpdates);

    (uint256 daiBorrowCapAfter, uint256 daiSupplyCapAfter) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.DAI_UNDERLYING
    );
    assertEq(daiBorrowCapAfter, capUpdates[0].borrowCap);
    assertEq(daiSupplyCapAfter, capUpdates[0].supplyCap);
    assertEq(lastUpdated.supplyCapLastUpdated, block.timestamp);
    assertEq(lastUpdated.borrowCapLastUpdated, block.timestamp);

    // after min time passed test caps decrease
    vm.warp(block.timestamp + 5 days + 1);
    (daiBorrowCapBefore, daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 90) / 100, // 10% relative decrease
      (daiBorrowCapBefore * 90) / 100 // 10% relative decrease
    );
    steward.updateCaps(capUpdates);
    vm.stopPrank();

    (daiBorrowCapAfter, daiSupplyCapAfter) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    assertEq(daiBorrowCapAfter, capUpdates[0].borrowCap);
    assertEq(daiSupplyCapAfter, capUpdates[0].supplyCap);
  }

  function test_updateCaps_outOfRange() public {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 120) / 100, // 20% relative increase (current maxChangePercent configured is 10%)
      (daiBorrowCapBefore * 120) / 100 // 20% relative increase
    );

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCaps(capUpdates);

    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 80) / 100, // 20% relative decrease
      (daiBorrowCapBefore * 80) / 100 // 20% relative decrease
    );
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCaps(capUpdates);

    vm.stopPrank();
  }

  function test_updateCaps_debounceNotRespected() public {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 110) / 100, // 10% relative increase
      (daiBorrowCapBefore * 110) / 100 // 10% relative increase
    );

    vm.startPrank(riskCouncil);
    steward.updateCaps(capUpdates);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(bytes(RiskStewardErrors.DEBOUNCE_NOT_RESPECTED));
    steward.updateCaps(capUpdates);
    vm.stopPrank();
  }

  function test_updateCaps_allKeepCurrent() public {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );

    vm.startPrank(riskCouncil);
    steward.updateCaps(capUpdates);

    (uint256 daiBorrowCapAfter, uint256 daiSupplyCapAfter) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.DAI_UNDERLYING
    );
    assertEq(daiBorrowCapAfter, daiBorrowCapBefore);
    assertEq(daiSupplyCapAfter, daiSupplyCapBefore);
    assertEq(lastUpdated.supplyCapLastUpdated, 0);
    assertEq(lastUpdated.borrowCapLastUpdated, 0);
  }

  function test_updateCaps_assetUnlisted() public {
    address unlistedAsset = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // stETH

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(unlistedAsset, 100, 100);

    vm.prank(riskCouncil);
    // as the update is from value 0
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCaps(capUpdates);
  }

  function test_updateCaps_assetRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAssetRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);
    vm.stopPrank();

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(AaveV3EthereumAssets.GHO_UNDERLYING, 100, 100);

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.ASSET_RESTRICTED));
    steward.updateCaps(capUpdates);
    vm.stopPrank();
  }

  function test_updateCaps_toValueZeroNotAllowed() public {
    // set risk config to allow 100% cap change to 0
    IRiskSteward.RiskParamConfig memory capsParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 100_00 // 100% relative change
    });

    riskConfig.supplyCap = capsParamConfig;
    riskConfig.borrowCap = capsParamConfig;

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(riskConfig);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      0, // 100% relative decrease to 0
      0 // 100% relative decrease to 0
    );

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.INVALID_UPDATE_TO_ZERO));
    steward.updateCaps(capUpdates);
  }

  /* ----------------------------- Rates Tests ----------------------------- */

  function test_updateRates() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio + 10_00, // 10% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 10_00, // 10% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 10_00, // 10% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 10_00 // 10% absolute increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateRates(rateUpdates);

    (
      uint256 afterOptimalUsageRatio,
      uint256 afterBaseVariableBorrowRate,
      uint256 afterVariableRateSlope1,
      uint256 afterVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.WETH_UNDERLYING
    );
    assertEq(afterOptimalUsageRatio, rateUpdates[0].params.optimalUsageRatio);
    assertEq(afterBaseVariableBorrowRate, rateUpdates[0].params.baseVariableBorrowRate);
    assertEq(afterVariableRateSlope1, rateUpdates[0].params.variableRateSlope1);
    assertEq(afterVariableRateSlope2, rateUpdates[0].params.variableRateSlope2);

    assertEq(lastUpdated.optimalUsageRatioLastUpdated, block.timestamp);
    assertEq(lastUpdated.baseVariableRateLastUpdated, block.timestamp);
    assertEq(lastUpdated.variableRateSlope1LastUpdated, block.timestamp);
    assertEq(lastUpdated.variableRateSlope2LastUpdated, block.timestamp);

    // after min time passed test rates decrease
    vm.warp(block.timestamp + 5 days + 1);

    (
      beforeOptimalUsageRatio,
      beforeBaseVariableBorrowRate,
      beforeVariableRateSlope1,
      beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio - 10_00, // 10% decrease
        baseVariableBorrowRate: beforeBaseVariableBorrowRate - 1_00, // 1% decrease
        variableRateSlope1: beforeVariableRateSlope1 - 1_00, // 1% decrease
        variableRateSlope2: beforeVariableRateSlope2 - 10_00 // 10% absolute decrease
      })
    });
    steward.updateRates(rateUpdates);
    vm.stopPrank();

    (
      afterOptimalUsageRatio,
      afterBaseVariableBorrowRate,
      afterVariableRateSlope1,
      afterVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);
    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.WETH_UNDERLYING);

    assertEq(afterOptimalUsageRatio, rateUpdates[0].params.optimalUsageRatio);
    assertEq(afterBaseVariableBorrowRate, rateUpdates[0].params.baseVariableBorrowRate);
    assertEq(afterVariableRateSlope1, rateUpdates[0].params.variableRateSlope1);
    assertEq(afterVariableRateSlope2, rateUpdates[0].params.variableRateSlope2);

    assertEq(lastUpdated.optimalUsageRatioLastUpdated, block.timestamp);
    assertEq(lastUpdated.baseVariableRateLastUpdated, block.timestamp);
    assertEq(lastUpdated.variableRateSlope1LastUpdated, block.timestamp);
    assertEq(lastUpdated.variableRateSlope2LastUpdated, block.timestamp);
  }

  function test_updateRates_outOfRange() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio + 12_00, // 12% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 12_00, // 12% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 12_00, // 12% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 12_00 // 12% absolute increase
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_debounceNotRespected() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio + 10_00, // 10% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 10_00, // 10% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 10_00, // 10% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 10_00 // 10% absolute increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateRates(rateUpdates);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(bytes(RiskStewardErrors.DEBOUNCE_NOT_RESPECTED));
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_assetUnlisted() public {
    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, // stETH
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: 40_00,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 2_00,
        variableRateSlope2: 50_00
      })
    });

    vm.prank(riskCouncil);
    vm.expectRevert();
    steward.updateRates(rateUpdates);
  }

  function test_updateRates_assetRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAssetRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);
    vm.stopPrank();

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.GHO_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: 40_00,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 2_00,
        variableRateSlope2: 50_00
      })
    });

    vm.prank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.ASSET_RESTRICTED));
    steward.updateRates(rateUpdates);
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public {
    (,uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore,,,,,, ) =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 10_00, // 10% absolute increase
      liqThreshold: ltBefore + 5_00, // 5% absolute increase
      liqBonus: (lbBefore - 100_00) + 2_00, // 2% absolute increase
      debtCeiling: debtCeilingBefore * 110 / 100, // 10% relative increase
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.UNI_UNDERLYING
    );

    (, uint256 ltvAfter, uint256 ltAfter, uint256 lbAfter, , , , , , ) =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    uint256 debtCeilingAfter = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    assertEq(ltvAfter, collateralUpdates[0].ltv);
    assertEq(ltAfter, collateralUpdates[0].liqThreshold);
    assertEq(lbAfter - 100_00, collateralUpdates[0].liqBonus);
    assertEq(debtCeilingAfter, collateralUpdates[0].debtCeiling);

    assertEq(lastUpdated.ltvLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationThresholdLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationBonusLastUpdated, block.timestamp);
    assertEq(lastUpdated.debtCeilingLastUpdated, block.timestamp);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    ( , ltvBefore, ltBefore, lbBefore , , , , , , ) =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 10_00, // 10% absolute decrease
      liqThreshold: ltBefore - 10_00, // 10% absolute decrease
      liqBonus: (lbBefore - 100_00) - 2_00, // 2% absolute decrease
      debtCeiling: debtCeilingBefore * 90 / 100, // 10% relative decrease
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();

    (
      ,
      ltvAfter,
      ltAfter,
      lbAfter,
      ,
      ,
      ,
      ,
      ,
    ) = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    debtCeilingAfter = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    assertEq(ltvAfter, collateralUpdates[0].ltv);
    assertEq(ltAfter, collateralUpdates[0].liqThreshold);
    assertEq(lbAfter - 100_00, collateralUpdates[0].liqBonus);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.UNI_UNDERLYING);

    assertEq(lastUpdated.ltvLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationThresholdLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationBonusLastUpdated, block.timestamp);
  }

  function test_updateCollateralSide_outOfRange() public {
    (,uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore,,,,,, ) =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 12_00, // 12% absolute increase
      liqThreshold: ltBefore + 11_00, // 11% absolute increase
      liqBonus: (lbBefore - 100_00) + 3_00, // 3% absolute increase
      debtCeiling: debtCeilingBefore * 112 / 100, // 12% relative increase
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCollateralSide(collateralUpdates);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 11_00, // 11% absolute decrease
      liqThreshold: ltBefore - 11_00, // 11% absolute decrease
      liqBonus: (lbBefore - 100_00) - 2_50, // 2.5% absolute decrease
      debtCeiling: debtCeilingBefore * 85 / 100, // 15% relative decrease
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_debounceNotRespected() public {
    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(AaveV3EthereumAssets.UNI_UNDERLYING) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: debtCeilingBefore * 110 / 100, // 10% relative increase
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    vm.warp(block.timestamp + 1 days);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(bytes(RiskStewardErrors.DEBOUNCE_NOT_RESPECTED));
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_liqProtocolFeeNotAllowed() public {
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
    vm.expectRevert(bytes(RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED));
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_assetUnlisted() public {
    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, // stETH
      ltv: 80_00,
      liqThreshold: 83_00,
      liqBonus: 5_00,
      debtCeiling: 1_000_000,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.prank(riskCouncil);
    vm.expectRevert();
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_updateCollateralSide_assetRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAssetRestricted(AaveV3EthereumAssets.UNI_UNDERLYING, true);
    vm.stopPrank();

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: 90_00,
      liqThreshold: 83_00,
      liqBonus: 1_00,
      debtCeiling: 100_000_000,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.prank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.ASSET_RESTRICTED));
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_updateCollateralSide_toValueZeroNotAllowed() public {
    // set risk config to allow 100% collateral param change to 0
    IRiskSteward.RiskParamConfig memory collateralParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 100_00 // 100% relative change
    });

    riskConfig.ltv = collateralParamConfig;
    riskConfig.liquidationThreshold = collateralParamConfig;
    riskConfig.liquidationBonus = collateralParamConfig;
    riskConfig.debtCeiling = collateralParamConfig;

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(riskConfig);

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: 0,
      liqThreshold: 0,
      liqBonus: 0,
      debtCeiling: 0, // 100% relative decrease to value 0
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.INVALID_UPDATE_TO_ZERO));
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_invalidCaller(address caller) public {
    vm.assume(caller != riskCouncil);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      EngineFlags.KEEP_CURRENT,
      EngineFlags.KEEP_CURRENT
    );

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    IEngine.RateStrategyUpdate[] memory rateStrategyUpdate = new IEngine.RateStrategyUpdate[](1);
    rateStrategyUpdate[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: _bpsToRay(90_00),
        baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
        variableRateSlope1: EngineFlags.KEEP_CURRENT,
        variableRateSlope2: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(caller);

    vm.expectRevert(bytes(RiskStewardErrors.INVALID_CALLER));
    steward.updateCaps(capUpdates);

    vm.expectRevert(bytes(RiskStewardErrors.INVALID_CALLER));
    steward.updateCollateralSide(collateralUpdates);

    vm.expectRevert(bytes(RiskStewardErrors.INVALID_CALLER));
    steward.updateRates(rateStrategyUpdate);

    vm.stopPrank();
  }

  function _bpsToRay(uint256 amount) internal pure returns (uint256) {
    return (amount * 1e27) / 10_000;
  }

  function _getInterestRatesForAsset(
    address asset
  )
    internal
    view
    returns (
      uint256 optimalUsageRatio,
      uint256 baseVariableBorrowRate,
      uint256 variableRateSlope1,
      uint256 variableRateSlope2
    )
  {
    address rateStrategyAddress = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getInterestRateStrategyAddress(asset);
    optimalUsageRatio = _rayToBps(IDefaultInterestRateStrategyV2(rateStrategyAddress).getOptimalUsageRatio(asset));
    baseVariableBorrowRate = _rayToBps(IDefaultInterestRateStrategyV2(rateStrategyAddress).getBaseVariableBorrowRate(asset));
    variableRateSlope1 = _rayToBps(IDefaultInterestRateStrategyV2(rateStrategyAddress).getVariableRateSlope1(asset));
    variableRateSlope2 = _rayToBps(IDefaultInterestRateStrategyV2(rateStrategyAddress).getVariableRateSlope2(asset));
    return (optimalUsageRatio, baseVariableBorrowRate, variableRateSlope1, variableRateSlope2);
  }

  function _rayToBps(uint256 amount) internal pure returns (uint256) {
    return amount / 1e23;
  }
}
