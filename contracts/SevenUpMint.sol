// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;
import "./libraries/SafeMath.sol";
import "./libraries/TransferHelper.sol";
import "./modules/Configable.sol";

contract SevenUpMint is Configable {
    using SafeMath for uint;
    
    uint public mintCumulation;
    uint public amountPerBlock;
    uint public lastRewardBlock;
    
    uint public totalLendProductivity;
    uint public totalBorrowProducitivity;
    uint public accAmountPerLend;
    uint public accAmountPerBorrow;
    
    uint public totalBorrowSupply;
    uint public totalLendSupply;
    
    uint public borrowPower = 0;

    bytes32 public MaxSupplyKey = bytes32("7upMaxSupply");
    bytes32 public UserMintKey = bytes32("7upTokenUserMint");
    bytes32 public TeamMintKey = bytes32("7upTokenTeamMint");
    bytes32 public TeamWalletKey = bytes32("team");
    bytes32 public SpareWalletKey = bytes32("spare");
    
    struct UserInfo {
        uint amount;     // How many tokens the user has provided.
        uint rewardDebt; // Reward debt. 
        uint rewardEarn; // Reward earn and not minted
        uint index;
    }
    
    mapping(address => UserInfo) public lenders;
    mapping(address => UserInfo) public borrowers;

    address[] public lenderList;
    address[] public borrowerList;

    uint public numberOfLender;
    uint public numberOfBorrower;

    event BorrowPowerChange (uint oldValue, uint newValue);
    event InterestRatePerBlockChanged (uint oldValue, uint newValue);
    event BorrowerProductivityIncreased (address indexed user, uint value);
    event BorrowerProductivityDecreased (address indexed user, uint value);
    event LenderProductivityIncreased (address indexed user, uint value);
    event LenderProductivityDecreased (address indexed user, uint value);
    event Mint(address indexed user, uint userAmount, uint teamAmount, uint spareAmount);
    
    function changeBorrowPower(uint _value) external onlyGovernor {
        uint old = borrowPower;
        require(_value != old, 'POWER_NO_CHANGE');
        require(_value <= 10000, 'INVALID_POWER_VALUE');
        
        _update();
        borrowPower = _value;
        
        emit BorrowPowerChange(old, _value);
    }
    
    // External function call
    // This function adjust how many token will be produced by each block, eg:
    // changeAmountPerBlock(100)
    // will set the produce rate to 100/block.
    function changeInterestRatePerBlock(uint value) external onlyGovernor returns (bool) {
        uint old = amountPerBlock;
        require(value != old, 'AMOUNT_PER_BLOCK_NO_CHANGE');

        _update();
        amountPerBlock = value;

        emit InterestRatePerBlockChanged(old, value);
        return true;
    }

    // Update reward variables of the given pool to be up-to-date.
    function _update() internal virtual {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 reward = _currentReward();
        if (totalLendProductivity.add(totalBorrowProducitivity) == 0 || reward == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint borrowReward = reward.mul(borrowPower).div(10000);
        uint lendReward = reward.sub(borrowReward);

        if(totalLendProductivity != 0 && lendReward > 0) {
            totalLendSupply = totalLendSupply.add(lendReward);
            accAmountPerLend = accAmountPerLend.add(lendReward.mul(1e12).div(totalLendProductivity));
        }

        if(totalBorrowProducitivity != 0 && borrowReward > 0) {
            totalBorrowSupply = totalBorrowSupply.add(borrowReward);
            accAmountPerBorrow = accAmountPerBorrow.add(borrowReward.mul(1e12).div(totalBorrowProducitivity));
        }
        
        lastRewardBlock = block.number;
    }
    
    function _currentReward() internal virtual view returns (uint){
        uint256 multiplier = block.number.sub(lastRewardBlock);
        uint reward = multiplier.mul(amountPerBlock);
        uint maxSupply = IConfig(config).params(MaxSupplyKey);
        if(totalLendSupply.add(totalBorrowSupply).add(reward) > maxSupply) {
            reward = maxSupply.sub(totalLendSupply).sub(totalBorrowSupply);
        }
        
        return reward;
    }
    
    // Audit borrowers's reward to be up-to-date
    function _auditBorrower(address user) internal {
        UserInfo storage userInfo = borrowers[user];
        if (userInfo.amount > 0) {
            uint pending = userInfo.amount.mul(accAmountPerBorrow).div(1e12).sub(userInfo.rewardDebt);
            userInfo.rewardEarn = userInfo.rewardEarn.add(pending);
            mintCumulation = mintCumulation.add(pending);
            userInfo.rewardDebt = userInfo.amount.mul(accAmountPerBorrow).div(1e12);
        }
    }
    
    // Audit lender's reward to be up-to-date
    function _auditLender(address user) internal {
        UserInfo storage userInfo = lenders[user];
        if (userInfo.amount > 0) {
            uint pending = userInfo.amount.mul(accAmountPerLend).div(1e12).sub(userInfo.rewardDebt);
            userInfo.rewardEarn = userInfo.rewardEarn.add(pending);
            mintCumulation = mintCumulation.add(pending);
            userInfo.rewardDebt = userInfo.amount.mul(accAmountPerLend).div(1e12);
        }
    }

    function increaseBorrowerProductivity(address user, uint value) external onlyPlatform returns (bool) {
        require(value > 0, 'PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO');

        UserInfo storage userInfo = borrowers[user];
        _update();
        _auditBorrower(user);

        if(borrowers[user].index == 0)
        {
            borrowerList.push(user);
            numberOfBorrower++;
            borrowers[user].index = numberOfBorrower;
        }

        totalBorrowProducitivity = totalBorrowProducitivity.add(value);

        userInfo.amount = userInfo.amount.add(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerBorrow).div(1e12);
        emit BorrowerProductivityIncreased(user, value);
        return true;
    }

    function decreaseBorrowerProductivity(address user, uint value) external onlyPlatform returns (bool) {
        require(value > 0, 'INSUFFICIENT_PRODUCTIVITY');
        
        UserInfo storage userInfo = borrowers[user];
        require(userInfo.amount >= value, "FORBIDDEN");
        _update();
        _auditBorrower(user);
        
        userInfo.amount = userInfo.amount.sub(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerBorrow).div(1e12);
        totalBorrowProducitivity = totalBorrowProducitivity.sub(value);

        emit BorrowerProductivityDecreased(user, value);
        return true;
    }
    
    function increaseLenderProductivity(address user, uint value) external onlyPlatform returns (bool) {
        require(value > 0, 'PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO');

        UserInfo storage userInfo = lenders[user];
        _update();
        _auditLender(user);

        if(lenders[user].index == 0)
        {
            lenderList.push(user);
            numberOfLender++;
            lenders[user].index = numberOfLender;
        }

        totalLendProductivity = totalLendProductivity.add(value);

        userInfo.amount = userInfo.amount.add(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerLend).div(1e12);
        emit LenderProductivityIncreased(user, value);
        return true;
    }

    // External function call 
    // This function will decreases user's productivity by value, and updates the global productivity
    // it will record which block this is happenning and accumulates the area of (productivity * time)
    function decreaseLenderProductivity(address user, uint value) external onlyPlatform returns (bool) {
        require(value > 0, 'INSUFFICIENT_PRODUCTIVITY');
        
        UserInfo storage userInfo = lenders[user];
        require(userInfo.amount >= value, "FORBIDDEN");
        _update();
        _auditLender(user);
        
        userInfo.amount = userInfo.amount.sub(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerLend).div(1e12);
        totalLendProductivity = totalLendProductivity.sub(value);

        emit LenderProductivityDecreased(user, value);
        return true;
    }
    
    function takeBorrowWithAddress(address user) public view returns (uint) {
        UserInfo storage userInfo = borrowers[user];
        uint _accAmountPerBorrow = accAmountPerBorrow;
        if (block.number > lastRewardBlock && totalBorrowProducitivity != 0) {
            uint reward = _currentReward();
            uint borrowReward = reward.mul(borrowPower).div(10000);
            
            _accAmountPerBorrow = accAmountPerBorrow.add(borrowReward.mul(1e12).div(totalBorrowProducitivity));
        }

        uint amount = userInfo.amount.mul(_accAmountPerBorrow).div(1e12).sub(userInfo.rewardDebt).add(userInfo.rewardEarn);
        return amount.mul(IConfig(config).params(UserMintKey)).div(10000);
    }
    
    function takeLendWithAddress(address user) public view returns (uint) {
        UserInfo storage userInfo = lenders[user];
        uint _accAmountPerLend = accAmountPerLend;
        if (block.number > lastRewardBlock && totalLendProductivity != 0) {
            uint reward = _currentReward();
            uint lendReward = reward.sub(reward.mul(borrowPower).div(10000)); 
            _accAmountPerLend = accAmountPerLend.add(lendReward.mul(1e12).div(totalLendProductivity));
        }
        uint amount = userInfo.amount.mul(_accAmountPerLend).div(1e12).sub(userInfo.rewardDebt).add(userInfo.rewardEarn);
        return amount.mul(IConfig(config).params(UserMintKey)).div(10000);
    }

    // Returns how much a user could earn plus the giving block number.
    function takeBorrowWithBlock() external view returns (uint, uint) {
        uint earn = takeBorrowWithAddress(msg.sender);
        return (earn, block.number);
    }
    
    function takeLendWithBlock() external view returns (uint, uint) {
        uint earn = takeLendWithAddress(msg.sender);
        return (earn, block.number);
    }

    function takeAll() public view returns (uint) {
        return takeBorrowWithAddress(msg.sender).add(takeLendWithAddress(msg.sender));
    }

    function takeAllWithBlock() external view returns (uint, uint) {
        return (takeAll(), block.number);
    }

    // External function call
    // When user calls this function, it will calculate how many token will mint to user from his productivity * time
    // Also it calculates global token supply from last time the user mint to this time.
    function mintBorrower() external returns (uint) {
        _update();
        _auditBorrower(msg.sender);
        require(borrowers[msg.sender].rewardEarn > 0, "NOTHING TO MINT");
        uint amount = borrowers[msg.sender].rewardEarn;
        _mintDistribution(msg.sender, amount);
        borrowers[msg.sender].rewardEarn = 0;
        return amount;
    }
    
    function mintLender() external returns (uint) {
        _update();
        _auditLender(msg.sender);
        require(lenders[msg.sender].rewardEarn > 0, "NOTHING TO MINT");
        uint amount = lenders[msg.sender].rewardEarn;
        _mintDistribution(msg.sender, amount);
        lenders[msg.sender].rewardEarn = 0;
        return amount;
    }

    function mintAll() external returns (uint) {
        _update();

        _auditBorrower(msg.sender);
        _auditLender(msg.sender);
        uint borrowAmount = borrowers[msg.sender].rewardEarn;
        uint lendAmount = lenders[msg.sender].rewardEarn;
        uint amount = lendAmount.add(borrowAmount);
        require(amount > 0, "NOTHING TO MINT");
        _mintDistribution(msg.sender, amount);
        borrowers[msg.sender].rewardEarn = 0;
        lenders[msg.sender].rewardEarn = 0;

        return amount;
    }

    // Returns how many productivity a user has and global has.
    function getBorrowerProductivity(address user) external view returns (uint, uint) {
        return (borrowers[user].amount, totalBorrowProducitivity);
    }
    
    function getLenderProductivity(address user) external view returns (uint, uint) {
        return (lenders[user].amount, totalLendProductivity);
    }

    // Returns the current gorss product rate.
    function interestsPerBlock() external view returns (uint, uint) {
        return (accAmountPerBorrow, accAmountPerLend);
    }

    function _mintDistribution(address user, uint amount) internal {
        uint userAmount = amount.mul(IConfig(config).params(UserMintKey)).div(10000);
        uint remainAmount = amount.sub(userAmount);
        uint teamAmount = remainAmount.mul(IConfig(config).params(TeamMintKey)).div(10000);
        if(teamAmount > 0) {
            TransferHelper.safeTransfer(IConfig(config).token(), IConfig(config).wallets(TeamWalletKey), teamAmount);
        }
        
        uint spareAmount = remainAmount.sub(teamAmount);
        if(spareAmount > 0) {
            TransferHelper.safeTransfer(IConfig(config).token(), IConfig(config).wallets(SpareWalletKey), spareAmount);
        }
        
        if(userAmount > 0) {
           TransferHelper.safeTransfer(IConfig(config).token(), user, userAmount); 
        }
        emit Mint(user, userAmount, teamAmount, spareAmount);
    }
}