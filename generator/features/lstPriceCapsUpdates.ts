import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {LstPriceCapUpdate, LstPriceCapUpdatePartial} from './types';
import {
  assetsSelectPrompt
} from '../prompts/assetsSelectPrompt';
import {numberPrompt} from '../prompts/numberPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';
import {translateJsAssetOracleToSol} from '../prompts/addressPrompt';

export async function fetchLstPriceCapUpdate(
  required?: boolean,
): Promise<LstPriceCapUpdatePartial> {
  return {
    snapshotTimestamp: await numberPrompt({
        message: 'Snapshot Timestamp',
        required,
      }, {
        skipTransform: true
      }
    ),
    snapshotRatio: await numberPrompt({
        message: 'Snapshot Ratio',
        required,
      }, {
        skipTransform: true
      }
    ),
    maxYearlyRatioGrowthPercent: await percentPrompt({
      message: 'Max Yearly Ratio Growth Percent',
      required,
    }),
  };
}

type LstPriceCapUpdates = LstPriceCapUpdate[];

export const lstPriceCapsUpdates: FeatureModule<LstPriceCapUpdates> = {
  value: FEATURE.LST_PRICE_CAP_UPDATE,
  description: 'LstPriceCapUpdates (snapshotTimestamp,snapshotRatio,maxYearlyRatioGrowthPercent)',
  async cli({pool}) {
    console.log(`Fetching information for LST Price Cap Updates on ${pool}`);

    const response: LstPriceCapUpdates = [];
    const assets = await assetsSelectPrompt({
      message: 'Select the asset whose oracle you want to amend',
      pool,
    });
    for (const asset of assets) {
      console.log(`collecting info for ${asset}`);

      response.push({asset, ...(await fetchLstPriceCapUpdate(true))});
    }
    return response;
  },
  build({pool, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function lstPriceCapsUpdates() public pure override returns (IRiskSteward.PriceCapLstUpdate[] memory) {
          IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](${cfg.length});

          ${cfg
            .map(
              (cfg, ix) => `priceCapUpdates[${ix}] = IRiskSteward.PriceCapLstUpdate({
               oracle: ${translateJsAssetOracleToSol(pool, cfg.asset)},
               priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
                snapshotTimestamp: ${cfg.snapshotTimestamp},
                snapshotRatio: ${cfg.snapshotRatio},
                maxYearlyRatioGrowthPercent: ${translateJsPercentToSol(cfg.maxYearlyRatioGrowthPercent)},
              })
             });`,
            )
            .join('\n')}

          return priceCapUpdates;
        }`,
        ],
      },
    };
    return response;
  },
};
