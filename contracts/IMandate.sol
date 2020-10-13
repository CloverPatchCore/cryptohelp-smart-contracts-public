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

    function dealPopulate(uint _id, address _targetManager, uint256 _duration, uint16 _takeProfit, uint16 _stopLoss) external payable;

    function dealSubmit(uint _id) external;
}