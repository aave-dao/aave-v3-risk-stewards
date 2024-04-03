// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ConfigConstants
 * @author BGD labs
 * @notice Library storing the configuration constants for the risk params.
 */
library ConfigConstants {
  /**
   * @notice The permitted percentage change in supply cap is determined by the relative percentage value.
   */
  bool public constant IS_SUPPLY_CAP_CHANGE_RELATIVE = true;
  /**
   * @notice The permitted percentage change in borrow cap is determined by the relative percentage value.
   */
  bool public constant IS_BORROW_CAP_CHANGE_RELATIVE = true;
  /**
   * @notice The permitted percentage change in optimal usage ratio is determined by the absolute percentage value.
   */
  bool public constant IS_OPTIMAL_USAGE_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in base variable borrow rate is determined by the absolute percentage value.
   */
  bool public constant IS_BASE_VARIABLE_BORROW_RATE_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in variable rate slope 1 is determined by the absolute percentage value.
   */
  bool public constant IS_VARIABLE_RATE_SLOPE_1_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in variable rate slope 2 is determined by the absolute percentage value.
   */
  bool public constant IS_VARIABLE_RATE_SLOPE_2_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in ltv is determined by the absolute percentage value.
   */
  bool public constant IS_LTV_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in liquidation threshold is determined by the absolute percentage value.
   */
  bool public constant IS_LIQUDATION_THRESHOLD_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in liquidation bonus is determined by the absolute percentage value.
   */
  bool public constant IS_LIQUIDATION_BONUS_CHANGE_RELATIVE = false;
  /**
   * @notice The permitted percentage change in debt ceiling is determined by the relative percentage value.
   */
  bool public constant IS_DEBT_CEILING_CHANGE_RELATIVE = true;
}
