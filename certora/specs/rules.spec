using RiskSteward as RS;
using AaveV3ConfigEngine as Engine;


/*===========================================================================
  This is a specification file for the contract RiskSteward.

  We check the following aspects for each update function:
  - The function update the correct field in the Debounce struct to current timestamp.
  - The function calls the correct function either in AaveV3ConfigEngine or in Capo to make the real update.
  =============================================================================*/

methods {
  function updateCaps(IAaveV3ConfigEngine.CapsUpdate[] capsUpdate) external;
  function getTimelock(address asset) external returns (IRiskSteward.Debounce) envfree;

  function AaveV3ConfigEngine.updateCaps(IAaveV3ConfigEngine.CapsUpdate[] updates)
    external => set_CALLED_updateCaps();
  function AaveV3ConfigEngine.updateRateStrategies(IAaveV3ConfigEngine.RateStrategyUpdate[])
    external => set_CALLED_updateRateStrategies();
  function AaveV3ConfigEngine.updateCollateralSide(IAaveV3ConfigEngine.CollateralUpdate[])
    external => set_CALLED_updateCollateral();

  function _.setCapParameters(IPriceCapAdapter.PriceCapUpdateParams) external => set_CALLED_setCapParameters() expect void;
  function _.setPriceCap(int256) external => set_CALLED_setPriceCap() expect void;
}


ghost bool CALLED_updateCaps {
  axiom 1==1;
}
function set_CALLED_updateCaps() {
  CALLED_updateCaps = true;
}

ghost bool CALLED_updateRateStrategies {
  axiom 1==1;
}
function set_CALLED_updateRateStrategies() {
  CALLED_updateRateStrategies = true;
}

ghost bool CALLED_updateCollateral {
  axiom 1==1;
}
function set_CALLED_updateCollateral() {
  CALLED_updateCollateral = true;
}

ghost bool CALLED_setCapParameters {
  axiom 1==1;
}
function set_CALLED_setCapParameters() {
  CALLED_setCapParameters = true;
}

ghost bool CALLED_setPriceCap {
  axiom 1==1;
}
function set_CALLED_setPriceCap() {
  CALLED_setPriceCap = true;
}

ghost uint256 KEEP_CURRENT {
  axiom KEEP_CURRENT == 2^256-1 - 42;
}

/*===========================================================================
  Rule: updateCaps_validity.

  Description: the rule checks that:
  1. After a successed call to updateCaps, the fields supplyCapLastUpdated and borrowCapLastUpdated 
     get the value of current timestamp.
  2. The function AaveV3ConfigEngine.updateCaps is called.

  Status: PASS
  ===========================================================================*/
rule updateCaps_validity(env e) {
  IAaveV3ConfigEngine.CapsUpdate[] capsUpdate;

  require capsUpdate.length <= 2; // The length of the array is either 1 or 2.
                                  // Accordingly loop_iter==2
  uint i; // this is the entry of the array that we shall look at
  require i==1 || i==2; 

  require capsUpdate[i].supplyCap != KEEP_CURRENT;
  require capsUpdate[i].borrowCap != KEEP_CURRENT;

  updateCaps(e,capsUpdate);

  address asset = capsUpdate[i].asset;

  assert getTimelock(asset).supplyCapLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).borrowCapLastUpdated == require_uint40(e.block.timestamp);
  assert CALLED_updateCaps==true;
}


/*===========================================================================
  Rule: updateRates_validity.

  Description: the rule checks that:
  1. After a successed call to updateRates, the fields optimalUsageRatio, baseVariableBorrowRate
     variableRateSlope1, variableRateSlope2 get the value of current timestamp.
  2. The function AaveV3ConfigEngine.updateRateStrategies is called.

  Status: PASS
  ===========================================================================*/
rule updateRates_validity(env e) {
  IAaveV3ConfigEngine.RateStrategyUpdate[] ratesUpdate;

  require ratesUpdate.length <= 2; // The length of the array is either 1 or 2.
                                  // Accordingly loop_iter==2
  uint i; // this is the entry of the array that we shall look at
  require i==1 || i==2; 
  
  require ratesUpdate[i].params.optimalUsageRatio != KEEP_CURRENT;
  require ratesUpdate[i].params.baseVariableBorrowRate != KEEP_CURRENT;
  require ratesUpdate[i].params.variableRateSlope1 != KEEP_CURRENT;
  require ratesUpdate[i].params.variableRateSlope2 != KEEP_CURRENT;
  
  updateRates(e,ratesUpdate);

  address asset = ratesUpdate[i].asset;

  assert getTimelock(asset).optimalUsageRatioLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).baseVariableRateLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).variableRateSlope1LastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).variableRateSlope2LastUpdated == require_uint40(e.block.timestamp);
  assert CALLED_updateRateStrategies==true;
}


/*===========================================================================
  Rule: updateCollateralSide_validity.

  Description: the rule checks that:
  1. After a successed call to updateCollateralSide, the fields ltvLastUpdated, liquidationThresholdLastUpdated
     liquidationBonusLastUpdated, and debtCeilingLastUpdated get the value of current timestamp.
  2. The function AaveV3ConfigEngine.updateCollateralSide is called.

  Status: PASS
  ===========================================================================*/
rule updateCollateralSide_validity(env e) {
  IAaveV3ConfigEngine.CollateralUpdate[] collateralUpdate;

  require collateralUpdate.length <= 2; // The length of the array is either 1 or 2.
                                        // Accordingly loop_iter==2
  uint i; // this is the entry of the array that we shall look at
  require i==1 || i==2; 
  
  require collateralUpdate[i].ltv != KEEP_CURRENT;
  require collateralUpdate[i].liqThreshold != KEEP_CURRENT;
  require collateralUpdate[i].liqBonus != KEEP_CURRENT;
  require collateralUpdate[i].debtCeiling != KEEP_CURRENT;
  
  updateCollateralSide(e,collateralUpdate);

  address asset = collateralUpdate[i].asset;

  assert getTimelock(asset).ltvLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).liquidationThresholdLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).liquidationBonusLastUpdated == require_uint40(e.block.timestamp);
  assert getTimelock(asset).debtCeilingLastUpdated == require_uint40(e.block.timestamp);
  assert CALLED_updateCollateral==true;
}





/*===========================================================================
  Rule: updateLstPriceCaps_validity

  Description: the rule checks that:
  1. After a successed call to updateLstPriceCaps, the field priceCapLastUpdated
     get the value of current timestamp.
  2. The function IPriceCapAdapter.setCapParameters is called.

  Status: PASS
  ===========================================================================*/
rule updateLstPriceCaps_validity(env e) {
  IRiskSteward.PriceCapLstUpdate[] priceCapUpdates;

  require priceCapUpdates.length <= 2; // The length of the array is either 1 or 2.
                                       // Accordingly loop_iter==2
  uint i; // this is the entry of the array that we shall look at
  require i==1 || i==2; 
  
  updateLstPriceCaps(e,priceCapUpdates);

  address oracle = priceCapUpdates[i].oracle;

  assert getTimelock(oracle).priceCapLastUpdated == require_uint40(e.block.timestamp);
  assert CALLED_setCapParameters==true;
}




/*===========================================================================
  Rule: updateStablePriceCaps_validity

  Description: the rule checks that:
  1. After a successed call to updateStablePriceCaps, the field priceCapLastUpdated
     get the value of current timestamp.
  2. The function IPriceCapAdapterStable.setPriceCap is called.

  Status: PASS
  ===========================================================================*/
rule updateStablePriceCaps_validity(env e) {
  IRiskSteward.PriceCapStableUpdate[] priceCapUpdates;

  require priceCapUpdates.length <= 2; // The length of the array is either 1 or 2.
                                       // Accordingly loop_iter==2
  uint i; // this is the entry of the array that we shall look at
  require i==1 || i==2; 
  
  
  updateStablePriceCaps(e,priceCapUpdates);

  address oracle = priceCapUpdates[i].oracle;

  assert getTimelock(oracle).priceCapLastUpdated == require_uint40(e.block.timestamp);
  assert CALLED_setPriceCap==true;
}


