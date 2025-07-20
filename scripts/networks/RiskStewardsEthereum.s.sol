// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsEthereum is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Ethereum.POOL), AaveV3Ethereum.RISK_STEWARD)
  {}
}
