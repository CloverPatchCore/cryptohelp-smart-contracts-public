pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./AMandate.sol";
import "./IMandateBook.sol";
import "./ITrade.sol";


contract MandateBook is IMandateBook, AMandate, ReentrancyGuard {
    using SafeMath for uint256;

    ITrade private _trd = ITrade(address(this));
    Mandate[] internal _mandates;
    Agreement[] internal _agreements;
    mapping(uint256 => mapping(address => uint256)) public countedBalance;

    modifier onlyExistAgreement(uint256 agreementId) {
        require(_agreements.length > agreementId, "Agreement not exist");
        _;
    }

    modifier onlyExistMandate(uint256 mandateId) {
        require(_mandates.length > mandateId, "Mandate not exist");
        _;
    }

    modifier onlyPositiveAmount(uint256 amount) {
        require(amount > 0, "Amount should be positive");
        _;
    }

    constructor() public {
        _init();
    }

    function getMandateStatus(
        uint256 mandateId
    ) external view override onlyExistMandate(mandateId) returns (AMandate.MandateLifeCycle) {
        return _mandates[mandateId].status;
    }

    function getMandate(
        uint256 mandateId
    ) external view override onlyExistMandate(mandateId) returns (AMandate.Mandate memory mandate) {
        return _mandates[mandateId];
    }

    function getAgreement(
        uint256 agreementId
    ) external view override onlyExistAgreement(agreementId) returns (AMandate.Agreement memory agreement) {
        return _agreements[agreementId];
    }

    function _init() private {}

    function getAgreementStatus(uint256 agreementId) external view override returns (AMandate.AgreementLifeCycle) {
        return _agreements[agreementId].status;
    }

    function createAgreement(
        address baseCoin,
        uint256 targetReturnRate,
        uint256 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint256 openPeriod,
        uint256 activePeriod
    ) external returns (uint256) {
        require(targetReturnRate <= maxCollateralRateIfAvailable, "Max collateral is greater than target return rate");
        _agreements.push(Agreement({
            status: AgreementLifeCycle.POPULATED,
            manager: msg.sender,
            baseCoin: baseCoin,
            targetReturnRate: targetReturnRate,
            maxCollateralRateIfAvailable: maxCollateralRateIfAvailable,
            __collatAmount: 0, 
            __freeCollatAmount: 0,
            __committedCapital: 0,
            __committedMandates: 0,
            openPeriod: openPeriod,
            activePeriod: activePeriod,
            publishTimestamp: 0,

            stat_actualReturnRate: 0,
            stat_remainingCollateral: 0,
            stat_actualDuration: 0,

            isDeleted: false
        }));
        uint256 agreementId = _agreements.length.sub(1);
        Agreement storage agreement = _agreements[agreementId];
        if(collatAmount > 0) _transferDepositCollateral(agreementId, collatAmount);
        emit CreateAgreement(
            agreementId,
            agreement.manager,
            agreement.baseCoin,
            agreement.targetReturnRate,
            agreement.maxCollateralRateIfAvailable,
            agreement.__collatAmount,
            agreement.openPeriod,
            agreement.activePeriod
        );
        return agreementId;
    }

    function populateAgreement(
        uint256 agreementId,
        address baseCoin,
        uint256 targetReturnRate,
        uint256 maxCollateralRateIfAvailable,
        uint256 collatAmount,
        uint256 activePeriod,
        uint256 openPeriod
    ) external onlyExistAgreement(agreementId) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        require(
            agreement.status <= AgreementLifeCycle.PUBLISHED,
            "Too late to change anything at AgreementLifeCycle.PUBLISHED"
        );
        _assertAgreementNotDeleted(agreement);
        if(agreement.__collatAmount > 0 && baseCoin != agreement.baseCoin) {
            revert("Can't change the basecoin when collateral deposited");
        }
        agreement.baseCoin = baseCoin;
        agreement.targetReturnRate = targetReturnRate;
        agreement.maxCollateralRateIfAvailable = maxCollateralRateIfAvailable;
        agreement.activePeriod = activePeriod;
        agreement.openPeriod = openPeriod;
        if(collatAmount > agreement.__collatAmount) {
            _transferDepositCollateral(agreementId, collatAmount.sub(agreement.__collatAmount));
        }
        else if(collatAmount < agreement.__collatAmount) {
            _transferWithdrawCollateral(agreementId, agreement.__collatAmount.sub(collatAmount));
        }
        emit PopulateAgreement(
            agreementId,
            agreement.manager,
            agreement.baseCoin,
            agreement.targetReturnRate,
            agreement.maxCollateralRateIfAvailable,
            agreement.__collatAmount,
            agreement.openPeriod,
            agreement.activePeriod
        );
    }

    function depositCollateral(
        uint256 agreementId,
        uint256 amount
    ) external override onlyExistAgreement(agreementId) returns (uint256 finalAgreementCollateralBalance){
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        _assertAgreementNotDeleted(agreement);
        require(address(0) != agreement.baseCoin);
        uint256 transferred = _transferDepositCollateral(agreementId, amount);
        emit DepositCollateral(agreementId, agreement.manager, transferred);
        return transferred;
    }

    function _transferDepositCollateral(
        uint256 agreementId,
        uint256 amount
    ) internal returns(uint256) {
        Agreement storage agreement = _agreements[agreementId];
        uint256 transferred = __safeTransferFrom(agreement.baseCoin, msg.sender, address(this), amount);
        agreement.__collatAmount = agreement.__collatAmount.add(transferred);
        agreement.__freeCollatAmount = agreement.__freeCollatAmount.add(transferred);
        return transferred;
    }

    function _transferWithdrawCollateral(
        uint256 agreementId,
        uint256 amount
    ) internal {
        Agreement storage agreement = _agreements[agreementId];
        IERC20 ierc20 = IERC20(agreement.baseCoin);
        ierc20.transfer(msg.sender, amount);
        agreement.__freeCollatAmount = agreement.__freeCollatAmount.sub(amount);
        agreement.__collatAmount = agreement.__collatAmount.sub(amount);
    }

    function withdrawCollateral(
        uint256 agreementId,
        uint256 amount
    ) external override onlyExistAgreement(agreementId) onlyPositiveAmount(amount) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        require(agreement.status < AgreementLifeCycle.PUBLISHED, "Can't withdraw collateral at this stage");
        require(agreement.__freeCollatAmount >= amount, "Not enough free collateral amount");
        _transferWithdrawCollateral(agreementId, amount);
        emit WithdrawCollateral(agreementId, agreement.manager, amount);
    }

    function processEthers() pure internal {
        revert();
    }

    function bERC20(uint256 agreementId) private view returns (IERC20) {
        return IERC20(_agreements[agreementId].baseCoin);
    }

    /* this function does the safe transferFrom per ERC20 standard.
    It is safe in the way that it will check the balances before and after
    calling the transferFrom and will revert if the balances don't match.
    It will also check allowances and will transfer maximum amount allowed
    in case it is lower than the amount to transfer*/
    function __safeTransferFrom(
        address coin,
        address from,
        address to,
        uint256 amount
    ) internal returns(uint256 transferredAmount) {
        IERC20 ierc20 = IERC20(coin);
        uint256 bBeforeFrom = ierc20.balanceOf(from);
        uint256 bBeforeTo = ierc20.balanceOf(to);
        uint256 allowance = ierc20.allowance(from,to);
        uint256 amountX = amount > allowance ? allowance : amount;
        ierc20.transferFrom(from, to, amountX);
        uint256 bAfterFrom = ierc20.balanceOf(from);
        uint256 bAfterTo = ierc20.balanceOf(to);
        require(bBeforeTo.add(amountX) == bAfterTo, "TransferFrom to-address balance mismatch");
        require(bBeforeFrom.sub(amountX)== bAfterFrom, "TransferFrom to-address balance mismatch");
        return amountX;
    }

    function _transferDepositCapital(
        Agreement storage agreement,
        Mandate storage mandate,
        uint256 amount,
        uint256 minRequiredCollatRate
    ) internal returns(uint256 transferred) {
        transferred = __safeTransferFrom(agreement.baseCoin, msg.sender, address(this), amount);
        mandate.__committedCapital = mandate.__committedCapital.add(transferred);        
        agreement.__committedCapital = agreement.__committedCapital.add(transferred);
        uint256 maxCollat = transferred.mul(agreement.maxCollateralRateIfAvailable).div(100);
        uint256 minCollat = transferred.mul(minRequiredCollatRate).div(100);
        require(agreement.__freeCollatAmount >= minCollat, "Insufficient collateral");
        uint256 collat = agreement.__freeCollatAmount < maxCollat? agreement.__freeCollatAmount : maxCollat;
        mandate.__collatAmount = mandate.__collatAmount.add(collat);
        agreement.__freeCollatAmount = agreement.__freeCollatAmount.sub(collat);
    }

    function _transferWithdrawCapital(
        Agreement storage agreement,
        Mandate storage mandate,
        uint256 amount
    ) internal returns(uint256 transferred) {
        transferred = __safeTransferFrom(agreement.baseCoin, address(this), mandate.investor, amount);
        uint256 collatToRelease = mandate.__collatAmount.mul(transferred).div(mandate.__committedCapital);
        mandate.__committedCapital = mandate.__committedCapital.sub(transferred);        
        agreement.__committedCapital = agreement.__committedCapital.sub(transferred);
        mandate.__collatAmount = mandate.__collatAmount.sub(collatToRelease);
        agreement.__freeCollatAmount = agreement.__freeCollatAmount.add(collatToRelease);

    }
    function depositCapital(
        uint256 mandateId,
        uint256 amount,
        uint256 minCollatRateRequirement
    ) external onlyExistMandate(mandateId) override returns (uint256 transferred) {
        Mandate storage mandate = _mandates[mandateId];
        Agreement storage agreement = _agreements[mandate.agreement];
        require(address(0) != agreement.baseCoin);
        require(agreement.status == AgreementLifeCycle.PUBLISHED);
        transferred = _transferDepositCapital(agreement, mandate, amount, minCollatRateRequirement);
        emit DepositCapital(mandate.agreement, agreement.manager, mandateId, mandate.investor, transferred);
    }


    function withdrawCapital(
        uint256 mandateId,
        uint256 amount
    ) external onlyExistMandate(mandateId) override returns (uint256 transferred) {
        Mandate storage mandate = _mandates[mandateId];
        require(msg.sender == mandate.investor, "Only Mandate Investor");
        Agreement storage agreement = _agreements[mandate.agreement];
        require(agreement.status < AgreementLifeCycle.ACTIVE, "Can't withdraw from agreement at this stage");
        require(amount <= mandate.__committedCapital, "Can't withdraw more than you have");
        transferred = _transferWithdrawCapital(agreement, mandate, amount);
        emit WithdrawCapital(mandate.agreement, agreement.manager, mandateId, mandate.investor, transferred);
        if(0 == mandate.__committedCapital) {
            _cancelEmptyMandate(agreement, mandate);
            emit CancelMandate(mandate.agreement, agreement.manager, mandateId, mandate.investor);
        }
    }

    function _cancelEmptyMandate(Agreement storage agreement, Mandate storage mandate) internal {
        agreement.__committedMandates = agreement.__committedMandates.sub(1);
        mandate.status = MandateLifeCycle.CANCELED;
    }

    function cancelMandate(uint256 mandateId) external override onlyExistMandate(mandateId) {
        Mandate storage mandate = _mandates[mandateId];
        Agreement storage agreement = _agreements[mandate.agreement];
        _assertIsMandateOrAgreementOwner(agreement, mandate);
        uint256 transferred = _transferWithdrawCapital(agreement, mandate, mandate.__committedCapital);
        emit WithdrawCapital(mandate.agreement, agreement.manager, mandateId, mandate.investor, transferred);
        _cancelEmptyMandate(agreement, mandate);
        emit CancelMandate(mandate.agreement, agreement.manager, mandateId, mandate.investor);
    }

    function publishAgreement(uint256 agreementId) external {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        _assertAgreementNotDeleted(agreement);
        require(agreement.status == AgreementLifeCycle.POPULATED);
        agreement.status = AgreementLifeCycle.PUBLISHED;
        agreement.publishTimestamp = block.timestamp;
        emit PublishAgreement(
            agreementId,
            agreement.manager,
            agreement.baseCoin,
            agreement.targetReturnRate,
            agreement.maxCollateralRateIfAvailable,
            agreement.__collatAmount,
            agreement.openPeriod,
            agreement.activePeriod,
            agreement.publishTimestamp
        );
    }

    function cancelAgreement(uint256 agreementId) external view onlyExistAgreement(agreementId) {
        revert("to be implemented later");
    }

    function unpublishAgreement(uint256 agreementId) external onlyExistAgreement(agreementId) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        require(0 == agreement.__committedMandates, "Agreement has committed mandates, use cancelAgreement");
        agreement.status = AgreementLifeCycle.POPULATED;
        emit UnpublishAgreement(agreementId, agreement.manager);
    }

    function commitToAgreement(
        uint256 agreementId,
        uint256 amount,
        uint256 minCollatRateRequirement
    ) external onlyExistAgreement(agreementId) returns (uint256 transferred) {
        Agreement storage agreement = _agreements[agreementId];
        require(agreement.status == AgreementLifeCycle.PUBLISHED);
        address investor = msg.sender;
        _mandates.push(Mandate({
            status: MandateLifeCycle.COMMITTED,
            investor: investor,
            agreement: agreementId,
            __committedCapital: 0,
            __collatAmount: 0
        }));
        uint256 mandateId = _mandates.length.sub(1);
        Mandate storage mandate = _mandates[mandateId];
        transferred = _transferDepositCapital(agreement, mandate, amount, minCollatRateRequirement);
        require(transferred > 0, "need to commit nonzero capital");
        agreement.__committedMandates = agreement.__committedMandates.add(1);
        emit CommitToAgreement(agreementId, agreement.manager, mandateId, investor, amount, mandate.__collatAmount);
    }

    function getAgreementPublishTimestamp(uint256 agreementId) public view returns(uint256) {
        return _agreements[agreementId].publishTimestamp;
    }

    function getAgreementCollateral(uint256 agreementId) public view returns(uint256) {
        return _agreements[agreementId].__collatAmount;
    }
    function getAgreementCommittedCapital(uint256 agreementId) public view returns(uint256) {
        return _agreements[agreementId].__committedCapital;
    }

    function activateAgreement(uint256 agreementId) external onlyExistAgreement(agreementId) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        require(AgreementLifeCycle.PUBLISHED == agreement.status, 'Agreement should be in PUBLISHED status');
        agreement.status = AgreementLifeCycle.ACTIVE;
        countedBalance[agreementId][agreement.baseCoin] = agreement.__committedCapital;
        emit ActivateAgreement(agreementId, agreement.manager);
    }

    function setExpiredAgreement(uint256 agreementId) public {
        Agreement storage agreement = _agreements[agreementId];
        _assertAgreementNotDeleted(agreement);
        require(agreement.status <= AgreementLifeCycle.ACTIVE, "Agreement is already expired");
        require(
            now > (agreement.publishTimestamp.add(agreement.openPeriod).add(agreement.activePeriod)),
            "Agreement is not over yet"
        );
        require(_trd.agreementClosed(agreementId) == false, "Agreement trades are not closed");
        agreement.status = AgreementLifeCycle.EXPIRED;
        emit SetExpiredAgreement(agreementId, agreement.manager);
    }

    function _assertAgreementNotDeleted(Agreement storage agreement) private view {
        require(!agreement.isDeleted, "Agreement already deleted");
    }

    function deleteAgreement(uint256 agreementId) external onlyExistAgreement(agreementId) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        _assertAgreementNotDeleted(agreement);
        require(agreement.status < AgreementLifeCycle.PUBLISHED, "Agreement status should be less than PUBLISHED");
        if (agreement.__collatAmount > 0) _transferWithdrawCollateral(agreementId, agreement.__collatAmount);
        agreement.isDeleted = true;
        emit DeleteAgreement(agreementId);
    }

    function settleMandate(uint256 mandateId) public nonReentrant {
        Mandate storage mandate = _mandates[mandateId];
        Agreement storage agreement = _agreements[mandate.agreement];
        _assertIsMandateOrAgreementOwner(agreement, mandate);
        require(AgreementLifeCycle.EXPIRED <= agreement.status, "Agreement should be in EXPIRED status");
        require(MandateLifeCycle.SETTLED > mandate.status, "Mandate was already settled");
        //find the share of the mandate in the pool and multiply by the finalBalance
        uint256 finalAgreementTradeBalance = _trd.balances(mandate.agreement);
        // the final trade balance per this mandate is calculated as a share in the entire trade balance
        uint256 mandateFinalTradeBalance = mandate.__committedCapital.mul(finalAgreementTradeBalance).div(agreement.__committedCapital);
        //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
        uint256 profitAbsTarget = mandate.__committedCapital.mul(agreement.targetReturnRate.add(100)).div(100);
        uint256 desiredCompensation;
        uint256 recoverableCompensation;
        uint256 mandateFinalCorrectedBalance;
        if (mandateFinalTradeBalance < profitAbsTarget) {
            //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
            desiredCompensation = profitAbsTarget.sub(mandateFinalTradeBalance);
            //now if the above is higher than the actual collateral, it will only count actual collateral
            recoverableCompensation = desiredCompensation > mandate.__collatAmount
                ? mandate.__collatAmount
                : desiredCompensation;
            //let's calculate the final that we have to pay as a sum of trade balance and the compensation
            mandateFinalCorrectedBalance = mandateFinalTradeBalance.add(recoverableCompensation);
        } else mandateFinalCorrectedBalance = profitAbsTarget;
        //withdraw percentage of the share on the mandate
        //settle the collateral
        IERC20(agreement.baseCoin).transfer(mandate.investor, mandateFinalCorrectedBalance);
        mandate.status = MandateLifeCycle.SETTLED;
        emit __service__settleMandate__values(
            mandateFinalTradeBalance,
            //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
            profitAbsTarget,
            //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
            desiredCompensation,
            //now if the above is higher than the actual collateral, it will only count actual collateral
            recoverableCompensation,
            //let's calculate the final that we have to pay as a sum of trade balance and the compensation
            mandateFinalCorrectedBalance
        );
    }

    function withdrawManagerCollateral(
        uint256 agreementId
    ) external onlyExistAgreement(agreementId) returns (bool) {
        Agreement storage agreement = _agreements[agreementId];
        _assertIsAgreementManager(agreement);
        require(agreement.status == AgreementLifeCycle.EXPIRED, "Agreement should be in EXPIRED status");
        uint256 finalAgreementTradeBalance = _trd.balances(agreementId).add(agreement.__collatAmount);
        uint256 targetReturnAmount = agreement.__committedCapital.mul(agreement.targetReturnRate.add(100)).div(100);
        uint256 amount = targetReturnAmount < finalAgreementTradeBalance ?
            finalAgreementTradeBalance.sub(targetReturnAmount) :
            0;
        agreement.status = AgreementLifeCycle.SETTLED;
        if (amount != 0) {
            address receiver = agreement.manager;
            IERC20(agreement.baseCoin).transfer(receiver, amount);
            emit ManagerCollateralWithdrawn(agreementId, receiver, amount);
        }
        return true;
    }

    function _assertIsAgreementManager(Agreement storage agreement) private view {
        require(msg.sender == agreement.manager, "Only appointed Fund Manager");
    }

    function _assertIsMandateOrAgreementOwner(
        Agreement storage agreement,
        Mandate storage mandate
    ) private view {
        address sender = msg.sender;
        require(sender == mandate.investor || sender == agreement.manager, "Only Investor or Manager");
    }


    event ManagerCollateralWithdrawn(
        uint256 indexed agreementId,
        address indexed manager,
        uint256 amount
    );

    event DeleteAgreement(uint256 agreementId);

    event CreateAgreement(
        uint256 indexed agreementId,
        address indexed manager,
        address indexed baseCoin,
        uint256 targetReturnRate,
        uint256 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint256 openPeriod,
        uint256 activePeriod
    );

    event PopulateAgreement(
        uint256 indexed agreementId,
        address indexed manager,
        address indexed baseCoin,
        uint256 targetReturnRate,
        uint256 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint256 openPeriod,
        uint256 activePeriod
    );

    event DepositCollateral(
        uint256 indexed agreementId,
        address indexed manager,
        uint256 amount
    );

    event WithdrawCollateral(
        uint256 indexed agreementId,
        address indexed manager,
        uint256 amount
    );

    event PublishAgreement(
        uint256 indexed agreementId,
        address indexed manager,
        address indexed baseCoin,
        uint256 targetReturnRate,
        uint256 maxCollateralRateIfAvailable,
        uint256 __collatAmount,
        uint256 openPeriod,
        uint256 activePeriod,
        uint256 publishTimestamp
    );

    event UnpublishAgreement(
        uint256 indexed agreementId,
        address indexed manager
    );

    event CommitToAgreement(
        uint256 indexed agreementId, 
        address manager, 
        uint256 indexed mandateId, 
        address indexed investor, 
        uint256 amount, 
        uint256 collateral
    );
    event ActivateAgreement(
        uint256 indexed agreementId,
        address indexed manager
    );
    event SetExpiredAgreement(
        uint256 indexed agreementId,
        address indexed manager
    );

    event CreateMandate(
        uint256 indexed id,
        address indexed investor
    );

    event DepositCapital(
        uint256 indexed agreementId,
        address manager,
        uint256 indexed mandateId,
        address indexed investor,
        uint256 amount
    );

    event WithdrawCapital(
        uint256 indexed agreementId,
        address manager,
        uint256 indexed mandateId,
        address indexed investor,
        uint256 amount
    );

    event CancelMandate(
        uint256 indexed agreementId,
        address manager,
        uint256 indexed mandateId,
        address indexed investor
    );

    event __service__settleMandate__values(
        uint256 mandateFinalTradeBalance,
        //we are checking if any compensation from the collateral needed (if the profit is below the promised one)
        uint256 profitAbsTarget,
        //calculate the ideal compensation from the collateral to cover the gap between real profit and target profit
        uint256 desiredCompensation,
        //now if the above is higher than the actual collateral, it will only count actual collateral
        uint256 recoverableCompensation,
        //let's calculate the final that we have to pay as a sum of trade balance and the compensation
        uint256 mandateFinalCorrectedBalance
    );
}
