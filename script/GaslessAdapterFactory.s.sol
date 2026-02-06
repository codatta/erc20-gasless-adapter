// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {GaslessAdapterFactory} from "../src/GaslessAdapterFactory.sol";
import {console} from "forge-std/console.sol";

contract GaslessAdapterFactoryDeploy is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployer);
        GaslessAdapterFactory factory = new GaslessAdapterFactory();
        vm.stopBroadcast();

        console.log("GaslessAdapterFactory deployed at:", address(factory));
    }
}

