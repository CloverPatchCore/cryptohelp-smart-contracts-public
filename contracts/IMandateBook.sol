pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./AMandate.sol";

interface IMandateBook {

    function getMandate(uint256 mandateId) external view returns (AMandate.Mandate memory mandate);
    function getMandateStatus(uint256 mandateId) external view returns (AMandate.MandateLifeCycle);
    

/*     function acceptMandate(uint id) external payable; // accepts collateral from fund manager


    function startMandate(uint id) external payable; // accepts collateral from fund manager

    function closeMandate(uint id) external;

    function createMandate(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable returns(uint256 id); //accepts investment funds from investor

    function populateMandate(uint id, address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable; //accepts investment funds from investor

    function submitMandate(uint id) external;
 */
    function cancelMandate(uint256 mandateId) external;
    
    function depositCapital(uint256 mandateId, uint256 amount, uint16 minCollatRateRequirement) external /* payable */ returns (uint256 finalMandateCapitalBalance);
    function withdrawCapital(uint256 mandateId, uint256 amount) external /* payable */ returns (uint256 finalMandateCapitalBalance);

    function getAgreement(uint256 agreementId) external view returns (AMandate.Agreement memory agreement);
    function getAgreementStatus(uint256 agreementId) external view returns (AMandate.AgreementLifeCycle status);

    function depositCollateral(uint256 agreementId, uint256 amount) external /* payable */ returns (uint256 finalAgreementCollateralBalance);
    function withdrawCollateral(uint256 agreementId, uint256 amount) external /* payable */;
}
