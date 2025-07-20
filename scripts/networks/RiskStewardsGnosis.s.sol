// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Gnosis} from 'aave-address-book/AaveV3Gnosis.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsGnosis is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Gnosis.POOL), AaveV3Gnosis.RISK_STEWARD)
  {}
}
