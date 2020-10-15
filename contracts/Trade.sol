pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "./IMandateBook.sol";
import "./MandateBook.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import { IUniswapV2Router01 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

// TODO: define what events we need more
// TODO: define how to be with trade strategies
// TODO: swap ERC20->ETH, ETH->ERC20, ERC20<->ERC20

contract Trade is MandateBook {
    using SafeMath for uint;

    // @dev event triggered on investor
    event ExtraStopped(uint _id);

    IMandateBook IMB = IMandateBook(address(this));
    address router;
    IUniswapV2Factory factory;

    // count balance in base asset
    //mapping ();
    struct Balance {
        uint init; // on start
        uint counted; // equivalent balance on every trade
    }

    mapping (uint => Balance) public balances; // trader absolute profit

    struct Trade {
        address fromAsset;
        address toAsset;
        uint amountIn;
        uint amountOut;
    }

    mapping (uint => Trade[]) public trades; // used for logging trader activity by agreement

    constructor(address routerContract, IUniswapV2Factory factoryV2) public {
        router = routerContract;
        factory = factoryV2;
    }

    // @dev swap any ERC20 token to any ERC20 token
    function swapTokenToToken(
        uint _agreementId,
        address tokenA,
        address tokenB,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    )
        public
        canTrade(_agreementId)
    {
        // TODO: check exchange direction (liquidity, existence)

        address tokenIn = tokenA;
        address tokenOut = tokenB;

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IUniswapV2Router01(router).swapExactTokensForTokens(amountIn, amountOutMin, path, msg.sender, block.timestamp);

        trades[_agreementId].push(Trade({
            fromAsset: tokenIn,
            toAsset: tokenOut,
            amountIn: amountIn,
            amountOut: amountOutMin
        }));

        // TODO: update profit table
    }

    // @dev sell ERC20 token for ETH
    function swapTokenForETH(
        uint _agreementId,
        address tokenIn,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    )
        public
        canTrade(_agreementId)
    {
        // TODO: check exchange direction (liquidity, existence)

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = IUniswapV2Router01(router).WETH();
        IUniswapV2Router01(router).swapExactTokensForETH(amountIn, amountOutMin, path, msg.sender, block.timestamp);

        trades[_agreementId].push(Trade({
            fromAsset: tokenIn,
            toAsset: address(0), // address 0x0 becouse receive the ether
            amountIn: amountIn,
            amountOut: amountOutMin
        }));

        // TODO: update profit table
    }

    // @dev buy ERC20 token for ETH
    function swapETHForToken(
        uint _agreementId,
        address tokenOut,
        uint amountOut,
        uint amountInMax,
        uint deadline
    )
        public
        payable
        canTrade(_agreementId)
    {
        // TODO: check exchange direction (liquidity, existence)

        require(amountInMax >= msg.value, "Ethers not enough");

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router01(router).WETH();
        path[1] = tokenOut;

        IUniswapV2Router01(router).swapETHForExactTokens(amountOut, path, msg.sender, block.timestamp);

        trades[_agreementId].push(Trade({
            fromAsset: address(0), // address 0x0 becouse sent the ether
            toAsset: tokenOut,
            amountIn: amountInMax,
            amountOut: amountOut
        }));

        // TODO: update profit table
    }

    // return profit by mandate, depend on first known price
    // returns absolute value gain or loss (positive is indicator)
    function countProfit(uint _agreementId) external returns (uint amount, bool positive) {
        if (balances[_agreementId].init <= balances[_agreementId].counted) {
            amount = balances[_agreementId].counted.sub(balances[_agreementId].init);
            positive = true;
        } else {
            amount = balances[_agreementId].init.sub(balances[_agreementId].counted);
            positive = false;
        }

        return (amount, positive);
    }

    // @dev investor can extra stop trades by mandate, if the losses are more than acceptable
    function extraStopTrade(uint _agreementId) 
        external
        onlyMandateInvestor(_agreementId)
        resolveExtraStop(_agreementId) 
    {
        AMandate.Agreement memory _a = IMB.getAgreement(_agreementId);
        _a.extraStopped = true;
        _agreements[_agreementId] = _a;

        emit ExtraStopped(_agreementId);
    }

    function _updateProfite() internal {
        // TODO: add logic
        // formula: get actual price to the base asset,
        // balances[_agreementId].counted = ;
    }

    function getPrice(address token, address baseToken) public returns(uint) {
        // TODO: add logic
    }

    modifier canTrade(uint _agreementId) {
        AMandate.Agreement memory _a = IMB.getAgreement(_agreementId);
        require(_a.manager == address(0), "Deal not exist");
        require(_a.manager == msg.sender, "Not manager");
        require(!_a.extraStopped, "Not manager");

        // TODO: clarify what values are valid for this operation [ACCEPTED, etc.. ]
        //require(_a.status == AMandate.AgreementLifeCycle.ACTIVE, "Not accepted");
        _;
    }

    modifier resolveExtraStop(uint _agreementId) {
        // TODO: add logic
        _;
    }
}