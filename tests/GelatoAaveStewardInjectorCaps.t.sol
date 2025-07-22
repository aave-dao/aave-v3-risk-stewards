// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {GelatoAaveStewardInjectorCaps} from '../src/contracts/gelato/GelatoAaveStewardInjectorCaps.sol';
import './AaveStewardsInjectorCaps.t.sol';

contract GelatoAaveStewardsInjectorCaps_Test is AaveStewardsInjectorCaps_Test {
  using Address for address;

  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 100_00
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.capConfig.supplyCap = defaultRiskParamConfig;
    riskConfig.capConfig.borrowCap = defaultRiskParamConfig;

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    address[] memory markets = new address[](1);
    markets[0] = _aWETH;

    _stewardInjector = new GelatoAaveStewardInjectorCaps(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      markets,
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardCaps(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      riskConfig
    );
    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
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
