// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IAaveStewardInjectorCollateral} from '../interfaces/IAaveStewardInjectorCollateral.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {EnumerableSet} from 'openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {IAToken} from 'aave-v3-origin/src/contracts/interfaces/IAToken.sol';

/**
 * @title AaveStewardInjectorCollateral
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform collateral update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorCollateral is AaveStewardInjectorBase, IAaveStewardInjectorCollateral {
  using Strings for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _markets;

  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param owner address of the owner of the stewards injector.
   * @param guardian address of the guardian of the stewards injector.
   */
  constructor(
    address riskOracle,
    address riskSteward,
    address owner,
    address guardian
  ) AaveStewardInjectorBase(riskOracle, riskSteward, owner, guardian) {}

  /// @inheritdoc AaveStewardInjectorBase
  function checkUpkeep(bytes memory) public view virtual override returns (bool, bytes memory) {
    address[] memory markets = getMarkets();
    string[] memory updateTypes = getUpdateTypes();

    ActionData[] memory actions = new ActionData[](markets.length * updateTypes.length);
    uint256 actionCount;

    for (uint256 i = 0; i < markets.length; i++) {
      for (uint256 j = 0; j < updateTypes.length; j++) {
        address market = markets[i];
        string memory updateType = updateTypes[j];

        try
          IRiskOracle(RISK_ORACLE).getLatestUpdateByParameterAndMarket(updateType, market)
        returns (IRiskOracle.RiskParameterUpdate memory updateRiskParams) {
          if (_canUpdateBeInjected(updateRiskParams)) {
            actions[actionCount] = ActionData({market: market, updateType: updateType});
            actionCount++;
          }
        } catch {}
      }
    }

    if (actionCount > 0) return (true, abi.encode(_getRandomizedAction(actions, actionCount)));
    return (false, '');
  }

  /// @inheritdoc AaveStewardInjectorBase
  function performUpkeep(bytes calldata performData) external override {
    ActionData memory actionData = abi.decode(performData, (ActionData));

    IRiskOracle.RiskParameterUpdate memory updateRiskParams = IRiskOracle(RISK_ORACLE)
      .getLatestUpdateByParameterAndMarket(actionData.updateType, actionData.market);

    if (!_canUpdateBeInjected(updateRiskParams)) {
      revert UpdateCannotBeInjected();
    }

    IRiskSteward(RISK_STEWARD).updateCollateralSide(_repackCollateralUpdate(updateRiskParams));
    _isUpdateIdExecuted[updateRiskParams.updateId] = true;

    emit ActionSucceeded(updateRiskParams.updateId);
  }

  /// @inheritdoc IAaveStewardInjectorCollateral
  function getMarkets() public view returns (address[] memory) {
    return _markets.values();
  }

  /// @inheritdoc IAaveStewardInjectorCollateral
  function addMarkets(address[] calldata markets) external onlyOwner {
    for (uint256 i = 0; i < markets.length; i++) {
      _markets.add(markets[i]);
      emit MarketAdded(markets[i]);
    }
  }

  /// @inheritdoc IAaveStewardInjectorCollateral
  function removeMarkets(address[] calldata markets) external onlyOwner {
    for (uint256 i = 0; i < markets.length; i++) {
      _markets.remove(markets[i]);
      emit MarketRemoved(markets[i]);
    }
  }

  /// @inheritdoc IAaveStewardInjectorCollateral
  function getUpdateTypes() public pure returns (string[] memory updateTypes) {
    updateTypes = new string[](3);
    updateTypes[0] = 'ltv';
    updateTypes[1] = 'liquidationThreshold';
    updateTypes[2] = 'liquidationBonus';
  }

  /**
   * @notice method to check if the update from risk oracle could be injected into the risk steward.
   * @dev only allow injecting collateral updates for the configured assets i.e aToken addresses.
   * @param updateRiskParams struct containing the risk param update from the risk oracle to check if it can be injected.
   * @return true if the update could be injected to the risk steward, false otherwise.
   */
  function _canUpdateBeInjected(
    IRiskOracle.RiskParameterUpdate memory updateRiskParams
  ) internal view returns (bool) {
    return (!isUpdateIdExecuted(updateRiskParams.updateId) &&
      (updateRiskParams.timestamp + EXPIRATION_PERIOD > block.timestamp) &&
      _markets.contains(updateRiskParams.market) &&
      (updateRiskParams.updateType.equal('ltv') ||
        updateRiskParams.updateType.equal('liquidationThreshold') ||
        updateRiskParams.updateType.equal('liquidationBonus')) &&
      !isDisabled(updateRiskParams.updateId) &&
      !isInjectorPaused());
  }

  /**
   * @notice method to repack update params from the risk oracle to the format of risk steward.
   * @param riskParams the risk update param from the edge risk oracle.
   * @return collateralUpdate the repacked collateral update in the format of the risk steward.
   */
  function _repackCollateralUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal view returns (IEngine.CollateralUpdate[] memory collateralUpdate) {
    address underlyingAddress = IAToken(riskParams.market).UNDERLYING_ASSET_ADDRESS();
    uint256 collateralValue = uint256(bytes32(riskParams.newValue));

    collateralUpdate = new IEngine.CollateralUpdate[](1);
    if (riskParams.updateType.equal('ltv')) {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: collateralValue,
        liqThreshold: EngineFlags.KEEP_CURRENT,
        liqBonus: EngineFlags.KEEP_CURRENT,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    } else if (riskParams.updateType.equal('liquidationThreshold')) {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: EngineFlags.KEEP_CURRENT,
        liqThreshold: collateralValue,
        liqBonus: EngineFlags.KEEP_CURRENT,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    } else {
      collateralUpdate[0] = IEngine.CollateralUpdate({
        asset: underlyingAddress,
        ltv: EngineFlags.KEEP_CURRENT,
        liqThreshold: EngineFlags.KEEP_CURRENT,
        liqBonus: collateralValue,
        debtCeiling: EngineFlags.KEEP_CURRENT,
        liqProtocolFee: EngineFlags.KEEP_CURRENT
      });
    }
  }

  /**
   * @notice method to select a randomized action from a list of actions.
   * @param actions the list of actions from where we select a randomized action.
   * @param actionCount the count of actions.
   * @return action the randomized action from the actions list.
   */
  function _getRandomizedAction(
    ActionData[] memory actions,
    uint256 actionCount
  ) internal view returns (ActionData memory action) {
    uint256 randomNumber = uint256(
      keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))
    );
    action = actions[randomNumber % actionCount];
  }
}
