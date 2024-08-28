// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsAvalanche is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Avalanche.POOL), AaveV3Avalanche.RISK_STEWARD)
  {}
}
