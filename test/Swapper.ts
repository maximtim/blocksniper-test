import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { IERC20, Swapper } from "../typechain-types";

describe("Swapper", function () {
  let swapper : Swapper;
  let BSCUSD : IERC20;

  const pancakeFactory = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73';
  const WETH = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';
  const BSCUSDaddr = '0x55d398326f99059fF775485246999027B3197955';

  beforeEach(async () => {
    const swapperFactory = await ethers.getContractFactory("Swapper");
    swapper = await swapperFactory.deploy(pancakeFactory, WETH);
    await swapper.waitForDeployment();

    BSCUSD = await ethers.getContractAt("IERC20", BSCUSDaddr);
  })

  it("swaps", async () => {
    const [signer] = await ethers.getSigners();

    const amountOut = ethers.parseEther('1000');
    const amountIn = await swapper.getTask1AmountIn(amountOut, BSCUSDaddr);

    const tx = swapper.task1Swap(
      amountOut,
      BSCUSDaddr,
      signer.address,
      (await time.latest()) + 1000,
      { value: amountIn });

    await expect(tx).to.changeEtherBalance(signer, -amountIn);
    await expect(tx).to.changeTokenBalance(BSCUSD, signer, amountOut);
  })

  it("swaps and adds liquidity", async () => {
    const [signer] = await ethers.getSigners();

    const amountOut = ethers.parseEther('1000');
    const [amountInSwap, amountInAddLiquidity] = await swapper.getTask2AmountsIn(amountOut, BSCUSDaddr);
    const totalAmountIn = amountInSwap + amountInAddLiquidity;

    const tx = swapper.task2SwapAndAddLiquidity(
      amountOut,
      BSCUSDaddr,
      signer.address,
      (await time.latest()) + 1000,
      { value: totalAmountIn });

    const pair = await ethers.getContractAt("IPancakePair", await swapper.pairFor(pancakeFactory, BSCUSDaddr, WETH));

    await expect(tx).to.changeEtherBalance(signer, -totalAmountIn);
    await expect(tx).to.emit(pair, "Mint").withArgs(await swapper.getAddress(), amountOut, amountInAddLiquidity);
    await expect(tx).to.emit(pair, "Transfer");
  })
});
