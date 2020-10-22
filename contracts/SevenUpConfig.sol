// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

contract SevenUpConfig {
    address public factory;
    address public platform;
    address public developer;
    address public mint;
    address public token;
    address public base;
    address public share;
    address public governor;
    
    mapping (address => mapping (bytes32 => uint)) public poolParams;
    mapping (bytes32 => uint) public params;
    mapping (bytes32 => uint) public wallets;

    event ParameterChange(uint key, uint value);
    
    constructor() public {
        developer = msg.sender;
    }
    
    function initialize (address _platform, address _factory, address _mint, address _token, address _base, address _share, address _governor) external {
        require(msg.sender == developer, "7UP: Config FORBIDDEN");
        mint        = _mint;
        platform    = _platform;
        factory     = _factory;
        token       = _token;
        base        = _base;
        share       = _share;
        governor    = _governor; 
    }

    function changeDeveloper(address _developer) external {
        require(msg.sender == developer, "7UP: Config FORBIDDEN");
        developer = _developer;
    }

    function setWallets(bytes32[] calldata _names, uint[] calldata _wallets) external {
        require(msg.sender == developer, "7UP: ONLY DEVELOPER");
        require(_names.length == _wallets.length ,"7UP: WALLET LENGTH MISMATCH");
        for(uint i = 0; i < _names.length; i ++)
        {
            wallets[_names[i]] = _wallets[i];
        }
    }

    function initParameter() external {
        require(msg.sender == developer, "Config FORBIDDEN");
        params[bytes32("platformShare")] = 100;
        params[bytes32("7upMaxSupply")] = 100000 * 1e18;
        params[bytes32("7upTokenUserMint")] = 5000;
        params[bytes32("7upTokenTeamMint")] = 3000;

        params[bytes32("depositEnable")] = 1;
        params[bytes32("withdrawEnable")] = 1;
        params[bytes32("borrowEnable")] = 1;
        params[bytes32("repayEnable")] = 1;
        params[bytes32("liquidationEnable")] = 1;
        params[bytes32("reinvestEnable")] = 1;
    }

    function setParameter(bytes32[] calldata _keys, uint[] calldata _values) external
    {
        require(msg.sender == governor, "7UP: ONLY DEVELOPER");
        require(_keys.length == _values.length ,"7UP: PARAMS LENGTH MISMATCH");
        for(uint i = 0; i < _keys.length; i ++)
        {
            params[_keys[i]] = _values[i];
        }
    }
    
    function setPoolParameter(address _pool, bytes32 _key, uint _value) external {
        require(msg.sender == governor || msg.sender == _pool || msg.sender == platform, "7UP: FORBIDDEN");
        poolParams[_pool][_key] = _value;
    }
}