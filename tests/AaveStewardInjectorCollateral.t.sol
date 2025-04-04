// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorCollateral, IAaveStewardInjectorCollateral} from '../src/contracts/AaveStewardInjectorCollateral.sol';
import {EdgeRiskStewardCollateral} from '../src/contracts/EdgeRiskStewardCollateral.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorCollateral_Test is AaveStewardsInjectorBaseTest {
  address internal _aWETH;
  address internal _aWBTC;

  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 1 days,
      maxPercentChange: 25 // 0.25% change allowed
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.collateralConfig.ltv = defaultRiskParamConfig;
    riskConfig.collateralConfig.liquidationThreshold = defaultRiskParamConfig;
    riskConfig.collateralConfig.liquidationBonus = defaultRiskParamConfig;

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](1);
    initialSenders[0] = _riskOracleOwner;
    string[] memory initialUpdateTypes = new string[](4);
    initialUpdateTypes[0] = 'ltv';
    initialUpdateTypes[1] = 'liquidationThreshold';
    initialUpdateTypes[2] = 'liquidationBonus';
    initialUpdateTypes[3] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    _stewardInjector = new AaveStewardInjectorCollateral(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardCollateral(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      riskConfig
    );
    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
    vm.stopPrank();

    _aWETH = _getAToken(address(weth));
    _aWBTC = _getAToken(address(wbtc));

    _addMarket(_aWETH);

    vm.prank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
  }

  function test_addMarkets() public {
    address[] memory markets = new address[](1);
    markets[0] = _aWETH;

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1))
    );
    AaveStewardInjectorCollateral(address(_stewardInjector)).addMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorCollateral.MarketAdded(_aWETH);

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCollateral(address(_stewardInjector)).addMarkets(markets);

    markets = AaveStewardInjectorCollateral(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 1);
    assertEq(markets[0], _aWETH);
  }

  function test_removeMarkets() public {
    address[] memory markets = AaveStewardInjectorCollateral(address(_stewardInjector))
      .getMarkets();
    assertEq(markets.length, 1);
    assertEq(markets[0], _aWETH);

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1))
    );
    AaveStewardInjectorCollateral(address(_stewardInjector)).removeMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorCollateral.MarketRemoved(_aWETH);

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCollateral(address(_stewardInjector)).removeMarkets(markets);

    markets = AaveStewardInjectorCollateral(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 0);

    // removing already removed market does nothing
    markets = new address[](1);
    markets[0] = _aWETH;
    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCollateral(address(_stewardInjector)).removeMarkets(markets);
    markets = AaveStewardInjectorCollateral(address(_stewardInjector)).getMarkets();
    assertEq(markets.length, 0);
  }

  function test_perform_invalidMarketPassed() public {
    _addUpdateToRiskOracle(_aWBTC, 'ltv', _encode(82_75));

    IAaveStewardInjectorCollateral.ActionData memory action = IAaveStewardInjectorCollateral
      .ActionData({market: _aWBTC, updateType: 'ltv'});

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));

    address[] memory markets = new address[](1);
    markets[0] = _aWBTC;
    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCollateral(address(_stewardInjector)).addMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function test_perform_invalidUpdateTypePassed() public {
    _addUpdateToRiskOracle(_aWETH, 'wrongUpdateType', _encode(105e18));

    IAaveStewardInjectorCollateral.ActionData memory action = IAaveStewardInjectorCollateral
      .ActionData({market: _aWETH, updateType: 'wrongUpdateType'});

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));

    _addUpdateToRiskOracle(_aWETH, 'ltv', _encode(82_75));
    action = IAaveStewardInjectorCollateral.ActionData({market: _aWETH, updateType: 'ltv'});
    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function test_multipleMarketInjection() public {
    _addMarket(_aWBTC);
    _addUpdateToRiskOracle(_aWETH, 'ltv', _encode(82_75));
    _addUpdateToRiskOracle(_aWBTC, 'ltv', _encode(82_75));

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_multipleUpdateTypeInjection() public {
    _addUpdateToRiskOracle(_aWETH, 'ltv', _encode(82_75));
    _addUpdateToRiskOracle(_aWETH, 'liquidationThreshold', _encode(86_25));
    _addUpdateToRiskOracle(_aWETH, 'liquidationBonus', _encode(5_25));

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleMarketInjection() public {
    _addMarket(_aWBTC);
    _addUpdateToRiskOracle(_aWETH, 'ltv', _encode(82_75));
    _addUpdateToRiskOracle(_aWETH, 'liquidationThreshold', _encode(86_25));
    _addUpdateToRiskOracle(_aWBTC, 'ltv', _encode(82_70));
    _addUpdateToRiskOracle(_aWBTC, 'liquidationThreshold', _encode(86_20));

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

  function _addUpdateToRiskOracle() internal override {
    vm.startPrank(_riskOracleOwner);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encode(82_75),
      'ltv',
      _aWETH,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addMarket(address market) internal {
    address[] memory markets = new address[](1);
    markets[0] = market;

    vm.prank(_stewardsInjectorOwner);
    AaveStewardInjectorCollateral(address(_stewardInjector)).addMarkets(markets);
  }

  function _addMultipleUpdatesToRiskOracleOfDifferentMarkets(uint160 count) internal {
    for (uint160 i = 0; i < count; i++) {
      vm.startPrank(_riskOracleOwner);

      address market = address(i);
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(82_50),
        'ltv',
        market,
        'additionalData'
      );
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(86_00),
        'liquidationThreshold',
        market,
        'additionalData'
      );
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encode(5_00),
        'liquidationBonus',
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
