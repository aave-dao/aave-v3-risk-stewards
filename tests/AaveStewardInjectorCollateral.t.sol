// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorCollateral} from '../src/contracts/AaveStewardInjectorCollateral.sol';
import {IAaveStewardInjectorBase} from '../src/interfaces/IAaveStewardInjectorBase.sol';
import {EdgeRiskStewardCollateral} from '../src/contracts/EdgeRiskStewardCollateral.sol';
import {IAToken} from 'aave-v3-origin/src/contracts/interfaces/IAToken.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import './AaveStewardsInjectorBase.t.sol';

contract AaveStewardsInjectorCollateral_Test is AaveStewardsInjectorBaseTest {
  address internal _aWETH;
  address internal _aWBTC;
  address internal _aUSDX;

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
    address[] memory initialSenders = new address[](2);
    initialSenders[0] = _riskOracleOwner;

    string[] memory initialUpdateTypes = new string[](2);
    initialUpdateTypes[0] = 'CollateralUpdate';
    initialUpdateTypes[1] = 'wrongUpdateType';

    _riskOracle = new RiskOracle('RiskOracle', initialSenders, initialUpdateTypes);
    vm.stopPrank();

    _aWETH = _getAToken(address(weth));
    _aWBTC = _getAToken(address(wbtc));
    _aUSDX = _getAToken(address(usdx));

    // setup steward injector
    vm.startPrank(_stewardsInjectorOwner);

    address computedRiskStewardAddress = vm.computeCreateAddress(
      _stewardsInjectorOwner,
      vm.getNonce(_stewardsInjectorOwner) + 1
    );
    address[] memory markets = new address[](1);
    markets[0] = _aWETH;

    _stewardInjector = new AaveStewardInjectorCollateral(
      address(_riskOracle),
      address(computedRiskStewardAddress),
      markets,
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

    vm.prank(poolAdmin);
    contracts.aclManager.addRiskAdmin(address(_riskSteward));
  }

  function test_multipleMarketInjection() public {
    _addMarket(_aWBTC);

    _addUpdateToRiskOracle(_aWETH, 'CollateralUpdate', _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT));
    _addUpdateToRiskOracle(_aWBTC, 'CollateralUpdate', _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT));

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());
  }

  function test_randomized_multipleMarketInjection() public {
    _addMarket(_aWBTC);
    _addMarket(_aUSDX);

    _addUpdateToRiskOracle(_aWETH, 'CollateralUpdate', _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT));
    _addUpdateToRiskOracle(_aUSDX, 'CollateralUpdate', _encodeCollateralUpdate(82_75, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT));
    _addUpdateToRiskOracle(_aWBTC, 'CollateralUpdate', _encodeCollateralUpdate(82_70, EngineFlags.KEEP_CURRENT, EngineFlags.KEEP_CURRENT));

    uint256 snapshot = vm.snapshotState();

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(3);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    assertTrue(vm.revertToState(snapshot));
    vm.warp(block.timestamp + 3);

    // previous updateId order of execution: 3, 1, 2
    // updateId order of execution:          1, 2, 3
    // we can see with block.timestamp changing the order of execution of action changes as well

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(1);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(2);
    assertTrue(_checkAndPerformAutomation());

    vm.expectEmit(address(_stewardInjector));
    emit IAaveStewardInjectorBase.ActionSucceeded(3);
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
    updateType = 'CollateralUpdate';
    market = _aWETH;

    _riskOracle.publishRiskParameterUpdate(
      'referenceId',
      _encodeCollateralUpdate(82_75, 86_25, 5_25),
      updateType,
      market,
      'additionalData'
    );
    vm.stopPrank();
  }

  function _addUpdateToRiskOracle(address market) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    string memory updateType = 'CollateralUpdate';

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

  function _addUpdateToRiskOracle(string memory updateType) internal override returns (string memory, address) {
    vm.startPrank(_riskOracleOwner);
    address market = _aWETH;

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
    AaveStewardInjectorCollateral(address(_stewardInjector)).addMarkets(markets);
  }

  function _addMultipleUpdatesToRiskOracleOfDifferentMarkets(uint160 count) internal {
    for (uint160 i = 0; i < count; i++) {
      vm.startPrank(_riskOracleOwner);

      address market = address(i);
      _riskOracle.publishRiskParameterUpdate(
        'referenceId',
        _encodeCollateralUpdate(82_50, 86_00, 5_00),
        'CollateralUpdate',
        market,
        'additionalData'
      );
      vm.stopPrank();

      _addMarket(market);
    }
  }

  function _encodeCollateralUpdate(uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus) internal pure returns (bytes memory) {
    return abi.encode(ltv, liquidationThreshold, liquidationBonus);
  }

  function _getAToken(address underlying) internal view returns (address aToken) {
    (aToken, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(underlying);
  }
}
