// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveStewardInjectorBase} from './IAaveStewardInjectorBase.sol';

/**
 * @title IAaveStewardInjectorRates
 * @author BGD Labs
 * @notice Defines the interface for the injector contract to automate rate updates on Risk Steward.
 **/
interface IAaveStewardInjectorRates is IAaveStewardInjectorBase {
  /**
   * @notice method to get the whitelisted update type for which injection is allowed from the risk oracle into the stewards.
   * @return string for the whitelisted update type - interest rate update.
   */
  function WHITELISTED_UPDATE_TYPE() external view returns (string memory);

  /**
   * @notice method to get the whitelisted asset for which injection is allowed from the risk oracle into the stewards.
   * @return address for the whitelisted asset.
   */
  function WHITELISTED_ASSET() external view returns (address);
}
