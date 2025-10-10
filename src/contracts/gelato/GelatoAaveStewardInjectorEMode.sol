// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveStewardInjectorEMode, AaveStewardInjectorBase} from '../AaveStewardInjectorEMode.sol';

/**
 * @title GelatoAaveStewardInjectorEMode
 * @author BGD Labs
 * @notice Contract to perform EMode category update automation using Gelato.
 */
contract GelatoAaveStewardInjectorEMode is AaveStewardInjectorEMode {
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
  ) AaveStewardInjectorEMode(riskOracle, riskSteward, markets, owner, guardian) {}

  /**
   * @inheritdoc AaveStewardInjectorBase
   * @dev the returned bytes is specific to gelato and is encoded with the function selector.
   */
  function checkUpkeep(bytes memory) public view override returns (bool, bytes memory) {
    (bool upkeepNeeded, bytes memory encodedActionDataToExecute) = super.checkUpkeep('');
    return (upkeepNeeded, abi.encodeCall(this.performUpkeep, encodedActionDataToExecute));
  }
}
