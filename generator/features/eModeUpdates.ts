import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {eModesSelect} from '../prompts';
import {EModeCategoryUpdate} from './types';
import {stringOrKeepCurrent, stringPrompt} from '../prompts/stringPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';

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
    label: await stringPrompt({
      message: 'label',
      required,
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
  build({pool, cfg}) {
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
               label: ${stringOrKeepCurrent(cfg.label)}
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
