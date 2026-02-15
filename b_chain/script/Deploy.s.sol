//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/LPPrivacy.sol";
import "@V4-Core/src/interfaces/IPoolManager.sol";

contract Deploy is Script {
     function run() external {
        vm.startBroadcast();

       IPoolManager poolmanager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        uint256 delay = 20;
        uint256 grace = 100;

        LPPrivacy hook = new LPPrivacy(
            poolmanager,
            delay,   // delay blocks
            grace   // grace period
        );

        vm.stopBroadcast();

     }
}