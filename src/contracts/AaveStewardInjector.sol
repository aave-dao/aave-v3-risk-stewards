// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRiskOracle} from './dependencies/IRiskOracle.sol';
import {IRiskSteward} from '../interfaces/IRiskSteward.sol';
import {IAaveStewardInjector, AutomationCompatibleInterface} from '../interfaces/IAaveStewardInjector.sol';
import {IAaveV3ConfigEngine as IEngine} from 'aave-v3-origin/src/periphery/contracts/v3-config-engine/AaveV3ConfigEngine.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

/**
 * @title AaveStewardInjector
 * @author BGD Labs
 * @notice Contract to perform automation on risk steward using the edge risk oracle.
 * @dev Aave chainlink automation-keeper-compatible contract to:
 *      - check if updates from edge risk oracles can be injected into risk steward.
 *      - injectes risk updates on the risk steward if all conditions are met.
 */
contract AaveStewardInjector is Ownable, IAaveStewardInjector {
  /// @inheritdoc IAaveStewardInjector
  address public immutable RISK_ORACLE;

  /// @inheritdoc IAaveStewardInjector
  address public immutable RISK_STEWARD;

  /**
   * @inheritdoc IAaveStewardInjector
   * @dev after an update is added on the risk oracle, the update is only valid from the timestamp it was added
   *      on the risk oracle plus the expiration time, after which the update cannot be injected into the risk steward.
   */
  uint256 public constant EXPIRATION_PERIOD = 6 hours;

  /**
   * @inheritdoc IAaveStewardInjector
   * @dev maximum number of updateIds to check before the latest updateCounter, if they could be injected.
   *      from the latest updateId we check 10 more updateIds to be sure that no update is being unchecked.
   */
  uint256 public constant MAX_SKIP = 10;

  mapping(uint256 => bool) internal _isUpdateIdExecuted;
  mapping(uint256 => bool) internal _disabledUpdates;
  mapping(address => bool) internal _isWhitelistedAddress;
  mapping(string => bool) internal _isValidUpdateType;

  /**
   * @param riskOracle address of the edge risk oracle contract.
   * @param riskSteward address of the risk steward contract.
   */
  constructor(address riskOracle, address riskSteward) {
    RISK_ORACLE = riskOracle;
    RISK_STEWARD = riskSteward;
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev run off-chain, checks if updates from risk oracle should be injected on risk steward
   */
  function checkUpkeep(bytes memory) public view virtual override returns (bool, bytes memory) {
    uint256 latestUpdateId = IRiskOracle(RISK_ORACLE).updateCounter();
    uint256 updateIdLowerBound = latestUpdateId <= MAX_SKIP ? 1 : latestUpdateId - MAX_SKIP;

    for (uint256 i = latestUpdateId; i >= updateIdLowerBound; i--) {
      if (_canUpdateBeInjected(i, false)) return (true, abi.encode(i));
    }

    return (false, '');
  }

  /**
   * @inheritdoc AutomationCompatibleInterface
   * @dev executes injection of an update from the risk oracle into the risk steward.
   * @param performData encoded updateId to inject into the risk steward.
   */
  function performUpkeep(bytes calldata performData) external override {
    uint256 updateIdToExecute = abi.decode(performData, (uint256));

    if (!_canUpdateBeInjected(updateIdToExecute, true)) {
      revert UpdateCannotBeInjected();
    }

    IRiskOracle.RiskParameterUpdate memory riskParams = IRiskOracle(RISK_ORACLE).getUpdateById(updateIdToExecute);
    IRiskSteward(RISK_STEWARD).updateRates(_repackRateUpdate(riskParams));
    emit ActionSucceeded(updateIdToExecute);
  }

  /// @inheritdoc IAaveStewardInjector
  function isDisabled(uint256 updateId) public view returns (bool) {
    return _disabledUpdates[updateId];
  }

  /// @inheritdoc IAaveStewardInjector
  function disableAutomationById(uint256 updateId, bool disabled) external onlyOwner {
    _disabledUpdates[updateId] = disabled;
    emit UpdateDisabled(updateId, disabled);
  }

  /// @inheritdoc IAaveStewardInjector
  function addUpdateType(string memory updateType, bool isValid) external onlyOwner {
    _isValidUpdateType[updateType] = isValid;
    emit UpdateTypeChanged(updateType, isValid);
  }

  /// @inheritdoc IAaveStewardInjector
  function isValidUpdateType(string memory updateType) public view returns (bool) {
    return _isValidUpdateType[updateType];
  }

  /// @inheritdoc IAaveStewardInjector
  function whitelistAddress(address contractAddress, bool isWhitelisted) external onlyOwner {
    _isWhitelistedAddress[contractAddress] = isWhitelisted;
    emit AddressWhitelisted(contractAddress, isWhitelisted);
  }

  /// @inheritdoc IAaveStewardInjector
  function isWhitelistedAddress(address contractAddress) public view returns (bool) {
    return _isWhitelistedAddress[contractAddress];
  }

  /// @inheritdoc IAaveStewardInjector
  function isUpdateIdExecuted(uint256 updateid) public view returns (bool) {
    return _isUpdateIdExecuted[updateid];
  }

  /**
   * @notice method to check if the updateId from risk oracle could be injected into the risk steward.
   * @param updateId the id from the risk oralce to check if it can be injected.
   * @param validateIfNewUpdatesExecuted if true, we validate that all updates after current are executed, false otherwise.
   * @return true if the update could be injected to the risk steward, false otherwise.
   */
  function _canUpdateBeInjected(
    uint256 updateId,
    bool validateIfNewUpdatesExecuted
  ) internal view returns (bool) {
    IRiskOracle.RiskParameterUpdate memory riskParams = IRiskOracle(RISK_ORACLE).getUpdateById(
      updateId
    );

    if (validateIfNewUpdatesExecuted) {
      uint256 latestUpdateId = IRiskOracle(RISK_ORACLE).updateCounter();
      if (updateId > latestUpdateId) return false;

      // validate that the latest updates are executed before exeucting the current update
      if (updateId != latestUpdateId) {
        for (uint256 i = updateId + 1; i <= latestUpdateId; i++) {
          if (!isUpdateIdExecuted(i) && !isDisabled(i)) return false;
        }
      }
    }

    return (
      !isUpdateIdExecuted(updateId) &&
      (riskParams.timestamp + EXPIRATION_PERIOD > block.timestamp) &&
      isWhitelistedAddress(riskParams.market) &&
      isValidUpdateType(riskParams.updateType) &&
      !isDisabled(updateId)
    );
  }

  /**
   * @notice method to repack update params from the risk oracle to the format of risk steward.
   * @param riskParams the risk update param from the edge risk oracle.
   * @return the repacked risk update in the format of the risk steward.
   */
  function _repackRateUpdate(
    IRiskOracle.RiskParameterUpdate memory riskParams
  ) internal pure returns (IEngine.RateStrategyUpdate[] memory) {
    IEngine.RateStrategyUpdate[] memory rateUpdate = new IEngine.RateStrategyUpdate[](1);
    rateUpdate[0].asset = riskParams.market;
    rateUpdate[0].params = abi.decode(riskParams.newValue, (IEngine.InterestRateInputData));
    return rateUpdate;
  }
}
