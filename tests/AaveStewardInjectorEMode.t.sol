// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorEMode} from '../src/contracts/AaveStewardInjectorEMode.sol';
import {IAaveStewardInjectorBase} from '../src/interfaces/IAaveStewardInjectorBase.sol';
import {EdgeRiskStewardEMode} from '../src/contracts/EdgeRiskStewardEMode.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorEMode_Test is AaveStewardsInjectorBaseTest {
  using SafeCast for uint256;

  uint8 internal _eModeIdOne = 1;
  uint8 internal _eModeIdTwo = 2;
  uint8 internal _eModeIdThree = 3;
  string internal _updateType = 'EModeCategoryUpdate_Core';

  function setUp() public override {
    super.setUp();

    IRiskSteward.RiskParamConfig memory defaultRiskParamConfig = IRiskSteward.RiskParamConfig({
      minDelay: 1 days,
      maxPercentChange: 25 // 0.25% change allowed
    });
    IRiskSteward.Config memory riskConfig;
    riskConfig.eModeConfig.ltv = defaultRiskParamConfig;
    riskConfig.eModeConfig.liquidationThreshold = defaultRiskParamConfig;
    riskConfig.eModeConfig.liquidationBonus = defaultRiskParamConfig;

    // setup risk oracle
    vm.startPrank(_riskOracleOwner);
    address[] memory initialSenders = new address[](2);
    initialSenders[0] = _riskOracleOwner;

    string[] memory initialUpdateTypes = new string[](2);
    initialUpdateTypes[0] = _updateType;
    initialUpdateTypes[1] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );

    address[] memory markets = new address[](1);
    markets[0] = _encodeUintToAddress(_eModeIdOne);

    _stewardInjector = new AaveStewardInjectorEMode(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      markets,
      _stewardsInjectorOwner,
      _stewardsInjectorGuardian
    );

    // setup risk steward
    _riskSteward = new EdgeRiskStewardEMode(
      address(contracts.poolProxy),
      report.configEngine,
      address(_stewardInjector),
      address(this),
      riskConfig
    );
    vm.assertEq(computedRiskStewardAddress, address(_riskSteward));
    vm.stopPrank();

    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setEModeCategory(_eModeIdOne, 82_50, 86_00, 105_00, 'EMode_1');
    contracts.poolConfiguratorProxy.setEModeCategory(_eModeIdTwo, 82_50, 86_00, 105_00, 'EMode_2');
    contracts.poolConfiguratorProxy.setEModeCategory(
      _eModeIdThree,
      82_50,
      86_00,
      105_00,
      'EMode_3'
    );
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
    vm.stopPrank();
  }

  function test_multipleMarketInjection() public {
    _addMarket(_encodeUintToAddress(_eModeIdTwo));

    _addUpdateToRiskOracle(
      _encodeUintToAddress(_eModeIdOne),
      _updateType,
      _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT)
    );
    _addUpdateToRiskOracle(
      _encodeUintToAddress(_eModeIdTwo),
      _updateType,
      _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT)
    );

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleMarketInjection() public {
    _addMarket(_encodeUintToAddress(_eModeIdTwo));
    _addMarket(_encodeUintToAddress(_eModeIdThree));

    _addUpdateToRiskOracle(
      _encodeUintToAddress(_eModeIdOne),
      _updateType,
      _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT)
    );
    _addUpdateToRiskOracle(
      _encodeUintToAddress(_eModeIdTwo),
      _updateType,
      _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT)
    );
    _addUpdateToRiskOracle(
      _encodeUintToAddress(_eModeIdThree),
      _updateType,
      _encodeCollateralUpdate(82_70, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT)
    );

    uint256 snapshot = vm.snapshotState();

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    assertTrue(vm.revertToState(snapshot));
    vm.warp(block.timestamp + 3);

    // previous updateId order of execution: 2, 1, 3
    // updateId order of execution:          1, 3, 2
    // we can see with block.timestamp changing the order of execution of action changes as well

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

  function _addUpdateToRiskOracle()
    internal
    override
    returns (string memory updateType, address market)
  {
    vm.startPrank(_riskOracleOwner);
    updateType = _updateType;
    market = _encodeUintToAddress(_eModeIdOne);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encodeCollateralUpdate(82_75, 86_25, 5_25),
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
      _encodeCollateralUpdate(82_75, 86_25, 5_25),
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
    address market = _encodeUintToAddress(_eModeIdOne);

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encodeCollateralUpdate(82_50, 86_00, 5_00),
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
    AaveStewardInjectorEMode(address(_stewardInjector)).addMarkets(markets);
  }

  function _addMultipleUpdatesToRiskOracleOfDifferentMarkets(uint160 count) internal {
    for (uint160 i = 0; i < count; i++) {
      vm.startPrank(_riskOracleOwner);

      address market = address(i);
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encodeCollateralUpdate(82_50, 86_00, 5_00),
        _updateType,
        market,
        'additionalData'
      );
      vm.stopPrank();

      _addMarket(market);
    }
  }

  function _encodeCollateralUpdate(
    uint256 ltv,
    uint256 liqThreshold,
    uint256 liqBonus
  ) internal pure returns (bytes memory) {
    return
      abi.encode(
        AaveStewardInjectorEMode.EModeCategoryUpdate({
          ltv: ltv,
          liqThreshold: liqThreshold,
          liqBonus: liqBonus
        })
      );
  }

  function _encodeUintToAddress(uint256 value) internal pure returns (address) {
    return address(value.toUint160());
  }
}
