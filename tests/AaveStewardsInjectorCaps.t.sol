// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorCaps, IAaveStewardInjectorCaps} from '../src/contracts/AaveStewardInjectorCaps.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorCaps_Test is AaveStewardsInjectorBaseTest {
  event MarketAdded(address indexed market);
  event MarketRemoved(address indexed market);

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
    string[] memory initialUpdateTypes = new string[](3);
    initialUpdateTypes[0] = 'supplyCap';
    initialUpdateTypes[1] = 'borrowCap';
    initialUpdateTypes[2] = 'wrongUpdateType';

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

    // setup risk steward
    _riskSteward = new RiskSteward(
      contracts.protocolDataProvider,
      IEngine(report.configEngine),
      address(_stewardInjector),
      riskConfig
    );
    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
    vm.stopPrank();

    _addMarket(address(weth));

    vm.startPrank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));

    // as initial caps are at 0, which the steward cannot update from
    contracts.poolConfiguratorProxy.setSupplyCap(address(weth), 100);
    contracts.poolConfiguratorProxy.setBorrowCap(address(weth), 50);
    contracts.poolConfiguratorProxy.setSupplyCap(address(wbtc), 100);
    contracts.poolConfiguratorProxy.setBorrowCap(address(wbtc), 50);
    vm.stopPrank();
  }

  function test_addMarkets() public {
    address[] memory markets = new address[](1);
    markets[0] = address(weth);

    vm.prank(address(1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit MarketAdded(address(weth));

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(markets);

    markets = AaveStewardInjectorCaps(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 1);
    assertEq(markets[0], address(weth));
  }

  function test_removeMarkets() public {
    address[] memory markets = AaveStewardInjectorCaps(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 1);
    assertEq(markets[0], address(weth));

    vm.prank(address(1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    AaveStewardInjectorCaps(address(_stewardInjector)).removeMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit MarketRemoved(address(weth));

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).removeMarkets(markets);

    markets = AaveStewardInjectorCaps(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 0);

    // removing already removed market does nothing
    markets = new address[](1);
    markets[0] = address(weth);
    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).removeMarkets(markets);
    markets = AaveStewardInjectorCaps(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 0);
  }

  function test_perform_invalidMarketPassed() public {
    _addUpdateToRiskOracle(address(wbtc), 'supplyCap', 105);

    IAaveStewardInjectorCaps.ActionData memory action = IAaveStewardInjectorCaps.ActionData({
      market: address(wbtc),
      updateType: 'supplyCap'
    });

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));

    address[] memory markets = new address[](1);
    markets[0] = address(wbtc);
    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function test_perform_invalidUpdateTypePassed() public {
    _addUpdateToRiskOracle(address(weth), 'wrongUpdateType', 105);

    IAaveStewardInjectorCaps.ActionData memory action = IAaveStewardInjectorCaps.ActionData({
      market: address(weth),
      updateType: 'wrongUpdateType'
    });

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));

    _addUpdateToRiskOracle(address(weth), 'supplyCap', 105);
    action = IAaveStewardInjectorCaps.ActionData({
      market: address(weth),
      updateType: 'supplyCap'
    });
    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function test_multipleMarketInjection() public {
    _addMarket(address(wbtc));
    _addUpdateToRiskOracle(address(weth), 'supplyCap', 105);
    _addUpdateToRiskOracle(address(wbtc), 'supplyCap', 105);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_multipleUpdateTypeInjection() public {
    _addUpdateToRiskOracle(address(weth), 'supplyCap', 105);
    _addUpdateToRiskOracle(address(weth), 'borrowCap', 55);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleMarketInjection() public {
    _addMarket(address(wbtc));
    _addUpdateToRiskOracle(address(weth), 'supplyCap', 105);
    _addUpdateToRiskOracle(address(weth), 'borrowCap', 55);
    _addUpdateToRiskOracle(address(wbtc), 'supplyCap', 105);
    _addUpdateToRiskOracle(address(wbtc), 'borrowCap', 55);

    uint256 snapshot = vm.snapshotState();

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(4);
    assertTrue(_checkAndPerformAutomation());

    assertTrue(vm.revertToState(snapshot));
    vm.warp(block.timestamp + 3);

    // previous updateId order of execution: 1, 3, 2, 4
    // updateId order of execution:          4, 1, 3, 2
    // we can see with block.timestamp changing the order of execution of action changes as well

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(4);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_noInjection_ifUpdateDoesNotExist() public {
    assertFalse(_checkAndPerformAutomation());
  }

  function _addUpdateToRiskOracle(address market, string memory updateType, uint256 value) internal {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(value),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
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

  function _addMarket(address market) internal {
    address[] memory markets = new address[](1);
    markets[0] = market;

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCaps(address(_stewardInjector)).addMarkets(markets);
  }
}
