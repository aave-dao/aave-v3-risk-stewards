// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardDiscountRate, IRiskSteward} from '../../src/contracts/EdgeRiskStewardDiscountRate.sol';
import {AaveStewardInjectorDiscountRate} from '../../src/contracts/AaveStewardInjectorDiscountRate.sol';

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
    address aaveOracle;
    address edgeRiskOracle;
    address owner;
    address guardian;
    address[] whitelistedMarkets;
  }

  function _deployRiskStewards(
    DeployStewardInput memory input
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardDiscountRate(input.pool, input.configEngine, input.riskCouncil, input.governance, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployDiscountRateStewardInjector(
    DeployInjectorInput memory input
  ) internal returns (address) {
    address stewardInjector = ICreate3Factory(input.create3Factory).create(
      input.salt,
      abi.encodePacked(
        type(AaveStewardInjectorDiscountRate).creationCode,
        abi.encode(input.aaveOracle, input.edgeRiskOracle, input.riskSteward, input.whitelistedMarkets, input.owner, input.guardian)
      )
    );
    return stewardInjector;
  }

  function _getRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.Config memory config;
    config.priceCapConfig.discountRatePendle = IRiskSteward.RiskParamConfig({
      minDelay: 2 days,
      maxPercentChange: 0.01e18 // 1%
    });

    return config;
  }
}

// make deploy-ledger contract=scripts/deploy/DeployDiscountRateInjector.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  address constant GUARDIAN = 0xff37939808EcF199A2D599ef91D699Fb13dab7F7;
  address constant EDGE_RISK_ORACLE = 0x7ABB46C690C52E919687D19ebF89C81A6136C1F2;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'DiscountRateStewardInjector';
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

    address[] memory whitelistedPendleAssets = new address[](3);
    whitelistedPendleAssets[0] = AaveV3EthereumAssets.PT_sUSDE_31JUL2025_UNDERLYING;
    whitelistedPendleAssets[1] = AaveV3EthereumAssets.PT_USDe_31JUL2025_UNDERLYING;
    whitelistedPendleAssets[2] = AaveV3EthereumAssets.PT_eUSDE_14AUG2025_UNDERLYING;

    DeployStewardContracts._deployDiscountRateStewardInjector(
      DeployStewardContracts.DeployInjectorInput({
        create3Factory: MiscEthereum.CREATE_3_FACTORY,
        salt: salt,
        riskSteward: riskSteward,
        aaveOracle: address(AaveV3Ethereum.ORACLE),
        edgeRiskOracle: EDGE_RISK_ORACLE,
        owner: GovernanceV3Ethereum.EXECUTOR_LVL_1,
        guardian: GUARDIAN,
        whitelistedMarkets: whitelistedPendleAssets
      })
    );
    vm.stopBroadcast();
  }
}
