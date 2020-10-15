pragma solidity ^0.6.6;

abstract contract AMandate {
    enum AgreementLifeCycle {
        EMPTY,
        POPULATED,
        PUBLISHED,
        ACTIVE,
        STOPPEDOUT,
        CLOSEDINPROFIT,
        EXPIRED,
        SETTLED
    }

    struct Agreement {
        AgreementLifeCycle status;
        address manager;
        address baseCoin;
        uint8 targetReturnRate;
        uint8 maxCollateralRateIfAvailable;
        uint256 collatAmount;
        uint32 duration;
        uint32 openPeriod;
        uint256 publishTimestamp;
        
        uint8 stat_actualReturnRate;
        uint8 stat_remainingCollateral;
    }

    enum MandateLifeCycle {
        EMPTY,
        POPULATED,
        COMMITTED,
        ACTIVE,
        STOPPEDOUT,
        CLOSEDINPROFIT,
        EXPIRED,
        SETTLED
    }

    struct Mandate {
        MandateLifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        uint256 collatAmount; // collateral ethers locked in by fund manager
        address investor;
        uint256 agreement;
        uint256 duration;
        uint16 takeProfit;
        uint16 stopLoss;
    }
}
