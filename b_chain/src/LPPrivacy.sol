//SPDX-License-Identifier:MIT

pragma solidity ^0.8.10;

import "@V4-Core/src/interfaces/IHooks.sol";
import "@V4-Core/src/interfaces/IPoolManager.sol";
import "@V4-Core/src/libraries/Hooks.sol";

contract LPPrivacy is IHooks {
    IPoolManager public poolManager;

    uint256 public delay_block;
    uint256 public gracePeriod;

    constructor(IPoolManager manager, uint256 delay, uint256 grace) {
        require(address(manager) != address(0), "Bad manager");
        require(delay > 0, "Bad delay");
        require(grace > 0, "Bad grace period");

        poolManager = manager;
        delay_block = delay;
        gracePeriod = grace;
    }

    bool private locked;

    event queuedIntent(uint256);
    event executedIntent(uint256);

    enum actionType {
        Add,
        Remove
    }

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

    mapping(uint256 => LiquidityIntent) public intent;
    mapping(uint256 => uint256) intentFee;
    mapping(address => uint256) rewards;

    uint256 intentid = 0;

    modifier nonReentrant() {
        require(!locked, "Reentrancy blocked");
        locked = true;
        _;
        locked = false;
    }

    modifier validIntent(uint256 intentId) {
        require(intentId < intentid, "Invalid intent");
        _;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        require(msg.sender == address(poolManager), "You can't proceed");

        LiquidityIntent memory _liquidityIntent;

        _liquidityIntent.lp = sender;
        _liquidityIntent.poolKey = key;
        _liquidityIntent.action = actionType.Add;
        _liquidityIntent.queueBlock = block.number;
        _liquidityIntent.executeAfterBlock =
            _liquidityIntent.queueBlock +
            delay_block;
        _liquidityIntent.isExecuted = false;
        _liquidityIntent.expiryBlock = block.number + delay_block + gracePeriod;
        intent[intentid] = _liquidityIntent;
        intent[intentid].tickLower = params.tickLower;
        intent[intentid].tickUpper = params.tickUpper;
        intent[intentid].liquidityDelta = int128(params.liquidityDelta);
        emit queuedIntent(intentid);
        intentid += 1;
        return this.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        LiquidityIntent memory _liquidityIntent;

        _liquidityIntent.lp = sender;
        _liquidityIntent.poolKey = key;
        _liquidityIntent.action = actionType.Remove;
        _liquidityIntent.queueBlock = block.number;
        _liquidityIntent.executeAfterBlock =
            _liquidityIntent.queueBlock +
            delay_block;
        _liquidityIntent.expiryBlock = block.number + delay_block + gracePeriod;
        _liquidityIntent.isExecuted = false;
        intent[intentid] = _liquidityIntent;
        intent[intentid].tickLower = params.tickLower;
        intent[intentid].tickUpper = params.tickUpper;
        intent[intentid].liquidityDelta = int128(params.liquidityDelta);
        emit queuedIntent(intentid);
        intentid += 1;
        return this.beforeRemoveLiquidity.selector;
    }

    function queueIntentFee(
        uint256 fees,
        uint256 intentId
    ) public payable validIntent(intentId) {
        require(msg.sender == intent[intentId].lp);
        require(msg.value >= fees);
        intentFee[intentId] = fees;
    }

    function executeIntent(uint256 intentId) public validIntent(intentId) {
        require(!intent[intentId].isCancelled);
        require(intentFee[intentId] > 0, "No fee");
        require(msg.sender != intent[intentId].lp);

        if (intent[intentId].isExecuted == true) {
            revert();
        }
        uint256 current_block = block.number;
        if (current_block < intent[intentId].executeAfterBlock) {
            revert();
        }

        require(current_block <= intent[intentId].expiryBlock);

        IPoolManager.ModifyLiquidityParams memory tParams;
        int24 tLower = intent[intentId].tickLower;
        int24 tUpper = intent[intentId].tickUpper;
        int128 lDelta = intent[intentId].liquidityDelta;
        tParams.tickLower = tLower;
        tParams.tickUpper = tUpper;
        tParams.liquidityDelta = lDelta;

        if (intent[intentId].action == actionType.Add) {
            if (lDelta <= 0) {
                revert();
            }
        }

        if (intent[intentId].action == actionType.Remove) {
            if (lDelta >= 0) {
                revert();
            }
        }

        bytes memory hookData;
        hookData = abi.encode(msg.sender, intent[intentId].lp, intentId);

        poolManager.modifyLiquidity(
            intent[intentId].poolKey,
            tParams,
            hookData
        );
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        require(msg.sender == address(poolManager));
        (address executerAddress, address LPAddress, uint256 intentId) = abi
            .decode(hookData, (address, address, uint256));
        LiquidityIntent storage intentt = intent[intentId];

        require(!intentt.isExecuted);
        require(intentId < intentid);
        uint256 fees = intentFee[intentId];
        intentFee[intentId] = 0;
        rewards[executerAddress] += fees;
        intentt.isExecuted = true;

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
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        require(msg.sender == address(poolManager));
        (address executerAddress, address LPAddress, uint256 intentId) = abi
            .decode(hookData, (address, address, uint256));
        LiquidityIntent storage intentt = intent[intentId];

        require(intentId < intentid);

        require(!intentt.isExecuted);
        uint256 fees = intentFee[intentId];
        intentFee[intentId] = 0;
        rewards[executerAddress] += fees;
        intentt.isExecuted = true;

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
        return (this.afterRemoveLiquidity.selector, delta);
    }

    function withdraw(uint256 amount) external nonReentrant {
        amount = rewards[msg.sender];
        require(amount > 0);
        rewards[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    function refundAfterExpiry(
        uint256 intentId
    ) external nonReentrant validIntent(intentId) {
        LiquidityIntent storage i = intent[intentId];

        require(block.number > i.expiryBlock, "Not expired yet");
        require(!i.isExecuted, "Already executed");
        require(!i.isCancelled, "Already cancelled");

        uint256 fee = intentFee[intentId];
        require(fee > 0);

        intentFee[intentId] = 0;
        i.isCancelled = true;
        (bool ok, ) = i.lp.call{value: fee}("");
        require(ok, "Refund failed");
    }

    function cancelIntent(
        uint256 intentId
    ) external nonReentrant validIntent(intentId) {
        LiquidityIntent storage i = intent[intentId];
        require(msg.sender == i.lp);
        require(!i.isExecuted);
        require(!i.isCancelled);

        uint256 fee = intentFee[intentId];
        i.isCancelled = true;
        intentFee[intentId] = 0;

        if (fee > 0) {
            (bool ok, ) = i.lp.call{value: fee}("");
            require(ok, "Refund failed");
        }
    }

    function getHookPermissions()
        external
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false
            });
    }

    function beforeInitialize(
    address,
    PoolKey calldata,
    uint160
) external pure override returns (bytes4) {
    return this.beforeInitialize.selector;
}

function afterInitialize(
    address,
    PoolKey calldata,
    uint160,
    int24
) external pure override returns (bytes4) {
    return this.afterInitialize.selector;
}

function beforeSwap(
    address,
    PoolKey calldata,
    IPoolManager.SwapParams calldata,
    bytes calldata
) external pure override returns (bytes4) {
    return this.beforeSwap.selector;
}

function afterSwap(
    address,
    PoolKey calldata,
    IPoolManager.SwapParams calldata,
    BalanceDelta,
    bytes calldata
) external pure override returns (bytes4) {
    return this.afterSwap.selector;
}

function beforeDonate(
    address,
    PoolKey calldata,
    uint256,
    uint256,
    bytes calldata
) external pure override returns (bytes4) {
    return this.beforeDonate.selector;
}

function afterDonate(
    address,
    PoolKey calldata,
    uint256,
    uint256,
    bytes calldata
) external pure override returns (bytes4) {
    return this.afterDonate.selector;
}

receive() external payable {}
}
