// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, lstPriceCapUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {lstPriceCapsUpdates} from './lstPriceCapsUpdates';

describe('feature: lstPriceCapUpdates', () => {
  it('should return reasonable code', () => {
    const output = lstPriceCapsUpdates.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: lstPriceCapUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          lstPriceCapsUpdates.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: lstPriceCapUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.LST_PRICE_CAP_UPDATE]: lstPriceCapUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
