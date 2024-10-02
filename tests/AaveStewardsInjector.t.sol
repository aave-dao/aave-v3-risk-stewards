// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {RiskSteward, IRiskSteward, IEngine, EngineFlags} from 'src/contracts/RiskSteward.sol';
import {TestnetProcedures} from 'aave-v3-origin/tests/utils/TestnetProcedures.sol';
import {RiskOracle} from '../src/contracts/dependencies/RiskOracle.sol';
import {AaveStewardInjector, IAaveStewardInjector} from '../src/contracts/AaveStewardInjector.sol';

contract AaveStewardsInjector_Test is TestnetProcedures {
  RiskSteward _riskSteward;
  RiskOracle _riskOracle;
  AaveStewardInjector _stewardInjector;

  address _riskOracleOwner = address(20);
  address _stewardsInjectorOwner = address(25);

  event ActionSucceeded(uint256 indexed updateId);
  event AddressWhitelisted(address indexed contractAddress, bool indexed isWhitelisted);
  event UpdateDisabled(uint256 indexed updateId, bool indexed disabled);
  event UpdateTypeChanged(string indexed updateType, bool indexed isValid);

  function setUp() public {
    initTestEnvironment();

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

    _riskOracle = new RiskOracle(
      'RiskOracle',
      initialSenders,
      initialUpdateTypes
    );
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(_stewardsInjectorOwner, vm.getNonce(_stewardsInjectorOwner) + 1);
    _stewardInjector = new AaveStewardInjector(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      _stewardsInjectorOwner
    );
    _stewardInjector.addUpdateType('RateStrategyUpdate', true);
    _stewardInjector.whitelistAddress(address(weth), true);

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

    vm.warp(5 days);
  }

  function test_rateInjection() public {
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

  function test_whitelistAddress() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.prank(address(1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    _stewardInjector.whitelistAddress(address(weth), true);

    assertTrue(_stewardInjector.isWhitelistedAddress(address(weth)));

    vm.expectEmit(address(_stewardInjector));
    emit AddressWhitelisted(address(weth), false);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.whitelistAddress(address(weth), false);

    assertFalse(_stewardInjector.isWhitelistedAddress(address(weth)));

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit AddressWhitelisted(address(weth), true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.whitelistAddress(address(weth), true);

    assertTrue(_stewardInjector.isWhitelistedAddress(address(weth)));

    isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);
  }

  function test_validUpdateType() public {
    // add rate update to risk oracle
    _addUpdateToRiskOracle();

    vm.prank(address(1));
    vm.expectRevert(bytes('Ownable: caller is not the owner'));
    _stewardInjector.addUpdateType('Random', true);

    assertTrue(_stewardInjector.isValidUpdateType('RateStrategyUpdate'));

    vm.expectEmit(address(_stewardInjector));
    emit UpdateTypeChanged('RateStrategyUpdate', false);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.addUpdateType('RateStrategyUpdate', false);

    assertFalse(_stewardInjector.isValidUpdateType('RateStrategyUpdate'));

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit UpdateTypeChanged('RateStrategyUpdate', true);

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.addUpdateType('RateStrategyUpdate', true);

    assertTrue(_stewardInjector.isValidUpdateType('RateStrategyUpdate'));

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

  function test_reverts_oldUpdateExecutedBeforeLatest() public {
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, 5_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 100); // updateId 1
    _addUpdateToRiskOracle(50_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 50); // updateId 2

    // the steward reverts if old updateId 1 is executed before new updateId 2
    vm.expectRevert(IAaveStewardInjector.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(1));

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(2);

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);

    isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);

    // no updates to check so returns false
    isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);
  }

  function test_oldUpdateExecutedBeforeLatest_whenLatestDisabled() public {
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, 5_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 100); // updateId 1
    _addUpdateToRiskOracle(50_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 50); // updateId 2

    vm.prank(_stewardsInjectorOwner);
    _stewardInjector.disableUpdateById(2, true);

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);

    // the steward does not reverts if old updateId 1 is executed before new updateId 2, as latest (updateId 2) is disabled
    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);

    isAutomationPerformed = _checkAndPerformAutomation();
    assertFalse(isAutomationPerformed);
  }

  function test_reverts_sameUpdateInjectedTwice() public {
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, 5_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 100); // updateId 1

    vm.expectEmit(address(_stewardInjector));
    emit ActionSucceeded(1);

    bool isAutomationPerformed = _checkAndPerformAutomation();
    assertTrue(isAutomationPerformed);

    vm.expectRevert(IAaveStewardInjector.UpdateCannotBeInjected.selector);
    _stewardInjector.performUpkeep(abi.encode(1));
  }

  function test_reverts_ifUpdateIdDoesNotExist() public {
    _addUpdateToRiskOracle(EngineFlags.KEEP_CURRENT, 5_00, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT, block.timestamp - 100); // updateId 1

    vm.expectRevert(bytes('Invalid update ID.'));
    _stewardInjector.performUpkeep(abi.encode(0));

    vm.expectRevert(bytes('Invalid update ID.'));
    _stewardInjector.performUpkeep(abi.encode(2));
  }

  function _addUpdateToRiskOracle(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2,
    uint256 updateTimestamp
  ) internal {
    uint256 currentTs = block.timestamp;
    vm.startPrank(_riskOracleOwner);
    vm.warp(updateTimestamp);

    IEngine.InterestRateInputData memory rate = IEngine.InterestRateInputData({
      optimalUsageRatio: optimalUsageRatio,
      baseVariableBorrowRate: baseVariableBorrowRate,
      variableRateSlope1: variableRateSlope1,
      variableRateSlope2: variableRateSlope2
    });
    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      abi.encode(rate),
      'RateStrategyUpdate',
      address(weth),
      'additionalData'
    );
    vm.warp(currentTs);
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle() internal {
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

  function _checkAndPerformAutomation() internal virtual returns (bool) {
    (bool shouldRunKeeper, bytes memory performData) = _stewardInjector.checkUpkeep('');
    if (shouldRunKeeper) {
      _stewardInjector.performUpkeep(performData);
    }
    return shouldRunKeeper;
  }
}
