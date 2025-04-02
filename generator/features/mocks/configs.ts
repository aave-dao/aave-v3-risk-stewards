import {Options} from '../../types';
import {CapsUpdate, CollateralUpdate, RateStrategyUpdate, LstPriceCapUpdate, StablePriceCapUpdate} from '../types';

export const MOCK_OPTIONS: Options = {
  pools: ['AaveV3Ethereum'],
  title: 'test',
  shortName: 'Test',
  date: '20231023',
  author: 'test',
  discussion: 'test',
};

export const capUpdate: CapsUpdate[] = [
  {
    asset: 'WETH',
    supplyCap: '10000',
    borrowCap: '5000'
  },
];

export const collateralUpdate: CollateralUpdate[] = [
  {
    asset: 'DAI',
    ltv: '8500',
    liqThreshold: '8800',
    liqBonus: '600',
    debtCeiling: '',
    liqProtocolFee: '1200'
  },
];

export const rateUpdateV3: RateStrategyUpdate[] = [
  {
    asset: 'WETH',
    params: {
      optimalUtilizationRate: '',
      baseVariableBorrowRate: '6',
      variableRateSlope1: '',
      variableRateSlope2: '',
    },
  },
  {
    asset: 'DAI',
    params: {
      optimalUtilizationRate: '',
      baseVariableBorrowRate: '4',
      variableRateSlope1: '10',
      variableRateSlope2: '',
    },
  },
  {
    asset: 'USDC',
    params: {
      optimalUtilizationRate: '',
      baseVariableBorrowRate: '4',
      variableRateSlope1: '10',
      variableRateSlope2: '',
    },
  },
  {
    asset: 'USDT',
    params: {
      optimalUtilizationRate: '',
      baseVariableBorrowRate: '6',
      variableRateSlope1: '10',
      variableRateSlope2: '',
    },
  },
  {
    asset: 'WBTC',
    params: {
      optimalUtilizationRate: '',
      baseVariableBorrowRate: '5',
      variableRateSlope1: '',
      variableRateSlope2: '',
    },
  },
];

export const lstPriceCapUpdate: LstPriceCapUpdate[] = [
  {
    asset: 'wstETH',
    snapshotTimestamp: '1723621200',
    snapshotRatio: '1177101458282319168',
    maxYearlyRatioGrowthPercent: '10.64',
  },
];

export const stablePriceCapUpdate: StablePriceCapUpdate[] = [
  {
    asset: 'USDT',
    priceCap: '108000000'
  }
];
