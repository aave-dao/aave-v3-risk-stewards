// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorCaps} from '../src/contracts/AaveStewardInjectorCaps.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorCaps_Test is AaveStewardsInjectorBaseTest {
  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 100_00
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
      optimalUsageRatio: defaultRiskParamConfig,
      priceCapLst: defaultRiskParamConfig,
      priceCapStable: defaultRiskParamConfig
    });

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = _riskOracleOwner;
    string[] memory initialUpdateTypes = new string[](2);
    initialUpdateTypes[0] = 'supplyCap';
    initialUpdateTypes[1] = 'borrowCap';

    _riskOracle = new RiskOracle(
      'RiskOracle',
      initialSenders,
      initialUpdateTypes
    );
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(_stewardsInjectorOwner, vm.getNonce(_stewardsInjectorOwner) + 1);
    _stewardInjector = new AaveStewardInjectorCaps(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      _stewardsInjectorOwner
    );
    address[] memory whitelistedMarkets = new address[](1);
    whitelistedMarkets[0] = address(weth);
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(whitelistedMarkets);

    // setup risk steward
    _riskSteward = new RiskSteward(
      contracts.protocolDataProvider,
      IEngine(report.configEngine),
      address(_stewardInjector),
      riskConfig
    );

    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
    vm.stopPrank();

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));

    // as initial caps are at 0, which the steward cannot update from
    contracts.poolConfiguratorProxy.setSupplyCap(address(weth), 100);
    contracts.poolConfiguratorProxy.setBorrowCap(address(weth), 50);
    vm.stopPrank();
  }

  function test_noInjection_ifUpdateDoesNotExist() public {
    assertFalse(_checkAndPerformAutomation());
  }

  function _addUpdateToRiskOracle() internal override {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(105),
      'supplyCap',
      address(weth),
      'additionalData'
    );
    vm.stopPrank();
  }
}
