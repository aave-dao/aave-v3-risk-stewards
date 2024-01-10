// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RiskStewardErrors
 * @author BGD labs
 * @notice Library with all the potential errors to be thrown by the steward
 */
library RiskStewardErrors {
  /**
   * @notice Only the permissioned council is allowed to call methods on the steward.
   */
  string public constant INVALID_CALLER = 'INVALID_CALLER';
  /**
   * @notice The steward only allows cap increases.
   */
  string public constant NOT_STRICTLY_HIGHER = 'NOT_STRICTLY_HIGHER';
  /**
   * @notice A single cap can only be increased once every 5 days
   */
  string public constant DEBOUNCE_NOT_RESPECTED = 'DEBOUNCE_NOT_RESPECTED';
  /**
   * @notice A single cap increase must not increase the cap by more than 100%
   */
  string public constant UPDATE_NOT_IN_RANGE = 'UPDATE_NOT_IN_RANGE';
  /**
   * @notice There must be at least one cap update per execution
   */
  string public constant NO_ZERO_UPDATES = 'NO_ZERO_UPDATES';
  /**
   * @notice The steward does allow updates of caps, but not the initialization of non existing caps.
   */
  string public constant NO_CAP_INITIALIZE = 'NO_CAP_INITIALIZE';

  string public constant PARAM_CHANGE_NOT_ALLOWED = 'PARAM_CHANGE_NOT_ALLOWED';
}
