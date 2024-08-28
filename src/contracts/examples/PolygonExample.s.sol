// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-periphery/contracts/v3-config-engine/EngineFlags.sol';
import {RiskStewardsPolygon} from '../../../scripts/networks/RiskStewardsPolygon.s.sol';

// make run-script network=polygon contract_path=src/contracts/examples/PolygonExample.s.sol:PolygonExample broadcast=false
contract PolygonExample is RiskStewardsPolygon {
  /**
   * @return string name identifier used for the diff
   */
  function name() internal pure override returns (string memory) {
    return 'polygon_example';
  }

  function capsUpdates() internal pure override returns (IEngine.CapsUpdate[] memory) {
    IEngine.CapsUpdate[] memory capUpdates = new IEngine.CapsUpdate[](1);
    capUpdates[0] = IEngine.CapsUpdate(
      AaveV3PolygonAssets.wstETH_UNDERLYING,
      75_000,
      EngineFlags.KEEP_CURRENT
    );
    return capUpdates;
  }
}
