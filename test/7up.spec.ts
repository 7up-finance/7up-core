import {expect, use} from 'chai';
import {Contract, ethers, BigNumber} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import SevenUp from '../build/SevenUpPool.json';
import SevenUpConfig from '../build/SevenUpConfig.json';
import SevenUpMint from '../build/SevenUpMint.json';
import SevenUpFactory from '../build/SevenUpFactory.json';
import SevenUpPlatform from '../build/SevenUpPlatform.json';
import SevenUpToken from '../build/SevenUpToken.json';
import SevenUpShare from '../build/SevenUpShare.json';
import ERC20 from '../build/ERC20Token.json';
import { BigNumber as BN } from 'bignumber.js'

use(solidity);

function convertBigNumber(bnAmount: BigNumber, divider: number) {
	return new BN(bnAmount.toString()).dividedBy(new BN(divider)).toFixed();
}

describe('deploy', () => {
	let provider = new MockProvider();
	const [walletMe, walletOther, walletDeveloper, walletTeam, walletSpare] = provider.getWallets();
	let configContract: Contract;
	let factoryContract: Contract;
	let mintContract:  Contract;
	let platformContract: Contract;
	let tokenContract: Contract;
	let shareContract: Contract;
	let masterChef 	: Contract;
	let tokenFIL 	: Contract;
	let tokenUSDT 	: Contract;
	let poolContract: Contract;
	let tx: any;
	let receipt: any;

	async function getBlockNumber() {
		const blockNumber = await provider.getBlockNumber()
		console.log("Current block number: " + blockNumber);
		return blockNumber;
	  }

	before(async () => {
		shareContract = await deployContract(walletDeveloper, SevenUpShare);
		configContract  = await deployContract(walletDeveloper, SevenUpConfig);
		factoryContract  = await deployContract(walletDeveloper, SevenUpFactory);
		mintContract  = await deployContract(walletDeveloper, SevenUpMint);
		platformContract  = await deployContract(walletDeveloper, SevenUpPlatform);
		tokenContract  = await deployContract(walletDeveloper, SevenUpToken);
		tokenUSDT 	= await deployContract(walletOther, ERC20, ['USDT', 'USDT', 18, ethers.utils.parseEther('1000000')]);
		tokenFIL 	= await deployContract(walletMe, ERC20, ['File Coin', 'FIL', 18, ethers.utils.parseEther('1000000')]);

		console.log('configContract = ', configContract.address);
		console.log('factoryContract = ', factoryContract.address);
		console.log('mintContract address = ', mintContract.address);
		console.log('platformContract address = ', platformContract.address);
		console.log('tokenContract address = ', tokenContract.address);
		console.log('tokenFIL address = ', tokenFIL.address);

		console.log('team:', ethers.utils.formatBytes32String("team"))
		console.log('spare:', ethers.utils.formatBytes32String("spare"))
		console.log('pledgePrice:', ethers.utils.formatBytes32String("pledgePrice"))
		
		await configContract.connect(walletDeveloper).initialize(
			platformContract.address, 
			factoryContract.address, 
			mintContract.address, 
			tokenContract.address, 
			tokenFIL.address,
			shareContract.address,
			walletDeveloper.address
		);
		await shareContract.connect(walletDeveloper).setupConfig(configContract.address);
		await factoryContract.connect(walletDeveloper).setupConfig(configContract.address);
		await mintContract.connect(walletDeveloper).setupConfig(configContract.address);
		await platformContract.connect(walletDeveloper).setupConfig(configContract.address);
		await tokenContract.connect(walletDeveloper).setupConfig(configContract.address);

		await configContract.connect(walletDeveloper).initParameter();
		await configContract.connect(walletDeveloper).setWallets([ethers.utils.formatBytes32String("team"), ethers.utils.formatBytes32String("spare")], [walletTeam.address, walletSpare.address]);
		await shareContract.connect(walletDeveloper).initialize();
		await tokenContract.connect(walletDeveloper).initialize();
		await factoryContract.connect(walletDeveloper).createPool(tokenFIL.address, tokenUSDT.address);

		let pool = await factoryContract.connect(walletDeveloper).getPool(tokenFIL.address, tokenUSDT.address);
		poolContract  = new Contract(pool, SevenUp.abi, provider).connect(walletMe);

		await tokenFIL.connect(walletMe).approve(poolContract.address, ethers.utils.parseEther('1000000'));
		await tokenFIL.connect(walletOther).approve(poolContract.address, ethers.utils.parseEther('1000000'));
		await tokenUSDT.connect(walletOther).approve(poolContract.address, ethers.utils.parseEther('1000000'));

		await tokenFIL.connect(walletMe).transfer(walletOther.address, ethers.utils.parseEther('100000'));
	})

	it("simple test", async () => {
		await (await mintContract.connect(walletDeveloper).changeInterestRatePerBlock(ethers.utils.parseEther('2000'))).wait();
		let pool = await factoryContract.connect(walletDeveloper).getPool(tokenFIL.address, tokenUSDT.address);
		await platformContract.connect(walletMe).deposit(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		const poolContract  = new Contract(pool, SevenUp.abi, provider).connect(walletMe);
		console.log(convertBigNumber((await poolContract.supplys(walletMe.address)).amountSupply, 1e18));
		expect(convertBigNumber((await poolContract.supplys(walletMe.address)).amountSupply, 1e18)).to.equals('1000');
		expect(convertBigNumber(await poolContract.remainSupply(), 1e18)).to.equals('1000');
		console.log(convertBigNumber(await mintContract.connect(walletMe).takeLendWithAddress(walletMe.address), 1));
		await platformContract.connect(walletMe).withdraw(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('500'));
		expect(convertBigNumber(await tokenFIL.balanceOf(walletMe.address), 1e18)).to.equals('899500');
		expect(convertBigNumber((await poolContract.supplys(walletMe.address)).amountSupply, 1e18)).to.equals('500');
		expect(convertBigNumber(await poolContract.remainSupply(), 1e18)).to.equals('500');
		console.log(convertBigNumber(await mintContract.connect(walletMe).takeLendWithAddress(walletMe.address), 1));
		await platformContract.connect(walletMe).withdraw(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('500'));
		expect(convertBigNumber(await tokenFIL.balanceOf(walletMe.address), 1e18)).to.equals('900000');
		expect(convertBigNumber((await poolContract.supplys(walletMe.address)).amountSupply, 1e18)).to.equals('0');
		expect(convertBigNumber(await poolContract.remainSupply(), 1e18)).to.equals('0');
		console.log(convertBigNumber(await mintContract.connect(walletMe).takeLendWithAddress(walletMe.address), 1));
		await mintContract.connect(walletMe).mintLender();
		console.log(convertBigNumber(await tokenContract.balanceOf(walletMe.address), 1));
		console.log(convertBigNumber(await tokenContract.balanceOf(walletTeam.address), 1));
		console.log(convertBigNumber(await tokenContract.balanceOf(walletSpare.address), 1));
		console.log(convertBigNumber(await mintContract.connect(walletMe).takeLendWithAddress(walletMe.address), 1));
	})

	async function sevenInfo() {
		let result = {
			interestPerSupply: await poolContract.interestPerSupply(),
			liquidationPerSupply: await poolContract.liquidationPerSupply(),
			interestPerBorrow : await poolContract.interestPerBorrow(),
			totalLiquidation: await poolContract.totalLiquidation(),
			totalLiquidationSupplyAmount: await poolContract.totalLiquidationSupplyAmount(),
			totalBorrow: await poolContract.totalBorrow(),
			totalPledge: await poolContract.totalPledge(),
			remainSupply: await poolContract.remainSupply(),
			lastInterestUpdate: await poolContract.lastInterestUpdate()
		};

		console.log('===sevenInfo begin===');
		for (let k in result) {
			console.log(k+':', convertBigNumber(result[k], 1))
		}
		console.log('===sevenInfo end===')
		return result;
	};

	async function SupplyStruct(user:any) {
		let result = await poolContract.supplys(user);

		console.log('===SupplyStruct begin===');
		for (let k in result) {
			console.log(k+':', convertBigNumber(result[k], 1))
		}
		console.log('===SupplyStruct end===');
		return result;
	};

	async function BorrowStruct(user:any) {
		let result = await poolContract.borrows(user);

		console.log('===BorrowStruct begin===');
		for (let k in result) {
			console.log(k+':', convertBigNumber(result[k], 1))
		}
		console.log('===BorrowStruct end===');
		return result;
	};

	it('deposit(1000) -> borrow(100) -> repay(100) -> withdraw(1000)', async() => {
		await platformContract.connect(walletMe).deposit(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after deposit: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));

		let maxBorrow = await poolContract.getMaximumBorrowAmount(ethers.utils.parseEther('10000'));
		console.log('maxBorrow:', convertBigNumber(maxBorrow, 1));
		await platformContract.connect(walletOther).borrow(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('10000'), maxBorrow);
		console.log('after borrow: ', 
			convertBigNumber(await tokenUSDT.balanceOf(walletOther.address), 1),
			convertBigNumber(await tokenFIL.balanceOf(walletOther.address), 1),
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));

		console.log('getInterests:', convertBigNumber(await poolContract.getInterests(),1));

		tx = await platformContract.connect(walletOther).repay(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('10000'));
		let receipt = await tx.wait()
		console.log('repay gas:', receipt.gasUsed.toString())
		// console.log('events:', receipt.events)
		// console.log(receipt.events[2].event, 'args:', receipt.events[2].args)
		// console.log('_supplyAmount:', convertBigNumber(receipt.events[2].args._supplyAmount, 1))
		// console.log('_collateralAmount:', convertBigNumber(receipt.events[2].args._collateralAmount, 1))
		// console.log('_interestAmount:', convertBigNumber(receipt.events[2].args._interestAmount, 1))

		console.log('after repay: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));

		await SupplyStruct(walletMe.address);
		await sevenInfo();
		await platformContract.connect(walletMe).withdraw(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after withdraw: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
	});

	it('deposit(1000) -> borrow(100) -> liquidation(100) -> withdraw(1000)', async() => {
		await platformContract.connect(walletMe).deposit(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after deposit: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		let maxBorrow = await poolContract.getMaximumBorrowAmount(ethers.utils.parseEther('10000'));
		await platformContract.connect(walletOther).borrow(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('10000'), maxBorrow);
		console.log('after borrow: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		await platformContract.connect(walletDeveloper).updatePoolParameter(
			tokenFIL.address, tokenUSDT.address, ethers.utils.formatBytes32String("pledgePrice"), ethers.utils.parseEther('0.01'));
		await platformContract.connect(walletMe).liquidation(tokenFIL.address, tokenUSDT.address, walletOther.address);
		console.log('after liquidation: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		await SupplyStruct(walletMe.address);
		await sevenInfo();
		await platformContract.connect(walletDeveloper).updatePoolParameter(
			tokenFIL.address, tokenUSDT.address, ethers.utils.formatBytes32String("pledgePrice"), ethers.utils.parseEther('0.02'));
		await platformContract.connect(walletMe).withdraw(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after withdraw: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
	});

	it('deposit(1000) -> borrow(100) -> liquidation(100) -> reinvest() -> withdraw(1000)', async() => {
		await platformContract.connect(walletMe).deposit(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after deposit: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		let maxBorrow = await poolContract.getMaximumBorrowAmount(ethers.utils.parseEther('10000'));
		await platformContract.connect(walletOther).borrow(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('10000'), maxBorrow);
		console.log('after borrow: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		await platformContract.connect(walletDeveloper).updatePoolParameter(
			tokenFIL.address, tokenUSDT.address, ethers.utils.formatBytes32String("pledgePrice"), ethers.utils.parseEther('0.01'));
		await platformContract.connect(walletMe).liquidation(tokenFIL.address, tokenUSDT.address, walletOther.address);
		console.log('after liquidation: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		await SupplyStruct(walletMe.address);
		await platformContract.connect(walletMe).reinvest(tokenFIL.address, tokenUSDT.address);
		await SupplyStruct(walletMe.address);
		await sevenInfo();
		await platformContract.connect(walletDeveloper).updatePoolParameter(
			tokenFIL.address, tokenUSDT.address, ethers.utils.formatBytes32String("pledgePrice"), ethers.utils.parseEther('0.02'));
		await platformContract.connect(walletMe).withdraw(tokenFIL.address, tokenUSDT.address, ethers.utils.parseEther('1000'));
		console.log('after withdraw: ', 
			convertBigNumber(await tokenFIL.balanceOf(poolContract.address), 1), 
			convertBigNumber(await tokenUSDT.balanceOf(poolContract.address), 1));
		await sevenInfo();
	});

})
