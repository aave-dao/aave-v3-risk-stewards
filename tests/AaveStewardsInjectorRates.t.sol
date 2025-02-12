// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorRates} from '../src/contracts/AaveStewardInjectorRates.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorRates_Test is AaveStewardsInjectorBaseTest {
  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 5_00 // 5%
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
    string[] memory initialUpdateTypes = new string[](1);
    initialUpdateTypes[0] = 'RateStrategyUpdate';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    _stewardInjector = new AaveStewardInjectorRates(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian,
      address(weth)
    );

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
    vm.stopPrank();
  }

  function test_reverts_ifUpdateDoesNotExist() public {
    vm.expectRevert(bytes('No update found for the specified parameter and market.'));
    (, bytes memory performData) = _stewardInjector.checkUpkeep('');

    vm.expectRevert(bytes('No update found for the specified parameter and market.'));
    _stewardInjector.performUpkeep(performData);
  }

  function _addUpdateToRiskOracle() internal override {
    vm.startPrank(_riskOracleOwner);

    IEngine.InterestRateInputData memory rate = IEngine.InterestRateInputData({
      optimalUsageRatio: EngineFlags.KEEP_CURRENT,
      baseVariableBorrowRate: 5_00,
      variableRateSlope1: EngineFlags.KEEP_CURRENT,
      variableRateSlope2: EngineFlags.KEEP_CURRENT
    });
    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(rate),
      'RateStrategyUpdate',
      address(weth),
      'additionalData'
    );
    vm.stopPrank();
  }
}
