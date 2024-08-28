// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3MetisAssets} from 'aave-address-book/AaveV3Metis.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-periphery/contracts/v3-config-engine/EngineFlags.sol';
import {RiskStewardsMetis} from '../../../scripts/networks/RiskStewardsMetis.s.sol';

// make run-script network=metis contract_path=src/contracts/examples/MetisExample.s.sol:MetisExample broadcast=false
contract MetisExample is RiskStewardsMetis {
  /**
   * @return string name identifier used for the diff
   */
  function name() internal pure override returns (string memory) {
    return 'metis_example';
  }

  function capsUpdates() internal pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3MetisAssets.WETH_UNDERLYING,
      3_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
