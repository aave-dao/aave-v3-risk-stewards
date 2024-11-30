import {generateScriptName, generateContractName, getPoolChain, generateFolderName, getChainAlias} from '../common';
import {Options, PoolIdentifier} from '../types';
import {prefixWithImports} from '../utils/importsResolver';
import {prefixWithPragma} from '../utils/constants';

export const scriptTemplate = (
  options: Options,
  pool: PoolIdentifier,
) => {
  const chain = getPoolChain(pool);
  const chainAlias = getChainAlias(chain);
  const payloadName = generateContractName(options, pool);
  const folderName = generateFolderName(options);
  const scriptName = generateScriptName(options, pool);

  const contract = `
  import {${payloadName}} from './${payloadName}.t.sol';
  import {${chain}Script} from 'solidity-utils/contracts/utils/ScriptUtils.sol';

  /**
   * @dev Deploy ${chain}
   * deploy-command: make deploy-ledger contract=src/contracts/updates/${folderName}/${scriptName}.s.sol:${scriptName} chain=${chainAlias}
   */
  contract ${scriptName} is ${payloadName}, ${chain}Script {
    function run() public {
      IPayloadsControllerCore.ExecutionAction[] memory actions = buildActions();

      vm.startBroadcast();
      IPayloadsControllerCore(address(0)).createPayload(actions); // TODO: import from address book once deployed
      vm.stopBroadcast();
    }
  }
  `;

  return prefixWithPragma(prefixWithImports(contract));
};
