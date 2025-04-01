import {ConfigFile} from '../../generator/types';
export const config: ConfigFile = {
  rootOptions: {
    pools: ['AaveV3Ethereum'],
    title: 'a',
    shortName: 'A',
    date: '20250401',
    author: 'a',
    discussion: 'a',
  },
  poolOptions: {
    AaveV3Ethereum: {
      configs: {STABLECOIN_PRICE_CAP_UPDATE: [{asset: 'WETH', priceCap: '30'}]},
      cache: {blockNumber: 22174283},
    },
  },
};
