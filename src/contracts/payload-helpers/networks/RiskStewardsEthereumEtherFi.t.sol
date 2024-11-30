// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumEtherFi} from 'aave-address-book/AaveV3EthereumEtherFi.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsEthereumEtherFi is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3EthereumEtherFi.POOL), AaveV3EthereumEtherFi.RISK_STEWARD)
  {}
}
