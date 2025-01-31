// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IAaveStewardInjectorCaps} from '../interfaces/IAaveStewardInjectorCaps.sol';
import {AaveStewardInjectorBase} from './AaveStewardInjectorBase.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from 'aave-v3-origin/src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {EnumerableSet} from 'solidity-utils/contracts/oz-common/EnumerableSet.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';

/**
 * @title AaveStewardInjectorCaps
 * @author BGD Labs
 * @notice Aave chainlink automation-keeper-compatible contract to perform caps update injection
 *         on risk steward using the edge risk oracle.
 */
contract AaveStewardInjectorCaps is AaveStewardInjectorBase, IAaveStewardInjectorCaps {
  using Strings for string;
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _markets;

  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   * @param guardian address of the guardian / owner of the stewards injector.
   */
  constructor(
    address riskOracle,
    address riskSteward,
    address guardian
  ) AaveStewardInjectorBase(riskOracle, riskSteward, guardian) {}

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

    IRiskSteward(RISK_STEWARD).updateCaps(_repackCapUpdate(updateRiskParams));
    _isUpdateIdExecuted[updateRiskParams.updateId] = true;

    emit ActionSucceeded(updateRiskParams.updateId);
  }

  /// @inheritdoc IAaveStewardInjectorCaps
  function getMarkets() public view returns (address[] memory) {
    return _markets.values();
  }

  /// @inheritdoc IAaveStewardInjectorCaps
  function addMarkets(address[] memory markets) public onlyOwner {
    for (uint256 i = 0; i < markets.length; i++) {
      _markets.add(markets[i]);
      emit MarketAdded(markets[i]);
    }
  }

  /// @inheritdoc IAaveStewardInjectorCaps
  function removeMarkets(address[] memory markets) public onlyOwner {
    for (uint256 i = 0; i < markets.length; i++) {
      _markets.remove(markets[i]);
      emit MarketRemoved(markets[i]);
    }
  }

  /// @inheritdoc IAaveStewardInjectorCaps
  function getUpdateTypes() public pure returns (string[] memory updateTypes) {
    updateTypes = new string[](2);
    updateTypes[0] = 'supplyCap';
    updateTypes[1] = 'borrowCap';
  }

  /**
   * @notice method to check if the update from risk oracle could be injected into the risk steward.
   * @dev only allow injecting cap updates for the configured assets.
   * @param updateRiskParams struct containing the risk param update from the risk oracle to check if it can be injected.
   * @return true if the update could be injected to the risk steward, false otherwise.
   */
  function _canUpdateBeInjected(
    IRiskOracle.RiskParameterUpdate memory updateRiskParams
  ) internal view returns (bool) {
    return (
      !isUpdateIdExecuted(updateRiskParams.updateId) &&
      (updateRiskParams.timestamp + EXPIRATION_PERIOD > block.timestamp) &&
      _markets.contains(updateRiskParams.market) &&
      (updateRiskParams.updateType.equal('supplyCap') || updateRiskParams.updateType.equal('borrowCap')) &&
      !isDisabled(updateRiskParams.updateId) &&
      !isInjectorPaused()
    );
  }

  /**
   * @notice method to repack update params from the risk oracle to the format of risk steward.
   * @param riskParams the risk update param from the edge risk oracle.
   * @return capUpdate the repacked caps update in the format of the risk steward.
   */
  function _repackCapUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal pure returns (IEngine.CapsUpdate[] memory capUpdate) {
    capUpdate = new IEngine.CapsUpdate[](1);

    if (riskParams.updateType.equal('supplyCap')) {
      capUpdate[0] = IEngine.CapsUpdate({
        asset: riskParams.market,
        supplyCap: abi.decode(riskParams.newValue, (uint256)),
        borrowCap: EngineFlags.KEEP_CURRENT
      });
    } else {
      capUpdate[0] = IEngine.CapsUpdate({
        asset: riskParams.market,
        supplyCap: EngineFlags.KEEP_CURRENT,
        borrowCap: abi.decode(riskParams.newValue, (uint256))
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
