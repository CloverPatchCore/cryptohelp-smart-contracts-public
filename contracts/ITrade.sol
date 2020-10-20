pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

interface ITrade is IMandateBook {

    function IMB() external returns (address);

    function router() external returns (address);

    function factory() external returns (address);

    function balances(uint256 _agreementId) external returns (uint256 init, uint256 counted);

    //function trades() external returns();

    function timeFrame() external returns (uint);

    function getFinalBalance(uint256 agreementId) external view returns (uint);

    function countTrades(uint256 agreementId) external view returns (uint);

    function getTrade(uint256 agreementId, uint256 index) external view returns (
        address fromAsset,
        address toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external;

    function swapTokenForETH(
        uint256 agreementId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external;

    // @dev buy ERC20 token for ETH
    function swapETHForToken(
        uint256 agreementId,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        uint256 deadline
    ) external payable;

    function countProfit(uint256 agreementId) external view returns (uint256 amount, bool positive);

    function calcPureProfit(uint256 feePercent, uint256 amount, uint256 buyOrderPrice, uint256 sellOrderPrice) external returns (uint256);
    
    function getPrice(address tokenA, address tokenB) external view returns(uint, uint);
    
    function getLiquidity(address tokenA, address tokenB) external view returns(uint256, uint256);
}