pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";

interface ITrade is IMandateBook {

    struct TradeLog {
        address fromAsset;
        address toAsset;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
    }

    function IMB() external view returns (address);

    function router() external view returns (address);

    function factory() external view returns (address);

    function balances(
        uint256 agreementId
    ) external view returns (uint256 counted);

    function agreementClosed(
        uint256 agreementId
    ) external view returns (bool);

    function getFinalBalance(
        uint256 agreementId
    ) external view returns (uint256);

    function countTrades(
        uint256 agreementId
    ) external view returns (uint256);

    function getTrade(
        uint256 agreementId,
        uint256 index
    ) external view returns (TradeLog memory tradeLog);

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external;

    function countProfit(
        uint256 agreementId
    ) external view returns (uint256 amount, bool positive);

    function getPrice(
        address tokenA,
        address tokenB
    ) external view returns(uint256, uint256);

    function getLiquidity(
        address tokenA,
        address tokenB
    ) external view returns(uint256, uint256);
}
