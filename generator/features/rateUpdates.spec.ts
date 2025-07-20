// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, rateUpdateV3, capUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {rateUpdatesV3} from './rateUpdates';

describe('feature: rateUpdatesV3', () => {
  it('should return reasonable code', () => {
    const output = rateUpdatesV3.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: rateUpdateV3,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          rateUpdatesV3.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: rateUpdateV3,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.RATE_UPDATE_V3]: rateUpdateV3},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
