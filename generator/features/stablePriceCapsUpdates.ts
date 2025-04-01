import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {StablePriceCapUpdate, StablePriceCapUpdatePartial} from './types';
import {
  assetsSelectPrompt
} from '../prompts/assetsSelectPrompt';
import {numberPrompt} from '../prompts/numberPrompt';
import {translateJsAssetOracleToSol} from '../prompts/addressPrompt';

export async function fetchStablePriceCapUpdate(
  required?: boolean,
): Promise<StablePriceCapUpdatePartial> {
  return {
    priceCap: await numberPrompt({
        message: 'Price Cap',
        required,
      }, {
        skipTransform: true
      }
    )
  };
}

type StablecoinPriceCapUpdates = StablePriceCapUpdate[];

export const stablePriceCapsUpdates: FeatureModule<StablecoinPriceCapUpdates> = {
  value: FEATURE.STABLECOIN_PRICE_CAP_UPDATE,
  description: 'StablecoinPriceCapUpdates (priceCap)',
  async cli({pool}) {
    console.log(`Fetching information for Stable Price Cap Updates on ${pool}`);

    const response: StablecoinPriceCapUpdates = [];
    const assets = await assetsSelectPrompt({
      message: 'Select the asset whose oracle you want to amend',
      pool,
    });
    for (const asset of assets) {
      console.log(`collecting info for ${asset}`);

      response.push({asset, ...(await fetchStablePriceCapUpdate(true))});
    }
    return response;
  },
  build({pool, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function stablePriceCapsUpdates() public pure override returns (IRiskSteward.PriceCapStableUpdate[] memory) {
          IRiskSteward.PriceCapStableUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](${cfg.length});

          ${cfg
            .map(
              (cfg, ix) => `priceCapUpdates[${ix}] = IRiskSteward.PriceCapStableUpdate({
               oracle: ${translateJsAssetOracleToSol(pool, cfg.asset)},
               priceCap: ${cfg.priceCap}
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
