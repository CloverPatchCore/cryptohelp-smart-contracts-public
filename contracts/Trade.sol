pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import "./MandateBook.sol";

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Trade is MandateBook, ITrade {
    using SafeMath for uint;

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
    mapping(uint => mapping(address => bool)) tokenSold; // agreement id -> mapping

    // by agreement id we store the balances of Assets (on the end of the agreement)
    mapping(uint => mapping(address => uint256)) countedBalance; // agreement id -> mapping

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

    function agreementClosed(uint agreementId) external override view returns (bool) {
        return _agreementClosed[agreementId];
    }

    function balances(uint256 agreementId) external override view returns (uint256 counted) {
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
        if (_getInitBalance(agreementId) < _balances[agreementId].counted) {
            amount = _balances[agreementId].counted.sub(_getInitBalance(agreementId));
            positive = true;
        } else {
            amount = _getInitBalance(agreementId).sub(_balances[agreementId].counted);
            positive = false;
        }

        return (amount, positive);
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
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1,) = _pair.getReserves();

        return (reserve0, reserve1);
    }

    function getFinalBalance(uint256 agreementId) public override view returns (uint) {
        Balance memory _b = _balances[agreementId];
        return _b.counted;
    }

    // trades from trader by the agreement
    function countTrades(uint256 agreementId) public override view returns (uint) {
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

    // @dev sell asset with optimal price by agreement id
    // @dev should be called before "sell", "sellAll"
    function countPossibleTradesDirection(uint256 agreementId)
    public
    onlyAfterActivePeriod(agreementId)
    {
        require(countedTrades[agreementId] == 0, "Trades calculated");

        TradeLog memory _t;
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
    function getOutAmount(uint256 agreementId, address asset) public view returns (uint amountOut) {
        (uint reserveA, uint reserveB) = getLiquidity(
            (address(0) == asset) ? _router.WETH() : asset,
            getBaseAsset(agreementId)
        );
        amountOut = _router.getAmountOut(
            countedBalance[agreementId][address(0)], // amountIn
            reserveA,
            reserveB
        );
    }

    // @dev sell one asset with optimal price by agreement id // should work properly
    function sell(uint256 agreementId, address asset) public onlyAfterActivePeriod(agreementId) {
        require(!_agreementClosed[agreementId], "Agreement was closed");
        require(countedTrades[agreementId] == countTrades(agreementId), "Trades not calculated");

        if (countTrades(agreementId) == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            _agreementClosed[agreementId] = true;
            return;
        }

        uint counterToClose;

        TradeLog memory _t;
        for (uint i = 0; i < countTrades(agreementId); i++) {
            _t = trades[agreementId][i];
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
        require(!_agreementClosed[agreementId], "Agreement was closed");

        uint256 openTradesCount = countTrades(agreementId);

        require(countedTrades[agreementId] == openTradesCount, "Trades not calculated");

        AMandate.Agreement memory _a = _IMB.getAgreement(agreementId);

        TradeLog memory _t;

        if (openTradesCount == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            _agreementClosed[agreementId] = true;

            return;
        }

        for (uint i = 0; i < openTradesCount; i++) {
            _t = trades[agreementId][i];
            if (!tokenSold[agreementId][_t.toAsset]) {
                _sell(agreementId, _t.toAsset);
            }
        }

        _agreementClosed[agreementId] = true;
    }

    function _getInitBalance(uint256 agreementId) internal view returns (uint256) {
        return (_IMB.getAgreement(agreementId)).__committedCapital;
    }

    function _sell(uint256 agreementId, address asset) internal {
        require(!_agreementClosed[agreementId], "Agreement was closed");

        AMandate.Agreement memory _a = _IMB.getAgreement(agreementId);

        require(
            block.timestamp > uint(_a.activePeriod).add(_a.publishTimestamp) &&
            _a.status != AMandate.AgreementLifeCycle.EXPIRED,
            "Agreement active or closed"
        );

        if (countTrades(agreementId) == 0) {
            _balances[agreementId].counted = _getInitBalance(agreementId);
            return;
        }

        uint amountIn;
        uint amountOut;

        require(!tokenSold[agreementId][asset], "Token has been swap yet");

        amountIn = countedBalance[agreementId][asset];
        amountOut = getOutAmount(agreementId, asset);

        uint256[] memory amounts = _swapTokenToToken(
            agreementId,
            asset,
            getBaseAsset(agreementId),
            amountIn,
            amountOut,
            block.timestamp.add(timeFrame)
        );

        _balances[agreementId].counted += amounts[amounts.length - 1];
        tokenSold[agreementId][asset] = true;
    }

    function getPair( address tokenIn, address tokenOut) public view returns (address fromFactory, address fromLib) {
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
        IUniswapV2Pair pair = IUniswapV2Pair(_factory.getPair(tokenIn, tokenOut));
        require(address(pair) != address(0), "Pair not exist");

        (uint256 reserve0, uint256 reserve1) = getLiquidity(tokenIn, tokenOut);

        require(reserve0 >= amountIn && reserve1 >= amountOut, "Not enough liquidity");

        TransferHelper.safeApprove(tokenIn, address(_router), amountIn);
        TransferHelper.safeApprove(tokenIn, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(pair), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        if (deadline == 0) {
            deadline = block.timestamp + timeFrame;
        }

        amounts = new uint256[](1);

        amounts[0] = 0;

        TransferHelper.safeTransferFrom(
            path[0], address(this), address(pair), amountIn
        );

        amounts = _router.swapExactTokensForTokens(amountIn, amountOut, path, address(this), deadline);

        trades[agreementId].push(
            TradeLog({
                fromAsset: tokenIn,
                toAsset: tokenOut,
                amountIn: amounts[0],
                amountOut: amounts[amounts.length - 1],
                timestamp: block.timestamp
            })
        );

        emit Traded(
            agreementId,
            tokenIn,
            tokenOut,
            amounts[0],
            amounts[amounts.length - 1],
            block.timestamp
        );
    }

    modifier canTrade(uint256 agreementId, address outAddress) {
        AMandate.Agreement memory _a = _IMB.getAgreement(agreementId);

        require(_a.manager == msg.sender, "Not manager");
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
