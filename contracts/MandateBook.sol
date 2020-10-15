pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AMandate.sol";
import "./IMandateBook.sol";

/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract MandateBook is IMandateBook, AMandate, ReentrancyGuard {

    Mandate[] private _mandates;
    Agreement[] private _agreements;
    //data structure designated to holding the info about the mandate

    //TODO to review
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

    modifier onlyAgreementManager(uint256 id) {
        require(address(0) != _agreements[id].manager, "Agreement Manager not set yet");
        require(msg.sender == _agreements[id].manager, "Only appointed Fund Manager");
        _;
    }


    constructor() public {
        _init();        
    }
    function getMandateStatus(uint id) external override returns (AMandate.MandateLifeCycle) {
        return _mandates[id].status;
    }

    function getMandate(uint id) external override returns (AMandate.Mandate memory mandate) {
        return _mandates[id];
    }

    //TODO to review
    function createMandate(address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public payable override nonReentrant returns(uint256 id) {

        Mandate memory m = Mandate({
            status: MandateLifeCycle.POPULATED,
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

    //TODO to review
    function populateMandate(uint256 id, address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable override nonReentrant onlyInvestor(id) {
        // validations
        require(_mandates[id].status < MandateLifeCycle.ACCEPTED, "MandateLifeCycle violation. Can't populate deal beyond MandateLifeCycle.ACCEPTED");
        
        // actions
        _mandates[id].status = MandateLifeCycle.POPULATED;
        _mandates[id].investor = msg.sender;
        _mandates[id].manager = manager;
        _mandates[id].duration = duration;
        _mandates[id].takeProfit = takeProfit;
        _mandates[id].stopLoss = stopLoss;

        if(msg.value > 0) this.depositMandate(id);
        
        // event emissions
        emit PopulateMandate(id, _mandates[id].ethers, msg.sender, manager, duration, takeProfit, stopLoss);
    }

    //TODO to review
    function submitMandate(uint256 id) external override onlyInvestor(id) {
        // validations
        // actions
        _mandates[id].status = MandateLifeCycle.SUBMITTED;
        // event emissions
        emit SubmitMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    //TODO to review
    function acceptMandate(uint256 id) external payable override onlyFundManager(id) {
        // validations

        // actions
        _mandates[id].status = MandateLifeCycle.ACCEPTED;
        if (msg.value > 0) this.depositCollateral(id);
        (bool isSufficientCollateral, uint256 outstanding) = checkStartCollateralConditions(id);
        if(!isSufficientCollateral) emit WaitForMoreCollateral(id, outstanding);
        
        // event emissions
        //ok to accept even with insufficient collateral TODO: discuss
        emit AcceptMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    /* Fund manager can collate the mandate in portions through acceptMandate, depositCollateral, 
    however the collaoteral balance after this function should satisfy the stopLoss ratio declared by investor */
    //TODO to review
    function startMandate(uint256 id) external payable override onlyFundManager(id) {
        // validations
        // assumed it's ok to start straight from the submitted or from the accepted state
        // MandateLifeCycle.ACCEPTED gives a fund manager a leeway to hold off with the actual start of portfolio management
        require(MandateLifeCycle.SUBMITTED == _mandates[id].status || MandateLifeCycle.ACCEPTED == _mandates[id].status, "Can only start MandateLifeCycle.SUBMITTED or MandateLifeCycle.ACCEPTED");
        
        // actions
        if (msg.value > 0) this.depositCollateral(id);

        //now, if collateral requirement is not met we will wait for more collateral
        (bool isSufficientCollateral, uint256 outstanding) = checkStartCollateralConditions(id);
        if(isSufficientCollateral) {
            _mandates[id].status = MandateLifeCycle.STARTED;
            emit StartMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
        } else {
            emit WaitForMoreCollateral(id, outstanding);
        }
        // event emissions
    }

    //TODO to review
    function checkStartCollateralConditions(uint256 id) public view returns(bool check, uint256 outstanding){
        check = _mandates[id].collatEthers * 100 > _mandates[id].ethers * (100 - _mandates[id].stopLoss);
        outstanding = (_mandates[id].ethers * (100 - _mandates[id].stopLoss) - _mandates[id].collatEthers * 100) / 100;
    }

    //TODO to review
    function closeMandate(uint256 id) external override onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CloseMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);

    }
    
    //TODO to review
    function cancelMandate(uint256 id) external override onlyFundManager(id) {
        // validations
        // actions
        // event emissions
        emit CancelMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    function _init() private {}

    //TODO to review
    function depositMandate(uint256 id) external payable override nonReentrant onlyInvestor(id) returns (uint256) {
        require(_mandates[id].status < MandateLifeCycle.ACCEPTED, "Can't add balance on or beyond MandateLifeCycle.ACCEPTED");
        
        _mandates[id].ethers += msg.value;
        
        emit DepositMandate(id, msg.value);

        return _mandates[id].ethers;
    } 

    //TODO to review
    function depositCollateral(uint256 id) external payable override nonReentrant returns (uint256) {
        require(_mandates[id].status < AgreementLifeCycle.SETTLED, "Can't add collateral to already AgreementLifeCycle.SETTLED and beyond");

        _mandates[id].collatEthers += msg.value;

        emit DepositCollateral(id, msg.value);

        return _mandates[id].collatEthers;

    }

    function createAgreement(
        address baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint32 duration,
        uint32 openPeriod
        
    ) external returns (uint256) {

        //validations


        //actions
        _agreements.push(Agreement({
            status: AgreementLifeCycle.POPULATED,
            manager: msg.sender,
            baseCoin: baseCoin,
            targetReturnRate: targetReturnRate,
            maxCollateralRateIfAvailable: maxCollateralRateIfAvailable,
            collatAmount: 0,
            committedCapital: 0, /* initially there's no capital committed  */
            duration: duration,
            openPeriod: openPeriod,
            publishTimestamp: 0,
            
            stat_actualReturnRate: 0,
            stat_remainingCollateral: collatAmount
        }));

        //TODO NOTE process collatAmount separately through transferFrom
        //emit events
        emit CreateAgreement();

        //return
        return _agreements.length - 1;
    }
    
    // fill agreement with data
    function populateAgreement(
        uint256 id,
        address baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint32 duration,
        uint32 openPeriod
    ) external onlyAgreementManager(id) {
        Agreement memory aa = _agreements[id];

        //validate
        require(aa.status <= AgreementLifeCycle.PUBLISHED, "Too late to change anything at AgreementLifeCycle.PUBLISHED");

        //execute
        aa.baseCoin = baseCoin;
        aa.targetReturnRate = targetReturnRate;
        aa.maxCollateralRateIfAvailable = maxCollateralRateIfAvailable;
        //collatAmount processed separately
        aa.duration = duration;
        aa.openPeriod = openPeriod;

        //TODO NOTE process collatAmount separately through transferFrom
        //TODO NOTE process collectedCapital separately if it is needed at all at this stage of AgreementlifeCycle

        //emit event
        emit PopulateAgreement();

        //return
    }

    function depositCollateral(uint256 id, uint256 amount) external onlyAgreementManager(id) {

    }

    function publishAgreement(uint256 id)  external onlyAgreementManager(id) {
        //validate

        //execute
        Agreement memory aa = _agreements[id];
        aa.status = AgreementLifeCycle.PUBLISHED;
        publishTimestamp = block.timestamp;

        //emit event
        emit PublishAgreement();
    }

    function commitToAgreement(uint256 id, uint256 amount) external {
        //validate

        //execute
        //create a mandate
        _mandates.push({
            status: MandateLifeCycle.COMMITTED,
            investor: msg.sender,
            agreement: id
        });

        //TODO manage committed capital through transferFrom

        {
            require(address(0) != _agreements[id].baseCoin);
            require(IERC20(_agreements[id].baseCoin).allowance(msg.sender))
            IERC20(_agreements[id].baseCoin).transferFrom(msg.sender, this.address, amount);
        }
        //emit event

        //return
    }


    /* this should commit the existing mandate to the agreement
    it should overwrite some parameters in the mandate
     */
    function commitToAgreement(uint256 agreementID, uint256 mandateID) external {
        //validate

        //execute

        //emit event

        //return
    }
     
    //TODO to review
    event CreateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event PopulateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event SubmitMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event AcceptMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event StartMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event CloseMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event CancelMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event DepositMandate(uint256 id, uint256 amount);
    //TODO to review
    event DepositCollateral(uint256 id, uint256 amount);
    //TODO to review
    event WaitForMoreCollateral(uint256 id, uint256 outstanding);


    event CreateAgreement(/* TODO parameters */);
    event PopulateAgreement(/* TODO parameters */);
    event PublishAgreement(/* TODO parameters */);
    

}

/*     function () {
        //validate

        //execute

        //emit event

        //return
    }
 */