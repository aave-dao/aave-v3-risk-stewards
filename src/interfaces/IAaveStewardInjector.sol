// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AutomationCompatibleInterface} from '../contracts/dependencies/AutomationCompatibleInterface.sol';

/**
 * @title IAaveStewardInjector
 * @author BGD Labs
 * @notice Defines the interface for the injector contract to automate actions for Risk Steward.
 **/
interface IAaveStewardInjector is AutomationCompatibleInterface {
  /**
   * @notice Emitted when performUpkeep is called and an update is injected into the risk steward.
   * @param updateId the risk oracle update id injected into the risk steward.
   */
  event ActionSucceeded(uint256 indexed updateId);

  /**
   * @notice Emitted when injection of a updateId is disabled/enabled.
   * @param updateId the risk oracle update id for which automation is disabled/enabled.
   * @param disabled true if updateId is disabled, false otherwise.
   */
  event UpdateDisabled(uint256 indexed updateId, bool indexed disabled);

  /**
   * @notice Emitted when the valid updateType on the steward injector is changed.
   * @param updateType the updateType for which the valid status on the steward injector is changed.
   * @param isValid true if the following updateType is valid, false otherwise.
   */
  event UpdateTypeChanged(string indexed updateType, bool indexed isValid);

  /**
   * @notice Emitted when the status of whitelisted for an asset on the steward injector is changed.
   * @param contractAddress the contract address which for which the whitelisted status is changed.
   * @param isWhitelisted true if the contract address is being whitelisted, false otherwise.
   */
  event AddressWhitelisted(address indexed contractAddress, bool indexed isWhitelisted);

  /**
   * @notice The following update cannot be injected in the steward injector because the conditions are not met.
   */
  error UpdateCannotBeInjected();

  /**
   * @notice method to check if injection of a updateId on risk steward is disabled.
   * @param updateId updateId from risk oracle to check if disabled.
   * @return bool if updateId is disabled or not.
   **/
  function isDisabled(uint256 updateId) external view returns (bool);

  /**
   * @notice method called by owner to disable/enabled injection of a updateId on risk steward.
   * @param updateId updateId from risk oracle for which we need to disable/enable injection.
   * @param disabled true if updateId should be disabled, false otherwise.
   */
  function disableAutomationById(uint256 updateId, bool disabled) external;

  /**
   * @notice method called by owner to whitelist an update type on the steward injector.
   * @param updateType string from the risk oracle to be whitelisted on the steward injector.
   * @param isValid true if updateType should be whitelisted, false otherwise.
   */
  function addUpdateType(string memory updateType, bool isValid) external;

  /**
   * @notice method to check if an update type on the steward injector is valid or not.
   * @param updateType string from the risk oracle to check if valid.
   * @return bool true if updateType is valid, false otherwise.
   */
  function isValidUpdateType(string memory updateType) external view returns (bool);

  /**
   * @notice method to whitelist an address on the steward injector.
   * @param contractAddress the contract address which for which the whitelisted status is updated.
   * @param isWhitelisted true if the contract address is being whitelisted, false otherwise.
   */
  function whitelistAddress(address contractAddress, bool isWhitelisted) external;

  /**
   * @notice method to check if the contract address is whitelisted on the steward injector.
   * @param contractAddress the contract address to check for the whitelisted status.
   * @return bool true if the contract address is whitelisted, false otherwise.
   */
  function isWhitelistedAddress(address contractAddress) external view returns (bool);

  /**
   * @notice method to check if the updateId from the risk oracle has been executed/injected into the risk steward.
   * @param updateid the updateId from the risk oracle to check if already executed/injected.
   * @return bool true if the updateId is executed/injected, false otherwise.
   */
  function isUpdateIdExecuted(uint256 updateid) external view returns (bool);

  /**
   * @notice method to get maximum number of updateIds to check before the latest updateId, if an injection could be performed upon.
   * @return max number of skips.
   */
  function MAX_SKIP() external view returns (uint256);

  /**
   * @notice method to get the address of the edge risk oracle contract.
   * @return edge risk oracle contract address.
   */
  function RISK_ORACLE() external view returns (address);

  /**
   * @notice method to get the address of the aave risk steward contract.
   * @return aave risk steward contract address.
   */
  function RISK_STEWARD() external view returns (address);

  /**
   * @notice method to get the expiration time for an update from the risk oracle.
   * @return time in seconds of the expiration time.
   */
  function EXPIRATION_PERIOD() external view returns (uint256);
}
