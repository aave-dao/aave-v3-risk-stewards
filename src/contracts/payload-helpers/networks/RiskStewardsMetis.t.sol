// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Metis} from 'aave-address-book/AaveV3Metis.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.t.sol';

abstract contract RiskStewardsMetis is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Metis.POOL), AaveV3Metis.RISK_STEWARD)
  {}
}
