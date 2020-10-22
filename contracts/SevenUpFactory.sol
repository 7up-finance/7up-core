// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

import "./7up.sol";
import "./modules/Configable.sol";

interface ISevenUpPool {
    function init(address _supplyToken,  address _collateralToken) external;
    function setupConfig(address config) external;
}


contract SevenUpFactory is Configable{
    event PoolCreated(address indexed lendToken, address indexed collateralToken, address pool);
    
    address[] public allPools;
    mapping(address => bool) public isPool;
    mapping (address => mapping (address => address)) public getPool;
    
    function createPool(address _lendToken, address _collateralToken) onlyDeveloper external returns (address pool) {
        require(getPool[_lendToken][_collateralToken] == address(0), "ALREADY CREATED");
        
        bytes memory bytecode = type(SevenUpPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_lendToken, _collateralToken));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        getPool[_lendToken][_collateralToken] = pool;
            
        allPools.push(pool);
        isPool[pool] = true;
        ISevenUpPool(pool).setupConfig(config);
        ISevenUpPool(pool).init(_lendToken, _collateralToken);
        
        emit PoolCreated(_lendToken, _collateralToken, pool);
    }

    function countPools() external view returns(uint) {
        return allPools.length;
    }
}