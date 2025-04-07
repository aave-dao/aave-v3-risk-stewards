// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {IAToken} from 'aave-v3-origin/src/contracts/interfaces/IAToken.sol';

/**
 * @title AaveStewardInjectorCollateral
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform collateral update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorCollateral is AaveStewardInjectorBase {
  using Strings for string;

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
    updateTypes = new string[](3);
    updateTypes[0] = 'ltv';
    updateTypes[1] = 'liquidationThreshold';
    updateTypes[2] = 'liquidationBonus';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal override {
    address underlyingAddress = IAToken(riskParams.market).UNDERLYING_ASSET_ADDRESS();
    uint256 collateralValue = uint256(bytes32(riskParams.newValue));

    IEngine.CollateralUpdate[] memory collateralUpdate = new IEngine.CollateralUpdate[](1);
    if (riskParams.updateType.equal('ltv')) {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: collateralValue,
        liqThreshold: EngineFlags.KEEP_CURRENT,
        liqBonus: EngineFlags.KEEP_CURRENT,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    } else if (riskParams.updateType.equal('liquidationThreshold')) {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: EngineFlags.KEEP_CURRENT,
        liqThreshold: collateralValue,
        liqBonus: EngineFlags.KEEP_CURRENT,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    } else {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: EngineFlags.KEEP_CURRENT,
        liqThreshold: EngineFlags.KEEP_CURRENT,
        liqBonus: collateralValue,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    }

    IRiskSteward(RISK_STEWARD).updateCollateralSide(collateralUpdate);
  }
}
