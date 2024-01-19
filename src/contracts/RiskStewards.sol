// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IACLManager, IPoolConfigurator, IPoolDataProvider} from 'aave-address-book/AaveV3.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';
import {EngineFlags} from 'aave-helpers/v3-config-engine/EngineFlags.sol';
import {DataTypes} from 'aave-address-book/AaveV3.sol';
import {RiskStewardErrors} from './libraries/RiskStewardsErrors.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-helpers/v3-config-engine/IAaveV3ConfigEngine.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';

/**
 * @title RiskSteward
 * @author BGD labs
 * @notice
 */
contract RiskSteward is IRiskSteward {
  using Address for address;

  uint256 internal constant BPS_MAX = 100_00;

  /// @inheritdoc IRiskSteward
  IEngine public immutable CONFIG_ENGINE;

  /// @inheritdoc IRiskSteward
  IPoolDataProvider public immutable POOL_DATA_PROVIDER;

  /// @inheritdoc IRiskSteward
  address public immutable RISK_COUNCIL;

  Config internal _riskConfig;

  mapping(address => Debounce) internal _timelocks;

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
   * @param riskConfig .
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
      (uint256 currentBorrowCap, uint256 currentSupplyCap) = POOL_DATA_PROVIDER.getReserveCaps(
        capUpdates[i].asset
      );

      _validateCapsUpdate(currentSupplyCap, currentBorrowCap, capUpdates[i]);
    }
    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCaps.selector, capUpdates)
    );
  }

  /// @inheritdoc IRiskSteward
  function updateRates(IEngine.RateStrategyUpdate[] calldata ratesUpdate) external onlyRiskCouncil {
    require(ratesUpdate.length > 0, RiskStewardErrors.NO_ZERO_UPDATES);
    for (uint256 i = 0; i < ratesUpdate.length; i++) {
      (
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2
      ) = _getInterestRatesForAsset(ratesUpdate[i].asset);

      _validateRatesUpdate(
        optimalUsageRatio,
        baseVariableBorrowRate,
        variableRateSlope1,
        variableRateSlope2,
        ratesUpdate[i]
      );
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
        liquidationBonus,
        debtCeiling,
        collateralUpdates[i]
      );
    }

    address(CONFIG_ENGINE).functionDelegateCall(
      abi.encodeWithSelector(CONFIG_ENGINE.updateCollateralSide.selector, collateralUpdates)
    );
  }

  /// @inheritdoc IRiskSteward
  function getTimelock(address asset) external view returns (Debounce memory) {
    return _timelocks[asset];
  }

  function _validateCapsUpdate(
    uint256 supplyCap,
    uint256 borrowCap,
    IEngine.CapsUpdate calldata capUpdate
  ) internal {
    require(supplyCap != 0 || borrowCap != 0, RiskStewardErrors.NO_CAP_INITIALIZE);
    address asset = capUpdate.asset;

    if (capUpdate.supplyCap != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        supplyCap,
        capUpdate.supplyCap,
        _timelocks[asset].supplyCapLastUpdated,
        _riskConfig.supplyCap
      );

      _timelocks[asset].supplyCapLastUpdated = uint40(block.timestamp);
    }

    if (capUpdate.supplyCap != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        borrowCap,
        capUpdate.supplyCap,
        _timelocks[asset].borrowCapLastUpdated,
        _riskConfig.borrowCap
      );

      _timelocks[asset].borrowCapLastUpdated = uint40(block.timestamp);
    }
  }

  function _validateRatesUpdate(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2,
    IEngine.RateStrategyUpdate calldata rateUpdate
  ) internal {
    require(
      rateUpdate.params.stableRateSlope1 == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.stableRateSlope2 == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.baseStableRateOffset == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.stableRateExcessOffset == EngineFlags.KEEP_CURRENT &&
        rateUpdate.params.optimalStableToTotalDebtRatio == EngineFlags.KEEP_CURRENT,
      RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED
    );
    address asset = rateUpdate.asset;

    if (rateUpdate.params.optimalUsageRatio != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        optimalUsageRatio,
        rateUpdate.params.optimalUsageRatio,
        _timelocks[asset].optimalUsageRatioLastUpdated,
        _riskConfig.optimalUsageRatio
      );

      _timelocks[asset].optimalUsageRatioLastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.baseVariableBorrowRate != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        baseVariableBorrowRate,
        rateUpdate.params.baseVariableBorrowRate,
        _timelocks[asset].baseVariableRateLastUpdated,
        _riskConfig.baseVariableBorrowRate
      );

      _timelocks[asset].baseVariableRateLastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.variableRateSlope1 != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        variableRateSlope1,
        rateUpdate.params.variableRateSlope1,
        _timelocks[asset].variableRateSlope1LastUpdated,
        _riskConfig.variableRateSlope1
      );

      _timelocks[asset].variableRateSlope1LastUpdated = uint40(block.timestamp);
    }

    if (rateUpdate.params.variableRateSlope2 != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        variableRateSlope2,
        rateUpdate.params.variableRateSlope2,
        _timelocks[asset].variableRateSlope2LastUpdated,
        _riskConfig.variableRateSlope2
      );

      _timelocks[asset].variableRateSlope2LastUpdated = uint40(block.timestamp);
    }
  }

  function _validateCollateralsUpdate(
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus,
    uint256 debtCeiling,
    IEngine.CollateralUpdate calldata collateralUpdate
  ) internal {
    require(
      collateralUpdate.liqProtocolFee == EngineFlags.KEEP_CURRENT,
      RiskStewardErrors.PARAM_CHANGE_NOT_ALLOWED
    );
    address asset = collateralUpdate.asset;

    if (collateralUpdate.ltv != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        ltv,
        collateralUpdate.ltv,
        _timelocks[asset].ltvLastUpdated,
        _riskConfig.ltv
      );

      _timelocks[asset].ltvLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.liqThreshold != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        liquidationThreshold,
        collateralUpdate.liqThreshold,
        _timelocks[asset].liqThresholdLastUpdated,
        _riskConfig.liquidationThreshold
      );

      _timelocks[asset].liqThresholdLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.liqBonus != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        liquidationBonus,
        collateralUpdate.liqBonus,
        _timelocks[asset].liqBonusLastUpdated,
        _riskConfig.liquidationBonus
      );

      _timelocks[asset].liqBonusLastUpdated = uint40(block.timestamp);
    }
    if (collateralUpdate.debtCeiling != EngineFlags.KEEP_CURRENT) {
      _validateParamUpdate(
        debtCeiling,
        collateralUpdate.debtCeiling,
        _timelocks[asset].debtCeilingLastUpdated,
        _riskConfig.debtCeiling
      );

      _timelocks[asset].debtCeilingLastUpdated = uint40(block.timestamp);
    }
  }

  function _validateParamUpdate(
    uint256 initialParamValue,
    uint256 newParamValue,
    uint40 lastUpdated,
    RiskParamConfig storage riskConfig // todo storage or memory
  ) internal view {
    require(
      block.timestamp - lastUpdated > riskConfig.minDelay,
      RiskStewardErrors.DEBOUNCE_NOT_RESPECTED
    );
    require(
      _updateWithinAllowedRange(initialParamValue, newParamValue, riskConfig.maxPercentChange),
      RiskStewardErrors.UPDATE_NOT_IN_RANGE
    );
  }

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
   * @notice Ensures the risk param change is within the allowed range.
   * @param from current risk param value
   * @param to new updated risk param value
   * @return bool true, if difference is within the maxPercentChange
   */
  function _updateWithinAllowedRange(
    uint256 from,
    uint256 to,
    uint256 maxPercentChange
  ) internal pure returns (bool) {
    int256 diff = int256(from - to);
    if (diff < 0) diff = -diff;

    uint256 maxDiff = (maxPercentChange * uint256(from)) / BPS_MAX;
    if (uint256(diff) > maxDiff) return false;
    return true;
  }
}
