pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { UniswapV2Library } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./IMandateBook.sol";
import "./MandateBook.sol";

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Trade is MandateBook, ITrade {
    using SafeMath for uint256;

    IMandateBook _IMB = IMandateBook(address(this));
    IUniswapV2Router02 _router;
    IUniswapV2Factory _factory;

    struct Balance {
        uint256 counted; // equivalent balance on every trade
    }

    mapping (uint256 => Balance) public _balances; // trader absolute profit

    mapping (uint256 => TradeLog[]) public trades; // used for logging trader activity by agreement

    mapping (uint256 => bool) public _agreementClosed;

    uint256 timeFrame = 15 * 60 * 1 seconds;

    mapping (uint256 => uint256) public countedTrades; // agreement id -> counter ticker

    // is was added to counted balance, token marked ad sold
    mapping(uint256 => mapping(address => bool)) tokenSold; // agreement id -> mapping

    // by agreement id we store the balances of Assets (on the end of the agreement)
    mapping(uint256 => mapping(address => uint256)) countedBalance; // agreement id -> mapping

    event Traded(
        uint256 agreementId,
        address fromAsset,
        address toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    // params uniV2Factory, uniV2Router
    constructor(address factoryV2, address routerContract) public {
        _factory = IUniswapV2Factory(factoryV2);
        _router = IUniswapV2Router02(routerContract);
    }

    function IMB() external override view returns (address) {
        return address(_IMB);
    }

    function agreementClosed(uint256 agreementId) external override view returns (bool) {
        return _agreementClosed[agreementId];
    }

    function balances(uint256 agreementId) external override view returns (uint256) {
        return _balances[agreementId].counted;
    }

    function router() external override view returns (address) {
        return address(_router);
    }

    function factory() external override view returns (address) {
        return address(_factory);
    }

    // return profit by agreement, depend on first known amount
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint256 agreementId) public override view returns (uint256 amount, bool positive) {
        uint256 agreementBalance = _balances[agreementId].counted;
        uint256 agreementInitBalance = _getInitBalance(agreementId);
        if (agreementInitBalance < agreementBalance) {
            amount = agreementBalance.sub(agreementInitBalance);
            positive = true;
        } else {
            amount = agreementInitBalance.sub(agreementBalance);
            positive = false;
        }
    }

    // @dev tokenA, tokenB
    function getPrice(address tokenA, address tokenB) public override view returns (uint256 price0Cumulative, uint256 price1Cumulative) {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        (price0Cumulative, price1Cumulative,) = UniswapV2OracleLibrary.currentCumulativePrices(address(_pair));
        return (price0Cumulative, price1Cumulative);
    }

    // @dev get liquidity for token A, B.
    function getLiquidity(address tokenA, address tokenB) public override view returns(uint256, uint256) {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        uint256 reserve0;
        uint256 reserve1;
        (reserve0, reserve1,) = _pair.getReserves();
        if (tokenA == _pair.token1()) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }

        return (reserve0, reserve1);
    }

    function getFinalBalance(uint256 agreementId) public override view returns (uint256) {
        Balance memory balance = _balances[agreementId];
        return balance.counted;
    }

    // trades from trader by the agreement
    function countTrades(uint256 agreementId) public override view returns (uint256) {
        return trades[agreementId].length;
    }

    function getTrade(uint256 agreementId, uint256 index) public override view returns (TradeLog memory) {
        require(index < countTrades(agreementId), "Trade not exist");

        return trades[agreementId][index];
    }

    function getBaseAsset(uint256 agreementId) public view returns (address) {
        return (_IMB.getAgreement(agreementId)).baseCoin;
    }

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    )
    external
    override
    canTrade(agreementId)
    {
        _swapTokenToToken(
            agreementId,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            deadline
        );
    }

    // @dev sell asset with optimal price by agreement id
    // @dev should be called before "sell", "sellAll"
    function _countPossibleTradesDirection(uint256 agreementId) private {
        TradeLog memory tradeLog;
        uint256 agreementTradesCount = countTrades(agreementId);
        for (uint256 i = countedTrades[agreementId]; i < agreementTradesCount; i++) {
            tradeLog = trades[agreementId][i];
            if (i == 0) {
                countedBalance[agreementId][tradeLog.fromAsset] = _getInitBalance(agreementId);
            }
            countedBalance[agreementId][tradeLog.fromAsset] = countedBalance[agreementId][tradeLog.fromAsset].sub(
                tradeLog.amountIn);
            countedBalance[agreementId][tradeLog.toAsset] = countedBalance[agreementId][tradeLog.toAsset].add(
                tradeLog.amountOut);
        }
        countedTrades[agreementId] = agreementTradesCount;
    }

    // @dev get optimal amount in base asset, depend on agreement
    function getOutAmount(uint256 agreementId, address asset) public view returns (uint256 amountOut) {
        (uint256 reserveA, uint256 reserveB) = getLiquidity(
            (address(0) == asset) ? _router.WETH() : asset,
            getBaseAsset(agreementId)
        );
        amountOut = _router.getAmountOut(
            countedBalance[agreementId][asset], // amountIn
            reserveA,
            reserveB
        );
    }

    // @dev sell one asset with optimal price by agreement id // should work properly
    function sell(uint256 agreementId, address asset) public onlyAfterActivePeriod(agreementId) {
        _sellValidation(agreementId);

        if (countedTrades[agreementId] == 0) {
            _countPossibleTradesDirection(agreementId);
        }

        if (countTrades(agreementId) == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            _agreementClosed[agreementId] = true;
            return;
        }

        uint256 counterToClose;
        for (uint256 i = 0; i < countTrades(agreementId); i++) {
            if (!tokenSold[agreementId][asset]) {
                _sell(agreementId, asset);
            }
            if (tokenSold[agreementId][asset] == true) {
                counterToClose++;
            }
        }

        if (counterToClose == countTrades(agreementId)) {
            _agreementClosed[agreementId] = true;
        }
    }

    // @dev on agreement end, close specific number of positions
    function sellAll(uint256 agreementId) external onlyAfterActivePeriod(agreementId) {
        _sellValidation(agreementId);

        if (countedTrades[agreementId] == 0) {
            _countPossibleTradesDirection(agreementId);
        }

        uint256 openTradesCount = countTrades(agreementId);

        TradeLog memory tradeLog;

        if (openTradesCount == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            _agreementClosed[agreementId] = true;

            return;
        }

        for (uint256 i = 0; i < openTradesCount; i++) {
            tradeLog = trades[agreementId][i];
            if (!tokenSold[agreementId][tradeLog.toAsset]) {
                _sell(agreementId, tradeLog.toAsset);
            }
        }

        _agreementClosed[agreementId] = true;
    }

    function _getInitBalance(uint256 agreementId) internal view returns (uint256) {
        return (_IMB.getAgreement(agreementId)).__committedCapital;
    }

    function _sellValidation(uint256 agreementId) internal view {
        require(!_agreementClosed[agreementId], "Agreement was closed");
        require(
            _IMB.getAgreementStatus(agreementId) == AMandate.AgreementLifeCycle.EXPIRED,
            "Agreement is not expired"
        );
    }

    function _sell(uint256 agreementId, address asset) private {
        uint256 currentTimestamp = block.timestamp;

        if (countTrades(agreementId) == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            return;
        }

        uint256 amountIn = countedBalance[agreementId][asset];
        uint256 amountOut = getOutAmount(agreementId, asset);

        uint256[] memory amounts = _swapTokenToToken(
            agreementId,
            asset,
            getBaseAsset(agreementId),
            amountIn,
            amountOut,
            currentTimestamp.add(timeFrame)
        );

        _balances[agreementId].counted = _balances[agreementId].counted.add(
            amounts[amounts.length.sub(1)]);
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
    )
    internal
    returns (uint256[] memory amounts)
    {
        uint256 tokenInMaxValue = agreementTradingTokenAmount[agreementId][tokenIn];
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
        deadline = deadline > 0 ? deadline : currentTimestamp.add(timeFrame);
        {
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
            amounts = _router.swapExactTokensForTokens(
                amountIn,
                amountOut,
                path,
                thisContract,
                deadline
            );
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
        agreementTradingTokenAmount[agreementId][tokenIn] = agreementTradingTokenAmount[agreementId][tokenIn].sub(
            firstAmount);
        agreementTradingTokenAmount[agreementId][tokenOut] = agreementTradingTokenAmount[
            agreementId][tokenOut].add(lastAmount);

        trades[agreementId].push(
            TradeLog({
                fromAsset: tokenIn,
                toAsset: tokenOut,
                amountIn: firstAmount,
                amountOut: lastAmount,
                timestamp: currentTimestamp
            })
        );

        emit Traded(
            agreementId,
            tokenIn,
            tokenOut,
            firstAmount,
            lastAmount,
            currentTimestamp
        );
    }

    modifier canTrade(uint256 agreementId) {
        AMandate.Agreement memory _a = _IMB.getAgreement(agreementId);
        require(countedTrades[agreementId] == 0, "Trades already calculated, use sell or sellAll");
        require(_a.manager == msg.sender, "Caller is not agreement manager");
        require(_a.status == AMandate.AgreementLifeCycle.ACTIVE, "Agreement status is not active");

        _;
    }

    modifier onlyAfterActivePeriod(uint256 agreementId) {
        AMandate.Agreement memory _a = _IMB.getAgreement(agreementId);

        // TODO: check time math logic
        require(block.timestamp > _a.publishTimestamp.add(_a.openPeriod).add(_a.activePeriod), "Agreement still active");
        _;
    }
}
