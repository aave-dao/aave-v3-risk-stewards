// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveStewardInjectorBase} from './IAaveStewardInjectorBase.sol';

/**
 * @title IAaveStewardInjectorCaps
 * @author BGD Labs
 * @notice Defines the interface for the injector contract to automate caps updates on Risk Steward.
 **/
interface IAaveStewardInjectorCaps is IAaveStewardInjectorBase {
  /**
   * @notice Emitted when a market is whitelisted.
   * @param market the address of the market i.e underlying reserve.
   */
  event MarketAdded(address indexed market);

  /**
   * @notice Emitted when a market is removed from the whitelist.
   * @param market the address of the market i.e underlying reserve.
   */
  event MarketRemoved(address indexed market);

  /**
   * @notice struct holding action for which update can be performed.
   * @param market underlying asset address for which action needs to be performed.
   * @param updateType updateType for which action needs to be performed.
   */
  struct ActionData {
    address market;
    string updateType;
  }

  /**
   * @notice method to get the whitelisted markets / assets on the injector.
   * @return array of whitelisted markets / assets.
   */
  function getMarkets() external view returns (address[] memory);

  /**
   * @notice method called by the owner to whitelist markets on the injector.
   * @param markets array of assets to whitelist.
   */
  function addMarkets(address[] memory markets) external;

  /**
   * @notice method called by the owner to remove whitelisted markets on the injector.
   * @param markets array of assets to remove from whitelist.
   */
  function removeMarkets(address[] memory markets) external;

  /**
   * @notice method to get all the valid update types.
   * @param updateTypes array of updateTypes.
   */
  function getUpdateTypes() external pure returns (string[] memory updateTypes);

  /**
   * @notice method to get the maximum number of updates to check if an action could be performed upon.
   * @return maximum size of updates to check.
   */
  function SIZE() external view returns (uint256);
}
