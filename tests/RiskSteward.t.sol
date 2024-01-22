// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskSteward, IRiskSteward, RiskStewardErrors, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {Rates} from 'aave-helpers/v3-config-engine/AaveV3Payload.sol';

contract RiskSteward_Test is Test {
  address public constant riskCouncil = address(42);
  RiskSteward public steward;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 19055256);

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 5 days,
      maxPercentChange: 10_00 // 10%
    });
    IRiskSteward.Config memory riskConfig = IRiskSteward.Config({
      ltv: defaultRiskParamConfig,
      liquidationThreshold: defaultRiskParamConfig,
      liquidationBonus: defaultRiskParamConfig,
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
      IEngine(AaveV3Ethereum.CONFIG_ENGINE),
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
      (daiSupplyCapBefore * 110) / 100, // 10% increase
      (daiBorrowCapBefore * 110) / 100 // 10% increase
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
      (daiSupplyCapBefore * 90) / 100, // 10% decrease
      (daiBorrowCapBefore * 90) / 100 // 10% decrease
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
      (daiSupplyCapBefore * 120) / 100, // 20% increase (current maxChangePercent configured is 10%)
      (daiBorrowCapBefore * 120) / 100 // 20% increase
    );

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateCaps(capUpdates);

    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3EthereumAssets.DAI_UNDERLYING,
      (daiSupplyCapBefore * 80) / 100, // 20% decrease
      (daiBorrowCapBefore * 80) / 100 // 20% decrease
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
      (daiSupplyCapBefore * 110) / 100, // 10% increase
      (daiBorrowCapBefore * 110) / 100 // 10% increase
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

    vm.startPrank(riskCouncil);
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

  /* ----------------------------- Rates Tests ----------------------------- */

  function test_updateRates() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: beforeOptimalUsageRatio * 110 / 100, // 10% increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate * 110 / 100, // 10% increase
        variableRateSlope1: beforeVariableRateSlope1 * 110 / 100, // 10% increase,
        variableRateSlope2: beforeVariableRateSlope2 * 110 / 100, // 10% increase,
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(riskCouncil);
    steward.updateRates(rateUpdates);

    (
      uint256 afterOptimalUsageRatio,
      uint256 afterBaseVariableBorrowRate,
      uint256 afterVariableRateSlope1,
      uint256 afterVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    RiskSteward.Debounce memory lastUpdated = steward.getTimelock(
      AaveV3EthereumAssets.DAI_UNDERLYING
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
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: beforeOptimalUsageRatio * 90 / 100, // 10% decrease
        baseVariableBorrowRate: beforeBaseVariableBorrowRate * 90 / 100, // 10% decrease
        variableRateSlope1: beforeVariableRateSlope1 * 90 / 100, // 10% decrease,
        variableRateSlope2: beforeVariableRateSlope2 * 90 / 100, // 10% decrease,
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
      })
    });
    steward.updateRates(rateUpdates);
    vm.stopPrank();

    (
      afterOptimalUsageRatio,
      afterBaseVariableBorrowRate,
      afterVariableRateSlope1,
      afterVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);
    lastUpdated = steward.getTimelock(AaveV3EthereumAssets.DAI_UNDERLYING);

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
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: beforeOptimalUsageRatio * 120 / 100, // 20% increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate * 120 / 100, // 20% increase
        variableRateSlope1: beforeVariableRateSlope1 * 120 / 100, // 20% increase,
        variableRateSlope2: beforeVariableRateSlope2 * 120 / 100, // 20% increase,
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.UPDATE_NOT_IN_RANGE));
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_stableNotAllowed() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: beforeOptimalUsageRatio * 110 / 100, // 10% increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate * 110 / 100, // 10% increase
        variableRateSlope1: beforeVariableRateSlope1 * 110 / 100, // 10% increase,
        variableRateSlope2: beforeVariableRateSlope2 * 110 / 100, // 10% increase,
        stableRateSlope1: 0,
        stableRateSlope2: _bpsToRay(10_00),
        baseStableRateOffset: _bpsToRay(2_00),
        stableRateExcessOffset: _bpsToRay(8_00),
        optimalStableToTotalDebtRatio: _bpsToRay(20_00)
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED));
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_debounceNotRespected() public {
    (
      uint256 beforeOptimalUsageRatio,
      uint256 beforeBaseVariableBorrowRate,
      uint256 beforeVariableRateSlope1,
      uint256 beforeVariableRateSlope2
    ) = _getInterestRatesForAsset(AaveV3EthereumAssets.DAI_UNDERLYING);

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.DAI_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: beforeOptimalUsageRatio * 110 / 100, // 10% increase
        baseVariableBorrowRate: beforeBaseVariableBorrowRate * 110 / 100, // 10% increase
        variableRateSlope1: beforeVariableRateSlope1 * 110 / 100, // 10% increase,
        variableRateSlope2: beforeVariableRateSlope2 * 110 / 100, // 10% increase,
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
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
      params: Rates.RateStrategyParams({
        optimalUsageRatio: _bpsToRay(40_00),
        baseVariableBorrowRate: 0,
        variableRateSlope1: _bpsToRay(2_00),
        variableRateSlope2: _bpsToRay(50_00),
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert();
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  function test_updateRates_assetRestricted() public {
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward.setAssetRestricted(AaveV3EthereumAssets.GHO_UNDERLYING, true);
    vm.stopPrank();

    IEngine.RateStrategyUpdate[] memory rateUpdates = new IEngine.RateStrategyUpdate[](1);
    rateUpdates[0] = IEngine.RateStrategyUpdate({
      asset: AaveV3EthereumAssets.GHO_UNDERLYING,
      params: Rates.RateStrategyParams({
        optimalUsageRatio: _bpsToRay(40_00),
        baseVariableBorrowRate: 0,
        variableRateSlope1: _bpsToRay(2_00),
        variableRateSlope2: _bpsToRay(50_00),
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(bytes(RiskStewardErrors.ASSET_RESTRICTED));
    steward.updateRates(rateUpdates);
    vm.stopPrank();
  }

  /* ----------------------------- Collateral Tests ----------------------------- */

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
      params: Rates.RateStrategyParams({
        optimalUsageRatio: _bpsToRay(90_00),
        baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
        variableRateSlope1: EngineFlags.KEEP_CURRENT,
        variableRateSlope2: EngineFlags.KEEP_CURRENT,
        stableRateSlope1: EngineFlags.KEEP_CURRENT,
        stableRateSlope2: EngineFlags.KEEP_CURRENT,
        baseStableRateOffset: EngineFlags.KEEP_CURRENT,
        stableRateExcessOffset: EngineFlags.KEEP_CURRENT,
        optimalStableToTotalDebtRatio: EngineFlags.KEEP_CURRENT
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
    optimalUsageRatio = IDefaultInterestRateStrategy(rateStrategyAddress).OPTIMAL_USAGE_RATIO();
    baseVariableBorrowRate = IDefaultInterestRateStrategy(rateStrategyAddress)
      .getBaseVariableBorrowRate();
    variableRateSlope1 = IDefaultInterestRateStrategy(rateStrategyAddress).getVariableRateSlope1();
    variableRateSlope2 = IDefaultInterestRateStrategy(rateStrategyAddress).getVariableRateSlope2();
    return (optimalUsageRatio, baseVariableBorrowRate, variableRateSlope1, variableRateSlope2);
  }
}
