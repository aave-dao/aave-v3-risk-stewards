// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {ReserveConfiguration, DataTypes} from 'aave-v3-origin/src/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IACLManager, IPoolConfigurator} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-origin/src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {GovV3Helpers} from 'aave-helpers/src/GovV3Helpers.sol';
import {ConfigEngineDeployer} from './utils/ConfigEngineDeployer.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {DeployRiskStewards} from '../scripts/deploy/DeployStewards.s.sol';

contract RiskSteward_Test is Test {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  address public constant riskCouncil = address(42);
  IRiskSteward public steward;
  IRiskSteward.Config public riskConfig;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 21974363);

    riskConfig = DeployRiskStewards._getRiskConfig();

    steward = new RiskSteward(
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

  function test_updateCaps() public virtual {
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
    vm.warp(block.timestamp + 3 days + 1);
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

  function test_updateCaps_outOfRange() public virtual {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 210) / 100, // 110% relative increase (current maxChangePercent configured is 100%)
      (daiBorrowCapBefore * 210) / 100 // 110% relative increase
    );

    vm.prank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCaps(capUpdates);

    IRiskSteward.RiskParamConfig memory newConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 10_00
    });
    IRiskSteward.Config memory config = riskConfig;
    config.capConfig.supplyCap = newConfig;
    config.capConfig.borrowCap = newConfig;

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(config);

    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 80) / 100, // 20% relative decrease
      (daiBorrowCapBefore * 80) / 100 // 20% relative decrease
    );
    vm.prank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCaps(capUpdates);

    vm.stopPrank();
  }

  function test_updateCaps_debounceNotRespected() public virtual {
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

    (daiBorrowCapBefore, daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      daiSupplyCapBefore + 1,
      daiBorrowCapBefore + 1
    );

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateCaps(capUpdates);
    vm.stopPrank();
  }

  function test_updateCaps_allKeepCurrent() public virtual {
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

    assertEq(daiBorrowCapBefore, daiBorrowCapAfter);
    assertEq(daiSupplyCapBefore, daiSupplyCapAfter);
  }

  function test_updateCaps_sameUpdate() public virtual {
    (uint256 daiBorrowCapBefore, uint256 daiSupplyCapBefore) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      daiSupplyCapBefore,
      daiBorrowCapBefore
    );

    vm.startPrank(riskCouncil);
    steward.updateCaps(capUpdates);

    (uint256 daiBorrowCapAfter, uint256 daiSupplyCapAfter) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveCaps(AaveV3EthereumAssets.DAI_UNDERLYING);

    assertEq(daiBorrowCapBefore, daiBorrowCapAfter);
    assertEq(daiSupplyCapBefore, daiSupplyCapAfter);
  }

  function test_updateCaps_assetUnlisted() public virtual {
    address unlistedAsset = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // stETH

    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(unlistedAsset, 100, 100);

    vm.prank(riskCouncil);
    // as the update is from value 0
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateCaps(capUpdates);
  }

  function test_updateCaps_assetRestricted() public virtual {
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

  function test_updateCaps_toValueZeroNotAllowed() public virtual {
    // set risk config to allow 100% cap change to 0
    IRiskSteward.RiskParamConfig memory capsParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 100_00 // 100% relative change
    });

    riskConfig.capConfig.supplyCap = capsParamConfig;
    riskConfig.capConfig.borrowCap = capsParamConfig;

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

  function test_updateRates() public virtual {
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
        optimalUsageRatio: beforeOptimalUsageRatio + 3_00, // 3% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 1_00, // 1% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 1_00, // 1% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 20_00 // 20% absolute increase
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
    vm.warp(block.timestamp + 3 days + 1);

    (
      beforeOptimalUsageRatio,
      beforeBaseVariableBorrowRate,
      beforeVariableRateSlope1,
      beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio - 3_00, // 3% decrease
        baseVariableBorrowRate: beforeBaseVariableBorrowRate - 1_00, // 1% decrease
        variableRateSlope1: beforeVariableRateSlope1 - 1_00, // 1% decrease
        variableRateSlope2: beforeVariableRateSlope2 - 20_00 // 20% absolute decrease
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

  function test_updateRates_outOfRange() public virtual {
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

  function test_updateRates_debounceNotRespected() public virtual {
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
        optimalUsageRatio: beforeOptimalUsageRatio + 3_00, // 3% absolute increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 1_00, // 1% absolute increase
        variableRateSlope1: beforeVariableRateSlope1 + 1_00, // 1% absolute increase
        variableRateSlope2: beforeVariableRateSlope2 + 20_00 // 20% absolute increase
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateRates(rateUpdates);

    (
      beforeOptimalUsageRatio,
      beforeBaseVariableBorrowRate,
      beforeVariableRateSlope1,
      beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.WETH_UNDERLYING);

    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.WETH_UNDERLYING,
      params: IEngine.InterestRateInputData({
        optimalUsageRatio: beforeOptimalUsageRatio + 1,
        baseVariableBorrowRate: beforeBaseVariableBorrowRate + 1,
        variableRateSlope1: beforeVariableRateSlope1 + 1,
        variableRateSlope2: beforeVariableRateSlope2 + 1
      })
    });

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_assetUnlisted() public virtual {
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

  function test_updateRates_assetRestricted() public virtual {
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

  function test_updateRates_allKeepCurrent() public virtual {
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
        optimalUsageRatio: EngineFlags.KEEP_CURRENT,
        baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
        variableRateSlope1: EngineFlags.KEEP_CURRENT,
        variableRateSlope2: EngineFlags.KEEP_CURRENT
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

    assertEq(beforeOptimalUsageRatio, afterOptimalUsageRatio);
    assertEq(beforeBaseVariableBorrowRate, afterBaseVariableBorrowRate);
    assertEq(beforeVariableRateSlope1, afterVariableRateSlope1);
    assertEq(beforeVariableRateSlope2, afterVariableRateSlope2);
  }

  function test_updateRate_sameUpdate() public virtual {
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
        optimalUsageRatio: beforeOptimalUsageRatio,
        baseVariableBorrowRate: beforeBaseVariableBorrowRate,
        variableRateSlope1: beforeVariableRateSlope1,
        variableRateSlope2: beforeVariableRateSlope2
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

    assertEq(beforeOptimalUsageRatio, afterOptimalUsageRatio);
    assertEq(beforeBaseVariableBorrowRate, afterBaseVariableBorrowRate);
    assertEq(beforeVariableRateSlope1, afterVariableRateSlope1);
    assertEq(beforeVariableRateSlope2, afterVariableRateSlope2);
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

  function test_updateCollateralSide() public virtual {
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
      ltv: ltvBefore + 50, // 0.5% absolute increase
      liqThreshold: ltBefore + 50, // 0.5% absolute increase
      liqBonus: (lbBefore - 100_00) + 50, // 0.5% absolute increase
      debtCeiling: (debtCeilingBefore * 120) / 100, // 20% relative increase
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
    vm.warp(block.timestamp + 3 days + 1);

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
      ltv: ltvBefore - 50, // 0.5% absolute decrease
      liqThreshold: ltBefore - 50, // 0.5% absolute decrease
      liqBonus: (lbBefore - 100_00) - 50, // 0.5% absolute decrease
      debtCeiling: (debtCeilingBefore * 80) / 100, // 20% relative decrease
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

  function test_updateCollateralSide_outOfRange() public virtual {
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
    vm.warp(block.timestamp + 3 days + 1);

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

  function test_updateCollateralSide_debounceNotRespected() public virtual {
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

    debtCeilingBefore =
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
        AaveV3EthereumAssets.UNI_UNDERLYING
      ) /
      100;

    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: debtCeilingBefore + 1,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    // expect revert as minimum time has not passed for next update
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateCollateralSide(collateralUpdates);
    vm.stopPrank();
  }

  function test_updateCollateralSide_liqProtocolFeeNotAllowed() public virtual {
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

  function test_updateCollateralSide_assetUnlisted() public virtual {
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

  function test_updateCollateralSide_assetRestricted() public virtual {
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

  function test_updateCollateralSide_toValueZeroNotAllowed() public virtual {
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
      debtCeiling: 0, // 100% relative decrease to value 0
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateCollateralSide(collateralUpdates);
  }

  function test_updateCollaterals_allKeepCurrent() public virtual {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: EngineFlags.KEEP_CURRENT,
      liqThreshold: EngineFlags.KEEP_CURRENT,
      liqBonus: EngineFlags.KEEP_CURRENT,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    (, uint256 ltvAfter, uint256 ltAfter, uint256 lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);

    uint256 debtCeilingAfter = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    assertEq(ltvBefore, ltvAfter);
    assertEq(ltBefore, ltAfter);
    assertEq(lbBefore, lbAfter);
    assertEq(debtCeilingBefore, debtCeilingAfter);
  }

  function test_updateCollaterals_sameUpdate() public virtual {
    (, uint256 ltvBefore, uint256 ltBefore, uint256 lbBefore, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    lbBefore = lbBefore - 100_00;

    uint256 debtCeilingBefore = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);
    collateralUpdates[0] = IEngine.CollateralUpdate({
      asset: AaveV3EthereumAssets.UNI_UNDERLYING,
      ltv: ltvBefore,
      liqThreshold: ltBefore,
      liqBonus: lbBefore,
      debtCeiling: debtCeilingBefore,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });

    vm.startPrank(riskCouncil);
    steward.updateCollateralSide(collateralUpdates);

    (, uint256 ltvAfter, uint256 ltAfter, uint256 lbAfter, , , , , , ) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveConfigurationData(AaveV3EthereumAssets.UNI_UNDERLYING);
    lbAfter = lbAfter - 100_00;

    uint256 debtCeilingAfter = AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER.getDebtCeiling(
      AaveV3EthereumAssets.UNI_UNDERLYING
    ) / 100;

    assertEq(ltvBefore, ltvAfter);
    assertEq(ltBefore, ltAfter);
    assertEq(lbBefore, lbAfter);
    assertEq(debtCeilingBefore, debtCeilingAfter);
  }

  /* ----------------------------- MISC ----------------------------- */

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
    steward.updateCollateralSide(collateralUpdates);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    steward.setRiskConfig(riskConfig);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    vm.stopPrank();
  }

  function test_assetRestricted() public {
    vm.expectEmit();
    emit IRiskSteward.AddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);

    assertTrue(steward.isAddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING));

    vm.expectEmit();
    emit IRiskSteward.AddressRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, false);

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
      collateralConfig: IRiskSteward.CollateralConfig({
        ltv: newRiskParamConfig,
        liquidationThreshold: newRiskParamConfig,
        liquidationBonus: newRiskParamConfig,
        debtCeiling: newRiskParamConfig
      }),
      rateConfig: IRiskSteward.RateConfig({
        baseVariableBorrowRate: newRiskParamConfig,
        variableRateSlope1: newRiskParamConfig,
        variableRateSlope2: newRiskParamConfig,
        optimalUsageRatio: newRiskParamConfig
      }),
      capConfig: IRiskSteward.CapConfig({
        supplyCap: newRiskParamConfig,
        borrowCap: newRiskParamConfig
      }),
      priceCapConfig: IRiskSteward.PriceCapConfig({
        priceCapLst: newRiskParamConfig,
        priceCapStable: newRiskParamConfig
      })
    });

    vm.expectEmit();
    emit IRiskSteward.RiskConfigSet(initialRiskConfig);

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setRiskConfig(initialRiskConfig);

    _validateRiskConfig(initialRiskConfig, steward.getRiskConfig());
  }

  function _validateRiskConfig(
    IRiskSteward.Config memory initialRiskConfig,
    IRiskSteward.Config memory updatedRiskConfig
  ) internal pure {
    assertEq(initialRiskConfig.collateralConfig.ltv.minDelay, updatedRiskConfig.collateralConfig.ltv.minDelay);
    assertEq(initialRiskConfig.collateralConfig.ltv.maxPercentChange, updatedRiskConfig.collateralConfig.ltv.maxPercentChange);
    assertEq(
      initialRiskConfig.collateralConfig.liquidationThreshold.minDelay,
      updatedRiskConfig.collateralConfig.liquidationThreshold.minDelay
    );
    assertEq(
      initialRiskConfig.collateralConfig.liquidationThreshold.maxPercentChange,
      updatedRiskConfig.collateralConfig.liquidationThreshold.maxPercentChange
    );
    assertEq(
      initialRiskConfig.collateralConfig.liquidationBonus.minDelay,
      updatedRiskConfig.collateralConfig.liquidationBonus.minDelay
    );
    assertEq(
      initialRiskConfig.collateralConfig.liquidationBonus.maxPercentChange,
      updatedRiskConfig.collateralConfig.liquidationBonus.maxPercentChange
    );
    assertEq(initialRiskConfig.capConfig.supplyCap.minDelay, updatedRiskConfig.capConfig.supplyCap.minDelay);
    assertEq(
      initialRiskConfig.capConfig.supplyCap.maxPercentChange,
      updatedRiskConfig.capConfig.supplyCap.maxPercentChange
    );
    assertEq(initialRiskConfig.capConfig.borrowCap.minDelay, updatedRiskConfig.capConfig.borrowCap.minDelay);
    assertEq(
      initialRiskConfig.capConfig.borrowCap.maxPercentChange,
      updatedRiskConfig.capConfig.borrowCap.maxPercentChange
    );
    assertEq(initialRiskConfig.collateralConfig.debtCeiling.minDelay, updatedRiskConfig.collateralConfig.debtCeiling.minDelay);
    assertEq(
      initialRiskConfig.collateralConfig.debtCeiling.maxPercentChange,
      updatedRiskConfig.collateralConfig.debtCeiling.maxPercentChange
    );
    assertEq(
      initialRiskConfig.rateConfig.baseVariableBorrowRate.minDelay,
      updatedRiskConfig.rateConfig.baseVariableBorrowRate.minDelay
    );
    assertEq(
      initialRiskConfig.rateConfig.baseVariableBorrowRate.maxPercentChange,
      updatedRiskConfig.rateConfig.baseVariableBorrowRate.maxPercentChange
    );
    assertEq(
      initialRiskConfig.rateConfig.variableRateSlope1.minDelay,
      updatedRiskConfig.rateConfig.variableRateSlope1.minDelay
    );
    assertEq(
      initialRiskConfig.rateConfig.variableRateSlope1.maxPercentChange,
      updatedRiskConfig.rateConfig.variableRateSlope1.maxPercentChange
    );
    assertEq(
      initialRiskConfig.rateConfig.variableRateSlope2.minDelay,
      updatedRiskConfig.rateConfig.variableRateSlope2.minDelay
    );
    assertEq(
      initialRiskConfig.rateConfig.variableRateSlope2.maxPercentChange,
      updatedRiskConfig.rateConfig.variableRateSlope2.maxPercentChange
    );
    assertEq(
      initialRiskConfig.rateConfig.optimalUsageRatio.minDelay,
      updatedRiskConfig.rateConfig.optimalUsageRatio.minDelay
    );
    assertEq(
      initialRiskConfig.rateConfig.optimalUsageRatio.maxPercentChange,
      updatedRiskConfig.rateConfig.optimalUsageRatio.maxPercentChange
    );
    assertEq(
      initialRiskConfig.priceCapConfig.priceCapLst.maxPercentChange,
      updatedRiskConfig.priceCapConfig.priceCapLst.maxPercentChange
    );
    assertEq(initialRiskConfig.priceCapConfig.priceCapLst.minDelay, updatedRiskConfig.priceCapConfig.priceCapLst.minDelay);
    assertEq(
      initialRiskConfig.priceCapConfig.priceCapStable.maxPercentChange,
      updatedRiskConfig.priceCapConfig.priceCapStable.maxPercentChange
    );
    assertEq(initialRiskConfig.priceCapConfig.priceCapStable.minDelay, updatedRiskConfig.priceCapConfig.priceCapStable.minDelay);
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
