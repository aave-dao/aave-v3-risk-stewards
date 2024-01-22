// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
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

  function test_updateCaps_debounce() public {
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
}
