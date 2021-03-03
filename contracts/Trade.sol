pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { UniswapV2Library } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./MandateBook.sol";


contract Trade is MandateBook {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TradeLog {
        address fromAsset;
        address toAsset;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
    }

    IUniswapV2Router02 _router;
    IUniswapV2Factory _factory;

    uint256 private constant _timeFrame = 15 * 60 * 1 seconds;
    mapping(uint256 => TradeLog[]) public trades; // used for logging trader activity by agreement
    mapping(uint256 => EnumerableSet.AddressSet) private _agreementActiveTokens;

    event Traded(
        uint256 agreementId,
        address fromAsset,
        address toAsset,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );

    constructor(address uniV2Factory, address uniV2Router) public {
        _factory = IUniswapV2Factory(uniV2Factory);
        _router = IUniswapV2Router02(uniV2Router);
    }

    function router() external view returns (address) {
        return address(_router);
    }

    function factory() external view returns (address) {
        return address(_factory);
    }

    // return profit by agreement, depend on first known amount
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint256 agreementId) public view returns (uint256 amount, bool positive) {
        uint256 agreementBalance = balances[agreementId];
        uint256 agreementInitBalance = _getInitBalance(agreementId);
        if (agreementInitBalance < agreementBalance) {
            amount = agreementBalance.sub(agreementInitBalance);
            positive = true;
        } else {
            amount = agreementInitBalance.sub(agreementBalance);
            positive = false;
        }
    }

    function getPrice(
        address tokenA,
        address tokenB
    ) public view returns (uint256 price0Cumulative, uint256 price1Cumulative) {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        (price0Cumulative, price1Cumulative,) = UniswapV2OracleLibrary.currentCumulativePrices(address(_pair));
    }

    // @dev get liquidity for token A, B.
    function getLiquidity(address tokenA, address tokenB) public view returns(uint256 reserve0, uint256 reserve1) {
        IUniswapV2Pair _pair = IUniswapV2Pair(_factory.getPair(tokenA, tokenB));
        (reserve0, reserve1,) = _pair.getReserves();
        if (tokenA == _pair.token1()) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }
    }

    // trades from trader by the agreement
    function countTrades(uint256 agreementId) public view returns (uint256) {
        return trades[agreementId].length;
    }

    function getTrade(uint256 agreementId, uint256 index) public view returns (TradeLog memory) {
        require(index < countTrades(agreementId), "Trade not exist");
        return trades[agreementId][index];
    }

    function getBaseAsset(uint256 agreementId) public view returns (address) {
        return getAgreement(agreementId).baseCoin;
    }

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    ) external canTrade(agreementId) {
        _swapTokenToToken(
            agreementId,
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            deadline
        );
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
    function sell(
        uint256 agreementId,
        address asset
    ) public onlyAfterActivePeriod(agreementId) canSell(agreementId) {
        if (countTrades(agreementId) == 0) {
            balances[agreementId] = _getInitBalance(agreementId);
            agreementClosed[agreementId] = true;
            return;
        }
        EnumerableSet.AddressSet storage set = _agreementActiveTokens[agreementId];
        require(set.contains(asset), "Not any funds in this asset");
        _sell(agreementId, asset);
        if (set.length() == 1 && set.contains(getBaseAsset(agreementId))) agreementClosed[agreementId] = true;
    }

    // @dev on agreement end, close specific number of positions
    function sellAll(
        uint256 agreementId
    ) external onlyAfterActivePeriod(agreementId) canSell(agreementId) {
        if (countTrades(agreementId) == 0) {
            balances[agreementId] = _getInitBalance(agreementId);
            agreementClosed[agreementId] = true;
            return;
        }

        address baseCoin = getBaseAsset(agreementId);
        EnumerableSet.AddressSet storage set = _agreementActiveTokens[agreementId];
        for (uint256 iterator = 0; iterator < set.length(); iterator++) {
            address token = set.at(iterator);
            if (token == baseCoin) continue;
            _sell(agreementId, token);
        }
        if (set.length() == 1 && set.contains(getBaseAsset(agreementId))) agreementClosed[agreementId] = true;
    }

    function _getInitBalance(uint256 agreementId) internal view returns (uint256) {
        return getAgreement(agreementId).__committedCapital;
    }

    function _sell(uint256 agreementId, address asset) private {
        uint256 currentTimestamp = block.timestamp;
        uint256 amountIn = countedBalance[agreementId][asset];
        uint256 amountOut = getOutAmount(agreementId, asset);
        uint256[] memory amounts = _swapTokenToToken(
            agreementId,
            asset,
            getBaseAsset(agreementId),
            amountIn,
            amountOut,
            currentTimestamp.add(_timeFrame)
        );
        balances[agreementId] = balances[agreementId].add(amounts[amounts.length.sub(1)]);
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
        deadline = deadline > 0 ? deadline : currentTimestamp.add(_timeFrame);
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
        _updateAgreementTokenActivity(agreementId, tokenIn);
        _updateAgreementTokenActivity(agreementId, tokenOut);
        emit Traded(
            agreementId,
            tokenIn,
            tokenOut,
            firstAmount,
            lastAmount,
            currentTimestamp
        );
    }

    function _updateAgreementTokenActivity(uint256 agreementId, address token) private {
        EnumerableSet.AddressSet storage set = _agreementActiveTokens[agreementId];
        bool tokenIsActive = countedBalance[agreementId][token] > 0;
        bool tokenInActiveList = set.contains(token);
        if (tokenIsActive && !tokenInActiveList) {
            set.add(token);
        } else if (!tokenIsActive && tokenInActiveList) {
            set.remove(token);
        }
    }

    modifier canTrade(uint256 agreementId) {
        AMandate.Agreement memory agreement = getAgreement(agreementId);
        require(agreement.manager == msg.sender, "Caller is not agreement manager");
        require(agreement.status == AMandate.AgreementLifeCycle.ACTIVE, "Agreement status is not active");
        _;
    }

    modifier canSell(uint256 agreementId) {
        AMandate.Agreement memory agreement = getAgreement(agreementId);
        require(!agreementClosed[agreementId], "Agreement was closed");
        require(
            getAgreementStatus(agreementId) == AMandate.AgreementLifeCycle.EXPIRED,
            "Agreement is not expired"
        );
        _;
    }

    modifier onlyAfterActivePeriod(uint256 agreementId) {
        AMandate.Agreement memory agreement = getAgreement(agreementId);
        require(
            block.timestamp > agreement.publishTimestamp.add(agreement.openPeriod).add(agreement.activePeriod),
            "Agreement still active"
        );
        _;
    }
}
