pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import "./MandateBook.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import { IUniswapV2Router01 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import { UniswapV2Library } from '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import { UniswapV2OracleLibrary } from '@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol';

contract Trade is MandateBook {
    using SafeMath for uint;

    // @dev event triggered on investor
    event ExtraStopped(uint256 id);

    IMandateBook IMB = IMandateBook(address(this));
    address router;
    IUniswapV2Factory factory;

    struct Balance {
        uint256 init; // on start
        uint256 counted; // equivalent balance on every trade
    }

    mapping (uint256 => Balance) public balances; // trader absolute profit

    struct Trade {
        address fromAsset;
        address toAsset;
        uint256 amountIn;
        uint256 amountOut;
    }

    mapping (uint256 => Trade[]) public trades; // used for logging trader activity by agreement

    uint256 timeFrame = 15 * 60 * 1 seconds;

    constructor(address routerContract, IUniswapV2Factory factoryV2) public {
        router = routerContract;
        factory = factoryV2;
    }

    function countTrades(uint256 agreementId) public view returns (uint) {
        return trades[agreementId].length;
    }

    function getTrade(uint256 agreementId, uint256 index) public view returns (Trade memory) {
        return trades[agreementId][index];
    }
    
    // @dev swap any ERC20 token to any ERC20 token
    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    )
        public
        canTrade(agreementId)
    {
        require(factory.getPair(tokenIn, tokenOut) != address(0), "Pair not exist");

        (uint256 reserve0, uint256 reserve1) = getLiquidity(tokenIn, tokenOut);

        require(reserve0 >= amountIn && reserve1 >= amountOutMin, "Not enough liquidity");

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        if (deadline == 0) {
            deadline = block.timestamp + timeFrame;
        }

        IUniswapV2Router01(router).swapExactTokensForTokens(amountIn, amountOutMin, path, msg.sender, deadline);

        trades[agreementId].push(Trade({
            fromAsset: tokenIn,
            toAsset: tokenOut,
            amountIn: amountIn,
            amountOut: amountOutMin
        }));

        // TODO: update profit table
    }

    // @dev sell ERC20 token for ETH
    function swapTokenForETH(
        uint256 agreementId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    )
        public
        canTrade(agreementId)
    {
        address WETH = IUniswapV2Router01(router).WETH();

        require(factory.getPair(tokenIn, WETH) != address(0), "Pair not exist");

        (uint256 reserve0, uint256 reserve1) = getLiquidity(tokenIn, WETH);

        require(reserve0 >= amountIn && reserve1 >= amountOutMin, "Not enough liquidity");

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = WETH;

        if (deadline == 0) {
            deadline = block.timestamp + timeFrame;
        }

        IUniswapV2Router01(router).swapExactTokensForETH(amountIn, amountOutMin, path, msg.sender, deadline);

        trades[agreementId].push(Trade({
            fromAsset: tokenIn,
            toAsset: address(0), // address 0x0 becouse receive the ether
            amountIn: amountIn,
            amountOut: amountOutMin
        }));

        // TODO: update profit table
    }

    // @dev buy ERC20 token for ETH
    function swapETHForToken(
        uint256 agreementId,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        uint256 deadline
    )
        public
        payable
        canTrade(agreementId)
    {
        require(amountInMax >= msg.value, "Ethers not enough");

        address WETH = IUniswapV2Router01(router).WETH();

        require(factory.getPair(WETH, tokenOut) != address(0), "Pair not exist");

        (uint256 reserve0, uint256 reserve1) = getLiquidity(WETH, tokenOut);

        require(reserve0 >= amountInMax && reserve1 >= amountOut, "Not enough liquidity");

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenOut;

        if (deadline == 0) {
            deadline = block.timestamp + timeFrame;
        }

        IUniswapV2Router01(router).swapETHForExactTokens(amountOut, path, msg.sender, deadline);

        trades[agreementId].push(Trade({
            fromAsset: address(0), // address 0x0 becouse sent the ether
            toAsset: tokenOut,
            amountIn: amountInMax,
            amountOut: amountOut
        }));

        // TODO: update profit table
    }

    // return profit by mandate, depend on first known price
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint256 agreementId) public view returns (uint256 amount, bool positive) {
        if (balances[agreementId].init <= balances[agreementId].counted) {
            amount = balances[agreementId].counted.sub(balances[agreementId].init);
            positive = true;
        } else {
            amount = balances[agreementId].init.sub(balances[agreementId].counted);
            positive = false;
        }

        return (amount, positive);
    }

    // @dev investor can extra stop trades by mandate, if the losses are more than acceptable
    function extraStopTrade(uint256 agreementId) 
        external
        onlyMandateInvestor(agreementId)
        resolveExtraStop(agreementId) 
    {
        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);
        _a.extraStopped = true;
        _agreements[agreementId] = _a;

        emit ExtraStopped(agreementId);
    }

    function _updateProfit() internal {
        // TODO: add logic
        // formula: get actual price to the base asset,
        // balances[agreementId].counted = ;
    }

    // @dev tokenA, tokenB
    function getPrice(address tokenA, address tokenB) public view returns(uint, uint) {
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(address(factory), tokenA, tokenB));
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(address(_pair));

        return (price0Cumulative, price1Cumulative);
    }

    // @dev get liquidity for token A, B.
    function getLiquidity(address tokenA, address tokenB) public view returns(uint256, uint256) {
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(address(factory), tokenA, tokenB));
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1,) = _pair.getReserves();

        return (reserve0, reserve1);
    }

    modifier canTrade(uint256 agreementId) {
        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);
        require(_a.manager == address(0), "Deal not exist");
        require(_a.manager == msg.sender, "Not manager");
        require(!_a.extraStopped, "Trades stopped");
        require(_a.status == AMandate.AgreementLifeCycle.ACTIVE, "Agreement status is not active");
        _;
    }

    // @dev access right to stop
    modifier resolveExtraStop(uint256 agreementId) {
        (uint256 loss, bool positive) = countProfit(agreementId);

        require(!positive, "Profit is in positive space");

        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);

        require(
            loss > balances[agreementId].init.mul(_a.extraStopLossPercent).div(100),
            "Extra stop loss not touched"
        );
        _;
    }
}