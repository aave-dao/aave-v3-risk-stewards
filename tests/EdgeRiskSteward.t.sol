// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EdgeRiskSteward} from 'src/contracts/EdgeRiskSteward.sol';
import './RiskSteward.t.sol';

contract EdgeRiskSteward_Test is RiskSteward_Test {
  function setUp() public override {
    super.setUp();

    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    steward = new EdgeRiskSteward(
      AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER,
      IEngine(configEngine),
      riskCouncil,
      riskConfig
    );
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));
    vm.stopPrank();
  }

  /* ----------------------------- Caps Tests ----------------------------- */

  function test_updateCaps() public override {
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
    vm.expectRevert(IRiskSteward.UpdateNotAllowed.selector);
    steward.updateCaps(capUpdates);
  }

  function test_updateCaps_outOfRange() public override {}

  function test_updateCaps_debounceNotRespected() public override {}

  function test_updateCaps_allKeepCurrent() public override {}

  function test_updateCaps_noSameUpdate() public override {}

  function test_updateCaps_assetUnlisted() public override {}

  function test_updateCaps_assetRestricted() public override {}

  function test_updateCaps_toValueZeroNotAllowed() public override {}

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

  function test_updateCollaterals_noSameUpdate() public override {}
}
