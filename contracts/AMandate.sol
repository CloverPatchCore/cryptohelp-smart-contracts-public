pragma solidity ^0.6.6;


/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract AMandate {
    enum LifeCycle {
        EMPTY,
        POPULATED,
        SUBMITTED,
        ACCEPTED,
        STARTED,
        STOPPEDOUT,
        CLOSED
    }

    struct Deal {
        LifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        address targetManager;
        uint16 takeProfit;
        uint16 stopLoss;
    }
}
