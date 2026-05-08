// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @notice Mirror of the pre-v3.7 RiskSteward.Config layout, where `CollateralConfig`
 *         still carries `debtCeiling` as a fourth slot. Used to ABI-decode `getRiskConfig()`
 *         from the currently deployed (old) stewards on-chain.
 */
interface IRiskStewardOld {
  struct RiskParamConfig {
    uint40 minDelay;
    uint256 maxPercentChange;
  }

  struct CollateralConfig {
    RiskParamConfig ltv;
    RiskParamConfig liquidationThreshold;
    RiskParamConfig liquidationBonus;
    RiskParamConfig debtCeiling;
  }

  struct EmodeConfig {
    RiskParamConfig ltv;
    RiskParamConfig liquidationThreshold;
    RiskParamConfig liquidationBonus;
  }

  struct RateConfig {
    RiskParamConfig baseVariableBorrowRate;
    RiskParamConfig variableRateSlope1;
    RiskParamConfig variableRateSlope2;
    RiskParamConfig optimalUsageRatio;
  }

  struct CapConfig {
    RiskParamConfig supplyCap;
    RiskParamConfig borrowCap;
  }

  struct PriceCapConfig {
    RiskParamConfig priceCapLst;
    RiskParamConfig priceCapStable;
    RiskParamConfig discountRatePendle;
  }

  struct Config {
    CollateralConfig collateralConfig;
    EmodeConfig eModeConfig;
    RateConfig rateConfig;
    CapConfig capConfig;
    PriceCapConfig priceCapConfig;
  }

  function getRiskConfig() external view returns (Config memory);
}
