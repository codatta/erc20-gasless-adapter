// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Wrapper.sol";

contract WrapperDeploy is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenVersion = vm.envString("TOKEN_VERSION");
        address realToken = vm.envAddress("REAL_TOKEN_ADDRESS");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        
        vm.startBroadcast(deployer);
        Wrapper wrapper = new Wrapper(
            tokenName,
            tokenVersion,
            realToken,
            initialOwner
        );
     
        vm.stopBroadcast();
        console.log("Wrapper deployed at:", address(wrapper));
        console.log("Owner:", wrapper.owner());
    }
}
