// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';

/**
 * @title AaveStewardInjectorRates
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform interest rate update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorRates is AaveStewardInjectorBase {
  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param markets list of market addresses to allow.
   * @param owner address of the owner of the stewards injector.
   * @param guardian address of the guardian of the stewards injector.
   */
  constructor(
    address riskOracle,
    address riskSteward,
    address[] memory markets,
    address owner,
    address guardian
  ) AaveStewardInjectorBase(riskOracle, riskSteward, markets, owner, guardian) {}

  function getUpdateTypes() public pure override returns (string[] memory updateTypes) {
    updateTypes = new string[](1);
    updateTypes[0] = 'RateStrategyUpdate';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal override {
    IEngine.RateStrategyUpdate[] memory rateUpdate = new IEngine.RateStrategyUpdate[](1);
    rateUpdate[0].asset = riskParams.market;
    rateUpdate[0].params = abi.decode(riskParams.newValue, (IEngine.InterestRateInputData));

    IRiskSteward(RISK_STEWARD).updateRates(rateUpdate);
  }
}
