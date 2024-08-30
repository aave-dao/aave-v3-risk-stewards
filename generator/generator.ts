import fs from 'fs';
import path from 'path';
import {generateContractName, generateFolderName} from './common';
import {proposalTemplate} from './templates/proposal.template';
import {confirm} from '@inquirer/prompts';
import {ConfigFile, Options, PoolConfigs, PoolIdentifier, Files} from './types';
import prettier from 'prettier';

const prettierSolCfg = await prettier.resolveConfig('foo.sol');
const prettierTsCfg = await prettier.resolveConfig('foo.ts');

/**
 * Generates all the file contents for aip/tests/payloads & script
 * @param options
 * @param poolConfigs
 * @returns
 */
export async function generateFiles(options: Options, poolConfigs: PoolConfigs): Promise<Files> {
  const jsonConfig = await prettier.format(
    `import {ConfigFile} from '../../generator/types';
    export const config: ConfigFile = ${JSON.stringify({
      rootOptions: options,
      poolOptions: (Object.keys(poolConfigs) as PoolIdentifier[]).reduce((acc, pool) => {
        acc[pool] = {configs: poolConfigs[pool]!.configs, cache: poolConfigs[pool]!.cache};
        return acc;
      }, {}),
    } as ConfigFile)}`,
    {...prettierTsCfg, filepath: 'foo.ts'},
  );

  async function createPayload(options: Options, pool: PoolIdentifier) {
    const contractName = generateContractName(options, pool);

    return {
      pool,
      payload: await prettier.format(proposalTemplate(options, poolConfigs[pool]!, pool), {
        ...prettierSolCfg,
        filepath: 'foo.sol',
      }),
      contractName: contractName,
    };
  }

  return {
    jsonConfig,
    payloads: await Promise.all(options.pools.map((pool) => createPayload(options, pool))),
  };
}

async function askBeforeWrite(options: Options, path: string, content: string) {
  if (!options.force && fs.existsSync(path)) {
    const currentContent = fs.readFileSync(path, {encoding: 'utf8'});
    // skip if content did not change
    if (currentContent === content) return;
    const force = await confirm({
      message: `A file already exists at ${path} do you want to overwrite`,
      default: false,
    });
    if (!force) return;
  }
  fs.writeFileSync(path, content);
}

/**
 * Writes the files according to defined folder/file format
 * @param options
 * @param param1
 */
export async function writeFiles(options: Options, {jsonConfig, payloads}: Files) {
  const baseName = generateFolderName(options);
  const baseFolder = path.join(process.cwd(), 'src/contracts/updates/', baseName);

  if (fs.existsSync(baseFolder)) {
    if (!options.force && fs.existsSync(baseFolder)) {
      const force = await confirm({
        message: 'A proposal already exists at that location, do you want to continue?',
        default: false,
      });
      if (!force) return;
    }
  } else {
    fs.mkdirSync(baseFolder, {recursive: true});
  }

  // write config
  await askBeforeWrite(options, path.join(baseFolder, 'config.ts'), jsonConfig);

  for (const {payload, contractName} of payloads) {
    await askBeforeWrite(
      options,
      path.join(baseFolder, `${contractName}.sol`),
      payload,
    );
  }
}
