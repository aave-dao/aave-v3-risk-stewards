// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {RiskStewardsEthereum} from '../payload-helpers/networks/RiskStewardsEthereum.t.sol';
import {IRiskSteward, IPriceCapAdapter} from '../../interfaces/IRiskSteward.sol';

// make run-script network=mainnet contract=src/contracts/examples/EthereumExample.sol:EthereumExample broadcast=false generate_diff=true
contract EthereumExample is RiskStewardsEthereum {
  /**
   * @return string name identifier used for the diff
   */
  function name() public pure override returns (string memory) {
    return 'ethereum_example';
  }

  function lstPriceCapsUpdates() public pure override returns (IRiskSteward.PriceCapLstUpdate[] memory) {
    IRiskSteward.PriceCapLstUpdate[] memory priceCapUpdates = new IRiskSteward.PriceCapLstUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapLstUpdate({
      oracle: AaveV3EthereumAssets.wstETH_ORACLE,
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: 1723621200,
        snapshotRatio: 1177101458282319168,
        maxYearlyRatioGrowthPercent: 10_64
      })
    });
    return priceCapUpdates;
  }
}
