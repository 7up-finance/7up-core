import {expect, use} from 'chai';
import {Contract, ethers, BigNumber} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import SevenUp from '../build/SevenUpPool.json';
import ERC20 from '../build/ERC20Token.json';
import { BigNumber as BN } from 'bignumber.js'

use(solidity);

function convertBigNumber(bnAmount: BigNumber, divider: number) {
	return new BN(bnAmount.toString()).dividedBy(new BN(divider)).toFixed();
}

// describe('7up-full', () => {
// 	let provider = new MockProvider();
// 	const [walletMe, walletOther, walletPool, newGovernor, walletTeam, walletInit] = provider.getWallets();
// 	let tokenUSDT 	: Contract;
// 	let tokenFIL 	: Contract;

// 	let sevenContract : Contract;
// 	let masterChef 	: Contract;
// 	let tx: any;
// 	let receipt: any;
	

// 	async function getBlockNumber() {
// 		const blockNumber = await provider.getBlockNumber()
// 		console.log("Current block number: " + blockNumber);
// 		return blockNumber;
// 	  }

// 	before(async () => {
// 		sevenContract  = await deployContract(walletMe, SevenUp);
// 		tokenUSDT 	= await deployContract(walletOther, ERC20, ['USDT', 'USDT', 18, ethers.utils.parseEther('1000000')]);
// 		tokenFIL 	= await deployContract(walletMe, ERC20, ['File Coin', 'FIL', 18, ethers.utils.parseEther('1000000')]);
		
// 		await sevenContract.connect(walletMe).init(tokenFIL.address, tokenUSDT.address);
// 		await sevenContract.connect(walletMe).updatePledgeRate(5000); // 60% pledge rate
// 		await sevenContract.connect(walletMe).updatePledgePrice(200); // 0.02 FIL = 1 USDT
// 		await sevenContract.connect(walletMe).updateLiquidationRate(9000); // 90% liquidation rate
		
// 		console.log('walletMe = ', walletMe.address);
// 		console.log('walletOther = ', walletOther.address);
// 		console.log('7up address = ', sevenContract.address);
// 		console.log('USDT address = ', tokenUSDT.address);
// 		console.log('FIL address = ', tokenFIL.address);
// 		await tokenFIL.connect(walletMe).approve(sevenContract.address, ethers.utils.parseEther('1000000'));
// 		await tokenFIL.connect(walletOther).approve(sevenContract.address, ethers.utils.parseEther('1000000'));
// 		await tokenUSDT.connect(walletOther).approve(sevenContract.address, ethers.utils.parseEther('1000000'));

// 		await tokenFIL.connect(walletMe).transfer(walletOther.address, ethers.utils.parseEther('100000'));
// 	});

// 	async function sevenInfo() {
// 		let result = {
// 			interestPerSupply: await sevenContract.interestPerSupply(),
// 			liquidationPerSupply: await sevenContract.liquidationPerSupply(),
// 			interestPerBorrow : await sevenContract.interestPerBorrow(),
// 			totalLiquidation: await sevenContract.totalLiquidation(),
// 			totalLiquidationSupplyAmount: await sevenContract.totalLiquidationSupplyAmount(),
// 			totalBorrow: await sevenContract.totalBorrow(),
// 			totalPledge: await sevenContract.totalPledge(),
// 			remainSupply: await sevenContract.remainSupply(),
// 			pledgeRate: await sevenContract.pledgeRate(),
// 			pledgePrice: await sevenContract.pledgePrice(),
// 			liquidationRate: await sevenContract.liquidationRate(),
// 			baseInterests: await sevenContract.baseInterests(),
// 			marketFrenzy: await sevenContract.marketFrenzy(),
// 			lastInterestUpdate: await sevenContract.lastInterestUpdate()
// 		};

// 		console.log('===sevenInfo begin===');
// 		for (let k in result) {
// 			console.log(k+':', convertBigNumber(result[k], 1))
// 		}
// 		console.log('===sevenInfo end===')
// 		return result;
// 	};

// 	async function SupplyStruct(user:any) {
// 		let result = await sevenContract.supplys(user);

// 		console.log('===SupplyStruct begin===');
// 		for (let k in result) {
// 			console.log(k+':', convertBigNumber(result[k], 1))
// 		}
// 		console.log('===SupplyStruct end===');
// 		return result;
// 	};

// 	async function BorrowStruct(user:any) {
// 		let result = await sevenContract.borrows(user);

// 		console.log('===BorrowStruct begin===');
// 		for (let k in result) {
// 			console.log(k+':', convertBigNumber(result[k], 1))
// 		}
// 		console.log('===BorrowStruct end===');
// 		return result;
// 	};

// 	it('simple deposit & withdraw', async() => {
		
// 		await sevenContract.connect(walletMe).deposit(ethers.utils.parseEther('1000'), walletMe.address);
// 		console.log(convertBigNumber((await sevenContract.supplys(walletMe.address)).amountSupply, 1));
// 		// expect(convertBigNumber((await sevenContract.supplys(walletMe.address)).amountSupply, 1)).to.equals('1000');
// 		// expect(convertBigNumber(await sevenContract.remainSupply(), 1)).to.equals('1000');

// 		await sevenContract.connect(walletMe).withdraw(ethers.utils.parseEther('500'), walletMe.address);
// 		// expect(convertBigNumber(await tokenFIL.balanceOf(walletMe.address), 1)).to.equals('899500');
// 		// expect(convertBigNumber((await sevenContract.supplys(walletMe.address)).amountSupply, 1)).to.equals('500');
// 		// expect(convertBigNumber(await sevenContract.remainSupply(), 1)).to.equals('500');

// 		await sevenContract.connect(walletMe).withdraw(ethers.utils.parseEther('500'), walletMe.address);
// 		// expect(convertBigNumber(await tokenFIL.balanceOf(walletMe.address), 1)).to.equals('900000');
// 		// expect(convertBigNumber((await sevenContract.supplys(walletMe.address)).amountSupply, 1)).to.equals('0');
// 		// expect(convertBigNumber(await sevenContract.remainSupply(), 1)).to.equals('0');
// 	});

// 	it('deposit(1000) -> borrow(100) -> repay(100) -> withdraw(1000)', async() => {
// 		await sevenContract.connect(walletMe).deposit(ethers.utils.parseEther('1000'), walletMe.address);
// 		console.log('after deposit: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));

// 		let maxBorrow = await sevenContract.getMaximumBorrowAmount(ethers.utils.parseEther('10000'));
// 		console.log('maxBorrow:', convertBigNumber(maxBorrow, 1));
// 		await sevenContract.connect(walletOther).borrow(ethers.utils.parseEther('10000'), maxBorrow, walletOther.address);
// 		console.log('after borrow: ', 
// 			convertBigNumber(await tokenUSDT.balanceOf(walletOther.address), 1),
// 			convertBigNumber(await tokenFIL.balanceOf(walletOther.address), 1),
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));

// 		await sevenInfo();
// 		console.log('getInterests:', convertBigNumber(await sevenContract.getInterests(),1));

// 		tx = await sevenContract.connect(walletOther).repay(ethers.utils.parseEther('10000'), walletOther.address);
// 		let receipt = await tx.wait()
// 		console.log('repay gas:', receipt.gasUsed.toString())
// 		// console.log('events:', receipt.events)
// 		// console.log(receipt.events[2].event, 'args:', receipt.events[2].args)
// 		console.log('_supplyAmount:', convertBigNumber(receipt.events[2].args._supplyAmount, 1))
// 		console.log('_collateralAmount:', convertBigNumber(receipt.events[2].args._collateralAmount, 1))
// 		console.log('_interestAmount:', convertBigNumber(receipt.events[2].args._interestAmount, 1))

// 		console.log('after repay: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));
// 			await sevenInfo();
// 		await SupplyStruct(walletMe.address);
// 		console.log('withdraw:', convertBigNumber(ethers.utils.parseEther('1000'),1));
// 		await sevenContract.connect(walletMe).withdraw(ethers.utils.parseEther('1000'), walletMe.address);
// 		console.log('after withdraw: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));
// 	});

// 	it('deposit(1000) -> borrow(100) -> liquidation(100) -> withdraw(1000)', async() => {
// 		await sevenContract.connect(walletMe).deposit(ethers.utils.parseEther('1000'), walletMe.address);
// 		console.log('after deposit: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));

// 		let maxBorrow = await sevenContract.getMaximumBorrowAmount(ethers.utils.parseEther('10000'));
// 		await sevenContract.connect(walletOther).borrow(ethers.utils.parseEther('10000'), maxBorrow, walletOther.address);
// 		console.log('after borrow: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));

// 		await sevenContract.connect(walletMe).updatePledgePrice(100); // 0.01 FIL = 1 USDT
// 		await sevenContract.connect(walletMe).liquidation(walletOther.address, walletMe.address);
// 		console.log('after liquidation: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));

// 		await sevenInfo();
// 		// console.log('getInterests:', convertBigNumber(await sevenContract.getInterests(),1));
// 		await SupplyStruct(walletMe.address);
// 		// console.log('withdraw:', convertBigNumber(ethers.utils.parseEther('1000'),1));
// 		await sevenContract.connect(walletMe).withdraw(ethers.utils.parseEther('1000'),  walletMe.address);
// 		console.log('after withdraw: ', 
// 			convertBigNumber(await tokenFIL.balanceOf(sevenContract.address), 1), 
// 			convertBigNumber(await tokenUSDT.balanceOf(sevenContract.address), 1));
// 			await sevenInfo();
// 	});
// });