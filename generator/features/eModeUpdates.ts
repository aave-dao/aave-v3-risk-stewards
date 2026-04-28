import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {eModesSelect} from '../prompts';
import {EModeCategoryUpdate} from './types';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';
import {boolPrompt, translateJsBoolToSol} from '../prompts/boolPrompt';

async function fetchEmodeCategoryUpdate<T extends boolean>(
  eModeCategory: string | number,
  required?: T,
): Promise<EModeCategoryUpdate> {
  return {
    eModeCategory,
    ltv: await percentPrompt({
      message: 'ltv',
      required,
    }),
    liqThreshold: await percentPrompt({
      message: 'liqThreshold',
      required,
    }),
    liqBonus: await percentPrompt({
      message: 'liqBonus',
      required,
    }),
    isolated: await boolPrompt({
      message: 'isolated',
      required,
      excludeDisabled: true,
    }),
  };
}

type EmodeUpdates = EModeCategoryUpdate[];

export const eModeUpdates: FeatureModule<EmodeUpdates> = {
  value: FEATURE.EMODES_UPDATE,
  description: 'eModeCategoriesUpdates (altering eMode category params)',
  async cli({pool}) {
    console.log(`Fetching information for EMode category updates on ${pool}`);

    const response: EmodeUpdates = [];
    const eModeCategories = await eModesSelect({
      message: 'Select the eModes you want to amend',
      pool,
    });

    if (eModeCategories) {
      for (const eModeCategory of eModeCategories) {
        console.log(`collecting info for ${eModeCategory}`);
        response.push(await fetchEmodeCategoryUpdate(eModeCategory));
      }
    }
    return response;
  },
  build({cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function eModeCategoriesUpdates() public pure override returns (IAaveV3ConfigEngine.EModeCategoryUpdate[] memory) {
          IAaveV3ConfigEngine.EModeCategoryUpdate[] memory eModeUpdates = new IAaveV3ConfigEngine.EModeCategoryUpdate[](${
            cfg.length
          });

          ${cfg
            .map(
              (cfg, ix) => `eModeUpdates[${ix}] = IAaveV3ConfigEngine.EModeCategoryUpdate({
               eModeCategory: ${cfg.eModeCategory},
               ltv: ${translateJsPercentToSol(cfg.ltv)},
               liqThreshold: ${translateJsPercentToSol(cfg.liqThreshold)},
               liqBonus: ${translateJsPercentToSol(cfg.liqBonus)},
               isolated: ${translateJsBoolToSol(cfg.isolated)},
               label: EngineFlags.KEEP_CURRENT_STRING
             });`,
            )
            .join('\n')}

          return eModeUpdates;
        }`,
        ],
      },
    };
    return response;
  },
};
