pragma solidity ^0.6.6;

abstract contract AMandate {
    /* don't forget to update the consts in the tests when you are changing the values here*/
    enum AgreementLifeCycle {
        EMPTY, // newly created and unfilled with data
        POPULATED, // filled with data
        PUBLISHED, // terms are solidified and Investors may now commit capital, TODO discuss rollback for the future
        ACTIVE, // trading may happen during this phase; no status transition backwards allowed
        STOPPEDOUT, //RESERVED
        CLOSEDINPROFIT, // RESERVED
        EXPIRED, //the ACTIVE period has been over now
        SETTLED // All Investors and a Manager have withdrawn their yields / collateral
    }

    struct Agreement {
        AgreementLifeCycle status;
        address manager; // creator of the agreement = Manager
        address baseCoin; // address of a (stable)coin for settlement; assumed IERC20 interface
        uint8 targetReturnRate; // the rate of return aimed at by Manager
        uint8 maxCollateralRateIfAvailable; // maximum percentage of collateral offered by Manager in case if the collateral is still available based on FCFS basis
        uint256 __collatAmount; // absolute collateral balance in baseCoin
        uint256 __freeCollatAmount; // absolute collateral remaining on the agreements after all the Mandates have been collateralized
        uint256 __committedCapital; // absolute amount of capital committed to this Agreement (usually made through Mandates)
        uint256 __committedMandates; // count of non-zero mandates participating in the trade; to count the settlement countdown against
        uint256 __settledMandates;
        uint32 openPeriod; // seconds of duration of a PUBLISHED period
        uint32 activePeriod; // seconds of duration of an ACTIVE phase of the Agreemenet
        // bool waitForOpenPeriodToActivate; // @TODO: let trade manager to decide if it possible to activate trade

        uint256 publishTimestamp; // timestamp when the Agreement was marked as PUBLISHED
        uint8 stat_actualReturnRate; // used to hold the actual results of trading on the Agreement
        uint8 stat_remainingCollateral; // used to hold the actual results of trading on the Agreement
        uint8 stat_actualDuration; // used to hold the actual results of trading on the Agreement
    }

    enum MandateLifeCycle { // THIS IS WORK-IN-PROGRESS
        EMPTY,
        POPULATED,
        COMMITTED,
        ACTIVE,
        STOPPEDOUT,
        CLOSEDINPROFIT,
        EXPIRED,
        SETTLED,
        CANCELED
    }

    struct Mandate {
        MandateLifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        address investor; // creater of this Mandate, Investor
        uint256 agreement; //reference to an agreementID to which this mandate is committed
        uint256 __committedCapital; // how much capital an Investor has committed; to be updated on the deposit / withdrawal
        uint256 __collatAmount; // collateral amount locked in by fund manager
    }
}
