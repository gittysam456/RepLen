//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/LPPrivacy.sol";

contract Deploy is Script {
     function run() external {
        vm.startBroadcast();

        IPoolManager manager =
            IPoolManager(address(0xdead)); // <-- set this

        LPPrivacy hook = new LPPrivacy(
            manager,
            20,   // delay blocks
            50    // grace period
        );

        vm.stopBroadcast();
     }
}