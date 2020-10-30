pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import "./MandateBook.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import { TransferHelper } from "./uniswapv2/libraries/TransferHelper.sol";
import { IUniswapV2Factory } from "./uniswapv2/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "./uniswapv2/interfaces/IUniswapV2Pair.sol";

import { IUniswapV2Router01 } from "./uniswapv2/interfaces/IUniswapV2Router01.sol";
import { IUniswapV2Router02 } from "./uniswapv2/interfaces/IUniswapV2Router02.sol";
import { UniswapV2Library } from "./uniswapv2/libraries/UniswapV2Library.sol";
import { UniswapV2OracleLibrary } from "./uniswapv2/libraries/UniswapV2OracleLibrary.sol";

contract Trade is MandateBook {
    using SafeMath for uint;

    IMandateBook IMB = IMandateBook(address(this));
    address router;
    IUniswapV2Factory factory;

    struct Balance {
        uint256 counted; // equivalent balance on every trade
    }

    mapping (uint256 => Balance) public balances; // trader absolute profit

    struct Trade {
        address fromAsset;
        address toAsset;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
    }

    mapping (uint256 => Trade[]) public trades; // used for logging trader activity by agreement

    mapping (uint256 => bool) public agreementClosed;

    uint256 timeFrame = 15 * 60 * 1 seconds;

    uint256 internal exchangeFee = 3; // 0.3 % for uniswap

    mapping (uint256 => uint256) public countedTrades; // agreement id -> counter ticker

    // is was added to counted balance
    mapping(uint => mapping(address => bool)) markedTokens; // agreement id -> mapping

    // by agreement id we store the balances of Assets (on the end of the agreement)
    mapping(uint => mapping(address => uint256)) countedBalance; // agreement id -> mapping

    constructor(address factoryV2, address routerContract) public {
        factory = IUniswapV2Factory(factoryV2);
        router = routerContract;
    }

    // return profit by agreement, depend on first known amount
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint256 agreementId) public view returns (uint256 amount, bool positive) {
        if (_getInitBalance(agreementId) < balances[agreementId].counted) {
            amount = balances[agreementId].counted.sub(_getInitBalance(agreementId));
            positive = true;
        } else {
            amount = _getInitBalance(agreementId).sub(balances[agreementId].counted);
            positive = false;
        }

        return (amount, positive);
    }

    // @dev tokenA, tokenB
    function getPrice(address tokenA, address tokenB) public view returns (uint256 price0Cumulative, uint256 price1Cumulative) {
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(address(factory), tokenA, tokenB));
        (price0Cumulative, price1Cumulative,) = UniswapV2OracleLibrary.currentCumulativePrices(address(_pair));
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

    function getFinalBalance(uint256 agreementId) public view returns (uint) {
        Balance memory _b = balances[agreementId];
        return _b.counted;
    }

    // trades from trader by the agreement
    function countTrades(uint256 agreementId) public view returns (uint) {
        return trades[agreementId].length;
    }

    function getTrade(uint256 agreementId, uint256 index) public view returns (Trade memory) {
        require(index < countTrades(agreementId), "Trade not exist");

        return trades[agreementId][index];
    }

    function getBaseAsset(uint256 agreementId) public view returns (address) {
        return (IMB.getAgreement(agreementId)).baseCoin;
    }

    function swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    )
        public
        canTrade(agreementId, tokenOut)
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

    function _swapTokenToToken(
        uint256 agreementId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    ) internal {
        require(factory.getPair(tokenIn, tokenOut) != address(0), "Pair not exist");

        (uint256 reserve0, uint256 reserve1) = getLiquidity(tokenIn, tokenOut);

        require(reserve0 >= amountIn && reserve1 >= amountOutMin, "Not enough liquidity");

        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        if (deadline == 0) {
            deadline = block.timestamp + timeFrame;
        }

        uint[] memory amounts = IUniswapV2Router01(router).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);

        trades[agreementId].push(Trade({
            fromAsset: tokenIn,
            toAsset: tokenOut,
            amountIn: amountIn,
            amountOut: amounts[amounts.length - 1],
            timestamp: block.timestamp
        }));
    }

    // TODO: should be called once only after active period end
    // @dev sell asset with optimal price by agreement id
    function countPossibleTradesDirection(uint256 agreementId) public {
        Trade memory _t;
        uint l = countTrades(agreementId);
        for (uint i = countedTrades[agreementId]; i < l; i++) {
            _t = trades[agreementId][i];
            if (i == 0) {
                countedBalance[agreementId][_t.fromAsset] = _getInitBalance(agreementId);
            }
            countedBalance[agreementId][_t.fromAsset] -= _t.amountIn;
            countedBalance[agreementId][_t.toAsset] += _t.amountOut;
        }
        countedTrades[agreementId] = l;
    }

    // @dev get optimal amount in base asset, depend on agreement
    function getOutAmount(uint256 agreementId, address asset) public returns (uint amountOut) {
        (uint reserveA, uint reserveB) = getLiquidity(
            (address(0) == asset) ? IUniswapV2Router01(router).WETH() : asset,
            getBaseAsset(agreementId)
        );
        amountOut = IUniswapV2Router02(router).getAmountOut(
            countedBalance[agreementId][address(0)], // amountIn
            reserveA,
            reserveB
        );
    }

    // @dev sell one asset with optimal price by agreement id // should work properly
    function sell(uint256 agreementId, address asset) public {
        _sell(agreementId, asset);
    }

    function _sell(uint256 agreementId, address asset) internal {
        require(!agreementClosed[agreementId], "Agreement was closed");

        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);

        require(
            block.timestamp > uint(_a.duration).add(_a.publishTimestamp) &&
            _a.status != AMandate.AgreementLifeCycle.EXPIRED,
            "Agreement active or closed"
        );

        if (countTrades(agreementId) == 0) {
            balances[agreementId].counted = _getInitBalance(agreementId);
            return;
        }

        uint amountIn;
        uint amountOut;

        require(!markedTokens[agreementId][asset], "Token has been swap yet");

        if (address(0) == asset) {
            amountIn = countedBalance[agreementId][address(0)];
            amountOut = getOutAmount(agreementId, asset);

            swapETHForToken(
                agreementId,
                getBaseAsset(agreementId), // tokenOut,
                amountOut, // amountOut
                amountIn, // amountInMax
                block.timestamp.add(timeFrame) //deadline
            );
        } else {
            amountIn = countedBalance[agreementId][asset];
            amountOut = getOutAmount(agreementId, asset);

            swapTokenToToken(
                agreementId, //uint256 agreementId,
                asset, //address tokenIn,
                getBaseAsset(agreementId), //address tokenOut,
                amountIn, //uint256 amountIn,
                amountOut, //uint256 amountOutMin,
                block.timestamp.add(timeFrame) //uint256 deadline
            );
        }

        balances[agreementId].counted += amountOut;
        markedTokens[agreementId][asset] = true;
    }

    // @dev on agreement end, close all positions
    function sellAll(uint256 agreementId) external {
        require(!agreementClosed[agreementId], "Agreement was closed");

        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);

        require(
            block.timestamp > uint(_a.duration).add(_a.publishTimestamp) &&
            _a.status != AMandate.AgreementLifeCycle.EXPIRED,
            "Agreement active or closed"
        );

        Trade memory _t;

        if (countTrades(agreementId) == 0) {
            balances[agreementId].counted = _getInitBalance(agreementId);
            return;
        }

        countPossibleTradesDirection(agreementId);

        for (uint i = 0; i < countTrades(agreementId); i++) {
            _t = trades[agreementId][i];
            if (!markedTokens[agreementId][_t.toAsset]) {
                _sell(agreementId, deadline);
            }

            markedTokens[agreementId][_t.toAsset] = true;
        }

        agreementClosed[agreementId] = true;
    }

    function _getInitBalance(uint256 agreementId) internal view returns (uint256) {
        return (IMB.getAgreement(agreementId)).__committedCapital;
    }

    modifier canTrade(uint256 agreementId, address outAddress) {
        AMandate.Agreement memory _a = IMB.getAgreement(agreementId);

        require(_a.manager == address(0), "Deal not exist");
        require(_a.manager == msg.sender, "Not manager");

        if (_a.status == AMandate.AgreementLifeCycle.EXPIRED) {
            require(address(0) != outAddress, "You cannot swap to ethereum now");
            require(getBaseAsset(agreementId) == outAddress, "Address should be only in base asset");
            _;
        }

        require(_a.status == AMandate.AgreementLifeCycle.ACTIVE, "Agreement status is not active");
        _;
    }
}