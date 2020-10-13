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
        // validations
        require(_deal.status < LifeCycle.ACCEPTED, "LifeCycle violation. Can't populate deal beyond LifeCycle.ACCEPTED");
        // actions
        _deal.status = LifeCycle.POPULATED;
        _deal.targetManager = targetManager;
        _deal.duration = duration;
        _deal.targetManager = takeProfit;
        _deal.stopLoss = stopLoss;
        
        // event emissions
        emit PopulateDeal(targetManager, duration, takeProfit, stopLoss);
    }

    function submitDeal() public onlyOwner {
        // validations
        // actions
        _deal.status = LifeCycle.SUBMITTED;
        // event emissions
        emit SubmitDeal(_deal.targetManager, _deal.duration, _deal.takeProfit, _deal.stopLoss);
    }
    function acceptDeal() public onlyFundManager {
        // validations
        // actions
        // event emissions
    }
    function startDeal() public onlyFundManager {
        // validations
        // actions
        // event emissions
    }
    function closeDeal() public onlyFundManager {
        // validations
        // actions
        // event emissions

    }
    function cancelDeal() public onlyFundManager {
        // validations
        // actions
        // event emissions
    }

    function _init() private {}

    event PopulateDeal(address indexed targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event SubmitDeal(address indexed targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event AcceptDeal();
    event StartDeal();
    event CloseDeal();
    event CancelDeal();
}