// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorDiscountRate} from '../src/contracts/AaveStewardInjectorDiscountRate.sol';
import {PendlePriceCapAdapter, IPendlePriceCapAdapter} from 'aave-capo/contracts/PendlePriceCapAdapter.sol';
import {IAaveStewardInjectorBase} from '../src/interfaces/IAaveStewardInjectorBase.sol';
import {EdgeRiskStewardDiscountRate} from '../src/contracts/EdgeRiskStewardDiscountRate.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorDiscountRate_Test is AaveStewardsInjectorBaseTest {
  string internal _updateType = 'PendleDiscountRateUpdate_Core';

  address internal _pendlePTAssetOne;
  address internal _pendlePTAssetTwo;

  function setUp() public override {
    super.setUp();

    IRiskSteward.Config memory config;
    config.priceCapConfig.discountRatePendle = IRiskSteward.RiskParamConfig({
      minDelay: 2 days,
      maxPercentChange: 0.01e18 // 1% change allowed
    });

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](2);
    initialSenders[0] = _riskOracleOwner;

    string[] memory initialUpdateTypes = new string[](2);
    initialUpdateTypes[0] = _updateType;
    initialUpdateTypes[1] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    // custom pendle setup

    // assume the already listed weth, wbtc assets as PT Tokens, we will mock the custom PT token behavior on them
    _pendlePTAssetOne = address(weth);
    _pendlePTAssetTwo = address(wbtc);

    // mocks so that the currently listed assets behave as Pendle PT assets
    vm.mockCall(
      _pendlePTAssetOne,
      abi.encodeWithSignature("expiry()"),
      abi.encode(block.timestamp + 120 days)
    );
    vm.mockCall(
      _pendlePTAssetTwo,
      abi.encodeWithSignature("expiry()"),
      abi.encode(block.timestamp + 120 days)
    );

    PendlePriceCapAdapter pendleOneAdapter = new PendlePriceCapAdapter(IPendlePriceCapAdapter.PendlePriceCapAdapterParams({
      assetToUsdAggregator: contracts.aaveOracle.getSourceOfAsset(_pendlePTAssetOne),
      pendlePrincipalToken: _pendlePTAssetOne,
      maxDiscountRatePerYear: 1e18, // 100%
      discountRatePerYear: 0.2e18, // 20%
      aclManager: report.aclManager,
      description: 'PT_1 Adapter'
    }));
    PendlePriceCapAdapter pendleTwoAdapter = new PendlePriceCapAdapter(IPendlePriceCapAdapter.PendlePriceCapAdapterParams({
      assetToUsdAggregator: contracts.aaveOracle.getSourceOfAsset(_pendlePTAssetTwo),
      pendlePrincipalToken: _pendlePTAssetTwo,
      maxDiscountRatePerYear: 1e18, // 100%
      discountRatePerYear: 0.2e18, // 20%
      aclManager: report.aclManager,
      description: 'PT_2 Adapter'
    }));

    address[] memory pendlePTOracles = new address[](2);
    pendlePTOracles[0] = address(pendleOneAdapter);
    pendlePTOracles[1] = address(pendleTwoAdapter);
    address[] memory pendlePTAssets = new address[](2);
    pendlePTAssets[0] = _pendlePTAssetOne;
    pendlePTAssets[1] = _pendlePTAssetTwo;

    // updates the listed assets oracle to pendle PT so they behave as pendle assets
    vm.prank(poolAdmin);
    contracts.aaveOracle.setAssetSources(pendlePTAssets, pendlePTOracles);

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );

    _stewardInjector = new AaveStewardInjectorDiscountRate(
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
    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
    vm.stopPrank();

    vm.prank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
  }

  function test_multipleDiscountRateInjection() public {
    _addUpdateToRiskOracle(_pendlePTAssetOne);
    _addUpdateToRiskOracle(_pendlePTAssetTwo);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleEModeInjection() public {
    _addUpdateToRiskOracle(_pendlePTAssetOne);
    _addUpdateToRiskOracle(_pendlePTAssetTwo);

    uint256 snapshot = vm.snapshotState();

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    assertTrue(vm.revertToState(snapshot));
    vm.warp(block.timestamp + 3);

    // previous updateId order of execution: 1, 2
    // updateId order of execution:          2, 1
    // we can see with block.timestamp changing the order of execution of action changes as well

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_checkUpkeepGasLimit() public {
    _addMultipleUpdatesToRiskOracleOfDifferentMarkets(40);

    uint256 startGas = gasleft();
    _stewardInjector.checkUpkeep('');
    uint256 gasUsed = startGas - gasleft();

    // for 40 markets added, the checkUpkeep gas consumed is less than 5m
    // which is within the bounds of automation infra
    assertLt(gasUsed, 5_000_000);
  }

  function _addUpdateToRiskOracle()
    internal
    override
    returns (string memory updateType, address market)
  {
    vm.startPrank(_riskOracleOwner);
    updateType = _updateType;
    market = _pendlePTAssetOne;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(0.21e18), // 21% discountRate
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle(
    address market
  ) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    string memory updateType = _updateType;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(0.21e18), // 21% discountRate
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _addUpdateToRiskOracle(
    string memory updateType
  ) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    address market = _pendlePTAssetOne;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(0.21e18), // 21% discountRate
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _addMultipleUpdatesToRiskOracleOfDifferentMarkets(uint160 count) internal {
    for (uint160 i = 0; i < count; i++) {
      vm.startPrank(_riskOracleOwner);

      address market = address(i);
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(0.21e18),
        _updateType,
        market,
        'additionalData'
      );
      vm.stopPrank();
    }
  }

  function _encode(uint256 input) internal pure returns (bytes memory encodedData) {
    encodedData = abi.encodePacked(uint256(input));
  }
}
