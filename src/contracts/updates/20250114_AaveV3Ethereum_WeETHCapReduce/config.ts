import {ConfigFile} from '../../generator/types';
export const config: ConfigFile = {
  rootOptions: {
    pools: ['AaveV3Ethereum'],
    title: 'weETH cap reduce',
    shortName: 'WeETHCapReduce',
    date: '20250114',
    author: 'BGD Labs',
    discussion: '',
  },
  poolOptions: {
    AaveV3Ethereum: {
      configs: {CAPS_UPDATE: [{asset: 'weETH', supplyCap: '', borrowCap: '100000'}]},
      cache: {blockNumber: 21622225},
    },
  },
};
