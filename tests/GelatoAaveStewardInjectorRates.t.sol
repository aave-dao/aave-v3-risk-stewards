// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {GelatoAaveStewardInjectorRates} from '../src/contracts/gelato/GelatoAaveStewardInjectorRates.sol';
import './AaveStewardsInjectorRates.t.sol';

contract GelatoAaveStewardsInjectorRates_Test is AaveStewardsInjectorRates_Test {
  using Address for address;

  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 5_00 // 5%
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.rateConfig.baseVariableBorrowRate = defaultRiskParamConfig;
    riskConfig.rateConfig.variableRateSlope1 = defaultRiskParamConfig;
    riskConfig.rateConfig.variableRateSlope2 = defaultRiskParamConfig;
    riskConfig.rateConfig.optimalUsageRatio = defaultRiskParamConfig;

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    address[] memory validMarkets = new address[](1);
    validMarkets[0] = address(weth);

    _stewardInjector = new GelatoAaveStewardInjectorRates(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      validMarkets,
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardRates(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      riskConfig
    );
    vm.stopPrank();

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
    vm.stopPrank();
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
