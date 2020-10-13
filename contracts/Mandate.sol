pragma solidity ^0.6.6;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract MandateBook is Ownable, ReentrancyGuard {

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
        uint256 ethers;
        LifeCycle status; // lifecycle status transitions to only happen through the functions; no direct setting or changing of the status
        address investor;
        address manager;
        uint256 duration;
        uint16 takeProfit;
        uint16 stopLoss;
    }

    address private _manager; //TODO REDO to list
    Mandate[] private _mandates;
    //data structure designated to holding the info about the mandate

    modifier onlyFundManager(uint256 id) {
        require(address(0) != _mandates[id].manager, "Fund Manager not appointed yet");
        require(msg.sender == _mandates[id].manager, "Only appointed Fund Manager");
        _;
    }

    //this checks if the sender is actually an investor on the indicated dealID
    modifier onlyInvestor(uint256 id) {
        require(msg.sender == _mandates[id].investor, "Only deal Investor");
        _;
    }

    constructor() public {
        _init();        
    }

    function createMandate(address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public payable nonReentrant returns(uint256 id) {

        Mandate memory m = Mandate({
            ethers: 0,
            status: LifeCycle.POPULATED,
            investor: msg.sender,
            manager: manager,
            duration: duration,
            takeProfit: takeProfit,
            stopLoss: stopLoss            
        });
        _mandates.push(m);
        id = _mandates.length - 1;
        if(msg.value > 0) _mandateTopUp(id, msg.value);

        emit CreateMandate(id, _mandates[id].ethers, msg.sender, manager, duration, takeProfit, stopLoss);
        
    }
    function populateMandate(uint256 id, address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public payable nonReentrant onlyInvestor(id) {
        // validations
        require(_mandates[id].status < LifeCycle.ACCEPTED, "LifeCycle violation. Can't populate deal beyond LifeCycle.ACCEPTED");
        
        // actions
        _mandates[id].status = LifeCycle.POPULATED;
        _mandates[id].investor = msg.sender;
        _mandates[id].manager = manager;
        _mandates[id].duration = duration;
        _mandates[id].takeProfit = takeProfit;
        _mandates[id].stopLoss = stopLoss;

        if(msg.value > 0) _mandateTopUp(id, msg.value);
        
        // event emissions
        emit PopulateMandate(id, _mandates[id].ethers, msg.sender, manager, duration, takeProfit, stopLoss);
    }

    function submitMandate(uint256 id) public onlyInvestor(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.SUBMITTED;
        // event emissions
        emit SubmitMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    function acceptMandate(uint256 id) public onlyFundManager(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.ACCEPTED;
        // event emissions
        emit AcceptMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    function startMandate(uint256 id) public onlyFundManager(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.STARTED;
        // event emissions
        emit StartMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    function closeMandate(uint256 id) public onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CloseMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);

    }
    function cancelMandate(uint256 id) public onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CancelMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    function _init() private {}

    function _mandateTopUp(uint256 id, uint256 amount) internal{
        require(_mandates[id].status < LifeCycle.ACCEPTED, "Can't add balance on or beyond LifeCycle.ACCEPTED");
        
        _mandates[id].ethers += amount;
        
        emit TopUpMandate(id, amount);
    } 

    event CreateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event PopulateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event SubmitMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event AcceptMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event StartMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event CloseMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event CancelMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event TopUpMandate(uint256 id, uint256 amount);
}