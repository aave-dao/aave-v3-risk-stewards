// sum.test.js
import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, collateralUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {collateralsUpdates} from './collateralsUpdates';

describe('feature: collateralUpdates', () => {
  it('should return reasonable code', () => {
    const output = collateralsUpdates.build({
      options: MOCK_OPTIONS,
      pool: 'AaveV3Ethereum',
      cfg: collateralUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      ['AaveV3Ethereum']: {
        artifacts: [
          collateralsUpdates.build({
            options: {...MOCK_OPTIONS, pools: ['AaveV3Ethereum']},
            pool: 'AaveV3Ethereum',
            cfg: collateralUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.COLLATERALS_UPDATE]: collateralUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, pools: ['AaveV3Ethereum']}, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
