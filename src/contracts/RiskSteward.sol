// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {EngineFlags} from 'aave-helpers/v3-config-engine/EngineFlags.sol';
import {RiskStewardErrors} from './libraries/RiskStewardErrors.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-helpers/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';

/**
 * @title RiskSteward
 * @author BGD labs
 * @notice Contract to manage the risk params within configured bound on aave v3 pool:
 *         This contract can update the following risk params: caps, ltv, liqThreshold, liqBonus, debtCeiling, interest rates params.
 */
contract RiskSteward is Ownable, IRiskSteward {
  using Address for address;

  /// @inheritdoc IRiskSteward
  IEngine public immutable CONFIG_ENGINE;

  /// @inheritdoc IRiskSteward
  IPoolDataProvider public immutable POOL_DATA_PROVIDER;

  /// @inheritdoc IRiskSteward
  address public immutable RISK_COUNCIL;

  uint256 internal constant BPS_MAX = 100_00;

  Config internal _riskConfig;

  mapping(address => Debounce) internal _timelocks;

  mapping(address => bool) internal _restrictedAssets;

  /**
   * @dev Modifier preventing anyone, but the council to update risk params.
   */
  modifier onlyRiskCouncil() {
    require(RISK_COUNCIL == msg.sender, RiskStewardErrors.INVALID_CALLER);
    _;
  }

  /**
   * @param poolDataProvider The pool data provider of the pool to be controlled by the steward
   * @param engine the config engine to be used by the steward
   * @param riskCouncil the safe address of the council being able to interact with the steward
   * @param riskConfig the risk configuration to setup for each individual risk param
   */
  constructor(
    IPoolDataProvider poolDataProvider,
    IEngine engine,
    address riskCouncil,
    Config memory riskConfig
  ) {
    POOL_DATA_PROVIDER = poolDataProvider;
    RISK_COUNCIL = riskCouncil;
    CONFIG_ENGINE = engine;
    _riskConfig = riskConfig;
  }

  /// @inheritdoc IRiskSteward
  function updateCaps(IEngine.CapsUpdate[] calldata capUpdates) external onlyRiskCouncil {
    require(capUpdates.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < capUpdates.length; i++) {
      address asset = capUpdates[i].asset;

      (uint256 currentBorrowCap, uint256 currentSupplyCap) = POOL_DATA_PROVIDER.getReserveCaps(
        capUpdates[i].asset
      );

      _validateCapsUpdate(currentSupplyCap, currentBorrowCap, capUpdates[i]);
      emit CapsUpdate(asset);
    }
    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCaps.selector, capUpdates)
    );
  }

  /// @inheritdoc IRiskSteward
  function updateRates(IEngine.RateStrategyUpdate[] calldata ratesUpdate) external onlyRiskCouncil {
    require(ratesUpdate.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < ratesUpdate.length; i++) {
      address asset = ratesUpdate[i].asset;

      (
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2
      ) = _getInterestRatesForAsset(asset);

      _validateRatesUpdate(
        optimalUsageRatio,
        baseVariableBorrowRate,
        variableRateSlope1,
        variableRateSlope2,
        ratesUpdate[i]
      );
      emit RateUpdate(asset);
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateRateStrategies.selector, ratesUpdate)
    );
  }

  /// @inheritdoc IRiskSteward
  function updateCollateralSide(
    IEngine.CollateralUpdate[] calldata collateralUpdates
  ) external onlyRiskCouncil {
    require(collateralUpdates.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < collateralUpdates.length; i++) {
      address asset = collateralUpdates[i].asset;

      (
        ,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        ,
        ,
        ,
        ,
        ,

      ) = POOL_DATA_PROVIDER.getReserveConfigurationData(asset);
      uint256 debtCeiling = POOL_DATA_PROVIDER.getDebtCeiling(asset);

      _validateCollateralsUpdate(
        ltv,
        liquidationThreshold,
        liquidationBonus - 100_00, // as the definition is 100% + x%, and config engine takes into account x% for simplicity.
        debtCeiling / 100, // as the definition is with 2 decimals, and config engine does not take the decimals into account.
        collateralUpdates[i]
      );
      emit CollateralUpdate(asset);
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCollateralSide.selector, collateralUpdates)
    );
  }

  /// @inheritdoc IRiskSteward
  function getTimelock(address asset) external view returns (Debounce memory) {
    return _timelocks[asset];
  }

  /// @inheritdoc IRiskSteward
  function setRiskConfig(Config memory riskConfig) external onlyOwner {
    _riskConfig = riskConfig;
    emit RiskConfigSet();
  }

  /// @inheritdoc IRiskSteward
  function getRiskConfig() external view returns (Config memory) {
    return _riskConfig;
  }

  /// @inheritdoc IRiskSteward
  function isAssetRestricted(address asset) external view returns (bool) {
    return _restrictedAssets[asset];
  }

  /// @inheritdoc IRiskSteward
  function setAssetRestricted(address asset, bool isRestricted) external onlyOwner {
    _restrictedAssets[asset] = isRestricted;
    emit AssetRestricted(asset, isRestricted);
  }

  /**
   * @notice method to validate the cap update and to update the debouce
   * @param currentSupplyCap the current supply cap of the asset
   * @param currentBorrowCap the current borrow cap of the asset
   * @param capUpdate struct containing the new supply, borrow cap of the asset
   */
  function _validateCapsUpdate(
    uint256 currentSupplyCap,
    uint256 currentBorrowCap,
    IEngine.CapsUpdate calldata capUpdate
  ) internal {
    address asset = capUpdate.asset;
    require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);
    require(capUpdate.supplyCap != 0 && capUpdate.borrowCap != 0, RiskStewardErrors.INVALID_UPDATE_TO_ZERO);

    if (capUpdate.supplyCap != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentSupplyCap,
        capUpdate.supplyCap,
        _timelocks[asset].supplyCapLastUpdated,
        _riskConfig.supplyCap,
        true
      );

      _timelocks[asset].supplyCapLastUpdated = uint40(block.timestamp);
    }

    if (capUpdate.borrowCap != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentBorrowCap,
        capUpdate.borrowCap,
        _timelocks[asset].borrowCapLastUpdated,
        _riskConfig.borrowCap,
        true
      );

      _timelocks[asset].borrowCapLastUpdated = uint40(block.timestamp);
    }
  }

  /**
   * @notice method to validate the interest rate update and to update the debouce
   * @param currentOptimalUsageRatio the current optimal usage ratio of the asset
   * @param currentBaseVariableBorrowRate the current base variable borrow rate of the asset
   * @param currentVariableRateSlope1 the current variable rate slope 1 of the asset
   * @param currentVariableRateSlope2 the current variable rate slope 2 of the asset
   * @param rateUpdate struct containing the new interest rates params of the asset
   */
  function _validateRatesUpdate(
    uint256 currentOptimalUsageRatio,
    uint256 currentBaseVariableBorrowRate,
    uint256 currentVariableRateSlope1,
    uint256 currentVariableRateSlope2,
    IEngine.RateStrategyUpdate calldata rateUpdate
  ) internal {
    address asset = rateUpdate.asset;
    require(
      rateUpdate.params.stableRateSlope1 == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.stableRateSlope2 == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.baseStableRateOffset == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.stableRateExcessOffset == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.optimalStableToTotalDebtRatio == EngineFlags.KEEP_CURRENT,
      RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED
    );
    require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);

    if (rateUpdate.params.optimalUsageRatio != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentOptimalUsageRatio,
        rateUpdate.params.optimalUsageRatio,
        _timelocks[asset].optimalUsageRatioLastUpdated,
        _riskConfig.optimalUsageRatio,
        false
      );

      _timelocks[asset].optimalUsageRatioLastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.baseVariableBorrowRate != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentBaseVariableBorrowRate,
        rateUpdate.params.baseVariableBorrowRate,
        _timelocks[asset].baseVariableRateLastUpdated,
        _riskConfig.baseVariableBorrowRate,
        false
      );

      _timelocks[asset].baseVariableRateLastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.variableRateSlope1 != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentVariableRateSlope1,
        rateUpdate.params.variableRateSlope1,
        _timelocks[asset].variableRateSlope1LastUpdated,
        _riskConfig.variableRateSlope1,
        false
      );

      _timelocks[asset].variableRateSlope1LastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.variableRateSlope2 != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentVariableRateSlope2,
        rateUpdate.params.variableRateSlope2,
        _timelocks[asset].variableRateSlope2LastUpdated,
        _riskConfig.variableRateSlope2,
        false
      );

      _timelocks[asset].variableRateSlope2LastUpdated = uint40(block.timestamp);
    }
  }

  /**
   * @notice method to validate the collateral update and to update the debouce
   * @param currentLtv the current ltv of the asset
   * @param currentLiquidationThreshold the current liquidation threshold of the asset
   * @param currentLiquidationBonus the current liquidation bonus of the asset
   * @param currentDebtCeiling the current debt ceiling of the asset
   * @param collateralUpdate struct containing the new collateral update of the asset
   */
  function _validateCollateralsUpdate(
    uint256 currentLtv,
    uint256 currentLiquidationThreshold,
    uint256 currentLiquidationBonus,
    uint256 currentDebtCeiling,
    IEngine.CollateralUpdate calldata collateralUpdate
  ) internal {
    address asset = collateralUpdate.asset;
    require(
      collateralUpdate.liqProtocolFee == EngineFlags.KEEP_CURRENT,
      RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED
    );
    require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);
    require(
      collateralUpdate.ltv != 0 &&
      collateralUpdate.liqThreshold != 0 &&
      collateralUpdate.liqThreshold != 0 &&
      collateralUpdate.debtCeiling != 0,
      RiskStewardErrors.INVALID_UPDATE_TO_ZERO
    );

    if (collateralUpdate.ltv != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentLtv,
        collateralUpdate.ltv,
        _timelocks[asset].ltvLastUpdated,
        _riskConfig.ltv,
        false
      );

      _timelocks[asset].ltvLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.liqThreshold != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentLiquidationThreshold,
        collateralUpdate.liqThreshold,
        _timelocks[asset].liquidationThresholdLastUpdated,
        _riskConfig.liquidationThreshold,
        false
      );

      _timelocks[asset].liquidationThresholdLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.liqBonus != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentLiquidationBonus,
        collateralUpdate.liqBonus,
        _timelocks[asset].liquidationBonusLastUpdated,
        _riskConfig.liquidationBonus,
        false
      );

      _timelocks[asset].liquidationBonusLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.debtCeiling != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        currentDebtCeiling,
        collateralUpdate.debtCeiling,
        _timelocks[asset].debtCeilingLastUpdated,
        _riskConfig.debtCeiling,
        true
      );

      _timelocks[asset].debtCeilingLastUpdated = uint40(block.timestamp);
    }
  }

  /**
   * @notice method to validate the risk param update is within the allowed bound and the debounce is respected
   * @param currentParamValue the current value of the risk param
   * @param newParamValue the new value of the risk param
   * @param lastUpdated timestamp when the risk param was last updated by the steward
   * @param riskConfig the risk configuration containing the minimum delay and the max percent change allowed for the risk param
   */
  function _validateParamUpdate(
    uint256 currentParamValue,
    uint256 newParamValue,
    uint40 lastUpdated,
    RiskParamConfig memory riskConfig,
    bool isChangeRelative
  ) internal view {
    require(
      block.timestamp - lastUpdated > riskConfig.minDelay,
      RiskStewardErrors.DEBOUNCE_NOT_RESPECTED
    );
    require(
      _updateWithinAllowedRange(currentParamValue, newParamValue, riskConfig.maxPercentChange, isChangeRelative),
      RiskStewardErrors.UPDATE_NOT_IN_RANGE
    );
  }

  /**
   * @notice method to fetch the current interest rate params of the asset
   * @param asset the address of the underlying asset
   * @return optimalUsageRatio the current optimal usage ratio of the asset
   * @return baseVariableBorrowRate the current base variable borrow rate of the asset
   * @return variableRateSlope1 the current variable rate slope 1 of the asset
   * @return variableRateSlope2 the current variable rate slope 2 of the asset
   */
  function _getInterestRatesForAsset(
    address asset
  )
    internal
    view
    returns (
      uint256 optimalUsageRatio,
      uint256 baseVariableBorrowRate,
      uint256 variableRateSlope1,
      uint256 variableRateSlope2
    )
  {
    address rateStrategyAddress = POOL_DATA_PROVIDER.getInterestRateStrategyAddress(asset);
    optimalUsageRatio = IDefaultInterestRateStrategy(rateStrategyAddress).OPTIMAL_USAGE_RATIO();
    baseVariableBorrowRate = IDefaultInterestRateStrategy(rateStrategyAddress)
      .getBaseVariableBorrowRate();
    variableRateSlope1 = IDefaultInterestRateStrategy(rateStrategyAddress).getVariableRateSlope1();
    variableRateSlope2 = IDefaultInterestRateStrategy(rateStrategyAddress).getVariableRateSlope2();
    return (optimalUsageRatio, baseVariableBorrowRate, variableRateSlope1, variableRateSlope2);
  }

  /**
   * @notice Ensures the risk param update is within the allowed range
   * @param from current risk param value
   * @param to new updated risk param value
   * @param maxPercentChange the max percent change allowed
   * @param isChangeRelative true, if maxPercentChange is relative in value, false if maxPercentChange
   *        is absolute in value.
   * @return bool true, if difference is within the maxPercentChange
   */
  function _updateWithinAllowedRange(
    uint256 from,
    uint256 to,
    uint256 maxPercentChange,
    bool isChangeRelative
  ) internal pure returns (bool) {
    int256 diff = int256(from) - int256(to);
    if (diff < 0) diff = -diff;

    uint256 maxDiff = isChangeRelative ? (maxPercentChange * from) / BPS_MAX : maxPercentChange;
    if (uint256(diff) > maxDiff) return false;
    return true;
  }
}
