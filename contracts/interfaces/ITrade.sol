pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import "../Types.sol";

interface ITrade is IMandateBook {
    function router() external view returns (address);

    function factory() external view returns (address);

    function getFinalBalance(uint256 agreementId) external view returns (uint256);

    function countTrades(uint256 agreementId) external view returns (uint256);

    function getTrade(uint256 agreementId, uint256 index) external view returns (Types.TradeLog memory tradeLog);

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external;

    function countProfit(uint256 agreementId) external view returns (uint256 amount, bool positive);

    function getPrice(address tokenA, address tokenB) external view returns (uint256, uint256);

    function getLiquidity(address tokenA, address tokenB) external view returns (uint256, uint256);
}
