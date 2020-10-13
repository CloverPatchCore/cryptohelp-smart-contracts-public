pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./AMandate.sol";

interface IMandateBook {
    function getStatus(uint id) external returns (AMandate.LifeCycle status);

    function getMandate(uint id) external returns (AMandate.Mandate memory mandate);

    function acceptMandate(uint id) external;

    function cancelMandate(uint id) external;

    function closeMandate(uint id) external;

    function createMandate(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable returns(uint256 id);

    function populateMandate(uint id, address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable;

    function submitMandate(uint id) external;
}