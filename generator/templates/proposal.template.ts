import {generateContractName, getPoolChain, generateFolderName, getChainAlias} from '../common';
import {Options, PoolConfig, PoolIdentifier} from '../types';
import {prefixWithImports} from '../utils/importsResolver';
import {prefixWithPragma} from '../utils/constants';

export const proposalTemplate = (
  options: Options,
  poolConfig: PoolConfig,
  pool: PoolIdentifier
) => {
  const {title, author, discussion} = options;
  const chain = getPoolChain(pool);
  const folderName = generateFolderName(options);
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
  * - deploy-command: make run-script contract=src/contracts/updates/${folderName}/${contractName}.sol:${contractName} network=${getChainAlias(
    chain
  )} broadcast=false generate_diff=true skip_timelock=false
  */
 contract ${contractName} is ${`RiskStewards${chain}`} {
  function name() public pure override returns (string memory) {
    return '${contractName}';
  }

   ${functions}
 }`;

  return prefixWithPragma(prefixWithImports(contract));
};
