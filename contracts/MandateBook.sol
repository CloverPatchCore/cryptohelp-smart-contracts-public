pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AMandate.sol";
import "./IMandateBook.sol";
import "./ITrade.sol";

/* Mandate to be set by the Investor
    therefore Investor == Owner */

contract MandateBook is IMandateBook, AMandate, ReentrancyGuard {

    ITrade private _trd = ITrade(address(this));
    Mandate[] internal _mandates;
    Agreement[] internal _agreements;
    mapping(uint256 => mapping(address => uint256)) internal _agreementTradingTokenAmount;
    //data structure designated to holding the info about the mandate

    //TODO to review
    modifier onlyAgreementManager(uint256 agreementID) {
        require(msg.sender == _agreements[agreementID].manager, "Only appointed Fund Manager");
        _;
    }

    //this checks if the sender is actually an investor on the indicated dealID
    modifier onlyMandateInvestor(uint256 mandateID) {
        require(msg.sender == _mandates[mandateID].investor, "Only Mandate Investor");
        _;
    }

    modifier onlyMandateOrAgreementOwner(uint256 mandateID) {
        require(msg.sender == _mandates[mandateID].investor || msg.sender == _agreements[_mandates[mandateID].agreement].manager, "Only Investor or Manager");
        _;
    }

    modifier onlyExistAgreement(uint256 id) {
        require(_agreements.length > id, "Agreement not exist");
        _;
    }

    modifier onlyExistMandate(uint256 id) {
        require(_mandates.length > id, "Mandate not exist");
        _;
    }

    modifier onlyPositiveAmount(uint256 amount) {
        require(amount > 0, "Amount should be positive");
        _;
    }

    constructor() public {
        _init();
    }

    function getMandateStatus(uint id) external view override onlyExistMandate(id) returns (AMandate.MandateLifeCycle) {
        return _mandates[id].status;
    }

    // @dev getter for mandate
    function getMandate(uint id) external view override onlyExistMandate(id) returns (AMandate.Mandate memory mandate) {
        return _mandates[id];
    }

    // @dev getter for agreement
    function getAgreement(uint id) external view override onlyExistAgreement(id) returns (AMandate.Agreement memory agreement) {
        return _agreements[id];
    }

    function getAgreementTradingTokenAmount(uint256 agreementId, address token) external view returns (uint256) {
        return _agreementTradingTokenAmount[agreementId][token];
    }

    //TODO to review
/*     function createMandate(uint256 manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) public  override nonReentrant returns(uint256 id) {

        Mandate memory m = Mandate({
            status: MandateLifeCycle.POPULATED,
            investor: msg.sender,
            agreement: 0,
            __committedCapital: 0,
            __collatAmount: 0
        });
        _mandates.push(m);
        id = _mandates.length - 1;
        if(msg.value > 0) processEthers();

        emit CreateMandate(id, msg.sender);

    }
 */
 /*
    //TODO to review
    function populateMandate(uint256 id, address manager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external  override nonReentrant onlyMandateInvestor(id) {
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
    } */

    //TODO to review
/*     function submitMandate(uint256 id) external override onlyMandateInvestor(id) {
        // validations
        // actions
        _mandates[id].status = MandateLifeCycle.SUBMITTED;
        // event emissions
        emit SubmitMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);
    }

    //TODO to review
    function acceptMandate(uint256 id) external override onlyAgreementManager(id) {
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
/*    function startMandate(uint256 id) external override onlyAgreementManager(id) {
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
    } */

/*     //TODO to review
    function checkStartCollateralConditions(uint256 id) public view returns(bool check, uint256 outstanding){
        check = _mandates[id].collatEthers * 100 > _mandates[id].ethers * (100 - _mandates[id].stopLoss);
        outstanding = (_mandates[id].ethers * (100 - _mandates[id].stopLoss) - _mandates[id].collatEthers * 100) / 100;
    }
 */
/*     //TODO to review
    function closeMandate(uint256 id) external override onlyAgreementManager(id) {
        // validations
        // actions
        // event emissions
        emit CloseMandate(id, _mandates[id].ethers, _mandates[id].investor, _mandates[id].manager, _mandates[id].duration, _mandates[id].takeProfit, _mandates[id].stopLoss);

    }
 */

    function _init() private {}

    //TODO to review
/*     function depositMandate(uint256 id) external override nonReentrant onlyMandateInvestor(id) returns (uint256) {
        require(_mandates[id].status < MandateLifeCycle.ACCEPTED, "Can't add balance on or beyond MandateLifeCycle.ACCEPTED");

        _mandates[id].ethers += msg.value;

        emit DepositMandate(id, msg.value);

        return _mandates[id].ethers;
    } */
    function getAgreementStatus(uint id) external view override returns (AMandate.AgreementLifeCycle) {
        return _agreements[id].status;
    }

    function createAgreement(
        address baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint32 openPeriod,
        uint32 activePeriod
    ) external returns (uint256) {

        //validations
        require(targetReturnRate <= maxCollateralRateIfAvailable, "Max collateral is greater than target return rate");

        //actions
        _agreements.push(Agreement({
            status: AgreementLifeCycle.POPULATED,
            manager: msg.sender,
            baseCoin: baseCoin,
            targetReturnRate: targetReturnRate,
            maxCollateralRateIfAvailable: maxCollateralRateIfAvailable,
            __collatAmount: 0, 
            __freeCollatAmount: 0,
            __committedCapital: 0, /* initially there's no capital committed  */
            __committedMandates: 0,
            openPeriod: openPeriod,
            activePeriod: activePeriod,
            publishTimestamp: 0,

            stat_actualReturnRate: 0,
            stat_remainingCollateral: 0,
            stat_actualDuration: 0
        }));

        uint256 agreementID = _agreements.length - 1;
        Agreement storage aa = _agreements[agreementID];
        if(collatAmount > 0) _transferDepositCollateral(agreementID, collatAmount);
        //emit events
        emit CreateAgreement(
            agreementID,
            aa.manager,
            aa.baseCoin,
            aa.targetReturnRate,
            aa.maxCollateralRateIfAvailable,
            aa.__collatAmount,
            aa.openPeriod,
            aa.activePeriod
        );

        //return
        return agreementID;
    }

    // fill agreement with data
    function populateAgreement(
        uint256 id,
        address baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint32 activePeriod,
        uint32 openPeriod
    ) external onlyAgreementManager(id) {
        Agreement storage aa = _agreements[id];

        //validate
        require(aa.status <= AgreementLifeCycle.PUBLISHED, "Too late to change anything at AgreementLifeCycle.PUBLISHED");

        //execute
        // @TODO disallow if collateral already deposited
        if(aa.__collatAmount > 0 && baseCoin != aa.baseCoin) {
            revert("Can't change the basecoin when collateral deposited");
        }
        aa.baseCoin = baseCoin;
        aa.targetReturnRate = targetReturnRate;
        aa.maxCollateralRateIfAvailable = maxCollateralRateIfAvailable;
        //collatAmount processed separately
        aa.activePeriod = activePeriod;
        aa.openPeriod = openPeriod;
        if(collatAmount > aa.__collatAmount) {
            _transferDepositCollateral(id, collatAmount - aa.__collatAmount);
        }
        else if(collatAmount < aa.__collatAmount) {
            _transferWithdrawCollateral(id, aa.__collatAmount - collatAmount);
        }
        //emit event
        emit PopulateAgreement(
            id,
            aa.manager,
            aa.baseCoin,
            aa.targetReturnRate,
            aa.maxCollateralRateIfAvailable,
            aa.__collatAmount,
            aa.openPeriod,
            aa.activePeriod
        );

        //return
    }

    function depositCollateral(uint256 agreementID, uint256 amount) external /* payable */ override onlyAgreementManager(agreementID)  returns (uint256 finalAgreementCollateralBalance){
        require(_agreements.length > agreementID);
        Agreement storage aa = _agreements[agreementID];
        require(address(0) != aa.baseCoin);
        //if(msg.value > 0) processEthers();
        uint256 transferred = _transferDepositCollateral(agreementID, amount);

        emit DepositCollateral(agreementID, aa.manager, transferred);

        return transferred;
    }
    function _transferDepositCollateral(uint256 agreementID, uint256 amount) internal returns(uint256) {
        Agreement storage a = _agreements[agreementID];

        uint256 transferred = __safeTransferFrom(a.baseCoin, msg.sender, address(this), amount);

        a.__collatAmount += transferred;
        a.__freeCollatAmount += transferred;

        return transferred;
    }

    function _transferWithdrawCollateral(uint256 agreementID, uint256 amount) internal {
        Agreement storage a = _agreements[agreementID];
        IERC20 ierc20 = IERC20(a.baseCoin);
        ierc20.transfer(msg.sender, amount);
        a.__freeCollatAmount -= amount;
        a.__collatAmount -= amount;
    }

    function withdrawCollateral(uint256 agreementID, uint256 amount) external override onlyExistAgreement(agreementID) onlyAgreementManager(agreementID) onlyPositiveAmount(amount) {

        Agreement storage a = _agreements[agreementID];
        require(a.status < AgreementLifeCycle.PUBLISHED, "Can't withdraw collateral at this stage");
        require(a.__freeCollatAmount >= amount, "Not enough free collateral amount");
        _transferWithdrawCollateral(agreementID, amount);

        emit WithdrawCollateral(agreementID, a.manager, amount);
    }

    function processEthers() pure internal {
        revert();//TODO critical to implement proce
    }

    function bERC20(uint256 agreementID) private view returns (IERC20) {
        return IERC20(_agreements[agreementID].baseCoin);
    }

    /* this function does the safe transferFrom per ERC20 standard.
    It is safe in the way that it will check the balances before and after
    calling the transferFrom and will revert if the balances don't match.
    It will also check allowances and will transfer maximum amount allowed
    in case it is lower than the amount to transfer*/
    function __safeTransferFrom(address coin, address from, address to, uint256 amount) internal returns(uint256 transferredAmount) {
        IERC20 ierc20 = IERC20(coin);

        uint256 bBeforeFrom = ierc20.balanceOf(from);
        uint256 bBeforeTo = ierc20.balanceOf(to);

        uint256 allowance = ierc20.allowance(from,to);
        uint256 amountX = amount > allowance ? allowance : amount;

        ierc20.transferFrom(from, to, amountX);

        uint256 bAfterFrom = ierc20.balanceOf(from);
        uint256 bAfterTo = ierc20.balanceOf(to);
        require(bBeforeTo + amountX == bAfterTo, "TransferFrom to-address balance mismatch");
        require(bBeforeFrom - amountX == bAfterFrom, "TransferFrom to-address balance mismatch");

        return amountX;

    }

    function _transferDepositCapital(Agreement storage aa, Mandate storage m, uint256 amount, uint256 minRequiredCollatRate) internal returns(uint256 transferred) {

        /* the allowance on the chosen ERC20 coin has to be sufficient for the transferFrom, taking into account all the previous allowances on possible earlier deals */
        /* UPD: still not convinced it's worth keeping the global allowances updated require(IERC20(_agreements[id].baseCoin).allowance(msg.sender) >= amount + _investors[msg.sender].globalAllowances[_agreements[id].baseCoin]); */

        transferred = __safeTransferFrom(aa.baseCoin, msg.sender, address(this), amount);

        m.__committedCapital += transferred;        
        aa.__committedCapital += transferred;
        uint256 maxCollat = transferred * aa.maxCollateralRateIfAvailable / 100;
        uint256 minCollat = transferred * minRequiredCollatRate / 100;
        require(aa.__freeCollatAmount >= minCollat, "Insufficient collateral");
        uint256 collat = aa.__freeCollatAmount < maxCollat? aa.__freeCollatAmount : maxCollat;

        m.__collatAmount += collat;
        aa.__freeCollatAmount -= collat;
    }

    function _transferWithdrawCapital(Agreement storage aa, Mandate storage m, uint256 amount) internal returns(uint256 transferred) {

        /* the allowance on the chosen ERC20 coin has to be sufficient for the transferFrom, taking into account all the previous allowances on possible earlier deals */
        /* UPD: still not convinced it's worth keeping the global allowances updated require(IERC20(_agreements[id].baseCoin).allowance(msg.sender) >= amount + _investors[msg.sender].globalAllowances[_agreements[id].baseCoin]); */

        transferred = __safeTransferFrom(aa.baseCoin, address(this), m.investor, amount);

        uint256 collatToRelease = m.__collatAmount * transferred / m.__committedCapital;
        m.__committedCapital -= transferred;        
        aa.__committedCapital -= transferred;
        m.__collatAmount -= collatToRelease;
        aa.__freeCollatAmount += collatToRelease;

    }
    function depositCapital(uint256 mandateID, uint256 amount, uint16 minCollatRateRequirement) external onlyExistMandate(mandateID) override returns (uint256 transferred) {
        Mandate storage m = _mandates[mandateID];
        Agreement storage aa = _agreements[m.agreement];
        require(address(0) != aa.baseCoin);
        require(aa.status == AgreementLifeCycle.PUBLISHED);

        transferred = _transferDepositCapital(aa, m, amount, minCollatRateRequirement);

        emit DepositCapital(m.agreement, aa.manager, mandateID, m.investor, transferred);
    }


    function withdrawCapital(uint256 mandateID, uint256 amount) external onlyExistMandate(mandateID) onlyMandateInvestor(mandateID) override returns (uint256 transferred) {
        // @TODO: implement
        Mandate storage m = _mandates[mandateID];
        Agreement storage aa = _agreements[m.agreement];
        // withdraw capital
        require(aa.status < AgreementLifeCycle.ACTIVE, "Can't withdraw from agreement at this stage");
        require(amount <= m.__committedCapital, "Can't withdraw more than you have");

        transferred = _transferWithdrawCapital(aa, m, amount);
        emit WithdrawCapital(m.agreement, aa.manager, mandateID, m.investor, transferred);

        if(0 == m.__committedCapital) {
            _cancelEmptyMandate(aa, m);
            emit CancelMandate(m.agreement, aa.manager, mandateID, m.investor);
        }
    }

    // ses the mandate status, decreases the counter in agreement, emits event
    function _cancelEmptyMandate(Agreement storage aa, Mandate storage m) internal {
        aa.__committedMandates--;
        m.status = MandateLifeCycle.CANCELED;
    }

    function cancelMandate(uint256 mandateID) external override onlyExistMandate(mandateID) onlyMandateOrAgreementOwner(mandateID) {
        // @TODO validations

        Mandate storage m = _mandates[mandateID];
        Agreement storage aa = _agreements[m.agreement];
        // actions
        uint256 transferred = _transferWithdrawCapital(aa, m, m.__committedCapital);
        emit WithdrawCapital(m.agreement, aa.manager, mandateID, m.investor, transferred);
        _cancelEmptyMandate(aa, m);
        // event emissions
        emit CancelMandate(m.agreement, aa.manager, mandateID, m.investor);
    }

    function publishAgreement(uint256 id)  external onlyAgreementManager(id) {
        //validate

        //execute
        Agreement storage aa = _agreements[id];
        require(aa.status == AgreementLifeCycle.POPULATED);

        aa.status = AgreementLifeCycle.PUBLISHED;
        aa.publishTimestamp = block.timestamp;

        //emit event
        emit PublishAgreement(
            id,
            aa.manager,
            aa.baseCoin,
            aa.targetReturnRate,
            aa.maxCollateralRateIfAvailable,
            aa.__collatAmount,
            aa.openPeriod,
            aa.activePeriod,
            aa.publishTimestamp
        );
    }

    // @TODO
    function cancelAgreement(uint256 agreementID) external view onlyExistAgreement(agreementID) onlyAgreementManager(agreementID) {
        revert("to be implemented later");
    }

    function unpublishAgreement(uint256 agreementID) external onlyExistAgreement(agreementID) onlyAgreementManager(agreementID) {
        // @TODO implement
        Agreement storage aa = _agreements[agreementID];
        require(0 == aa.__committedMandates, "Agreement has committed mandates, use cancelAgreement");
        aa.status = AgreementLifeCycle.POPULATED;
        emit UnpublishAgreement(agreementID, aa.manager);
    }

    function commitToAgreement(uint256 agreementID, uint256 amount, uint16 minCollatRateRequirement) external onlyExistAgreement(agreementID) returns (uint256 transferred) {

        //validate
        Agreement storage aa = _agreements[agreementID];
        require(aa.status == AgreementLifeCycle.PUBLISHED);

        //create a mandate
        _mandates.push(Mandate({
            status: MandateLifeCycle.COMMITTED,
            investor: msg.sender,
            agreement: agreementID,
            __committedCapital: 0,
            __collatAmount: 0
        }));
        uint256 mandateID = _mandates.length - 1;
        Mandate storage m = _mandates[mandateID];

        transferred = _transferDepositCapital(aa, m, amount, minCollatRateRequirement);
        require(transferred > 0, "need to commit nonzero capital");
        aa.__committedMandates++;

        //emit event
        emit CommitToAgreement(agreementID, aa.manager, mandateID, msg.sender, amount, m.__collatAmount);

        //return
    }

    function getAgreementPublishTimestamp(uint256 id) public view returns(uint256) {
        return _agreements[id].publishTimestamp;
    }

    function getAgreementCollateral(uint256 id) public view returns(uint256) {
        return _agreements[id].__collatAmount;
    }
    function getAgreementCommittedCapital(uint256 id) public view returns(uint256) {
        return _agreements[id].__committedCapital;
    }

    function activateAgreement(uint256 id) external onlyAgreementManager(id) {
        Agreement storage aa = _agreements[id];
        require(AgreementLifeCycle.PUBLISHED == aa.status, 'Can only activate agreements from AgreementLifeCycle.PUBLISHED status');

        // @TODO: do not activate till open period is over

        aa.status = AgreementLifeCycle.ACTIVE;
        _agreementTradingTokenAmount[id][aa.baseCoin] = aa.__committedCapital;

        emit ActivateAgreement(id, aa.manager);
    }

    function setExpiredAgreement(uint256 agreementID) public {
        Agreement storage aa = _agreements[agreementID];

        require(aa.status <= AgreementLifeCycle.ACTIVE, "Agreement is already expired");

        require(
            now > (aa.publishTimestamp + aa.openPeriod + aa.activePeriod),
            "Agreement is not over yet"
        );

        require(_trd.agreementClosed(agreementID) == false, "Agreement trades are not closed");

        aa.status = AgreementLifeCycle.EXPIRED;

        emit SetExpiredAgreement(agreementID, aa.manager);
    }

    function settleMandate(uint256 mandateID) public onlyMandateOrAgreementOwner(mandateID) nonReentrant {
        Mandate storage m = _mandates[mandateID];
        Agreement storage aa = _agreements[m.agreement];
        require(AgreementLifeCycle.EXPIRED <= aa.status, "Agreement should be in EXPIRED status");
        require(MandateLifeCycle.SETTLED > m.status, "Mandate was already settled");

        //find the share of the mandate in the pool and multiply by the finalBalance
        uint256 finalAgreementTradeBalance = _trd.balances(m.agreement);
        // the final trade balance per this mandate is calculated as a share in the entire trade balance
        uint256 mandateFinalTradeBalance = m.__committedCapital * finalAgreementTradeBalance / aa.__committedCapital;
        //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
        uint256 profitAbsTarget = m.__committedCapital * (100 + aa.targetReturnRate) / 100;
        //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
        uint256 desiredCompensation = mandateFinalTradeBalance < profitAbsTarget ? profitAbsTarget - mandateFinalTradeBalance : 0;
        //now if the above is higher than the actual collateral, it will only count actual collateral
        uint256 recoverableCompensation = desiredCompensation > m.__collatAmount ? m.__collatAmount : desiredCompensation;
        //let's calculate the final that we have to pay as a sum of trade balance and the compensation
        uint mandateFinalCorrectedBalance = mandateFinalTradeBalance + recoverableCompensation;
        //and then the remaining collateral if any to be sent back to Manager
        uint256 mandateCollatLeft = m.__collatAmount - recoverableCompensation;

        //withdraw percentage of the share on the mandate
        //settle the collateral
        IERC20(aa.baseCoin).transfer(m.investor, mandateFinalCorrectedBalance);

        m.status = MandateLifeCycle.SETTLED;

        emit __service__settleMandate__values(
            mandateFinalTradeBalance,
            //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
            profitAbsTarget,
            //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
            desiredCompensation,
            //now if the above is higher than the actual collateral, it will only count actual collateral
            recoverableCompensation,
            //let's calculate the final that we have to pay as a sum of trade balance and the compensation
            mandateFinalCorrectedBalance,
            //and then the remaining collateral if any to be sent back to Manager
            mandateCollatLeft
        );
    }

    function withdrawManagerCollateral(uint256 agreementID) external onlyExistAgreement(agreementID) onlyAgreementManager(agreementID) returns (bool) {
        Agreement storage agreement = _agreements[agreementID];
        require(agreement.status == AgreementLifeCycle.EXPIRED, "Agreement should be in EXPIRED status");
        uint256 finalAgreementTradeBalance = _trd.balances(agreementID);
        uint256 targetReturnAmount = agreement.__committedCapital * (100 + agreement.targetReturnRate) / 100;
        uint256 amount = targetReturnAmount < finalAgreementTradeBalance ?
            finalAgreementTradeBalance - targetReturnAmount :
            0;
        agreement.status = AgreementLifeCycle.SETTLED;
        if (amount != 0) {
            address receiver = agreement.manager;
            IERC20(agreement.baseCoin).transfer(receiver, amount);
            emit ManagerCollateralWithdrawn(agreementID, receiver, amount);
        }
        return true;
    }
    
    //#############################
    //#############################
    //#############################
    //#############################
    //#############################
    event ManagerCollateralWithdrawn(
        uint256 indexed agreementID,
        address indexed manager,
        uint256 amount
    );

    event WaitForMoreCollateral(uint256 indexed agreementID, uint256 outstanding);

    event CreateAgreement(
        uint256 indexed agreementID,
        address indexed manager,
        address indexed baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint32 openPeriod,
        uint32 activePeriod);
    event PopulateAgreement(
        uint256 indexed agreementID,
        address indexed manager,
        address indexed baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint32 openPeriod,
        uint32 activePeriod);
    event DepositCollateral(uint256 indexed agreementID, address indexed manager, uint256 amount);
    event WithdrawCollateral(uint256 indexed agreementID, address indexed manager, uint256 amount);
    event PublishAgreement(
        uint256 indexed agreementID,
        address indexed manager,
        address indexed baseCoin,
        uint8 targetReturnRate,
        uint8 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint32 openPeriod,
        uint32 activePeriod,
        uint256 publishTimestamp);
    event UnpublishAgreement(uint256 indexed agreementID, address indexed manager);
    event CommitToAgreement(
        uint256 indexed agreementID, 
        address manager, 
        uint256 indexed mandateID, 
        address indexed investor, 
        uint256 amount, 
        uint256 collateral);
    event ActivateAgreement(uint256 indexed agreementID, address indexed manager);
    event SetExpiredAgreement(uint256 indexed agreementID, address indexed manager);

    //TODO to review
    event CreateMandate(uint256 indexed id, address indexed investor);
    //TODO to review
    // event PopulateMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    /* event SubmitMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event AcceptMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event StartMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);
    //TODO to review
    event CloseMandate(uint256 id, uint256 ethers, address indexed investor, address indexed manager, uint256 duration, uint16 takeProfit, uint16 stopLoss);*/

    event DepositCapital(uint256 indexed agreementID, address manager, uint256 indexed mandateID, address indexed investor, uint256 amount);
    event WithdrawCapital(uint256 indexed agreementID, address manager, uint256 indexed mandateID, address indexed investor, uint256 amount);

    event CancelMandate(uint256 indexed agreementID, address manager, uint256 indexed mandateID, address indexed investor);
    event __service__settleMandate__values(
        uint256 mandateFinalTradeBalance,
        //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
        uint256 profitAbsTarget,
        //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
        uint256 desiredCompensation,
        //now if the above is higher than the actual collateral, it will only count actual collateral
        uint256 recoverableCompensation,
        //let's calculate the final that we have to pay as a sum of trade balance and the compensation
        uint mandateFinalCorrectedBalance,
        //and then the remaining collateral if any to be sent back to Manager
        uint256 mandateCollatLeft
    );

}

/*     function () {
        //validate

        //execute

        //emit event

        //return
    }
 */
