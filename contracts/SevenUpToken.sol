// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;
import "./libraries/SafeMath.sol";
import "./modules/Configable.sol";

contract SevenUpToken is Configable {
    using SafeMath for uint;      
    
    // implementation of ERC20 interfaces.
    string public name = "Seven Up Token";
    string public symbol = "7UP";
    uint8 public decimals = 18;
    uint public totalSupply = 100000 * (1e18);
    
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    
    constructor() public {
        balanceOf[address(this)] = totalSupply;
    }
    
    function initialize() external onlyDeveloper {
        _transfer(address(this), IConfig(config).mint(), 100000 * 1e18);
    }
    
    function _transfer(address from, address to, uint value) internal {
        require(balanceOf[from] >= value, '7UP: INSUFFICIENT_BALANCE');
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (to == address(0)) { // burn
            totalSupply = totalSupply.sub(value);
        }
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        require(allowance[from][msg.sender] >= value, '7UP: INSUFFICIENT_ALLOWANCE');
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }
    
}