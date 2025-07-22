// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorCaps} from '../src/contracts/AaveStewardInjectorCaps.sol';
import {IAaveStewardInjectorBase} from '../src/interfaces/IAaveStewardInjectorBase.sol';
import {EdgeRiskStewardCaps} from '../src/contracts/EdgeRiskStewardCaps.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorCaps_Test is AaveStewardsInjectorBaseTest {
  event MarketAdded(address indexed market);
  event MarketRemoved(address indexed market);

  address internal _aWETH;
  address internal _aWBTC;

  function setUp() public virtual override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 3 days,
      maxPercentChange: 100_00
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.capConfig.supplyCap = defaultRiskParamConfig;
    riskConfig.capConfig.borrowCap = defaultRiskParamConfig;

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = _riskOracleOwner;
    string[] memory initialUpdateTypes = new string[](3);
    initialUpdateTypes[0] = 'supplyCap';
    initialUpdateTypes[1] = 'borrowCap';
    initialUpdateTypes[2] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    _aWETH = _getAToken(address(weth));
    _aWBTC = _getAToken(address(wbtc));

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    address[] memory markets = new address[](1);
    markets[0] = _aWETH;

    _stewardInjector = new AaveStewardInjectorCaps(
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

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));

    // as initial caps are at 0, which the steward cannot update from
    contracts.poolConfiguratorProxy.setSupplyCap(address(weth), 100);
    contracts.poolConfiguratorProxy.setBorrowCap(address(weth), 50);
    contracts.poolConfiguratorProxy.setSupplyCap(address(wbtc), 100);
    contracts.poolConfiguratorProxy.setBorrowCap(address(wbtc), 50);
    vm.stopPrank();
  }

  function test_multipleMarketInjection() public {
    _addMarket(_aWBTC);
    _addUpdateToRiskOracle(_aWETH, 'supplyCap', _encode(105e18));
    _addUpdateToRiskOracle(_aWBTC, 'supplyCap', _encode(105e8));

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_multipleUpdateTypeInjection() public {
    _addUpdateToRiskOracle(_aWETH, 'supplyCap', _encode(105e18));
    _addUpdateToRiskOracle(_aWETH, 'borrowCap', _encode(55e18));

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleMarketInjection() public {
    _addMarket(_aWBTC);
    _addUpdateToRiskOracle(_aWETH, 'supplyCap', _encode(105e18));
    _addUpdateToRiskOracle(_aWETH, 'borrowCap', _encode(55e18));
    _addUpdateToRiskOracle(_aWBTC, 'supplyCap', _encode(105e8));
    _addUpdateToRiskOracle(_aWBTC, 'borrowCap', _encode(55e8));

    uint256 snapshot = vm.snapshotState();

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(4);
    assertTrue(_checkAndPerformAutomation());

    assertTrue(vm.revertToState(snapshot));
    vm.warp(block.timestamp + 3);

    // previous updateId order of execution: 1, 3, 2, 4
    // updateId order of execution:          4, 1, 3, 2
    // we can see with block.timestamp changing the order of execution of action changes as well

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(4);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
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

  function _addUpdateToRiskOracle(
    address market,
    string memory updateType,
    bytes memory value
  ) internal {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      value,
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle() internal override returns (string memory updateType, address market) {
    vm.startPrank(_riskOracleOwner);
    updateType = 'supplyCap';
    market = _aWETH;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(105e18),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle(address market) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    string memory updateType = 'supplyCap';

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(105e18),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _addUpdateToRiskOracle(string memory updateType) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    address market = _aWETH;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(105e18),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
    return (updateType, market);
  }

  function _addMarket(address market) internal {
    address[] memory markets = new address[](1);
    markets[0] = market;

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(markets);
  }

  function _addMultipleUpdatesToRiskOracleOfDifferentMarkets(uint160 count) internal {
    for (uint160 i = 0; i < count; i++) {
      vm.startPrank(_riskOracleOwner);

      address market = address(i);
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(105e18),
        'supplyCap',
        market,
        'additionalData'
      );
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(55e18),
        'borrowCap',
        market,
        'additionalData'
      );
      vm.stopPrank();

      _addMarket(market);
    }
  }

  function _encode(uint256 input) internal pure returns (bytes memory encodedData) {
    encodedData = abi.encodePacked(uint256(input));
  }

  function _getAToken(address underlying) internal view returns (address aToken) {
    (aToken, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(underlying);
  }
}
