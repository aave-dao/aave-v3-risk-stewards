// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {GelatoAaveStewardInjectorDiscountRate} from '../src/contracts/gelato/GelatoAaveStewardInjectorDiscountRate.sol';
import './AaveStewardInjectorDiscountRate.t.sol';

contract GelatoAaveStewardsInjectorDiscountRate_Test is AaveStewardsInjectorDiscountRate_Test {
  using Address for address;

  function setUp() public override {
    super.setUp();

    IRiskSteward.Config memory config;
    config.priceCapConfig.discountRatePendle = IRiskSteward.RiskParamConfig({
      minDelay: 2 days,
      maxPercentChange: 0.01e18 // 1% change allowed
    });

    address[] memory pendlePTAssets = new address[](2);
    pendlePTAssets[0] = _pendlePTAssetOne;
    pendlePTAssets[1] = _pendlePTAssetTwo;

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );

    _stewardInjector = new GelatoAaveStewardInjectorDiscountRate(
      report.aaveOracle,
      address(_riskOracle),
      address(computedRiskStewardAddress),
      pendlePTAssets,
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardDiscountRate(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      config
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
