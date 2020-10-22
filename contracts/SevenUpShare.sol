// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './modules/Configable.sol';
import './modules/BaseShareField.sol';

contract SevenUpShare is Configable, BaseShareField {
    event ProductivityIncreased (address indexed user, uint value);
    event ProductivityDecreased (address indexed user, uint value);
    event Mint(address indexed user, uint amount);
    
    function initialize() external onlyDeveloper {
        shareToken = IConfig(config).base();
    }
    
    function stake(uint _amount) external {
        TransferHelper.safeTransferFrom(IConfig(config).token(), msg.sender, address(this), _amount);
        _increaseProductivity(msg.sender, _amount);
        emit ProductivityIncreased(msg.sender, _amount);
    }
    
    function withdraw(uint _amount) external {
        _decreaseProductivity(msg.sender, _amount);
        TransferHelper.safeTransfer(IConfig(config).token(), msg.sender, _amount);
        emit ProductivityDecreased(msg.sender, _amount);
    }
    
    function queryReward() external view returns (uint){
        return _takeWithAddress(msg.sender);
    }
    
    function mintReward() external {
        uint amount = _mint(msg.sender);
        emit Mint(msg.sender, amount);
    }
}