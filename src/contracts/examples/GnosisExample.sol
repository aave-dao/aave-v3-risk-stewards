// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3GnosisAssets} from 'aave-address-book/AaveV3Gnosis.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsGnosis} from '../../../scripts/networks/RiskStewardsGnosis.s.sol';

// make run-script network=gnosis contract=src/contracts/examples/GnosisExample.sol:GnosisExample broadcast=false generate_diff=true skip_timelock=false
contract GnosisExample is RiskStewardsGnosis {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'gnosis_example';
  }

  function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3GnosisAssets.wstETH_UNDERLYING,
      8_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
