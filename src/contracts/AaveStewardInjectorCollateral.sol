// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {IAToken} from 'aave-v3-origin/src/contracts/interfaces/IAToken.sol';

/**
 * @title AaveStewardInjectorCollateral
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform collateral update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorCollateral is AaveStewardInjectorBase {
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

  /// @inheritdoc AaveStewardInjectorBase
  function getUpdateTypes() public pure override returns (string[] memory updateTypes) {
    updateTypes = new string[](1);
    updateTypes[0] = 'CollateralUpdate';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal override {
    address underlyingAddress = IAToken(riskParams.market).UNDERLYING_ASSET_ADDRESS();
    (uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus) = abi.decode(riskParams.newValue, (uint256, uint256, uint256));

    IEngine.CollateralUpdate[] memory collateralUpdate = new IEngine.CollateralUpdate[](1);
    collateralUpdate[0] = IEngine.CollateralUpdate({
      asset: underlyingAddress,
      ltv: ltv,
      liqThreshold: liquidationThreshold,
      liqBonus: liquidationBonus,
      debtCeiling: EngineFlags.KEEP_CURRENT,
      liqProtocolFee: EngineFlags.KEEP_CURRENT
    });
    IRiskSteward(RISK_STEWARD).updateCollateralSide(collateralUpdate);
  }
}
