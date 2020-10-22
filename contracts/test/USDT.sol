// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

import './ERC20Token.sol';

contract USDT is ERC20Token {
    address owner;

    constructor() ERC20Token("USDT", "USDT", 6, 1000000000000000) public {
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    function swap() payable external returns (uint) {
        balanceOf[msg.sender] += msg.value * 1000 * 10**6 / 10**18;
        totalSupply += balanceOf[msg.sender];
        return balanceOf[msg.sender];
    }
    
    function withdraw() external returns (uint) {
        (bool success,) = owner.call{value:address(this).balance}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }
}
