// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {RiskOracle} from '../src/contracts/dependencies/RiskOracle.sol';
import {AaveStewardInjectorBase, OwnableWithGuardian, IAaveStewardInjectorBase} from '../src/contracts/AaveStewardInjectorBase.sol';
import {IWithGuardian} from 'solidity-utils/contracts/access-control/interfaces/IWithGuardian.sol';
import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';

abstract contract AaveStewardsInjectorBaseTest is TestnetProcedures {
  IRiskSteward _riskSteward;
  RiskOracle _riskOracle;
  AaveStewardInjectorBase _stewardInjector;

  address _riskOracleOwner = address(20);
  address _stewardsInjectorOwner = address(25);
  address _stewardsInjectorGuardian = address(30);

  function setUp() public virtual {
    initTestEnvironment();

    vm.warp(5 days);
  }

  function test_injection() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_disableUpdate() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(1))
    );
    _stewardInjector.disableUpdateById(1, true);

    assertFalse(_stewardInjector.isDisabled(1));

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.UpdateDisabled(1, true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.disableUpdateById(1, true);

    assertTrue(_stewardInjector.isDisabled(1));

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.UpdateDisabled(1, false);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.disableUpdateById(1, false);

    assertFalse(_stewardInjector.isDisabled(1));

    isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_injectorPaused() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(IWithGuardian.OnlyGuardianOrOwnerInvalidCaller.selector, address(1))
    );
    _stewardInjector.pauseInjector(true);

    assertFalse(_stewardInjector.isInjectorPaused());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.InjectorPaused(true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.pauseInjector(true);

    assertTrue(_stewardInjector.isInjectorPaused());

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.InjectorPaused(false);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.pauseInjector(false);

    assertFalse(_stewardInjector.isInjectorPaused());

    isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_isUpdatedIdExecuted() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    assertFalse(_stewardInjector.isUpdateIdExecuted(1));

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
    assertTrue(_stewardInjector.isUpdateIdExecuted(1));

    isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);
  }

  function test_expiredUpdate() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    uint256 initialTs = block.timestamp;
    vm.warp(initialTs + _stewardInjector.EXPIRATION_PERIOD());

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.warp(initialTs);
    isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_reverts_sameUpdateInjectedTwice() public {
    _addUpdateToRiskOracle(); // updateId 1

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);

    (bool shouldRunKeeper, bytes memory performData) = _stewardInjector.checkUpkeep('');
    _stewardInjector.performUpkeep(performData);
    assertTrue(shouldRunKeeper);

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(performData);
  }

  function test_addMarkets() public {
    address marketToAdd = address(999);
    address[] memory markets = new address[](1);
    markets[0] = marketToAdd;

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1))
    );
    _stewardInjector.addMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.MarketAdded(marketToAdd);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.addMarkets(markets);

    address[] memory newMarkets = _stewardInjector.getMarkets();
    assertEq(newMarkets.length, 2);
    assertEq(marketToAdd, newMarkets[1]);
  }

  function test_removeMarkets() public {
    address[] memory markets = _stewardInjector.getMarkets();
    assertEq(markets.length, 1);

    vm.prank(address(1));
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(1))
    );
    _stewardInjector.removeMarkets(markets);

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.MarketRemoved(markets[0]);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.removeMarkets(markets);

    address[] memory newMarkets = _stewardInjector.getMarkets();
    assertEq(newMarkets.length, 0);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.removeMarkets(markets);
    newMarkets = _stewardInjector.getMarkets();
    assertEq(newMarkets.length, 0);
  }

  function test_perform_invalidMarketPassed() public {
    address invalidMarket = address(3939);
    (string memory updateType,) = _addUpdateToRiskOracle(invalidMarket);

    IAaveStewardInjectorBase.ActionData memory action = IAaveStewardInjectorBase.ActionData({
      market: invalidMarket,
      updateType: updateType
    });

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function test_perform_invalidUpdateTypePassed() public {
    (, address market) = _addUpdateToRiskOracle('wrongUpdateType');

    IAaveStewardInjectorBase.ActionData memory action = IAaveStewardInjectorBase.ActionData({
      market: market,
      updateType: 'wrongUpdateType'
    });

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(action));
  }

  function _addUpdateToRiskOracle() internal virtual returns (string memory updateType, address market);

  function _addUpdateToRiskOracle(address market) internal virtual returns (string memory, address);

  function _addUpdateToRiskOracle(string memory updateType) internal virtual returns (string memory, address);

  function _checkAndPerformAutomation() internal virtual returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = _stewardInjector.checkUpkeep('');
    if (shouldRunKeeper) {
      _stewardInjector.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }
}
