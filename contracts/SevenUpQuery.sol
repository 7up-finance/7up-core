// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;
pragma experimental ABIEncoderV2;

import "./libraries/SafeMath.sol";

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
}

interface IConfig {
    function developer() external view returns (address);
    function platform() external view returns (address);
    function factory() external view returns (address);
    function mint() external view returns (address);
    function token() external view returns (address);
    function developPercent() external view returns (uint);
    function wallet() external view returns (address);
    function base() external view returns (address);
    function share() external view returns (address);
    function poolParams(address pool, bytes32 key) external view returns (uint);
    function params(bytes32 key) external view returns(uint);
    function setParameter(uint[] calldata _keys, uint[] calldata _values) external;
    function setPoolParameter(address _pool, bytes32 _key, uint _value) external;
}

interface ISevenUpFactory {
    function countPools() external view returns(uint);
    function allPools(uint index) external view returns(address);
    function isPool(address addr) external view returns(bool);
    function getPool(address lend, address collateral) external view returns(address);
}

interface ISevenUpPool {
    function supplyToken() external view returns(address);
    function collateralToken() external view returns(address);
    function totalBorrow() external view returns(uint);
    function totalPledge() external view returns(uint);
    function remainSupply() external view returns(uint);
    function getInterests() external view returns(uint);
    function numberBorrowers() external view returns(uint);
    function borrowerList(uint index) external view returns(address);
    function borrows(address user) external view returns(uint,uint,uint,uint,uint);
    function getRepayAmount(uint amountCollateral, address from) external view returns(uint);
    function liquidationHistory(address user, uint index) external view returns(uint,uint,uint);
    function liquidationHistoryLength(address user) external view returns(uint);
}

interface ISevenUpMint {
    function maxSupply() external view returns(uint);
    function mintCumulation() external view returns(uint);
    function takeLendWithAddress(address user) external view returns (uint);
    function takeBorrowWithAddress(address user) external view returns (uint);
}

interface ISwapPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract SevenUpQuery {
    address public owner;
    address public config;
    using SafeMath for uint;

    struct PoolInfoStruct {
        address pair;
        uint totalBorrow;
        uint totalPledge;
        uint remainSupply;
        uint borrowInterests;
        uint supplyInterests;
        address supplyToken;
        address collateralToken;
        uint8 supplyTokenDecimals;
        uint8 collateralTokenDecimals;
        string supplyTokenSymbol;
        string collateralTokenSymbol;
    }

    struct TokenStruct {
        string name;
        string symbol;
        uint8 decimals;
        uint balance;
        uint totalSupply;
        uint allowance;
    }

    struct MintTokenStruct {
        uint mintCumulation;
        uint maxSupply;
        uint takeBorrow;
        uint takeLend;
    }

    struct BorrowInfo {
        address user;
        uint amountCollateral;
        uint interestSettled;
        uint amountBorrow;
        uint interests;
    }

    struct LiquidationStruct {
        address pool;
        address user;
        uint amountCollateral;
        uint expectedRepay;
        uint liquidationRate;
    }

    struct PoolConfigInfo {
        uint baseInterests;
        uint marketFrenzy;
        uint pledgeRate;
        uint pledgePrice;
        uint liquidationRate;   
    }

    struct UserLiquidationStruct {
        uint amountCollateral;
        uint liquidationAmount;
        uint timestamp;
    }

    constructor() public {
        owner = msg.sender;
    }
    
    function initialize (address _config) external {
        require(msg.sender == owner, "FORBIDDEN");
        config = _config;
    }

    function getPoolInfoByIndex(uint index) public view returns (PoolInfoStruct memory info) {
        uint count = ISevenUpFactory(IConfig(config).factory()).countPools();
        if (index >= count || count == 0) {
            return info;
        }
        address pair = ISevenUpFactory(IConfig(config).factory()).allPools(index);
        return getPoolInfo(pair);
    }

    function getPoolInfoByTokens(address lend, address collateral) public view returns (PoolInfoStruct memory info) {
        address pair = ISevenUpFactory(IConfig(config).factory()).getPool(lend, collateral);
        return getPoolInfo(pair);
    }
    
    function getPoolInfo(address pair) public view returns (PoolInfoStruct memory info) {
        if(!ISevenUpFactory(IConfig(config).factory()).isPool(pair)) {
            return info;
        }
        info.pair = pair;
        info.totalBorrow = ISevenUpPool(pair).totalBorrow();
        info.totalPledge = ISevenUpPool(pair).totalPledge();
        info.remainSupply = ISevenUpPool(pair).remainSupply();
        info.borrowInterests = ISevenUpPool(pair).getInterests();
        info.supplyInterests = info.borrowInterests;
        info.supplyToken = ISevenUpPool(pair).supplyToken();
        info.collateralToken = ISevenUpPool(pair).collateralToken();
        info.supplyTokenDecimals = IERC20(info.supplyToken).decimals();
        info.collateralTokenDecimals = IERC20(info.collateralToken).decimals();
        info.supplyTokenSymbol = IERC20(info.supplyToken).symbol();
        info.collateralTokenSymbol = IERC20(info.collateralToken).symbol();

        if(info.totalBorrow + info.remainSupply > 0) {
            info.supplyInterests = info.borrowInterests * info.totalBorrow / (info.totalBorrow + info.remainSupply);
        }
    }

    function queryPoolList() public view returns (PoolInfoStruct[] memory list) {
        uint count = ISevenUpFactory(IConfig(config).factory()).countPools();
        if(count > 0) {
            list = new PoolInfoStruct[](count);
            for(uint i = 0;i < count;i++) {
                list[i] = getPoolInfoByIndex(i);
            }
        }
    }

    function queryToken(address user, address spender, address token) public view returns (TokenStruct memory info) {
        info.name = IERC20(token).name();
        info.symbol = IERC20(token).symbol();
        info.decimals = IERC20(token).decimals();
        info.balance = IERC20(token).balanceOf(user);
        info.totalSupply = IERC20(token).totalSupply();
        if(spender != user) {
            info.allowance = IERC20(token).allowance(user, spender);
        }
    }

    function queryTokenList(address user, address spender, address[] memory tokens) public view returns (TokenStruct[] memory token_list) {
        uint count = tokens.length;
        if(count > 0) {
            token_list = new TokenStruct[](count);
            for(uint i = 0;i < count;i++) {
                token_list[i] = queryToken(user, spender, tokens[i]);
            }
        }
    }

    function queryMintToken(address user) public view returns (MintTokenStruct memory info) {
        address token = IConfig(config).mint();
        info.mintCumulation = ISevenUpMint(token).mintCumulation();
        info.maxSupply = IConfig(config).params(bytes32("7upMaxSupply"));
        info.takeBorrow = ISevenUpMint(token).takeBorrowWithAddress(user);
        info.takeLend = ISevenUpMint(token).takeLendWithAddress(user);
    }

    function getBorrowInfo(address _pair, address _user) public view returns (BorrowInfo memory info){
        (, uint amountCollateral, uint interestSettled, uint amountBorrow, uint interests) = ISevenUpPool(_pair).borrows(_user);
        info = BorrowInfo(_user, amountCollateral, interestSettled, amountBorrow, interests);
    }

    function iterateBorrowInfo(address _pair, uint _start, uint _end) public view returns (BorrowInfo[] memory list){
        require(_start <= _end && _start >= 0 && _end >= 0, "INVAID_PARAMTERS");
        uint count = ISevenUpPool(_pair).numberBorrowers();
        if (_end > count) _end = count;
        count = _end - _start;
        list = new BorrowInfo[](count);
        uint index = 0;
        for(uint i = _start; i < _end; i++) {
            address user = ISevenUpPool(_pair).borrowerList(i);
            list[index] = getBorrowInfo(_pair, user);
            index++;
        }
    }

    function iterateLiquidationInfo(uint _startPoolIndex, uint _startIndex, uint _countLiquidation) public view returns (
        LiquidationStruct[] memory liquidationList, 
        uint liquidationCount,
        uint poolIndex, 
        uint userIndex)
    {
        require(_countLiquidation < 30, "EXCEEDING MAX ALLOWED");
        liquidationList = new LiquidationStruct[](_countLiquidation);
        uint poolCount = ISevenUpFactory(IConfig(config).factory()).countPools();

        require(_startPoolIndex < poolCount, "INVALID POOL INDEX");

        for(uint i = _startPoolIndex; i < poolCount; i++) {
            address pool = ISevenUpFactory(IConfig(config).factory()).allPools(i);
            uint liquidationRate = IConfig(config).poolParams(pool, bytes32("liquidationRate"));
            uint pledgePrice = IConfig(config).poolParams(pool, bytes32("pledgePrice"));
            uint borrowsCount = ISevenUpPool(pool).numberBorrowers();
            require(_startIndex < borrowsCount, "INVALID START INDEX");
            poolIndex = i;

            for(uint j = _startIndex; j < borrowsCount; j ++)
            {
                address user = ISevenUpPool(pool).borrowerList(j);
                (, uint amountCollateral, , , ) = ISevenUpPool(pool).borrows(user);
                uint repayAmount = ISevenUpPool(pool).getRepayAmount(amountCollateral, user);
                userIndex = j + 1;

                if(repayAmount > amountCollateral.mul(pledgePrice).div(1e18).mul(liquidationRate).div(1e18))
                {
                    liquidationList[liquidationCount].user             = user;
                    liquidationList[liquidationCount].pool             = pool;
                    liquidationList[liquidationCount].amountCollateral = amountCollateral;
                    liquidationList[liquidationCount].expectedRepay    = repayAmount;
                    liquidationList[liquidationCount].liquidationRate  = liquidationRate;

                    liquidationCount ++;
                    if(liquidationCount == _countLiquidation)
                    {
                        return (liquidationList, liquidationCount, poolIndex, userIndex);
                    }
                }
            }
        }
    }

    function iteratePairLiquidationInfo(address _pair, uint _start, uint _end) public view returns (
        LiquidationStruct[] memory list)
    {
        require(_start <= _end && _start >= 0 && _end >= 0, "INVAID_PARAMTERS");
        uint count = ISevenUpPool(_pair).numberBorrowers();
        if (_end > count) _end = count;
        count = _end - _start;
        uint index = 0;
        uint liquidationRate = IConfig(config).poolParams(_pair, bytes32("liquidationRate"));
        uint pledgePrice = IConfig(config).poolParams(_pair, bytes32("pledgePrice"));
        for(uint i = _start; i < _end; i++) {
            address user = ISevenUpPool(_pair).borrowerList(i);
            (, uint amountCollateral, , , ) = ISevenUpPool(_pair).borrows(user);
            uint repayAmount = ISevenUpPool(_pair).getRepayAmount(amountCollateral, user);
            if(repayAmount > amountCollateral.mul(pledgePrice).div(1e18).mul(liquidationRate).div(1e18))
            {
                index++;
            }
        }
        list = new LiquidationStruct[](index);
        index = 0;
        for(uint i = _start; i < _end; i++) {
            address user = ISevenUpPool(_pair).borrowerList(i);
            (, uint amountCollateral, , , ) = ISevenUpPool(_pair).borrows(user);
            uint repayAmount = ISevenUpPool(_pair).getRepayAmount(amountCollateral, user);
            if(repayAmount > amountCollateral.mul(pledgePrice).div(1e18).mul(liquidationRate).div(1e18))
            {
                list[index].user             = user;
                list[index].pool             = _pair;
                list[index].amountCollateral = amountCollateral;
                list[index].expectedRepay    = repayAmount;
                list[index].liquidationRate  = liquidationRate;
                index++;
            }
        }
    }

    function getPoolConf(address _pair) public view returns (PoolConfigInfo memory info) {
        info.baseInterests = IConfig(config).poolParams(_pair, bytes32("baseInterests"));
        info.marketFrenzy = IConfig(config).poolParams(_pair, bytes32("marketFrenzy"));
        info.pledgeRate = IConfig(config).poolParams(_pair, bytes32("pledgeRate"));
        info.pledgePrice = IConfig(config).poolParams(_pair, bytes32("pledgePrice"));
        info.liquidationRate = IConfig(config).poolParams(_pair, bytes32("liquidationRate"));
    }

    function queryUserLiquidationList(address _pair, address _user) public view returns (UserLiquidationStruct[] memory list) {
        uint count = ISevenUpPool(_pair).liquidationHistoryLength(_user);
        if(count > 0) {
            list = new UserLiquidationStruct[](count);
            for(uint i = 0;i < count; i++) {
                (uint amountCollateral, uint liquidationAmount, uint timestamp) = ISevenUpPool(_pair).liquidationHistory(_user, i);
                list[i] = UserLiquidationStruct(amountCollateral, liquidationAmount, timestamp);
            }
        }
    }

    function getSwapPairReserve(address _pair) public view returns (address token0, address token1, uint8 decimals0, uint8 decimals1, uint reserve0, uint reserve1) {
        token0 = ISwapPair(_pair).token0();
        token1 = ISwapPair(_pair).token1();
        decimals0 = IERC20(token0).decimals();
        decimals1 = IERC20(token1).decimals();
        (reserve0, reserve1, ) = ISwapPair(_pair).getReserves();
    }
}