// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, capUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {capsUpdates} from './capsUpdates';

describe('feature: capUpdates', () => {
  it('should return reasonable code', () => {
    const output = capsUpdates.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: capUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          capsUpdates.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: capUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.CAPS_UPDATE]: capUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
