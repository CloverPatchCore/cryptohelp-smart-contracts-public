pragma solidity ^0.6.6;
import "@openzeppelin/contracts/access/Ownable.sol";

/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract Mandate is Ownable {

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

    address private _manager;
    Deal private _deal;
    //data structure designated to holding the info about the mandate

    modifier onlyFundManager() {
        require(_deal.targetManager != address(0), "Fund Manager not appointed yet");
        require(msg.sender == _deal.targetManager, "Only appointed Fund Manager");
        _;
    }

    constructor() public {
        _init();        
    }
    function populateDeal(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public payable onlyOwner {
        _populateDeal(targetManager, duration, takeProfit, stopLoss);
    }

    function submitDeal() public onlyOwner {}
    function acceptDeal() public onlyFundManager {}
    function startDeal() public onlyFundManager {}
    function closeDeal() public onlyFundManager {}
    function cancelDeal() public onlyFundManager {}

    function _populateDeal(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) private {
        require(_deal.status < LifeCycle.ACCEPTED, "The deal is too far in the lifecycle to amend it");
        //TODO assign values here
    }
    function _init() private {}

    event PopulateDeal();
    event SubmitDeal();
    event AcceptDeal();
    event StartDeal();
    event CloseDeal();
    event CancelDeal();
}