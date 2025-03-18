// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Celo} from 'aave-address-book/AaveV3Celo.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsCelo is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Celo.POOL), AaveV3Celo.RISK_STEWARD)
  {}
}
