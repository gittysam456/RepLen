//SPDX-License-Identifier:MIT

pragma solidity^0.8.10;

import "@V4-Core/src/interfaces/IHooks.sol";
import "@V4-Core/src/interfaces/IPoolManager.sol";

contract LPPrivacy is IHooks{
    IPoolManager public poolManager;

    uint256 public delay_block;

    event queuedIntent(uint256);
    event executedIntent(uint256);

    enum actionType {
            Add, Remove
        };

    struct LiquidityIntent {
        address lp;
        PoolKey poolKey;
        actionType action;
        uint256 queueBlock;
        uint256 executeAfterBlock;
        bool isExecuted;
    }

    mapping(uint256 => LiquidityIntent ) public intent;

    uint256 intentid = 0;

     function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        LiquidityIntent memory _liquidityIntent ;
        PoolKey poolkey = key;
        _liquidityIntent.lp = sender;
        _liquidityIntent.poolKey = poolkey;
        _liquidityIntent.action = actionType.Add;
        _liquidityIntent.queueBlock = block.number;
        _liquidityIntent.executeAfterBlock = _liquidityIntent.queueBlock + delay_block;
        _liquidityIntent.isExecuted = false;
        intent[intentid] =  _liquidityIntent;
        intentid += 1;
        emit queuedIntent(intentid);
        return this.beforeAddLiquidity.selector();
    }

     function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {

    }

    function executeIntent(uint256 intentId) public {
        

    }
}