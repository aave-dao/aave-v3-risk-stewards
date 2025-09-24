// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsPlasma is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Plasma.POOL), AaveV3Plasma.RISK_STEWARD)
  {}
}
