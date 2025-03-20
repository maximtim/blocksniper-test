// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import './interfaces/IPancakePair.sol';
import './interfaces/IWETH.sol';

contract Swapper {
    address public immutable factory;
    address public immutable WETH;

    using TransferHelper for address;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor (address factory_, address WETH_) {
        factory = factory_;
        WETH = WETH_;
    }

    function task1Swap(uint256 amountOut, address tokenOut, address to, uint deadline)
        public
        payable
        ensure(deadline)
        returns (uint256 amountIn) 
    {
        address pair; bool reversed;
        (pair, amountIn,,, reversed) = _getData(amountOut, tokenOut);

        require(amountIn <= msg.value, 'Not enough input');

        IWETH(WETH).deposit{value: amountIn}();
        WETH.safeTransfer(pair, amountIn);

        (uint256 amount0, uint256 amount1) = reversed ? (amountOut, uint256(0)) : (uint256(0), amountOut);

        IPancakePair(pair).swap(amount0, amount1, to, new bytes(0));

        if (msg.value > amountIn) TransferHelper.safeTransferETH(msg.sender, msg.value - amountIn); // refund dust eth, if any
    }

    function task2SwapAndAddLiquidity(uint256 amountOut, address tokenOut, address to, uint deadline)
        external
        payable
        ensure(deadline)
        returns (uint256 amountInSwap, uint256 amountInAddLiquidity, uint256 liquidity) 
    {
        address pair;
        bool reversed;
        {
            uint256 reserveIn; uint256 reserveOut;
            (pair, amountInSwap, reserveIn, reserveOut, reversed) = _getData(amountOut, tokenOut);
            amountInAddLiquidity = quote(amountOut, reserveOut - amountOut, reserveIn + amountInSwap);
        }
        uint256 totalAmount = amountInSwap + amountInAddLiquidity;

        require(totalAmount <= msg.value, 'Not enough input');
        IWETH(WETH).deposit{value: totalAmount}();

        WETH.safeTransfer(pair, amountInSwap);
        (uint256 amount0, uint256 amount1) = reversed ? (amountOut, uint256(0)) : (uint256(0), amountOut);
        IPancakePair(pair).swap(amount0, amount1, address(this), new bytes(0));

        WETH.safeTransfer(pair, amountInAddLiquidity);
        tokenOut.safeTransfer(pair, amountOut);
        liquidity = IPancakePair(pair).mint(to);

        if (msg.value > totalAmount) TransferHelper.safeTransferETH(msg.sender, msg.value - totalAmount); // refund dust eth, if any
    }

    function getTask2AmountsIn(uint256 amountOut, address tokenOut)
        public
        view
        returns (uint256, uint256)
    {
        (, uint256 amountInSwap, uint256 reserveIn, uint256 reserveOut,) = _getData(amountOut, tokenOut);
        uint256 amountInAddLiquidity = quote(amountOut, reserveOut - amountOut, reserveIn + amountInSwap);
        return (amountInSwap, amountInAddLiquidity);
    }

    function getTask1AmountIn(uint256 amountOut, address tokenOut)
        public
        view
        returns (uint256 amountIn)
    {
        (, amountIn,,,) = _getData(amountOut, tokenOut);
    }

    function _getData(uint256 amountOut, address tokenOut)
        internal
        view
        returns (address pair, uint256 amountIn, uint256 reserveIn, uint256 reserveOut, bool reversed) 
    {
        address token0; address token1;
        (token0, token1, reversed) = sortTokens(WETH, tokenOut);
        pair = pairFor(factory, token0, token1);
        
        (uint256 reserve0, uint256 reserve1,) = IPancakePair(pair).getReserves();
        (reserveIn, reserveOut) = reversed ? (reserve1, reserve0) : (reserve0, reserve1);
        amountIn = getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "PancakeLibrary: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "PancakeLibrary: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "PancakeLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "PancakeLibrary: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * (amountOut) * (10000);
        uint256 denominator = (reserveOut - (amountOut)) * (9975);
        amountIn = (numerator / denominator) + (1);
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1, bool reversed) {
        require(tokenA != tokenB, "PancakeLibrary: IDENTICAL_ADDRESSES");
        (token0, token1, reversed) = tokenA < tokenB ? (tokenA, tokenB, false) : (tokenB, tokenA, true);
        require(token0 != address(0), "PancakeLibrary: ZERO_ADDRESS");
    }

    function pairFor(
        address factory_,
        address tokenA,
        address tokenB
    ) public pure returns (address pair) {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory_,
                            keccak256(abi.encodePacked(tokenA, tokenB)),
                            hex"00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5" // init code hash
                        )
                    )
            ))
        );
    }
}
