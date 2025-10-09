// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorRates} from '../src/contracts/AaveStewardInjectorRates.sol';
import {EdgeRiskStewardRates} from '../src/contracts/EdgeRiskStewardRates.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorRates_Test is AaveStewardsInjectorBaseTest {
  function setUp() public virtual override {
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

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = _riskOracleOwner;
    string[] memory initialUpdateTypes = new string[](2);
    initialUpdateTypes[0] = 'RateStrategyUpdate';
    initialUpdateTypes[1] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    address[] memory validMarkets = new address[](1);
    validMarkets[0] = address(weth);

    _stewardInjector = new AaveStewardInjectorRates(
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

  function _addUpdateToRiskOracle() internal override returns (string memory updateType, address market) {
    vm.startPrank(_riskOracleOwner);
    updateType = 'RateStrategyUpdate';
    market = address(weth);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _getDefaultEncodedRate(),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle(address market) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    string memory updateType = 'RateStrategyUpdate';

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _getDefaultEncodedRate(),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _addUpdateToRiskOracle(string memory updateType) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    address market = address(weth);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _getDefaultEncodedRate(),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _getDefaultEncodedRate() internal pure returns (bytes memory) {
    IEngine.InterestRateInputData memory rate = IEngine.InterestRateInputData({
      optimalUsageRatio: EngineFlags.KEEP_CURRENT,
      baseVariableBorrowRate: 5_00,
      variableRateSlope1: EngineFlags.KEEP_CURRENT,
      variableRateSlope2: EngineFlags.KEEP_CURRENT
    });
    return abi.encode(rate);
  }
}
