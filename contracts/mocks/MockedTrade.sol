pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./../Trade.sol";

contract MockedTrade is Trade {
    constructor(
        address factoryV2,
        address routerContract
    ) public Trade(factoryV2, routerContract) {}

    function increaseAgreementIncome(
        uint256 agreementId,
        uint256 amount
    ) external onlyExistAgreement(agreementId) onlyPositiveAmount(amount) returns (bool) {
        Agreement memory agreement = _agreements[agreementId];
        IERC20(agreement.baseCoin).transferFrom(msg.sender, address(this), amount);
        balances[agreementId] = balances[agreementId].add(amount);
        return true;
    }
}
