// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsArbitrum is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Arbitrum.POOL), AaveV3Arbitrum.RISK_STEWARD)
  {}
}
