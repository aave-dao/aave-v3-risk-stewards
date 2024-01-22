// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RiskStewardErrors
 * @author BGD labs
 * @notice Library with all the potential errors to be thrown by the steward
 */
library RiskStewardErrors {
  /**
   * @notice Only the permissioned council is allowed to call methods on the steward
   */
  string public constant INVALID_CALLER = 'INVALID_CALLER';
  /**
   * @notice A single risk param update can only be changed after the minimum delay configured has passed
   */
  string public constant DEBOUNCE_NOT_RESPECTED = 'DEBOUNCE_NOT_RESPECTED';
  /**
   * @notice A single risk param update must not be increased / decreased by maxPercentChange configured
   */
  string public constant UPDATE_NOT_IN_RANGE = 'UPDATE_NOT_IN_RANGE';
  /**
   * @notice There must be at least one risk param update per execution
   */
  string public constant NO_ZERO_UPDATES = 'NO_ZERO_UPDATES';
  /**
   * @notice The steward does not allow the risk param change for the param given
   */
  string public constant PARAM_CHANGE_NOT_ALLOWED = 'PARAM_CHANGE_NOT_ALLOWED';
  /**
   * @notice The steward does not allow updates of risk param of a restricted asset
   */
  string public constant ASSET_RESTRICTED = 'ASSET_RESTRICTED';
}
