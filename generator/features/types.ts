import {NumberInputValues, PercentInputValues} from '../prompts';

export interface AssetSelector {
  asset: string;
}

export interface CapsUpdatePartial {
  supplyCap: NumberInputValues;
  borrowCap: NumberInputValues;
}

export interface CapsUpdate extends CapsUpdatePartial, AssetSelector {}

export interface CollateralUpdatePartial {
  ltv: PercentInputValues;
  liqThreshold: PercentInputValues;
  liqBonus: PercentInputValues;
  debtCeiling: NumberInputValues;
  liqProtocolFee: PercentInputValues;
}

export interface CollateralUpdate extends CollateralUpdatePartial, AssetSelector {}

export interface RateStrategyParams {
  optimalUtilizationRate: string;
  baseVariableBorrowRate: string;
  variableRateSlope1: string;
  variableRateSlope2: string;
}

export interface RateStrategyUpdate extends AssetSelector {
  params: RateStrategyParams;
}

export interface LstPriceCapUpdatePartial {
  snapshotTimestamp: NumberInputValues;
  snapshotRatio: NumberInputValues;
  maxYearlyRatioGrowthPercent: PercentInputValues;
}

export interface StablePriceCapUpdatePartial {
  priceCap: NumberInputValues;
}

export interface LstPriceCapUpdate extends LstPriceCapUpdatePartial, AssetSelector {}

export interface StablePriceCapUpdate extends StablePriceCapUpdatePartial, AssetSelector {}
