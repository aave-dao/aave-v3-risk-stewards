// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {IAToken} from 'aave-v3-origin/src/contracts/interfaces/IAToken.sol';
import {IERC20Metadata} from 'openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol';

/**
 * @title AaveStewardInjectorCaps
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform caps update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorCaps is AaveStewardInjectorBase {
  using Strings for string;

  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param owner address of the owner of the stewards injector.
   * @param guardian address of the guardian of the stewards injector.
   */
  constructor(
    address riskOracle,
    address riskSteward,
    address owner,
    address guardian
  ) AaveStewardInjectorBase(riskOracle, riskSteward, owner, guardian) {}

  /// @inheritdoc AaveStewardInjectorBase
  function getUpdateTypes() public pure override returns (string[] memory updateTypes) {
    updateTypes = new string[](2);
    updateTypes[0] = 'supplyCap';
    updateTypes[1] = 'borrowCap';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal override {
    address underlyingAddress = IAToken(riskParams.market).UNDERLYING_ASSET_ADDRESS();
    uint256 capValue = abi.decode(
      abi.encodePacked(new bytes(32 - riskParams.newValue.length), riskParams.newValue),
      (uint256)
    ) / (10 ** IERC20Metadata(riskParams.market).decimals());

    IEngine.CapsUpdate[] memory capUpdate = new IEngine.CapsUpdate[](1);
    if (riskParams.updateType.equal('supplyCap')) {
      capUpdate[0] = IEngine.CapsUpdate({
        asset: underlyingAddress,
        supplyCap: capValue,
        borrowCap: EngineFlags.KEEP_CURRENT
      });
    } else {
      capUpdate[0] = IEngine.CapsUpdate({
        asset: underlyingAddress,
        supplyCap: EngineFlags.KEEP_CURRENT,
        borrowCap: capValue
      });
    }

    IRiskSteward(RISK_STEWARD).updateCaps(capUpdate);
  }
}
