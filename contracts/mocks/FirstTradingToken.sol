// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./MockERC20.sol";

contract FirstTradingToken is MockERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public MockERC20(name, symbol, supply) {
        return;
    }
}
