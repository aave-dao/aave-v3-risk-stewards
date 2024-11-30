// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3MetisAssets} from 'aave-address-book/AaveV3Metis.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsMetis} from '../payload-helpers/networks/RiskStewardsMetis.t.sol';

// make run-script network=metis contract=src/contracts/examples/MetisExample.sol:MetisExample broadcast=false generate_diff=true
contract MetisExample is RiskStewardsMetis {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'metis_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3MetisAssets.WETH_UNDERLYING,
      3_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
