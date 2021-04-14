pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {UniswapV2Library} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./MandateBook.sol";
import "./interfaces/ITrade.sol";

contract Trade is MandateBook, ITrade {
    using SafeMath for uint256;
    IUniswapV2Router02 private _router;
    IUniswapV2Factory private _factory;

    uint256 public constant TIME_FRAME = 15 minutes;

    mapping(uint256 => TradeLog[]) public trades;
    mapping(uint256 => mapping(address => bool)) public tokenSold;

    event Traded(
        uint256 agreementId,
        address fromAsset,
        address toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    constructor(address factoryV2, address routerContract) public {
        _factory = IUniswapV2Factory(factoryV2);
        _router = IUniswapV2Router02(routerContract);
    }

    function router() external view override returns (address) {
        return address(_router);
    }

    function factory() external view override returns (address) {
        return address(_factory);
    }

    // return profit by agreement, depend on first known amount
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint256 agreementId) public view override returns (uint256 amount, bool positive) {
        uint256 agreementBalance = balances[agreementId];
        uint256 agreementInitBalance = getAgreement(agreementId).__committedCapital;
        if (agreementInitBalance < agreementBalance) {
            amount = agreementBalance.sub(agreementInitBalance);
            positive = true;
        } else {
            amount = agreementInitBalance.sub(agreementBalance);
            positive = false;
        }
    }

    function getPrice(address tokenA, address tokenB)
        public
        view
        override
        returns (uint256 price0Cumulative, uint256 price1Cumulative)
    {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        (price0Cumulative, price1Cumulative, ) = UniswapV2OracleLibrary.currentCumulativePrices(address(_pair));
        return (price0Cumulative, price1Cumulative);
    }

    function getLiquidity(address tokenA, address tokenB) public view override returns (uint256, uint256) {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        uint256 reserve0;
        uint256 reserve1;
        (reserve0, reserve1, ) = _pair.getReserves();
        if (tokenA == _pair.token1()) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }
        return (reserve0, reserve1);
    }

    function getFinalBalance(uint256 agreementId) public view override returns (uint256) {
        return balances[agreementId];
    }

    function countTrades(uint256 agreementId) public view override returns (uint256) {
        return trades[agreementId].length;
    }

    function getTrade(uint256 agreementId, uint256 index) public view override returns (TradeLog memory) {
        require(index < countTrades(agreementId), "Trade not exist");
        return trades[agreementId][index];
    }

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    ) external override {
        Agreement memory agreement = getAgreement(agreementId);
        require(agreement.manager == msg.sender, "Caller is not agreement manager");
        require(agreement.status == AgreementLifeCycle.ACTIVE, "Agreement status is not active");
        _swapTokenToToken(agreementId, tokenIn, tokenOut, amountIn, amountOut, deadline);
    }

    // @dev get optimal amount in base asset, depend on agreement
    function getOutAmount(uint256 agreementId, address asset) public view returns (uint256 amountOut) {
        (uint256 reserveA, uint256 reserveB) =
            getLiquidity((address(0) == asset) ? _router.WETH() : asset, getAgreement(agreementId).baseCoin);
        amountOut = _router.getAmountOut(
            countedBalance[agreementId][asset], // amountIn
            reserveA,
            reserveB
        );
    }

    // @dev sell one asset with optimal price by agreement id
    function sell(uint256 agreementId, address asset) public {
        uint256 openTradesCount = countTrades(agreementId);
        (address agreementBaseCoin, bool exit) = _preSell(agreementId, openTradesCount);
        if (exit) return;
        require(asset != agreementBaseCoin, "It's not possible to sell baseCoin");
        require(!tokenSold[agreementId][asset], "Asset already sold");
        if (!tokenSold[agreementId][agreementBaseCoin]) {
            tokenSold[agreementId][agreementBaseCoin] = true;
            balances[agreementId] = countedBalance[agreementId][agreementBaseCoin];
        }
        if (countedBalance[agreementId][asset] == 0) tokenSold[agreementId][asset] = true;
        else _sell(agreementId, agreementBaseCoin, asset);
        uint256 counter;
        for (uint256 i = 0; i < openTradesCount; i++) {
            address tokenTo = trades[agreementId][i].toAsset;
            if (tokenSold[agreementId][tokenTo]) counter++;
        }
        if (counter == openTradesCount) agreementClosed[agreementId] = true;
    }

    // @dev on agreement end, close specific number of positions
    function sellAll(uint256 agreementId) external {
        uint256 openTradesCount = countTrades(agreementId);
        (address agreementBaseCoin, bool exit) = _preSell(agreementId, openTradesCount);
        if (exit) return;
        if (!tokenSold[agreementId][agreementBaseCoin]) {
            tokenSold[agreementId][agreementBaseCoin] = true;
            balances[agreementId] = countedBalance[agreementId][agreementBaseCoin];
        }
        TradeLog memory tradeLog;
        for (uint256 i = 0; i < openTradesCount; i++) {
            tradeLog = trades[agreementId][i];
            address asset = tradeLog.toAsset;
            if (!tokenSold[agreementId][asset]) {
                if (countedBalance[agreementId][asset] == 0) tokenSold[agreementId][asset] = true;
                else _sell(agreementId, agreementBaseCoin, asset);
            }
        }
        agreementClosed[agreementId] = true;
    }

    function _preSell(uint256 agreementId, uint256 openTradesCount) private returns (address baseCoin, bool exit) {
        Agreement memory agreement = getAgreement(agreementId);
        require(
            block.timestamp > agreement.publishTimestamp.add(agreement.openPeriod).add(agreement.activePeriod),
            "Agreement still active"
        );
        require(!agreementClosed[agreementId], "Agreement was closed");
        require(agreement.status == AgreementLifeCycle.EXPIRED, "Agreement is not expired");
        baseCoin = agreement.baseCoin;
        if (openTradesCount == 0) {
            balances[agreementId] = agreement.__committedCapital;
            agreementClosed[agreementId] = true;
            exit = true;
        }
    }

    function _sell(
        uint256 agreementId,
        address baseCoin,
        address asset
    ) private {
        uint256 currentTimestamp = block.timestamp;
        uint256 amountIn = countedBalance[agreementId][asset];
        uint256 amountOut = getOutAmount(agreementId, asset);
        uint256[] memory amounts =
            _swapTokenToToken(agreementId, asset, baseCoin, amountIn, amountOut, currentTimestamp.add(TIME_FRAME));
        balances[agreementId] = balances[agreementId].add(amounts[amounts.length.sub(1)]);
        tokenSold[agreementId][asset] = true;
    }

    function getPair(address tokenIn, address tokenOut) public view returns (address fromFactory, address fromLib) {
        fromFactory = _factory.getPair(tokenIn, tokenOut);
        fromLib = UniswapV2Library.pairFor(address(_factory), tokenIn, tokenOut);
    }

    function _swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        require(tokenIn != tokenOut, "Swap tokenIn must be not equal to tokenOut");
        uint256 tokenInMaxValue = countedBalance[agreementId][tokenIn];
        require(tokenInMaxValue >= amountIn, "Not enough tokenIn amount for this");
        IUniswapV2Pair pair = IUniswapV2Pair(_factory.getPair(tokenIn, tokenOut));
        require(address(pair) != address(0), "Pair not exist");
        {
            (uint256 reserve0, uint256 reserve1) = getLiquidity(tokenIn, tokenOut);
            require(reserve0 >= amountIn && reserve1 >= amountOut, "Not enough liquidity");
        }
        address thisContract = address(this);
        TransferHelper.safeApprove(tokenIn, address(_router), amountIn);
        TransferHelper.safeApprove(tokenIn, thisContract, amountIn);
        TransferHelper.safeApprove(tokenIn, address(pair), amountIn);
        uint256 currentTimestamp = block.timestamp;
        deadline = deadline > 0 ? deadline : currentTimestamp.add(TIME_FRAME);
        {
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
            amounts = _router.swapExactTokensForTokens(amountIn, amountOut, path, thisContract, deadline);
        }
        _saveSwapData(agreementId, tokenIn, tokenOut, amounts[0], amounts[amounts.length.sub(1)]);
    }

    function _saveSwapData(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 firstAmount,
        uint256 lastAmount
    ) private {
        uint256 currentTimestamp = block.timestamp;
        countedBalance[agreementId][tokenIn] = countedBalance[agreementId][tokenIn].sub(firstAmount);
        countedBalance[agreementId][tokenOut] = countedBalance[agreementId][tokenOut].add(lastAmount);
        trades[agreementId].push(
            TradeLog({
                fromAsset: tokenIn,
                toAsset: tokenOut,
                amountIn: firstAmount,
                amountOut: lastAmount,
                timestamp: currentTimestamp
            })
        );
        emit Traded(agreementId, tokenIn, tokenOut, firstAmount, lastAmount, currentTimestamp);
    }
}
