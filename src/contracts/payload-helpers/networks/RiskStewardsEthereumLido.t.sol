// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumLido} from 'aave-address-book/AaveV3EthereumLido.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsEthereumLido is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3EthereumLido.POOL), AaveV3EthereumLido.RISK_STEWARD)
  {}
}
