// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, eModeUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {eModeUpdates} from './eModeUpdates';

describe('feature: eModeUpdates', () => {
  it('should return reasonable code', () => {
    const output = eModeUpdates.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: eModeUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          eModeUpdates.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: eModeUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.EMODES_UPDATE]: eModeUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
