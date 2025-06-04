// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardEMode, IRiskSteward} from '../../src/contracts/EdgeRiskStewardEMode.sol';
import {AaveStewardInjectorEMode} from '../../src/contracts/AaveStewardInjectorEMode.sol';

library DeployStewardContracts {
  struct DeployStewardInput {
    address pool;
    address configEngine;
    address riskCouncil;
    address governance;
  }

  struct DeployInjectorInput {
    address create3Factory;
    bytes32 salt;
    address riskSteward;
    address edgeRiskOracle;
    address owner;
    address guardian;
    uint8[] whitelistedEModes;
  }

  function _deployRiskStewards(DeployStewardInput memory input) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardEMode(input.pool, input.configEngine, input.riskCouncil, input.governance, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployEModeStewardInjector(DeployInjectorInput memory input) internal returns (address) {
    address[] memory whitelistedMarkets = new address[](input.whitelistedEModes.length);
    for (uint256 i = 0; i < input.whitelistedEModes.length; i++) {
      whitelistedMarkets[i] = address(uint160(input.whitelistedEModes[i]));
    }

    address stewardInjector = ICreate3Factory(input.create3Factory).create(
      input.salt,
      abi.encodePacked(
        type(AaveStewardInjectorEMode).creationCode,
        abi.encode(input.edgeRiskOracle, input.riskSteward, whitelistedMarkets, input.owner, input.guardian)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory config;
    config.eModeConfig = IRiskSteward.EmodeConfig({
      ltv: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50}),
      liquidationThreshold: IRiskSteward.RiskParamConfig({
        minDelay: 3 days,
        maxPercentChange: 50
      }),
      liquidationBonus: IRiskSteward.RiskParamConfig({minDelay: 3 days, maxPercentChange: 50})
    });
    return config;
  }
}

// make deploy-ledger contract=scripts/deploy/DeployEModeInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = address(0); // TODO

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'EModeStewardInjector';
    address predictedStewardsInjector = ICreate3Factory(MiscEthereum.CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      DeployStewardContracts.DeployStewardInput({
        pool: address(AaveV3Ethereum.POOL),
        configEngine: AaveV3Ethereum.CONFIG_ENGINE,
        riskCouncil: predictedStewardsInjector,
        governance: GovernanceV3Ethereum.EXECUTOR_LVL_1
      })
    );

    uint8[] memory whitelistedEModes = new uint8[](1);
    whitelistedEModes[0] = 8;

    DeployStewardContracts._deployEModeStewardInjector(
      DeployStewardContracts.DeployInjectorInput({
        create3Factory: MiscEthereum.CREATE_3_FACTORY,
        salt: salt,
        riskSteward: riskSteward,
        edgeRiskOracle: EDGE_RISK_ORACLE,
        owner: GovernanceV3Ethereum.EXECUTOR_LVL_1,
        guardian: GUARDIAN,
        whitelistedEModes: whitelistedEModes
      })
    );
    vm.stopBroadcast();
  }
}
