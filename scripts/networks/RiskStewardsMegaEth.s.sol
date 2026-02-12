// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3MegaEth} from 'aave-address-book/AaveV3MegaEth.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsMegaEth is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3MegaEth.POOL), AaveV3MegaEth.RISK_STEWARD)
  {}
}
