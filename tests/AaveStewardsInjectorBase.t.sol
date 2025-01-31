// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {RiskOracle} from '../src/contracts/dependencies/RiskOracle.sol';
import {AaveStewardInjectorBase, IAaveStewardInjectorBase} from '../src/contracts/AaveStewardInjectorBase.sol';

abstract contract AaveStewardsInjectorBaseTest is TestnetProcedures {
  RiskSteward _riskSteward;
  RiskOracle _riskOracle;
  AaveStewardInjectorBase _stewardInjector;

  address _riskOracleOwner = address(20);
  address _stewardsInjectorOwner = address(25);

  event ActionSucceeded(uint256 indexed updateId);
  event AddressWhitelisted(address indexed contractAddress, bool indexed isWhitelisted);
  event UpdateDisabled(uint256 indexed updateId, bool indexed disabled);
  event UpdateTypeChanged(string indexed updateType, bool indexed isValid);
  event InjectorPaused(bool indexed isPaused);

  function setUp() public virtual {
    initTestEnvironment();

    vm.warp(5 days);
  }

  function test_injection() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_disableUpdate() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.prank(address(1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    _stewardInjector.disableUpdateById(1, true);

    assertFalse(_stewardInjector.isDisabled(1));

    vm.expectEmit(address(_stewardInjector));
    emit UpdateDisabled(1, true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.disableUpdateById(1, true);

    assertTrue(_stewardInjector.isDisabled(1));

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit UpdateDisabled(1, false);

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
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    _stewardInjector.pauseInjector(true);

    assertFalse(_stewardInjector.isInjectorPaused());

    vm.expectEmit(address(_stewardInjector));
    emit InjectorPaused(true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.pauseInjector(true);

    assertTrue(_stewardInjector.isInjectorPaused());

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit InjectorPaused(false);

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
    emit ActionSucceeded(1);

    (bool shouldRunKeeper, bytes memory performData) = _stewardInjector.checkUpkeep('');
    _stewardInjector.performUpkeep(performData);
    assertTrue(shouldRunKeeper);

    vm.expectRevert(IAaveStewardInjectorBase.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(performData);
  }

  function _addUpdateToRiskOracle() internal virtual;

  function _checkAndPerformAutomation() internal virtual returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = _stewardInjector.checkUpkeep('');
    if (shouldRunKeeper) {
      _stewardInjector.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }
}
