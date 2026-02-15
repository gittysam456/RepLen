pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/LPPrivacy.sol";

contract DeployTest is Test {
    function testDeploy() public {
        address fakeManager = address(0x1234);

        LPPrivacy lp = new LPPrivacy(
            IPoolManager (fakeManager),
            10,
            20
        );

        assert(address(lp) != address(0));
    }
}