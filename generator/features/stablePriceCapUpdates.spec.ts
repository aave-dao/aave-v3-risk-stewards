// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, stablePriceCapUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {stablePriceCapsUpdates} from './stablePriceCapsUpdates';

describe('feature: capUpdates', () => {
  it('should return reasonable code', () => {
    const output = stablePriceCapsUpdates.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: stablePriceCapUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          stablePriceCapsUpdates.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: stablePriceCapUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.STABLE_PRICE_CAP_UPDATE]: stablePriceCapUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
