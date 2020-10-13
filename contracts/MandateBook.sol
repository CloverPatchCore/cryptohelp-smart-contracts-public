pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AMandate.sol";
import "./IMandateBook.sol";

/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract Mandate is IMandateBook, AMandate, Ownable, ReentrancyGuard {

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
    function getStatus(uint id) external override returns (AMandate.LifeCycle) {
        return _mandates[id].status;
    }

    function getMandate(uint id) external override returns (AMandate.Mandate memory mandate) {
        return _mandates[id];
    }

    function createMandate(address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public payable override nonReentrant returns(uint256 id) {

        Mandate memory m = Mandate({
            status: LifeCycle.POPULATED,
            ethers: 0,
            collatEthers: 0,
            investor: msg.sender,
            manager: manager,
            duration: duration,
            takeProfit: takeProfit,
            stopLoss: stopLoss            
        });
        _mandates.push(m);
        id = _mandates.length - 1;
        if(msg.value > 0) this.depositMandate(id);

        emit CreateMandate(id, _mandates[id].ethers, msg.sender, manager, duration, takeProfit, stopLoss);
        
    }
    function populateMandate(uint256 id, address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable override nonReentrant onlyInvestor(id) {
        // validations
        require(_mandates[id].status < LifeCycle.ACCEPTED, "LifeCycle violation. Can't populate deal beyond LifeCycle.ACCEPTED");
        
        // actions
        _mandates[id].status = LifeCycle.POPULATED;
        _mandates[id].investor = msg.sender;
        _mandates[id].manager = manager;
        _mandates[id].duration = duration;
        _mandates[id].takeProfit = takeProfit;
        _mandates[id].stopLoss = stopLoss;

        if(msg.value > 0) this.depositMandate(id);
        
        // event emissions
        emit PopulateMandate(id, _mandates[id].ethers, msg.sender, manager, duration, takeProfit, stopLoss);
    }

    function submitMandate(uint256 id) external override onlyInvestor(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.SUBMITTED;
        // event emissions
        emit SubmitMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    function acceptMandate(uint256 id) external payable override onlyFundManager(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.ACCEPTED;
        // event emissions
        emit AcceptMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    /* Fund manager can collate the mandate in portions through acceptMandate, depositCollateral, 
    however the collaoteral balance after this function should satisfy the stopLoss ratio declared by investor */
    function startMandate(uint256 id) external payable override onlyFundManager(id) {
        // validations
        // actions
        _mandates[id].status = LifeCycle.STARTED;
        // event emissions
        emit StartMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }
    function closeMandate(uint256 id) external override onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CloseMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);

    }
    function cancelMandate(uint256 id) external override onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CancelMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    function _init() private {}

    function depositMandate(uint256 id) external payable override nonReentrant onlyInvestor(id) returns (uint256) {
        require(_mandates[id].status < LifeCycle.ACCEPTED, "Can't add balance on or beyond LifeCycle.ACCEPTED");
        
        _mandates[id].ethers += msg.value;
        
        emit DepositMandate(id, msg.value);

        return _mandates[id].ethers;
    } 

    function depositCollateral(uint256 id) external payable override nonReentrant returns (uint256) {
        require(_mandates[id].status < LifeCycle.SETTLED, "Can't add collateral to already LifeCycle.SETTLED and beyond");

        _mandates[id].collatEthers += msg.value;

        emit DepositCollateral(id, msg.value);

        return _mandates[id].collatEthers;

    }
    event CreateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event PopulateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event SubmitMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event AcceptMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event StartMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event CloseMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event CancelMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    event DepositMandate(uint256 id, uint256 amount);
    event DepositCollateral(uint256 id, uint256 amount);
}