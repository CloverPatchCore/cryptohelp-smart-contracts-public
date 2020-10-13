pragma solidity ^0.6.6;

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

    struct Mandate {
        LifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        uint256 ethers;
        address investor;
        address manager;
        uint16 takeProfit;
        uint16 stopLoss;
    }
}
