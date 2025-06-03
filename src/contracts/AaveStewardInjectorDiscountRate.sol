// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveOracle} from 'aave-v3-origin/src/contracts/interfaces/IAaveOracle.sol';

/**
 * @title AaveStewardInjectorDiscountRate
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform pendle discountRate update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorDiscountRate is AaveStewardInjectorBase {
  IAaveOracle public immutable AAVE_ORACLE;

  /**
   * @param aaveOracle address of the aave oracle of the instance.
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param markets list of market addresses to allow.
   * @param owner address of the owner of the stewards injector.
   * @param guardian address of the guardian of the stewards injector.
   */
  constructor(
    address aaveOracle,
    address riskOracle,
    address riskSteward,
    address[] memory markets,
    address owner,
    address guardian
  ) AaveStewardInjectorBase(riskOracle, riskSteward, markets, owner, guardian) {
    AAVE_ORACLE = IAaveOracle(aaveOracle);
  }

  /// @inheritdoc AaveStewardInjectorBase
  function getUpdateTypes() public pure override returns (string[] memory updateTypes) {
    updateTypes = new string[](1);
    updateTypes[0] = 'PendleDiscountRateUpdate_Core';
  }

  /// @inheritdoc AaveStewardInjectorBase
  function _injectUpdate(IRiskOracle.RiskParameterUpdate memory riskParams) internal override {
    // we get discountRate in BPS from RiskOracle, so we multiply by 1e14 to convert in the format of DiscountRateOracle
    // as 100% discountRate on the DiscountRateOracle is 1e18
    uint256 discountRate = abi.decode(
      abi.encodePacked(new bytes(32 - riskParams.newValue.length), riskParams.newValue),
      (uint256)
    ) * 1e14;

    IRiskSteward.DiscountRatePendleUpdate[] memory discountRateUpdate = new IRiskSteward.DiscountRatePendleUpdate[](1);
    discountRateUpdate[0] = IRiskSteward.DiscountRatePendleUpdate({
      oracle: AAVE_ORACLE.getSourceOfAsset(riskParams.market), // reserve address is encoded in the market address
      discountRate: discountRate
    });
    IRiskSteward(RISK_STEWARD).updatePendleDiscountRates(discountRateUpdate);
  }
}
