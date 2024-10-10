// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3AvalancheAssets} from 'aave-address-book/AaveV3Avalanche.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsAvalanche} from '../../../scripts/networks/RiskStewardsAvalanche.s.sol';

// make run-script network=avalanche contract_path=src/contracts/examples/AvalancheExample.sol:AvalancheExample broadcast=false
contract AvalancheExample is RiskStewardsAvalanche {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'avalanche_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate({
      asset: AaveV3AvalancheAssets.USDC_UNDERLYING,
      supplyCap: 200_000_000,
      borrowCap: EngineFlags.KEEP_CURRENT
    });
    return capUpdates;
  }
}
