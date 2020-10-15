pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./AMandate.sol";

interface IMandateBook {
    function getMandateStatus(uint id) external returns (AMandate.MandateLifeCycle status);

    function getMandate(uint id) external returns (AMandate.Mandate memory mandate);

    function acceptMandate(uint id) external payable; // accepts collateral from fund manager

    function cancelMandate(uint id) external;

    function startMandate(uint id) external payable; // accepts collateral from fund manager

    function closeMandate(uint id) external;

    function createMandate(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable returns(uint256 id); //accepts investment funds from investor

    function populateMandate(uint id, address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable; //accepts investment funds from investor

    function submitMandate(uint id) external;

    function depositMandate(uint256 id) external payable returns (uint256 finalMandateBalance);

    function depositCollateral(uint256 id) external payable returns (uint256 finalCollateralBalance);
}