// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskStewardsEthereum} from '../../../../scripts/networks/RiskStewardsEthereum.s.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {IAaveV3ConfigEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';

/**
 * @title weETH cap reduce
 * @author BGD Labs
 * - deploy-command: make run-script contract=src/contracts/updates/20250114_AaveV3Ethereum_WeETHCapReduce/AaveV3Ethereum_WeETHCapReduce_20250114.sol:AaveV3Ethereum_WeETHCapReduce_20250114 network=mainnet broadcast=false generate_diff=true skip_timelock=false
 */
contract AaveV3Ethereum_WeETHCapReduce_20250114 is RiskStewardsEthereum {
  function name() public pure override returns (string memory) {
    return 'AaveV3Ethereum_WeETHCapReduce_20250114';
  }

  function capsUpdates() public pure override returns (IAaveV3ConfigEngine.CapsUpdate[] memory) {
    IAaveV3ConfigEngine.CapsUpdate[] memory capsUpdate = new IAaveV3ConfigEngine.CapsUpdate[](1);

    capsUpdate[0] = IAaveV3ConfigEngine.CapsUpdate({
      asset: AaveV3EthereumAssets.weETH_UNDERLYING,
      supplyCap: EngineFlags.KEEP_CURRENT,
      borrowCap: 100_000
    });

    return capsUpdate;
  }
}
