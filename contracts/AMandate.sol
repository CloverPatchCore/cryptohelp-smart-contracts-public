pragma solidity ^0.6.6;

abstract contract AMandate {
    enum LifeCycle {
        EMPTY,
        POPULATED,
        SUBMITTED,
        ACCEPTED,
        STARTED,
        STOPPEDOUT,
        CLOSEDINPROFIT,
        SETTLED
    }

    struct Mandate {
        LifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        uint256 ethers;
        uint256 collatEthers; // collateral ethers locked in by fund manager
        address investor;
        address manager;
        uint256 duration;
        uint16 takeProfit;
        uint16 stopLoss;
    }
}
