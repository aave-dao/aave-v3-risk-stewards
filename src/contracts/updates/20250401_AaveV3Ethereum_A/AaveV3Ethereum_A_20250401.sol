// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskStewardsEthereum} from '../../../../scripts/networks/RiskStewardsEthereum.s.sol';
import {IRiskSteward} from '../../../interfaces/IRiskSteward.sol';

/**
 * @title a
 * @author a
 * - discussion: a
 * - deploy-command: make run-script contract=src/contracts/updates/20250401_AaveV3Ethereum_A/AaveV3Ethereum_A_20250401.sol:AaveV3Ethereum_A_20250401 network=mainnet broadcast=false generate_diff=true skip_timelock=false
 */
contract AaveV3Ethereum_A_20250401 is RiskStewardsEthereum {
  function name() public pure override returns (string memory) {
    return 'AaveV3Ethereum_A_20250401';
  }

  function stablePriceCapsUpdates()
    public
    pure
    override
    returns (IRiskSteward.PriceCapStableUpdate[] memory)
  {
    IRiskSteward.PriceCapStableUpdate[]
      memory priceCapUpdates = new IRiskSteward.PriceCapStableUpdate[](1);

    priceCapUpdates[0] = IRiskSteward.PriceCapStableUpdate({
      oracle: AaveV3EthereumAssets.WETH_ORACLE,
      priceCap: 30
    });

    return priceCapUpdates;
  }
}
