// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';

/**
 * @title AaveStewardInjectorEMode
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform EMode category update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorEMode is AaveStewardInjectorBase {
  using SafeCast for uint160;

  /// @notice Struct containing the eMode category update
  struct EModeCategoryUpdate {
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
  }

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
    updateTypes[0] = 'EModeCategoryUpdate_Core';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(IRiskOracle.RiskParameterUpdate memory riskParams) internal override {
    EModeCategoryUpdate memory update = abi.decode(riskParams.newValue, (EModeCategoryUpdate));

    // eMode category id is encoded in the market address
    uint8 eModeId = uint160(riskParams.market).toUint8();

    IEngine.EModeCategoryUpdate[] memory eModeUpdate = new IEngine.EModeCategoryUpdate[](1);
    eModeUpdate[0] = IEngine.EModeCategoryUpdate({
      eModeCategory: eModeId,
      ltv: update.ltv,
      liqThreshold: update.liqThreshold,
      liqBonus: update.liqBonus,
      label: EngineFlags.KEEP_CURRENT_STRING
    });
    IRiskSteward(RISK_STEWARD).updateEModeCategories(eModeUpdate);
  }
}
