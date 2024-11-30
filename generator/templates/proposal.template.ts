import {generateContractName, getPoolChain, getChainAlias} from '../common';
import {Options, PoolConfig, PoolIdentifier} from '../types';
import {prefixWithImports} from '../utils/importsResolver';
import {prefixWithPragma} from '../utils/constants';

export const proposalTemplate = (
  options: Options,
  poolConfig: PoolConfig,
  pool: PoolIdentifier,
) => {
  const {title, author, discussion} = options;
  const chain = getPoolChain(pool);
  const contractName = generateContractName(options, pool);

  const functions = poolConfig.artifacts
    .map((artifact) => artifact.code?.fn)
    .flat()
    .filter((f) => f !== undefined)
    .join('\n');

  const contract = `/**
  * @title ${title || 'TODO'}
  * @author ${author || 'TODO'}
  * - discussion: ${discussion || 'TODO'}
  * - test-command: make run-test contract=${contractName} network=${getChainAlias(chain)} generate_diff=true
  */
 contract ${contractName} is ${`RiskStewards${chain}`
 } {
  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('${getChainAlias(chain)}'), ${poolConfig.cache.blockNumber});
    super.setUp(); // TODO: remove once deployed
  }

  function name() public pure override returns (string memory) {
    return '${contractName}';
  }

   ${functions}
 }`;

  return prefixWithPragma(prefixWithImports(contract));
};
