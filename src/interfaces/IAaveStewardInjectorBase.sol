// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAaveStewardInjectorBase
 * @author BGD Labs
 * @notice Defines the interface for the base injector contract to automate actions for Risk Steward.
 **/
interface IAaveStewardInjectorBase {
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
   * @notice Emitted when the injector is paused/unpaused.
   * @param isPaused true if the injector is being paused, false otherwise.
   */
  event InjectorPaused(bool indexed isPaused);

  /**
   * @notice Emitted when a market is whitelisted.
   * @param market the address of the market.
   */
  event MarketAdded(address indexed market);

  /**
   * @notice Emitted when a market is removed from the whitelist.
   * @param market the address of the market.
   */
  event MarketRemoved(address indexed market);

  /**
   * @notice The following update cannot be injected in the steward injector because the conditions are not met.
   */
  error UpdateCannotBeInjected();

  /**
   * @notice struct holding action for which update can be performed.
   * @param market market address for which action needs to be performed.
   * @param updateType updateType for which action needs to be performed.
   */
  struct ActionData {
    address market;
    string updateType;
  }

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
  function disableUpdateById(uint256 updateId, bool disabled) external;

  /**
   * @notice method to check if the updateId from the risk oracle has been executed/injected into the risk steward.
   * @param updateId the updateId from the risk oracle to check if already executed/injected.
   * @return bool true if the updateId is executed/injected, false otherwise.
   */
  function isUpdateIdExecuted(uint256 updateId) external view returns (bool);

  /**
   * @notice method called by owner to pause/unpause the injector.
   * @param isPaused true if the injector is being paused, false otherwise.
   */
  function pauseInjector(bool isPaused) external;

  /**
   * @notice method to check if the injector is paused.
   * @return true if the injector is paused, false otherwise.
   */
  function isInjectorPaused() external view returns (bool);

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

  /**
   * @notice method to get the whitelisted markets addresses on the injector.
   * @return array of whitelisted markets addresses.
   */
  function getMarkets() external view returns (address[] memory);

  /**
   * @notice method called by the owner to whitelist markets on the injector.
   * @param markets array of addresses to whitelist.
   */
  function addMarkets(address[] calldata markets) external;

  /**
   * @notice method called by the owner to remove whitelisted markets on the injector.
   * @param markets array of addresses to remove from whitelist.
   */
  function removeMarkets(address[] calldata markets) external;

  /**
   * @notice method to get all the valid update types.
   * @param updateTypes array of updateTypes.
   */
  function getUpdateTypes() external view returns (string[] memory updateTypes);
}
