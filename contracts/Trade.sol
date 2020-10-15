pragma solidity ^0.6.6;
/* 
import "./IMandateBook.sol";

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import { IUniswapV2Router01 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

// TODO: define what events we need more
// TODO: define how to be with trade strategies

contract Trade {

    event ExtraStopped(uint _id);

    IMandateBook IMB;
    address router;
    IUniswapV2Factory factory;

    // trader address -> mandate id -> balance
    mapping (address => mapping (uint => uint)) profitTable; // trader absolute profit
    //mapping (address => {}) tradesHistory; // TODO: if required

    //
    constructor(IMandateBook mandateBook, address routerContract, IUniswapV2Factory factoryV2) {
        IMB = mandateBook;
        router = routerContract;
        factory = factoryV2;
    }

    // @dev call this operation before exchange
    function buyWETH(uint _mandateId) public {
        AMandate.Mandate memory _m = IMB.getMandate(_mandateId);
        uint ethBalance = _m.ethers;
        address WETH = IUniswapV2Router01(router).WETH();

        // TODO: add logic
    }

    // @dev call this operation on return exchange
    function sellWETH(uint _mandateId) public {
        AMandate.Mandate memory _m = IMB.getMandate(_mandateId);
        address WETH = IUniswapV2Router01(router).WETH();
        // TODO: add logic
    }

    // buy/sell operation with token a token b
    function swap(
        uint _mandateId,
        address tokenA,
        address tokenB,
        uint amountIn,
        uint amountOutMin,
        uint deadline
    )
        public
        canTrade(_mandateId)
    {
        address tokenIn = tokenA;
        address tokenOut = tokenB;

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, address(router), amountIn);

        // amountOutMin must be retrieved from an oracle of some kind
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        IUniswapV2Router01(router)
            .swapExactTokensForETH(amountIn, amountOutMin, path, msg.sender, block.timestamp);

        // TODO: write exchanges details to tradesHistory, if required
        // TODO: update profit table
    }

    // return profit by mandate, depend on first known price
    // returns absolute value gain or loss (positive is indicator)
    function profitByMandate(uint _mandateId) external returns (uint amount, bool positive) {
        // TODO: add logic
    }

    // @dev investor can extra stop trades by mandate, if the losses are more than acceptable
    function extraStopTrade(uint _mandateId) external onlyInvestor(_mandateId) {
        // TODO: add logic

        emit ExtraStopped(_mandateId);
    }

    function _updateProfite() internal {
        // TODO: add logic
    }

    modifier canTrade(uint _mandateId) {
        AMandate.Mandate memory _m = IMB.getMandate(_mandateId);
        require(_m.manager == address(0), "Deal not exist");
        require(_m.manager == msg.sender, "Not manager");

        // TODO: clarify what values are valid for this operation [ACCEPTED, etc.. ]
        require(_m.status == AMandate.LifeCycle.ACCEPTED, "Not accepted");
        _;
    }

    modifier onlyInvestor(uint _mandateId) {
        AMandate.Mandate memory _m = IMB.getMandate(_mandateId);
        require(_m.investor == msg.sender, "Only deal Investor");
        // TODO: countedLoss to init deposit less or equal to deal defined value
        _;
    }
} */