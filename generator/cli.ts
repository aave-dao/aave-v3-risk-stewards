import path from 'path';
import {Command, Option} from 'commander';
import {CHAIN_TO_CHAIN_ID, getDate, getPoolChain, pascalCase} from './common';
import {input, checkbox} from '@inquirer/prompts';
import {
  ConfigFile,
  Options,
  POOLS,
  PoolCache,
  PoolConfigs,
  PoolIdentifier,
} from './types';
import {capsUpdates} from './features/capsUpdates';
import {rateUpdatesV3} from './features/rateUpdates';
import {collateralsUpdates} from './features/collateralsUpdates';
import {eModeUpdates} from './features/eModeUpdates';
import {lstPriceCapsUpdates} from './features/lstPriceCapsUpdates';
import {stablePriceCapsUpdates} from './features/stablePriceCapsUpdates';
import {generateFiles, writeFiles} from './generator';
import {getClient} from '@bgd-labs/rpc-env';
import {getBlockNumber} from 'viem/actions';

const program = new Command();

program
  .name('proposal-generator')
  .description('CLI to generate aave proposals')
  .version('1.0.0')
  .addOption(new Option('-f, --force', 'force creation (might overwrite existing files)'))
  .addOption(new Option('-p, --pools <pools...>').choices(POOLS))
  .addOption(new Option('-t, --title <string>', 'aip title'))
  .addOption(new Option('-a, --author <string>', 'author'))
  .addOption(new Option('-d, --discussion <string>', 'forum link'))
  .addOption(new Option('-c, --configFile <string>', 'path to config file'))
  .allowExcessArguments(false)
  .parse(process.argv);

let options = program.opts<Options>();
let poolConfigs: PoolConfigs = {};

const FEATURE_MODULES_V3 = [
  rateUpdatesV3,
  capsUpdates,
  collateralsUpdates,
  lstPriceCapsUpdates,
  stablePriceCapsUpdates,
  eModeUpdates
];

async function generateDeterministicPoolCache(pool: PoolIdentifier): Promise<PoolCache> {
  const chain = getPoolChain(pool);
  const client = getClient(CHAIN_TO_CHAIN_ID[chain], {});
  return {blockNumber: Number(await getBlockNumber(client))};
}

async function fetchPoolOptions(pool: PoolIdentifier) {
  poolConfigs[pool] = {
    configs: {},
    artifacts: [],
    cache: await generateDeterministicPoolCache(pool),
  };

  const features = await checkbox({
    message: `What do you want to do on ${pool}?`,
    choices: FEATURE_MODULES_V3.map((m) => ({value: m.value, name: m.description})),
  });
  for (const feature of features) {
    const module = FEATURE_MODULES_V3.find((m) => m.value === feature)!;
    poolConfigs[pool]!.configs[feature] = await module.cli({
      options,
      pool,
      cache: poolConfigs[pool]!.cache,
    });
    poolConfigs[pool]!.artifacts.push(
      module.build({
        options,
        pool,
        cfg: poolConfigs[pool]!.configs[feature],
        cache: poolConfigs[pool]!.cache,
      }),
    );
  }
}

if (options.configFile) {
  const {config: cfgFile}: {config: ConfigFile} = await import(
    path.join(process.cwd(), options.configFile)
  );
  options = {...options, ...cfgFile.rootOptions};
  poolConfigs = cfgFile.poolOptions as any;
  for (const pool of options.pools) {
    if (poolConfigs[pool]) {
      poolConfigs[pool]!.artifacts = [];
      for (const feature of Object.keys(poolConfigs[pool]!.configs)) {
        const module = FEATURE_MODULES_V3.find((m) => m.value === feature)!;
        poolConfigs[pool]!.artifacts.push(
          module.build({
            options,
            pool,
            cfg: poolConfigs[pool]!.configs[feature],
            cache: poolConfigs[pool]!.cache,
          }),
        );
      }
    } else {
      await fetchPoolOptions(pool);
    }
  }
} else {
  options.pools = await checkbox({
    message: 'Chains this proposal targets',
    choices: POOLS.map((v) => ({name: v, value: v})),
    required: true,
  });

  if (!options.title) {
    options.title = await input({
      message:
        'Short title of your steward update that will be used as contract name (please refrain from including author or date)',
      validate(input) {
        if (input.length == 0) return "Your title can't be empty";
        // this is no exact math
        // fully qualified identifiers are not allowed to be longer then 300 chars on etherscan api
        // the path is roughly src(3)/date(8)_title/title_date(8):title_date(8), so 3 + 3*8 + 3 title.length
        // so 80 sounds like a reasonable upper bound to stay below 300 character limit
        if (input.trim().length > 80) return 'Your title is to long';
        return true;
      },
    });
  }
  options.shortName = pascalCase(options.title);
  options.date = getDate();

  if (!options.author) {
    options.author = await input({
      message: 'Author of your proposal',
      validate(input) {
        if (input.length == 0) return "Your author can't be empty";
        return true;
      },
    });
  }

  if (!options.discussion) {
    options.discussion = await input({
      message: 'Link to forum discussion',
    });
  }

  for (const pool of options.pools) {
    await fetchPoolOptions(pool);
  }
}

try {
  const files = await generateFiles(options, poolConfigs);
  await writeFiles(options, files);
} catch (e) {
  console.log(JSON.stringify({options, poolConfigs}, null, 2));
  throw e;
}
