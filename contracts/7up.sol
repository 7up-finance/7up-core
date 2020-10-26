// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;
import "./interface/IERC20.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";
import "./modules/Configable.sol";

contract SevenUpPool is Configable
{
    using SafeMath for uint;

    address public dev;
    address public factory;
    address public supplyToken;
    address public collateralToken;

    struct SupplyStruct {
        uint amountSupply;
        uint interestSettled;
        uint liquidationSettled;

        uint interests;
        uint liquidation;
    }

    struct BorrowStruct {
        uint index;
        uint amountCollateral;
        uint interestSettled;
        uint amountBorrow;
        uint interests;
    }

    struct LiquidationStruct {
        uint amountCollateral;
        uint liquidationAmount;
        uint timestamp;
    }

    address[] public borrowerList;
    uint public numberBorrowers;

    mapping(address => SupplyStruct) public supplys;
    mapping(address => BorrowStruct) public borrows;
    mapping(address => LiquidationStruct []) public liquidationHistory;
    mapping(address => uint) public liquidationHistoryLength;

    uint public interestPerSupply;
    uint public liquidationPerSupply;
    uint public interestPerBorrow;

    uint public totalLiquidation;
    uint public totalLiquidationSupplyAmount;

    uint public totalBorrow;
    uint public totalPledge;

    uint public remainSupply;

    uint public lastInterestUpdate;

    event Deposit(address indexed _user, uint _amount, uint _collateralAmount);
    event Withdraw(address indexed _user, uint _supplyAmount, uint _collateralAmount, uint _interestAmount);
    event Borrow(address indexed _user, uint _supplyAmount, uint _collateralAmount);
    event Repay(address indexed _user, uint _supplyAmount, uint _collateralAmount, uint _interestAmount);
    event Liquidation(address indexed _liquidator, address indexed _user, uint _supplyAmount, uint _collateralAmount);
    event Reinvest(address indexed _user, uint _reinvestAmount);

    constructor() public 
    {
        factory = msg.sender;
    }

    function init(address _supplyToken,  address _collateralToken) external onlyFactory
    {
        supplyToken = _supplyToken;
        collateralToken = _collateralToken;

        IConfig(config).setPoolParameter(address(this), bytes32("baseInterests"), 2 * 1e17);
        IConfig(config).setPoolParameter(address(this), bytes32("marketFrenzy"), 1 * 1e18);
        IConfig(config).setPoolParameter(address(this), bytes32("pledgeRate"), 6 * 1e17);
        IConfig(config).setPoolParameter(address(this), bytes32("pledgePrice"), 2 * 1e16);
        IConfig(config).setPoolParameter(address(this), bytes32("liquidationRate"), 90 * 1e16);

        lastInterestUpdate = block.number;
    }

    function updateInterests() internal
    {
        uint totalSupply = totalBorrow + remainSupply;
        uint interestPerBlock = getInterests();

        interestPerSupply = interestPerSupply.add(totalSupply == 0 ? 0 : interestPerBlock.mul(block.number - lastInterestUpdate).mul(totalBorrow).div(totalSupply));
        interestPerBorrow = interestPerBorrow.add(interestPerBlock.mul(block.number - lastInterestUpdate));
        lastInterestUpdate = block.number;
    }

    function getInterests() public view returns(uint interestPerBlock)
    {
        uint totalSupply = totalBorrow + remainSupply;
        uint baseInterests = IConfig(config).poolParams(address(this), bytes32("baseInterests"));
        uint marketFrenzy = IConfig(config).poolParams(address(this), bytes32("marketFrenzy"));

        interestPerBlock = totalSupply == 0 ? 0 : baseInterests.add(totalBorrow.mul(marketFrenzy).div(totalSupply)).div(365 * 28800);
    }

    function updateLiquidation(uint _liquidation) internal
    {
        uint totalSupply = totalBorrow + remainSupply;
        liquidationPerSupply = liquidationPerSupply.add(totalSupply == 0 ? 0 : _liquidation.mul(1e18).div(totalSupply));
    }

    function deposit(uint amountDeposit, address from) public onlyPlatform
    {
        require(amountDeposit > 0, "7UP: INVALID AMOUNT");
        TransferHelper.safeTransferFrom(supplyToken, from, address(this), amountDeposit);

        updateInterests();

        uint addLiquidation = liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].liquidationSettled);

        supplys[from].interests = supplys[from].interests.add(interestPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].interestSettled));
        supplys[from].liquidation = supplys[from].liquidation.add(addLiquidation);

        supplys[from].amountSupply = supplys[from].amountSupply.add(amountDeposit);
        remainSupply = remainSupply.add(amountDeposit);

        supplys[from].interestSettled = interestPerSupply.mul(supplys[from].amountSupply).div(1e18);
        supplys[from].liquidationSettled = liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18);
        emit Deposit(from, amountDeposit, addLiquidation);
    }

    function reinvest(address from) public onlyPlatform returns(uint reinvestAmount)
    {
        updateInterests();

        uint addLiquidation = liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].liquidationSettled);

        supplys[from].interests = supplys[from].interests.add(interestPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].interestSettled));
        supplys[from].liquidation = supplys[from].liquidation.add(addLiquidation);

        reinvestAmount = supplys[from].interests;

        uint platformShare = reinvestAmount.mul(IConfig(config).params(bytes32("platformShare"))).div(1e18);
        reinvestAmount = reinvestAmount.sub(platformShare);

        supplys[from].amountSupply = supplys[from].amountSupply.add(reinvestAmount);
        supplys[from].interests = 0;

        supplys[from].interestSettled = supplys[from].amountSupply == 0 ? 0 : interestPerSupply.mul(supplys[from].amountSupply).div(1e18);
        supplys[from].liquidationSettled = supplys[from].amountSupply == 0 ? 0 : liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18);

        distributePlatformShare(platformShare);

        emit Reinvest(from, reinvestAmount);
    }

    function getWithdrawAmount(address from) external view returns (uint withdrawAmount, uint interestAmount, uint liquidationAmount)
    {
        uint totalSupply = totalBorrow + remainSupply;
        uint _interestPerSupply = interestPerSupply.add(totalSupply == 0 ? 0 : getInterests().mul(block.number - lastInterestUpdate).mul(totalBorrow).div(totalSupply));
        uint _totalInterest = supplys[from].interests.add(_interestPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].interestSettled));
        liquidationAmount = supplys[from].liquidation.add(liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].liquidationSettled));

        uint platformShare = _totalInterest.mul(IConfig(config).params(bytes32("platformShare"))).div(1e18);
        interestAmount = _totalInterest.sub(platformShare);

        uint withdrawLiquidationSupplyAmount = totalLiquidation == 0 ? 0 : liquidationAmount.mul(totalLiquidationSupplyAmount).div(totalLiquidation);

        if(withdrawLiquidationSupplyAmount > supplys[from].amountSupply.add(interestAmount))
            withdrawAmount = 0;
        else 
            withdrawAmount = supplys[from].amountSupply.add(interestAmount).sub(withdrawLiquidationSupplyAmount);
    }

    function distributePlatformShare(uint platformShare) internal 
    {
        require(platformShare <= remainSupply, "7UP: NOT ENOUGH PLATFORM SHARE");
        if(platformShare > 0) {
            uint buybackShare = IConfig(config).params(bytes32("buybackShare"));
            uint buybackAmount = platformShare.mul(buybackShare).div(1e18);
            uint dividendAmount = platformShare.sub(buybackAmount);
            if(dividendAmount > 0) TransferHelper.safeTransfer(supplyToken, IConfig(config).share(), dividendAmount);
            if(buybackAmount > 0) TransferHelper.safeTransfer(supplyToken, IConfig(config).wallets(bytes32("team")), buybackAmount);
            remainSupply = remainSupply.sub(platformShare);
        }
    }

    function withdraw(uint amountWithdraw, address from) public onlyPlatform
    {
        require(amountWithdraw > 0, "7UP: INVALID AMOUNT");
        require(amountWithdraw <= supplys[from].amountSupply, "7UP: NOT ENOUGH BALANCE");

        updateInterests();

        uint addLiquidation = liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].liquidationSettled);

        supplys[from].interests = supplys[from].interests.add(interestPerSupply.mul(supplys[from].amountSupply).div(1e18).sub(supplys[from].interestSettled));
        supplys[from].liquidation = supplys[from].liquidation.add(addLiquidation);

        uint withdrawLiquidation = supplys[from].liquidation.mul(amountWithdraw).div(supplys[from].amountSupply);
        uint withdrawInterest = supplys[from].interests.mul(amountWithdraw).div(supplys[from].amountSupply);

        uint platformShare = withdrawInterest.mul(IConfig(config).params(bytes32("platformShare"))).div(1e18);
        uint userShare = withdrawInterest.sub(platformShare);

        distributePlatformShare(platformShare);

        uint withdrawLiquidationSupplyAmount = totalLiquidation == 0 ? 0 : withdrawLiquidation.mul(totalLiquidationSupplyAmount).div(totalLiquidation);
        uint withdrawSupplyAmount = 0;
        if(withdrawLiquidationSupplyAmount < amountWithdraw.add(userShare))
            withdrawSupplyAmount = amountWithdraw.add(userShare).sub(withdrawLiquidationSupplyAmount);
        
        require(withdrawSupplyAmount <= remainSupply, "7UP: NOT ENOUGH POOL BALANCE");
        require(withdrawLiquidation <= totalLiquidation, "7UP: NOT ENOUGH LIQUIDATION");

        remainSupply = remainSupply.sub(withdrawSupplyAmount);
        totalLiquidation = totalLiquidation.sub(withdrawLiquidation);
        totalLiquidationSupplyAmount = totalLiquidationSupplyAmount.sub(withdrawLiquidationSupplyAmount);
        totalPledge = totalPledge.sub(withdrawLiquidation);

        supplys[from].interests = supplys[from].interests.sub(withdrawInterest);
        supplys[from].liquidation = supplys[from].liquidation.sub(withdrawLiquidation);
        supplys[from].amountSupply = supplys[from].amountSupply.sub(amountWithdraw);

        supplys[from].interestSettled = supplys[from].amountSupply == 0 ? 0 : interestPerSupply.mul(supplys[from].amountSupply).div(1e18);
        supplys[from].liquidationSettled = supplys[from].amountSupply == 0 ? 0 : liquidationPerSupply.mul(supplys[from].amountSupply).div(1e18);

        if(withdrawSupplyAmount > 0) TransferHelper.safeTransfer(supplyToken, from, withdrawSupplyAmount); 
        if(withdrawLiquidation > 0) TransferHelper.safeTransfer(collateralToken, from, withdrawLiquidation);

        emit Withdraw(from, withdrawSupplyAmount, withdrawLiquidation, withdrawInterest);
    }

    function getMaximumBorrowAmount(uint amountCollateral) external view returns(uint amountBorrow)
    {
        uint pledgePrice = IConfig(config).poolParams(address(this), bytes32("pledgePrice"));
        uint pledgeRate = IConfig(config).poolParams(address(this), bytes32("pledgeRate"));

        amountBorrow = pledgePrice.mul(amountCollateral).mul(pledgeRate).div(1e36);
    }

    function borrow(uint amountCollateral, uint expectBorrow, address from) public onlyPlatform
    {
        if(amountCollateral > 0) TransferHelper.safeTransferFrom(collateralToken, from, address(this), amountCollateral);

        updateInterests();

        uint pledgePrice = IConfig(config).poolParams(address(this), bytes32("pledgePrice"));
        uint pledgeRate = IConfig(config).poolParams(address(this), bytes32("pledgeRate"));

        uint maximumBorrow = pledgePrice.mul(borrows[from].amountCollateral + amountCollateral).mul(pledgeRate).div(1e36);
        uint repayAmount = getRepayAmount(borrows[from].amountCollateral, from);

        require(repayAmount + expectBorrow <= maximumBorrow, "7UP: EXCEED MAX ALLOWED");
        require(expectBorrow <= remainSupply, "7UP: INVALID BORROW");

        totalBorrow = totalBorrow.add(expectBorrow);
        totalPledge = totalPledge.add(amountCollateral);
        remainSupply = remainSupply.sub(expectBorrow);

        if(borrows[from].index == 0)
        {
            borrowerList.push(from);
            borrows[from].index = borrowerList.length;
            numberBorrowers ++;
        }

        borrows[from].interests = borrows[from].interests.add(interestPerBorrow.mul(borrows[from].amountBorrow).div(1e18).sub(borrows[from].interestSettled));
        borrows[from].amountCollateral = borrows[from].amountCollateral.add(amountCollateral);
        borrows[from].amountBorrow = borrows[from].amountBorrow.add(expectBorrow);
        borrows[from].interestSettled = interestPerBorrow.mul(borrows[from].amountBorrow).div(1e18);

        if(expectBorrow > 0) TransferHelper.safeTransfer(supplyToken, from, expectBorrow);

        emit Borrow(from, expectBorrow, amountCollateral);
    }

    function getRepayAmount(uint amountCollateral, address from) public view returns(uint repayAmount)
    {
        uint _interestPerBorrow = interestPerBorrow.add(getInterests().mul(block.number - lastInterestUpdate));
        uint _totalInterest = borrows[from].interests.add(_interestPerBorrow.mul(borrows[from].amountBorrow).div(1e18).sub(borrows[from].interestSettled));

        uint repayInterest = borrows[from].amountCollateral == 0 ? 0 : _totalInterest.mul(amountCollateral).div(borrows[from].amountCollateral);
        repayAmount = borrows[from].amountCollateral == 0 ? 0 : borrows[from].amountBorrow.mul(amountCollateral).div(borrows[from].amountCollateral).add(repayInterest);
    }

    function repay(uint amountCollateral, address from) public onlyPlatform returns(uint repayAmount, uint repayInterest)
    {
        require(amountCollateral <= borrows[from].amountCollateral, "7UP: NOT ENOUGH COLLATERAL");
        require(amountCollateral > 0, "7UP: INVALID AMOUNT");

        updateInterests();

        borrows[from].interests = borrows[from].interests.add(interestPerBorrow.mul(borrows[from].amountBorrow).div(1e18).sub(borrows[from].interestSettled));

        repayAmount = borrows[from].amountBorrow.mul(amountCollateral).div(borrows[from].amountCollateral);
        repayInterest = borrows[from].interests.mul(amountCollateral).div(borrows[from].amountCollateral);

        totalPledge = totalPledge.sub(amountCollateral);
        totalBorrow = totalBorrow.sub(repayAmount);
        
        borrows[from].amountCollateral = borrows[from].amountCollateral.sub(amountCollateral);
        borrows[from].amountBorrow = borrows[from].amountBorrow.sub(repayAmount);
        borrows[from].interests = borrows[from].interests.sub(repayInterest);
        borrows[from].interestSettled = borrows[from].amountBorrow == 0 ? 0 : interestPerBorrow.mul(borrows[from].amountBorrow).div(1e18);

        remainSupply = remainSupply.add(repayAmount.add(repayInterest));

        TransferHelper.safeTransfer(collateralToken, from, amountCollateral);
        TransferHelper.safeTransferFrom(supplyToken, from, address(this), repayAmount + repayInterest);

        emit Repay(from, repayAmount, amountCollateral, repayInterest);
    }

    function liquidation(address _user, address from) public onlyPlatform returns(uint borrowAmount)
    {
        require(supplys[from].amountSupply > 0, "7UP: ONLY SUPPLIER");

        updateInterests();

        borrows[_user].interests = borrows[_user].interests.add(interestPerBorrow.mul(borrows[_user].amountBorrow).div(1e18).sub(borrows[_user].interestSettled));

        uint liquidationRate = IConfig(config).poolParams(address(this), bytes32("liquidationRate"));
        uint pledgePrice = IConfig(config).poolParams(address(this), bytes32("pledgePrice"));

        uint collateralValue = borrows[_user].amountCollateral.mul(pledgePrice).div(1e18);
        uint expectedRepay = borrows[_user].amountBorrow.add(borrows[_user].interests);

        require(expectedRepay >= collateralValue.mul(liquidationRate).div(1e18), '7UP: NOT LIQUIDABLE');

        updateLiquidation(borrows[_user].amountCollateral);

        totalLiquidation = totalLiquidation.add(borrows[_user].amountCollateral);
        totalLiquidationSupplyAmount = totalLiquidationSupplyAmount.add(expectedRepay);
        totalBorrow = totalBorrow.sub(borrows[_user].amountBorrow);

        borrowAmount = borrows[_user].amountBorrow;

        LiquidationStruct memory liq;
        liq.amountCollateral = borrows[_user].amountCollateral;
        liq.liquidationAmount = expectedRepay;
        liq.timestamp = block.timestamp;
        
        liquidationHistory[_user].push(liq);
        liquidationHistoryLength[_user] ++;
        
        emit Liquidation(from, _user, borrows[_user].amountBorrow, borrows[_user].amountCollateral);

        borrows[_user].amountCollateral = 0;
        borrows[_user].amountBorrow = 0;
        borrows[_user].interests = 0;
        borrows[_user].interestSettled = 0;
    }
}