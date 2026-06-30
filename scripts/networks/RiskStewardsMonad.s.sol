// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Monad} from 'aave-address-book/AaveV3Monad.sol';
import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

abstract contract RiskStewardsMonad is RiskStewardsBase {
  constructor()
    RiskStewardsBase(address(AaveV3Monad.POOL), 0x98217A06721Ebf727f2C8d9aD7718ec28b7aAe34) // replace with AaveV3Monad.RISK_STEWARD once released
  {}
}
