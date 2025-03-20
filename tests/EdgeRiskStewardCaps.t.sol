// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskStewardCaps} from 'src/contracts/EdgeRiskStewardCaps.sol';
import {IPriceCapAdapter} from 'aave-capo/interfaces/IPriceCapAdapter.sol';
import './RiskSteward.t.sol';

contract EdgeRiskStewardCaps_Test is RiskSteward_Test {
  function setUp() public override {
    super.setUp();

    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward = new EdgeRiskStewardCaps(
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER,
      IEngine(configEngine),
      riskCouncil,
      riskConfig
    );
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
    vm.stopPrank();
  }

  /* ----------------------------- Rates Tests ----------------------------- */

  function test_updateRates() public override {
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
    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(block.timestamp - 2),
        snapshotRatio: 1.1e18,
        maxYearlyRatioGrowthPercent: 9_68
      })
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateLstPriceCaps(priceCapUpdates);
  }

  /* ----------------------------- Stable Price Cap Test ----------------------------- */

  function test_updateStablePriceCap() public {
    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.USDT_ORACLE,
      priceCap: 1060000
    });

    vm.startPrank(riskCouncil);
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateStablePriceCaps(priceCapUpdates);
  }
}
