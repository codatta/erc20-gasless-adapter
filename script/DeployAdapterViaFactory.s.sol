// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {GaslessAdapterFactory} from "../src/GaslessAdapterFactory.sol";
import {console} from "forge-std/console.sol";

/**
 * @notice Example script to deploy an adapter via factory
 * @dev Usage:
 *   forge script script/DeployAdapterViaFactory.s.sol:DeployAdapterViaFactory --rpc-url $RPC_URL --broadcast
 *   Environment variables:
 *     - PRIVATE_KEY: Deployer private key
 *     - FACTORY_ADDRESS: Factory contract address
 *     - UNDERLYING_TOKEN: Underlying ERC20 token address
 *     - TOKEN_NAME: EIP712 domain name
 *     - TOKEN_VERSION: EIP712 domain version
 *     - OWNER: Owner address for the adapter
 */
contract DeployAdapterViaFactory is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address underlyingToken = vm.envAddress("UNDERLYING_TOKEN");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenVersion = vm.envString("TOKEN_VERSION");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(deployer);
        GaslessAdapterFactory factory = GaslessAdapterFactory(factoryAddress);
        address adapter = factory.deployAdapter(underlyingToken, tokenName, tokenVersion, owner);
        vm.stopBroadcast();

        console.log("Adapter deployed at:", adapter);
        console.log("Underlying token:", underlyingToken);
        console.log("Owner:", owner);
    }
}

