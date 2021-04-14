pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "../Types.sol";

interface IMandateBook {
    function getMandate(uint256 mandateId) external view returns (Types.Mandate memory mandate);

    function getMandateStatus(uint256 mandateId) external view returns (Types.MandateLifeCycle);

    function cancelMandate(uint256 mandateId) external;

    function depositCapital(
        uint256 mandateId,
        uint256 amount,
        uint256 minCollatRateRequirement
    ) external returns (uint256 finalMandateCapitalBalance);

    function withdrawCapital(uint256 mandateId, uint256 amount) external returns (uint256 finalMandateCapitalBalance);

    function getAgreement(uint256 agreementId) external view returns (Types.Agreement memory agreement);

    function getAgreementStatus(uint256 agreementId) external view returns (Types.AgreementLifeCycle status);

    function depositCollateral(uint256 agreementId, uint256 amount)
        external
        returns (uint256 finalAgreementCollateralBalance);

    function withdrawCollateral(uint256 agreementId, uint256 amount) external;
}
