pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./AMandate.sol";

interface IMandate {
    function getStatus(uint _id) external returns (AMandate.LifeCycle _status);

    function getDeal(uint _id) external returns (AMandate.Deal memory _deal);

    function dealAccept(uint _id) external;

    function dealCancel(uint _id) external;

    function dealClose(uint _id) external;

    function dealCreate(uint _id) external;

    function dealSubmit(uint _id) external;

    function dealPopulate(address targetManager, uint256 duration, uint16 takeProfit, uint16 stopLoss) external payable;
}