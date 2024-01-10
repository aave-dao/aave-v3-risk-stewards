// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {EngineFlags} from 'aave-helpers/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine} from 'aave-helpers/v3-config-engine/IAaveV3ConfigEngine.sol';

/**
 * @title IRiskSteward
 * @author BGD labs
 * @notice Contract managing caps increasing on an aave v3 pool
 */
interface IRiskSteward {
  /**
   * @notice Stuct storing the last update of a specific cap
   */
  struct Debounce {
    uint40 supplyCapLastUpdated;
    uint40 borrowCapLastUpdated;
    uint40 ltvLastUpdated;
    uint40 liqBonusLastUpdated;
    uint40 liqThresholdLastUpdated;
    uint40 debtCeilingLastUpdated;
    uint40 baseVariableRateLastUpdated;
    uint40 variableRateSlope1LastUpdated;
    uint40 variableRateSlope2LastUpdated;
    uint40 optimalUsageRatioLastUpdated;
  }

  struct RiskParamConfig {
    uint40 minDelay;
    uint256 maxPercentChange;
  }

  struct Config {
    RiskParamConfig ltv;
    RiskParamConfig liquidationThreshold;
    RiskParamConfig liquidationBonus;
    RiskParamConfig supplyCap;
    RiskParamConfig borrowCap;
    RiskParamConfig debtCeiling;
    RiskParamConfig baseVariableBorrowRate;
    RiskParamConfig variableRateSlope1;
    RiskParamConfig variableRateSlope2;
    RiskParamConfig optimalUsageRatio;
  }

  /**
   * @notice The minimum delay that must be respected between updating a specific cap twice
   */
  function MINIMUM_DELAY() external pure returns (uint256);

  /**
   * @notice The config engine used to perform the cap update via delegatecall
   */
  function CONFIG_ENGINE() external view returns (IAaveV3ConfigEngine);

  /**
   * @notice The pool data provider of the POOL the steward controls
   */
  function POOL_DATA_PROVIDER() external view returns (IPoolDataProvider);

  /**
   * @notice The safe controlling the steward
   */
  function RISK_COUNCIL() external view returns (address);

  /**
   * @notice Allows increasing borrow and supply caps accross multiple assets
   * @dev A cap increase is only possible ever 5 days per asset
   * @dev A cap increase is only allowed to increase the cap by 50%
   * @param capUpdates caps to be updated
   */
  function updateCaps(IAaveV3ConfigEngine.CapsUpdate[] calldata capUpdates) external;

  function updateRates(IAaveV3ConfigEngine.RateStrategyUpdate[] calldata rateUpdates) external;

  function updateCollateralSide(IAaveV3ConfigEngine.CollateralUpdate[] calldata collateralUpdates) external;

  /**
   * @notice Returns the timelock for a specific asset
   * @param asset for which to fetch the timelock
   */
  function getTimelock(address asset) external view returns (Debounce memory);
}
