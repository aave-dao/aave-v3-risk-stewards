// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {GelatoAaveStewardInjectorEMode} from '../src/contracts/gelato/GelatoAaveStewardInjectorEMode.sol';
import './AaveStewardInjectorEMode.t.sol';

contract GelatoAaveStewardsInjectorEMode_Test is AaveStewardsInjectorEMode_Test {
  using Address for address;

  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 1 days,
      maxPercentChange: 25 // 0.25% change allowed
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.eModeConfig.ltv = defaultRiskParamConfig;
    riskConfig.eModeConfig.liquidationThreshold = defaultRiskParamConfig;
    riskConfig.eModeConfig.liquidationBonus = defaultRiskParamConfig;

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );

    address[] memory markets = new address[](1);
    markets[0] = _encodeUintToAddress(_eModeIdOne);

    _stewardInjector = new GelatoAaveStewardInjectorEMode(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      markets,
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardEMode(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      riskConfig
    );
    vm.stopPrank();

    vm.prank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
  }

  function _checkAndPerformAutomation() internal virtual override returns (bool) {
    (bool shouldRunKeeper, bytes memory encodedPerformData) = _stewardInjector.checkUpkeep('');
    if (shouldRunKeeper) {
      address(_stewardInjector).functionCall(encodedPerformData);
    }
    return shouldRunKeeper;
  }

  function _performAutomation(bytes memory encodedCalldata) internal override {
    address(_stewardInjector).functionCall(encodedCalldata);
  }
}
