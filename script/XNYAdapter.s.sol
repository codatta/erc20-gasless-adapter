// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {XNYAdapter} from "../src/XNYAdapter.sol";
import {console} from "forge-std/console.sol";

contract XNYAdapterDeploy is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenVersion = vm.envString("TOKEN_VERSION");
        address realToken = vm.envAddress("REAL_TOKEN_ADDRESS");
        address initialOwner = vm.envAddress("INITIAL_OWNER");

        vm.startBroadcast(deployer);
        XNYAdapter adapter = new XNYAdapter(tokenName, tokenVersion, realToken, initialOwner);

        vm.stopBroadcast();
        console.log("XNYAdapter deployed at:", address(adapter));
        console.log("Owner:", adapter.owner());
    }
}
