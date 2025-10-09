// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {AaveV3Plasma} from 'aave-address-book/AaveV3Plasma.sol';
import {GovernanceV3Plasma} from 'aave-address-book/GovernanceV3Plasma.sol';
import {ICreate3Factory} from 'solidity-utils/contracts/create3/interfaces/ICreate3Factory.sol';
import {EdgeRiskStewardDiscountRate, IRiskSteward} from '../../src/contracts/EdgeRiskStewardDiscountRate.sol';
import {AaveStewardInjectorDiscountRate} from '../../src/contracts/AaveStewardInjectorDiscountRate.sol';
import {GelatoAaveStewardInjectorDiscountRate} from '../../src/contracts/gelato/GelatoAaveStewardInjectorDiscountRate.sol';

library DeployStewardContracts {
  struct DeployStewardInput {
    address pool;
    address configEngine;
    address riskCouncil;
    address owner;
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
    bool isGelatoInjector;
  }

  function _deployRiskStewards(
    DeployStewardInput memory input
  ) internal returns (address) {
    address riskSteward = address(
      new EdgeRiskStewardDiscountRate(input.pool, input.configEngine, input.riskCouncil, input.owner, _getRiskConfig())
    );
    return riskSteward;
  }

  function _deployDiscountRateStewardInjector(
    DeployInjectorInput memory input
  ) internal returns (address) {
    bytes memory injectorCode = input.isGelatoInjector ?
      type(GelatoAaveStewardInjectorDiscountRate).creationCode : type(AaveStewardInjectorDiscountRate).creationCode;

    address stewardInjector = ICreate3Factory(input.create3Factory).create(
      input.salt,
      abi.encodePacked(
        injectorCode,
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
        owner: GovernanceV3Ethereum.EXECUTOR_LVL_1
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
        whitelistedMarkets: whitelistedPendleAssets,
        isGelatoInjector: false
      })
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployDiscountRateInjector.s.sol:DeployPlasma chain=plasma
contract DeployPlasma is PlasmaScript {
  address constant GUARDIAN = 0x1cF16B4e76D4919bD939e12C650b8F6eb9e02916;
  address constant EDGE_RISK_ORACLE = 0xAe48F22903d43f13f66Cc650F57Bd4654ac222cb;
  address constant CREATE_3_FACTORY = 0xc4A82c968540B47032F3a51fA7e4f09f6FAE3308;

  function run() external {
    vm.startBroadcast();
    bytes32 salt = 'DiscountRateStewardInjectorV2';
    address predictedStewardsInjector = ICreate3Factory(CREATE_3_FACTORY)
      .predictAddress(msg.sender, salt);

    address riskSteward = DeployStewardContracts._deployRiskStewards(
      DeployStewardContracts.DeployStewardInput({
        pool: address(AaveV3Plasma.POOL),
        configEngine: AaveV3Plasma.CONFIG_ENGINE,
        riskCouncil: predictedStewardsInjector,
        owner: GovernanceV3Plasma.EXECUTOR_LVL_1
      })
    );

    DeployStewardContracts._deployDiscountRateStewardInjector(
      DeployStewardContracts.DeployInjectorInput({
        create3Factory: CREATE_3_FACTORY,
        salt: salt,
        riskSteward: riskSteward,
        aaveOracle: address(AaveV3Plasma.ORACLE),
        edgeRiskOracle: EDGE_RISK_ORACLE,
        owner: GovernanceV3Plasma.EXECUTOR_LVL_1,
        guardian: GUARDIAN,
        whitelistedMarkets: new address[](0),
        isGelatoInjector: true
      })
    );
    vm.stopBroadcast();
  }
}
