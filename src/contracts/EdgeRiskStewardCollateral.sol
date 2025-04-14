// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './RiskSteward.sol';

/**
 * @title EdgeRiskStewardCollateral
 * @author BGD labs
 * @notice Contract to manage the collateral params updates within configured bound on aave v3 pool.
 *         To be triggered by the Aave Steward Injector Contract in a automated way via the Edge Risk Oracle.
 */
contract EdgeRiskStewardCollateral is RiskSteward {
  /**
   * @param pool the aave pool to be controlled by the steward
   * @param engine the config engine to be used by the steward
   * @param riskCouncil the safe address of the council being able to interact with the steward
   * @param owner the owner of the risk steward being able to set configs and mark items as restricted
   * @param riskConfig the risk configuration to setup for each individual risk param
   */
  constructor(
    address pool,
    address engine,
    address riskCouncil,
    address owner,
    Config memory riskConfig
  ) RiskSteward(pool, engine, riskCouncil, owner, riskConfig) {}

  /// @inheritdoc IRiskSteward
  function updateRates(
    IEngine.RateStrategyUpdate[] calldata
  ) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /// @inheritdoc IRiskSteward
  function updateCaps(IEngine.CapsUpdate[] calldata) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /// @inheritdoc IRiskSteward
  function updateEModeCategories(
    IEngine.EModeCategoryUpdate[] calldata
  ) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /// @inheritdoc IRiskSteward
  function updateLstPriceCaps(
    PriceCapLstUpdate[] calldata
  ) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /// @inheritdoc IRiskSteward
  function updateStablePriceCaps(
    PriceCapStableUpdate[] calldata
  ) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /// @inheritdoc IRiskSteward
  function updatePendleDiscountRates(
    DiscountRatePendleUpdate[] calldata
  ) external virtual override onlyRiskCouncil {
    revert UpdateNotAllowed();
  }

  /**
   * @notice method to validate the collaterals update
   * @param collateralUpdates list containing the new collateral updates of the assets
   * @dev custom overload to forbid debtCeiling change
   */
  function _validateCollateralsUpdate(
    IEngine.CollateralUpdate[] calldata collateralUpdates
  ) internal view override {
    for (uint256 i = 0; i < collateralUpdates.length; i++) {
      if (collateralUpdates[i].debtCeiling != EngineFlags.KEEP_CURRENT)
        revert ParamChangeNotAllowed();
    }
    super._validateCollateralsUpdate(collateralUpdates);
  }
}
