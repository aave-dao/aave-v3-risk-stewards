// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-origin/core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {DeploymentLibrary, UpgradePayload} from 'protocol-v3.1-upgrade/scripts/Deploy.s.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {GovV3Helpers} from 'aave-helpers/GovV3Helpers.sol';
import {ConfigEngineDeployer} from './utils/ConfigEngineDeployer.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import {IPriceCapAdapterStable} from 'aave-capo/interfaces/IPriceCapAdapterStable.sol';

contract RiskSteward_Test is Test {
  address public constant riskCouncil = address(42);
  RiskSteward public steward;
  address public configEngine;
  IRiskSteward.RiskParamConfig public defaultRiskParamConfig;
  IRiskSteward.Config public riskConfig;

  event AddressRestricted(address indexed contractAddress, bool indexed isRestricted);

  event RiskConfigSet(IRiskSteward.Config indexed riskConfig);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 19339970);

    // update protocol to v3.1
    address v3_1_updatePayload = DeploymentLibrary._deployEthereum();
    GovV3Helpers.executePayload(vm, v3_1_updatePayload);

    // deploy new config engine
    configEngine = ConfigEngineDeployer.deployEngine(
      address(UpgradePayload(v3_1_updatePayload).DEFAULT_IR())
    );

    defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
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
      optimalUsageRatio: defaultRiskParamConfig,
      priceCapLst: defaultRiskParamConfig,
      priceCapStable: defaultRiskParamConfig
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
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCaps(capUpdates);

    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 80) / 100, // 20% relative decrease
      (daiBorrowCapBefore * 80) / 100 // 20% relative decrease
    );
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
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
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
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
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCaps(capUpdates);
  }

  function test_updateCaps_assetRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);
    vm.stopPrank();

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(AaveV3EthereumAssets.GHO_UNDERLYING, 100, 100);

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.AssetIsRestricted.selector);
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
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
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
        optimalUsageRatio: beforeOptimalUsageRatio + 5_00, // 5% absolute increase
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
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
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
        optimalUsageRatio: beforeOptimalUsageRatio + 5_00, // 5% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 10_00, // 10% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 10_00, // 10% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 10_00 // 10% absolute increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateRates(rateUpdates);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
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
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);
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
    vm.expectRevert(IRiskSteward.AssetIsRestricted.selector);
    steward.updateRates(rateUpdates);
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 10_00, // 10% absolute increase
      liqThreshold: ltBefore + 5_00, // 5% absolute increase
      liqBonus: (lbBefore - 100_00) + 2_00, // 2% absolute increase
      debtCeiling: (debtCeilingBefore * 110) / 100, // 10% relative increase
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

    uint256 debtCeilingAfter = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

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

    (, ltvBefore, ltBefore, lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    debtCeilingBefore =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
        AaveV3EthereumAssets.UNI_UNDERLYING
      ) /
      100;

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 10_00, // 10% absolute decrease
      liqThreshold: ltBefore - 10_00, // 10% absolute decrease
      liqBonus: (lbBefore - 100_00) - 2_00, // 2% absolute decrease
      debtCeiling: (debtCeilingBefore * 90) / 100, // 10% relative decrease
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();

    (, ltvAfter, ltAfter, lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    debtCeilingAfter =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
        AaveV3EthereumAssets.UNI_UNDERLYING
      ) /
      100;

    assertEq(ltvAfter, collateralUpdates[0].ltv);
    assertEq(ltAfter, collateralUpdates[0].liqThreshold);
    assertEq(lbAfter - 100_00, collateralUpdates[0].liqBonus);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.UNI_UNDERLYING);

    assertEq(lastUpdated.ltvLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationThresholdLastUpdated, block.timestamp);
    assertEq(lastUpdated.liquidationBonusLastUpdated, block.timestamp);
  }

  function test_updateCollateralSide_outOfRange() public {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore + 12_00, // 12% absolute increase
      liqThreshold: ltBefore + 11_00, // 11% absolute increase
      liqBonus: (lbBefore - 100_00) + 3_00, // 3% absolute increase
      debtCeiling: (debtCeilingBefore * 112) / 100, // 12% relative increase
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert();
    steward.updateCollateralSide(collateralUpdates);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore - 11_00, // 11% absolute decrease
      liqThreshold: ltBefore - 11_00, // 11% absolute decrease
      liqBonus: (lbBefore - 100_00) - 2_50, // 2.5% absolute decrease
      debtCeiling: (debtCeilingBefore * 85) / 100, // 15% relative decrease
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_debounceNotRespected() public {
    // as the definition is with 2 decimals, and config engine does not take the decimals into account, so we divide by 100.
    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: (debtCeilingBefore * 110) / 100, // 10% relative increase
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    vm.warp(block.timestamp + 1 days);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
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
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
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
    steward.setAddressRestricted(AaveV3EthereumAssets.UNI_UNDERLYING, true);
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
    vm.expectRevert(IRiskSteward.AssetIsRestricted.selector);
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
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
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
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
        variableRateSlope1: EngineFlags.KEEP_CURRENT,
        variableRateSlope2: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(caller);

    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateCaps(capUpdates);

    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateCollateralSide(collateralUpdates);

    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateRates(rateStrategyUpdate);

    vm.expectRevert('Ownable: caller is not the owner');
    steward.setRiskConfig(riskConfig);

    vm.expectRevert('Ownable: caller is not the owner');
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    vm.stopPrank();
  }

  /* ----------------------------- LST Price Cap Tests ----------------------------- */

  function test_updateLstPriceCap() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio - 2)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateLstPriceCaps(priceCapUpdates);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.wstETH_ORACLE
    );

    uint256 snapshotRatioAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotRatio();
    uint256 snapshotTimestampAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotTimestamp();
    uint256 maxYearlyGrowthPercentAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    assertEq(snapshotTimestampAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotTimestamp);
    assertEq(snapshotRatioAfter, priceCapUpdates[0].priceCapUpdateParams.snapshotRatio);
    assertEq(
      maxYearlyGrowthPercentAfter,
      priceCapUpdates[0].priceCapUpdateParams.maxYearlyRatioGrowthPercent
    );

    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    // after min time passed test collateral update decrease
    vm.warp(block.timestamp + 5 days + 1);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - delay),
        snapshotRatio: uint104(uint256(currentRatio - 1)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentAfter * 91) / 100) // ~10% relative decrease
      })
    });

    steward.updateLstPriceCaps(priceCapUpdates);

    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.wstETH_ORACLE);

    snapshotRatioAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getSnapshotRatio();
    snapshotTimestampAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getSnapshotTimestamp();
    maxYearlyGrowthPercentAfter = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();
    assertEq(lastUpdated.priceCapLastUpdated, block.timestamp);

    vm.stopPrank();
  }

  function test_updateLstPriceCaps_debounceNotRespected() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio - 2)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateLstPriceCaps(priceCapUpdates);

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
    vm.stopPrank();
  }

  function test_updateLstPriceCap_invalidRatio() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio + 1)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCap_outOfRange() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio - 1)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 120) / 100) // 20% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCap_isCapped() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio / 2)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.InvalidPriceCapUpdate.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCap_toValueZeroNotAllowed() public {
    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: 0,
        snapshotRatio: uint104(uint256(currentRatio / 2)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    vm.startPrank(riskCouncil);
    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: 0,
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });

    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio / 2)),
        maxYearlyRatioGrowthPercent: 0
      })
    });

    // expect revert as snapshot ratio is greater than current
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  function test_updateLstPriceCap_oracleRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.wstETH_ORACLE, true);
    vm.stopPrank();

    int256 currentRatio = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).getRatio();
    uint48 delay = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE).MINIMUM_SNAPSHOT_DELAY();

    uint256 maxYearlyGrowthPercentBefore = IPriceCapAdapter(AaveV3EthereumAssets.wstETH_ORACLE)
      .getMaxYearlyGrowthRatePercent();

    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](
      1
    );
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2 * delay),
        snapshotRatio: uint104(uint256(currentRatio / 2)),
        maxYearlyRatioGrowthPercent: uint16((maxYearlyGrowthPercentBefore * 110) / 100) // 10% relative increase
      })
    });
  }

  /* ----------------------------- Stable Price Cap Tests ----------------------------- */

  function test_updateStablePriceCap() public {}

  function test_updateStablePriceCap_outOfRange() public {}

  function test_updateStablePriceCap_isCapped() public {}

  function test_updateStablePriceCap_toValueZeroNotAllowed() public {}

  function test_updateStablePriceCap_oracleRestricted() public {}

  /* ----------------------------- MISC ----------------------------- */

  function test_assetRestricted() public {
    vm.expectEmit();
    emit AddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    assertTrue(steward.isAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING));

    vm.expectEmit();
    emit AddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, false);

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, false);

    assertFalse(steward.isAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING));
  }

  function test_setRiskConfig() public {
    IRiskSteward.RiskParamConfig memory newRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 10 days,
      maxPercentChange: 20_00 // 20%
    });

    IRiskSteward.Config memory initialRiskConfig = IRiskSteward.Config({
      ltv: newRiskParamConfig,
      liquidationThreshold: newRiskParamConfig,
      liquidationBonus: newRiskParamConfig,
      supplyCap: newRiskParamConfig,
      borrowCap: newRiskParamConfig,
      debtCeiling: newRiskParamConfig,
      baseVariableBorrowRate: newRiskParamConfig,
      variableRateSlope1: newRiskParamConfig,
      variableRateSlope2: newRiskParamConfig,
      optimalUsageRatio: newRiskParamConfig,
      priceCapLst: newRiskParamConfig,
      priceCapStable: newRiskParamConfig
    });

    vm.expectEmit();
    emit RiskConfigSet(initialRiskConfig);

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(initialRiskConfig);

    _validateRiskConfig(initialRiskConfig, steward.getRiskConfig());
  }

  function test_constructor() public {
    riskConfig = IRiskSteward.Config({
      ltv: defaultRiskParamConfig,
      liquidationThreshold: defaultRiskParamConfig,
      liquidationBonus: defaultRiskParamConfig,
      supplyCap: defaultRiskParamConfig,
      borrowCap: defaultRiskParamConfig,
      debtCeiling: defaultRiskParamConfig,
      baseVariableBorrowRate: defaultRiskParamConfig,
      variableRateSlope1: defaultRiskParamConfig,
      variableRateSlope2: defaultRiskParamConfig,
      optimalUsageRatio: defaultRiskParamConfig,
      priceCapLst: defaultRiskParamConfig,
      priceCapStable: defaultRiskParamConfig
    });

    steward = new RiskSteward(
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER,
      IEngine(configEngine),
      riskCouncil,
      riskConfig
    );

    assertEq(
      address(steward.POOL_DATA_PROVIDER()),
      address(AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER)
    );
    assertEq(address(steward.CONFIG_ENGINE()), address(IEngine(configEngine)));
    assertEq(steward.RISK_COUNCIL(), riskCouncil);
    _validateRiskConfig(riskConfig, steward.getRiskConfig());
  }

  function _validateRiskConfig(
    IRiskSteward.Config memory initialRiskConfig,
    IRiskSteward.Config memory updatedRiskConfig
  ) internal {
    assertEq(initialRiskConfig.ltv.minDelay, updatedRiskConfig.ltv.minDelay);
    assertEq(initialRiskConfig.ltv.maxPercentChange, updatedRiskConfig.ltv.maxPercentChange);
    assertEq(
      initialRiskConfig.liquidationThreshold.minDelay,
      updatedRiskConfig.liquidationThreshold.minDelay
    );
    assertEq(
      initialRiskConfig.liquidationThreshold.maxPercentChange,
      updatedRiskConfig.liquidationThreshold.maxPercentChange
    );
    assertEq(
      initialRiskConfig.liquidationBonus.minDelay,
      updatedRiskConfig.liquidationBonus.minDelay
    );
    assertEq(
      initialRiskConfig.liquidationBonus.maxPercentChange,
      updatedRiskConfig.liquidationBonus.maxPercentChange
    );
    assertEq(initialRiskConfig.supplyCap.minDelay, updatedRiskConfig.supplyCap.minDelay);
    assertEq(
      initialRiskConfig.supplyCap.maxPercentChange,
      updatedRiskConfig.supplyCap.maxPercentChange
    );
    assertEq(initialRiskConfig.borrowCap.minDelay, updatedRiskConfig.borrowCap.minDelay);
    assertEq(
      initialRiskConfig.borrowCap.maxPercentChange,
      updatedRiskConfig.borrowCap.maxPercentChange
    );
    assertEq(initialRiskConfig.debtCeiling.minDelay, updatedRiskConfig.debtCeiling.minDelay);
    assertEq(
      initialRiskConfig.debtCeiling.maxPercentChange,
      updatedRiskConfig.debtCeiling.maxPercentChange
    );
    assertEq(
      initialRiskConfig.baseVariableBorrowRate.minDelay,
      updatedRiskConfig.baseVariableBorrowRate.minDelay
    );
    assertEq(
      initialRiskConfig.baseVariableBorrowRate.maxPercentChange,
      updatedRiskConfig.baseVariableBorrowRate.maxPercentChange
    );
    assertEq(
      initialRiskConfig.variableRateSlope1.minDelay,
      updatedRiskConfig.variableRateSlope1.minDelay
    );
    assertEq(
      initialRiskConfig.variableRateSlope1.maxPercentChange,
      updatedRiskConfig.variableRateSlope1.maxPercentChange
    );
    assertEq(
      initialRiskConfig.variableRateSlope2.minDelay,
      updatedRiskConfig.variableRateSlope2.minDelay
    );
    assertEq(
      initialRiskConfig.variableRateSlope2.maxPercentChange,
      updatedRiskConfig.variableRateSlope2.maxPercentChange
    );
    assertEq(
      initialRiskConfig.optimalUsageRatio.minDelay,
      updatedRiskConfig.optimalUsageRatio.minDelay
    );
    assertEq(
      initialRiskConfig.optimalUsageRatio.maxPercentChange,
      updatedRiskConfig.optimalUsageRatio.maxPercentChange
    );
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
    address rateStrategyAddress = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getInterestRateStrategyAddress(asset);

    IDefaultInterestRateStrategyV2.InterestRateData
      memory interestRateData = IDefaultInterestRateStrategyV2(rateStrategyAddress)
        .getInterestRateDataBps(asset);
    return (
      interestRateData.optimalUsageRatio,
      interestRateData.baseVariableBorrowRate,
      interestRateData.variableRateSlope1,
      interestRateData.variableRateSlope2
    );
  }
}
