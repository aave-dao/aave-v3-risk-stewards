// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {EngineFlags} from 'aave-helpers/v3-config-engine/EngineFlags.sol';
import {RiskStewardErrors} from './libraries/RiskStewardErrors.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IDefaultInterestRateStrategyV2} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';

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
  function updateCaps(IEngine.CapsUpdate[] calldata capsUpdate) external onlyRiskCouncil {
    _validateCapsUpdate(capsUpdate);
    _updateCaps(capsUpdate);
  }

  /// @inheritdoc IRiskSteward
  function updateRates(IEngine.RateStrategyUpdate[] calldata ratesUpdate) external onlyRiskCouncil {
    _validateRatesUpdate(ratesUpdate);
    _updateRates(ratesUpdate);
  }

  /// @inheritdoc IRiskSteward
  function updateCollateralSide(
    IEngine.CollateralUpdate[] calldata collateralUpdates
  ) external onlyRiskCouncil {
    _validateCollateralsUpdate(collateralUpdates);
    _updateCollateralSide(collateralUpdates);
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
   * @notice method to validate the caps update
   * @param capsUpdate list containing the new supply, borrow caps of the assets
   */
  function _validateCapsUpdate(
    IEngine.CapsUpdate[] calldata capsUpdate
  ) internal view
  {
    require(capsUpdate.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < capsUpdate.length; i++) {
      address asset = capsUpdate[i].asset;

      require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);
      require(capsUpdate[i].supplyCap != 0 && capsUpdate[i].borrowCap != 0, RiskStewardErrors.INVALID_UPDATE_TO_ZERO);

      (uint256 currentBorrowCap, uint256 currentSupplyCap) = POOL_DATA_PROVIDER.getReserveCaps(
        capsUpdate[i].asset
      );

      _validateParamUpdate(
        currentSupplyCap,
        capsUpdate[i].supplyCap,
        _timelocks[asset].supplyCapLastUpdated,
        _riskConfig.supplyCap,
        true
      );
      _validateParamUpdate(
        currentBorrowCap,
        capsUpdate[i].borrowCap,
        _timelocks[asset].borrowCapLastUpdated,
        _riskConfig.borrowCap,
        true
      );
    }
  }

  /**
   * @notice method to validate the interest rates update
   * @param ratesUpdate list containing the new interest rates params of the assets
   */
  function _validateRatesUpdate(
    IEngine.RateStrategyUpdate[] calldata ratesUpdate
  ) internal view {
    require(ratesUpdate.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < ratesUpdate.length; i++) {
      address asset = ratesUpdate[i].asset;
      require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);

      (
        uint256 currentOptimalUsageRatio,
        uint256 currentBaseVariableBorrowRate,
        uint256 currentVariableRateSlope1,
        uint256 currentVariableRateSlope2
      ) = _getInterestRatesForAsset(asset);

      _validateParamUpdate(
        currentOptimalUsageRatio,
        ratesUpdate[i].params.optimalUsageRatio,
        _timelocks[asset].optimalUsageRatioLastUpdated,
        _riskConfig.optimalUsageRatio,
        false
      );

      _validateParamUpdate(
        currentBaseVariableBorrowRate,
        ratesUpdate[i].params.baseVariableBorrowRate,
        _timelocks[asset].baseVariableRateLastUpdated,
        _riskConfig.baseVariableBorrowRate,
        false
      );

      _validateParamUpdate(
        currentVariableRateSlope1,
        ratesUpdate[i].params.variableRateSlope1,
        _timelocks[asset].variableRateSlope1LastUpdated,
        _riskConfig.variableRateSlope1,
        false
      );

      _validateParamUpdate(
        currentVariableRateSlope2,
        ratesUpdate[i].params.variableRateSlope2,
        _timelocks[asset].variableRateSlope2LastUpdated,
        _riskConfig.variableRateSlope2,
        false
      );
    }
  }

  /**
   * @notice method to validate the collaterals update
   * @param collateralUpdates list containing the new collateral updates of the assets
   */
  function _validateCollateralsUpdate(
    IEngine.CollateralUpdate[] calldata collateralUpdates
  ) internal view {
    require(collateralUpdates.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);

    for (uint256 i = 0; i < collateralUpdates.length; i++) {
      address asset = collateralUpdates[i].asset;

      (
        ,
        uint256 currentLtv,
        uint256 currentLiquidationThreshold,
        uint256 currentLiquidationBonus,
        ,
        ,
        ,
        ,
        ,

      ) = POOL_DATA_PROVIDER.getReserveConfigurationData(asset);
      uint256 currentDebtCeiling = POOL_DATA_PROVIDER.getDebtCeiling(asset);

      require(
      collateralUpdates[i].liqProtocolFee == EngineFlags.KEEP_CURRENT,
      RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED
      );
      require(!_restrictedAssets[asset], RiskStewardErrors.ASSET_RESTRICTED);
      require(
        collateralUpdates[i].ltv != 0 &&
        collateralUpdates[i].liqThreshold != 0 &&
        collateralUpdates[i].liqThreshold != 0 &&
        collateralUpdates[i].debtCeiling != 0,
        RiskStewardErrors.INVALID_UPDATE_TO_ZERO
      );

      _validateParamUpdate(
        currentLtv,
        collateralUpdates[i].ltv,
        _timelocks[asset].ltvLastUpdated,
        _riskConfig.ltv,
        false
      );
      _validateParamUpdate(
        currentLiquidationThreshold,
        collateralUpdates[i].liqThreshold,
        _timelocks[asset].liquidationThresholdLastUpdated,
        _riskConfig.liquidationThreshold,
        false
      );
      _validateParamUpdate(
        currentLiquidationBonus,
        collateralUpdates[i].liqBonus,
        _timelocks[asset].liquidationBonusLastUpdated,
        _riskConfig.liquidationBonus,
        false
      );
      _validateParamUpdate(
        currentDebtCeiling,
        collateralUpdates[i].debtCeiling,
        _timelocks[asset].debtCeilingLastUpdated,
        _riskConfig.debtCeiling,
        true
      );
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
    if (newParamValue == EngineFlags.KEEP_CURRENT) return;

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
   * @notice method to update the borrow / supply caps using the config engine and updates the debounce
   * @param capsUpdate list containing the new supply, borrow caps of the assets
   */
  function _updateCaps(IEngine.CapsUpdate[] calldata capsUpdate) internal {
    for (uint256 i = 0; i < capsUpdate.length; i++) {
      address asset = capsUpdate[i].asset;

      if (capsUpdate[i].supplyCap != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].supplyCapLastUpdated = uint40(block.timestamp);
      }

      if (capsUpdate[i].borrowCap != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].borrowCapLastUpdated = uint40(block.timestamp);
      }
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCaps.selector, capsUpdate)
    );
  }

  /**
   * @notice method to update the interest rates params using the config engine and updates the debounce
   * @param ratesUpdate list containing the new interest rates params of the assets
   */
  function _updateRates(IEngine.RateStrategyUpdate[] calldata ratesUpdate) internal {
    for (uint256 i = 0; i < ratesUpdate.length; i++) {
      address asset = ratesUpdate[i].asset;

      if (ratesUpdate[i].params.optimalUsageRatio != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].optimalUsageRatioLastUpdated = uint40(block.timestamp);
      }

      if (ratesUpdate[i].params.baseVariableBorrowRate != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].baseVariableRateLastUpdated = uint40(block.timestamp);
      }

      if (ratesUpdate[i].params.variableRateSlope1 != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].variableRateSlope1LastUpdated = uint40(block.timestamp);
      }

      if (ratesUpdate[i].params.variableRateSlope2 != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].variableRateSlope2LastUpdated = uint40(block.timestamp);
      }
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateRateStrategies.selector, ratesUpdate)
    );
  }

  /**
   * @notice method to update the collateral side params using the config engine and updates the debounce
   * @param collateralUpdates list containing the new collateral updates of the assets
   */
  function _updateCollateralSide(IEngine.CollateralUpdate[] calldata collateralUpdates) internal {
    for (uint256 i = 0; i < collateralUpdates.length; i++) {
      address asset = collateralUpdates[i].asset;

      if (collateralUpdates[i].ltv != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].ltvLastUpdated = uint40(block.timestamp);
      }
      if (collateralUpdates[i].liqThreshold != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].liquidationThresholdLastUpdated = uint40(block.timestamp);
      }
      if (collateralUpdates[i].liqBonus != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].liquidationBonusLastUpdated = uint40(block.timestamp);
      }
      if (collateralUpdates[i].debtCeiling != EngineFlags.KEEP_CURRENT) {
        _timelocks[asset].debtCeilingLastUpdated = uint40(block.timestamp);
      }
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCollateralSide.selector, collateralUpdates)
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
    IDefaultInterestRateStrategyV2.InterestRateData memory interestRateData = IDefaultInterestRateStrategyV2(rateStrategyAddress).getInterestRateDataBps(asset);
    return (
      interestRateData.optimalUsageRatio,
      interestRateData.baseVariableBorrowRate,
      interestRateData.variableRateSlope1,
      interestRateData.variableRateSlope2
    );
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
