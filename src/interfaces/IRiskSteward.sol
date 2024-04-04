// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {EngineFlags} from 'aave-helpers/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';

/**
 * @title IRiskSteward
 * @author BGD labs
 * @notice Defines the interface for the contract to manage the risk params updates on aave v3 pool
 */
interface IRiskSteward {
  /**
   * @notice Only the permissioned council is allowed to call methods on the steward
   */
  error InvalidCaller();

  /**
   * @notice A single risk param update can only be changed after the minimum delay configured has passed
   */
  error DebounceNotRespected();

  /**
   * @notice A single risk param update must not be increased / decreased by maxPercentChange configured
   */
  error UpdateNotInRange();

  /**
   * @notice There must be at least one risk param update per execution
   */
  error NoZeroUpdates();

  /**
   * @notice The steward does not allow the risk param change for the param given
   */
  error ParamChangeNotAllowed();

  /**
   * @notice The steward does not allow updates of risk param of a restricted asset
   */
  error AssetIsRestricted();

  /**
   * @notice Setting the risk parameter value to zero is not allowed
   */
  error InvalidUpdateToZero();

  /**
   * @notice Emitted when the owner configures an asset as restricted to be used by steward
   * @param asset address of the underlying asset
   * @param isRestricted true if asset is set as restricted, false otherwise
   */
  event AssetRestricted(address indexed asset, bool indexed isRestricted);

  /**
   * @notice Emitted when the risk configuration for the risk params has been set
   * @param riskConfig struct containing the risk configurations
   */
  event RiskConfigSet(Config indexed riskConfig);

  /**
   * @notice Emitted when the supply cap has been updated using the steward
   * @param asset address of the underlying asset for which supply cap has been updated
   * @param newSupplyCap new supply cap which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new supply cap update
   */
  event SupplyCapUpdated(
    address indexed asset,
    uint256 indexed newSupplyCap,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the borrow cap has been updated using the steward
   * @param asset address of the underlying asset for which borrow cap has been updated
   * @param newBorrowCap new borrow cap which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new borrow cap update
   */
  event BorrowCapUpdated(
    address indexed asset,
    uint256 indexed newBorrowCap,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the uOptimal has been updated using the steward
   * @param asset address of the underlying asset for which uOptimal has been updated
   * @param newOptimalUsageRatio new uOptimal which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new uOptimal update
   */
  event OptimalUsageRatioUpdated(
    address indexed asset,
    uint256 indexed newOptimalUsageRatio,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the base variable borrow rate has been updated using the steward
   * @param asset address of the underlying asset for which base variable borrow rate has been updated
   * @param newBaseVariableBorrowRate new base variable borrow rate which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new base variable borrow rate update
   */
  event BaseVariableBorrowRateUpdated(
    address indexed asset,
    uint256 indexed newBaseVariableBorrowRate,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the variable rate slope 1 has been updated using the steward
   * @param asset address of the underlying asset for which variable rate slope 1 has been updated
   * @param newVariableRateSlope1 new variable rate slope 1 which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new variable rate slope 1 update
   */
  event VariableRateSlope1Updated(
    address indexed asset,
    uint256 indexed newVariableRateSlope1,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the variable rate slope 2 has been updated using the steward
   * @param asset address of the underlying asset for which variable rate slope 2 has been updated
   * @param newVariableRateSlope2 new variable rate slope 2 which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new variable rate slope 2 update
   */
  event VariableRateSlope2Updated(
    address indexed asset,
    uint256 indexed newVariableRateSlope2,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the loan to value has been updated using the steward
   * @param asset address of the underlying asset for which loan to value has been updated
   * @param newLtv new loan to value which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new LTV update
   */
  event LtvUpdated(address indexed asset, uint256 newLtv, uint40 indexed nextAllowedTimestamp);

  /**
   * @notice Emitted when the liquidation threshold has been updated using the steward
   * @param asset address of the underlying asset for which liquidation threshold has been updated
   * @param newLiquidationThreshold new liquidation threshold which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new liquidation threshold update
   */
  event LiquidationThresholdUpdated(
    address indexed asset,
    uint256 newLiquidationThreshold,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the liquidation bonus has been updated using the steward
   * @param asset address of the underlying asset for which liquidation bonus has been updated
   * @param newLiquidationBonus new liquidation bonus which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new liquidation bonus update
   */
  event LiquidationBonusUpdated(
    address indexed asset,
    uint256 newLiquidationBonus,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Emitted when the debt ceiling has been updated using the steward
   * @param asset address of the underlying asset for which debt ceiling has been updated
   * @param newDebtCeiling new debt ceiling which has been set for the asset
   * @param nextAllowedTimestamp next permitted timestamp for a new debt ceiling update
   */
  event DebtCeilingUpdated(
    address indexed asset,
    uint256 newDebtCeiling,
    uint40 indexed nextAllowedTimestamp
  );

  /**
   * @notice Struct storing the last update by the steward of each risk param
   */
  struct Debounce {
    uint40 supplyCapLastUpdated;
    uint40 borrowCapLastUpdated;
    uint40 ltvLastUpdated;
    uint40 liquidationBonusLastUpdated;
    uint40 liquidationThresholdLastUpdated;
    uint40 debtCeilingLastUpdated;
    uint40 baseVariableRateLastUpdated;
    uint40 variableRateSlope1LastUpdated;
    uint40 variableRateSlope2LastUpdated;
    uint40 optimalUsageRatioLastUpdated;
  }

  /**
   * @notice Struct storing the minimum delay and maximum percent change for a risk param
   */
  struct RiskParamConfig {
    uint40 minDelay;
    uint256 maxPercentChange;
  }

  /**
   * @notice Struct storing the risk configuration for all the risk param
   */
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
   * @notice The config engine used to perform the cap update via delegatecall
   */
  function CONFIG_ENGINE() external view returns (IEngine);

  /**
   * @notice The pool data provider of the POOL the steward controls
   */
  function POOL_DATA_PROVIDER() external view returns (IPoolDataProvider);

  /**
   * @notice The safe controlling the steward
   */
  function RISK_COUNCIL() external view returns (address);

  /**
   * @notice Allows increasing borrow and supply caps across multiple assets
   * @dev A cap update is only possible after minDelay has passed after last update
   * @dev A cap increase / decrease is only allowed by a magnitude of maxPercentChange
   * @param capUpdates struct containing new caps to be updated
   */
  function updateCaps(IEngine.CapsUpdate[] calldata capUpdates) external;

  /**
   * @notice Allows updating interest rates params across multiple assets
   * @dev A rate update is only possible after minDelay has passed after last update
   * @dev A rate increase / decrease is only allowed by a magnitude of maxPercentChange
   * @param rateUpdates struct containing new interest rate params to be updated
   */
  function updateRates(IEngine.RateStrategyUpdate[] calldata rateUpdates) external;

  /**
   * @notice Allows updating collateral params across multiple assets
   * @dev A collateral update is only possible after minDelay has passed after last update
   * @dev A collateral increase / decrease is only allowed by a magnitude of maxPercentChange
   * @param collateralUpdates struct containing new collateral rate params to be updated
   */
  function updateCollateralSide(IEngine.CollateralUpdate[] calldata collateralUpdates) external;

  /**
   * @notice method to check if an asset is restricted to be used by the risk stewards
   * @param asset address of the underlying asset
   * @return bool if asset is restricted or not
   */
  function isAssetRestricted(address asset) external view returns (bool);

  /**
   * @notice method called by the owner to set an asset as restricted
   * @param asset address of the underlying asset
   * @param isRestricted true if asset needs to be restricted, false otherwise
   */
  function setAssetRestricted(address asset, bool isRestricted) external;

  /**
   * @notice Returns the timelock for a specific asset i.e the last updated timestamp
   * @param asset for which to fetch the timelock
   * @return struct containing the latest updated timestamps of all the risk params by the steward
   */
  function getTimelock(address asset) external view returns (Debounce memory);

  /**
   * @notice method to get the risk configuration set for all the risk params
   * @return struct containing the risk configurations
   */
  function getRiskConfig() external view returns (Config memory);

  /**
   * @notice method called by the owner to set the risk configuration for the risk params
   * @param riskConfig struct containing the risk configurations
   */
  function setRiskConfig(Config memory riskConfig) external;
}
