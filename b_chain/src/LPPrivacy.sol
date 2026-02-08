//SPDX-License-Identifier:MIT

pragma solidity^0.8.10;

import "@V4-Core/src/interfaces/IHooks.sol";
import "@V4-Core/src/interfaces/IPoolManager.sol";
import {IERC20Minimal} from "@V4-Core/src/interfaces/external/IERC20Minimal.sol";

contract LPPrivacy is IHooks{
    IPoolManager public poolManager;

    uint256 public delay_block;
    uint256 public gracePeriod;

    event queuedIntent(uint256);
    event executedIntent(uint256);

    enum actionType {
            Add, Remove
        };

    struct LiquidityIntent {
        address lp;
        PoolKey poolKey;
        actionType action;
        int24 tickLower; 
        int24 tickUpper;
        int128 liquidityDelta;
        uint256 queueBlock;
        uint256 executeAfterBlock;
        uint256 expiryBlock;
        bool isCancelled;
        bool isExecuted;
    }

    mapping(uint256 => LiquidityIntent ) public intent;
    mapping (uint256 => uint256) intentFee;
    mapping (address => uint256) rewards;

    uint256 intentid = 0;

     function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {

        require( msg.sender == address(poolManager),"You can't proceed");

        LiquidityIntent memory _liquidityIntent ;
       
        _liquidityIntent.lp = sender;
        _liquidityIntent.poolKey = key;
        _liquidityIntent.action = actionType.Add;
        _liquidityIntent.queueBlock = block.number;
        _liquidityIntent.executeAfterBlock = _liquidityIntent.queueBlock + delay_block;
        _liquidityIntent.isExecuted = false;
        _liquidityIntent.expiryBlock = block.number + delay_block + gracePeriod;
        intent[intentid] =  _liquidityIntent;
        intent[intentid].tickLower = params.tickLower;
        intent[intentid].tickUpper = params.tickUpper;
        intent[intentid].liquidityDelta = params.liquidityDelta;
        emit queuedIntent(intentid);
        intentid += 1;
        return this.beforeAddLiquidity.selector;
    }

     function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
         LiquidityIntent memory _liquidityIntent ;
       
        _liquidityIntent.lp = sender;
        _liquidityIntent.poolKey = key;
        _liquidityIntent.action = actionType.Remove;
        _liquidityIntent.queueBlock = block.number;
        _liquidityIntent.executeAfterBlock = _liquidityIntent.queueBlock + delay_block;
        _liquidityIntent.expiryBlock = block.number + delay_block + gracePeriod;
        _liquidityIntent.isExecuted = false;
        intent[intentid] =  _liquidityIntent;
        intent[intentid].tickLower = params.tickLower;
        intent[intentid].tickUpper = params.tickUpper;
        intent[intentid].liquidityDelta = params.liquidityDelta;
        emit queuedIntent(intentid);
        intentid += 1;
        return this.beforeRemoveLiquidity.selector;

    }

    function queueIntentFee(uint256 fees, uint256 intentId) public payable  {
        require(msg.sender == intent[intentId].lp);
        require(msg.value >= fees);
        intentFee[intentId] = fees;

    }

    function executeIntent(uint256 intentId, uint Fees) public {
        require(!intent[id].isCancelled);

        if (intentId >= intentid) {
            revert();
        }
        if (intentFee[intentId] <= 0) {
            revert();
        }
        if (intent[intentId].isExecuted == true) {
            revert();
        }
        uint256 current_block = block.number;
        if(current_block < intent[intentId].executeAfterBlock) {
            revert();
        }

        require(current_block <= intent[intentId].expiryBlock);

        ModifyLiquidityParams tParams;
        int24 tLower = intent[intentId].tickLower;
        int24 tUpper = intent[intentId].tickUpper;
        int128 lDelta = intent[intentId].liquidityDelta;
        tParams.tickLower = tLower;
        tParams.tickUpper = tUpper;
        tParams.liquidityDelta = lDelta;

        if (intent[intentId].action == Add) {
            if (lDelta <= 0) {
                revert();
            }
        }   

        if (intent[intentId].action == Remove) {
            if (lDelta >= 0) {
                revert();
            }
        }

        bytes  hookData;
        hookData = abi.encode(msg.sender, intent[intentId].lp, intentId);

        poolManager.modifyLiquidity(intent[intentId].poolKey, tParams, hookData);
        
    }

     function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {

         require(msg.sender == poolManager);
        (address executerAddress, address LPAddress, uint256 intentId) = abi.decode(hookData,(address, address, uint256));
        LiquidityIntent storage intentt = intent[intentId];

        require(!intentt.isExecuted);
        uint256 fees = intentFee[intentId];
        intentFee[intentId] = 0;
        rewards[executerAddress] += fees;
        intentt[intentId].isExecuted = true;


        address token0 = key.currency0;
        address token1 = key.currency1;

        int256 a0 = delta.amount0();
        int256 a1 = delta.amount1();

        if (a0 < 0) {
            poolManager.settle(token0, LPAddress, -a0); 
        }

        if (a0 > 0) {
           poolManager.take(token0, LPAddress, a0);

        }

        if (a1 < 0) {
            poolManager.settle(token1, LPAddress, -a1);
        }

        if (a1 > 0) {
            poolManager.take(token1, LPAddress, a1);
        }
      
        emit executedIntent(intentId);
        return (this.afterAddLiquidity.selector, delta);
    }

     function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {

         require(msg.sender == poolManager);
        (address executerAddress, address LPAddress, uint256 intentId) = abi.decode(hookData,(address, address, uint256));
        LiquidityIntent storage intentt = intent[intentId];

        require(!intentt.isExecuted);
        uint256 fees = intentFee[intentId];
        intentFee[intentId] = 0;
        rewards[executerAddress] += fees;
        intentt[intentId].isExecuted = true;

        address token0 = key.currency0;
        address token1 = key.currency1;

        int256 a0 = delta.amount0();
        int256 a1 = delta.amount1();

        if (a0 < 0) {
            poolManager.settle(token0, LPAddress, -a0);
        }

        if (a0 > 0) {
            poolManager.take(token0, LPAddress, a0);
        }
        
        if (a1 < 0) {
            poolManager.settle(token1, LPAddress, -a1);
        }

        if (a1 > 0) {
            poolManager.take(token1, LPAddress, a1);
        }
      
        emit executedIntent(intentId);
        return (this.afterRemoveLiquidity.selector,delta);

    }

    function withdraw(uint256 amount, address account) external payable {
        amount = rewards[msg.sender];
        require(amount > 0);
        rewards[msg.sender] = 0;

    }

    function refundAfterExpiry(uint256 id) external payable returns(uint256) {
        require(block.number <= intent[id].expiryBlock);
        require(!intent[id].isExecuted);
        require(!intent[id].isCancelled);
        uint256 fee = intentFee[id];
        intent[id] = 0;
        poolManager.settle(fee);


    }

    function cancelIntent(uint256 id) {
        require(id < intentid);
        require(msg.sender == intent[id].lp);
        require(!intent[id].isExecuted);
        require(!intent[id].isCancelled);
        intent[id].isCancelled = true;

    }

}