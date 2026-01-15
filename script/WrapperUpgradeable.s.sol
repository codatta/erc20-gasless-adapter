// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/WrapperUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract WrapperUpgradeableDeploy is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        string memory tokenName = vm.envString("TOKEN_NAME");
        string memory tokenVersion = vm.envString("TOKEN_VERSION");
        address realToken = vm.envAddress("REAL_TOKEN_ADDRESS");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        
        vm.startBroadcast(deployer);
        
        // 1. 部署实现合约（不需要参数，因为使用 upgradeable 版本）
        WrapperUpgradeable implementation = new WrapperUpgradeable();
        
        console.log("Implementation deployed at:", address(implementation));
        
        // 2. 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            WrapperUpgradeable.initialize.selector,
            tokenName,
            tokenVersion,
            realToken,
            initialOwner
        );
        
        // 3. 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        console.log("Proxy deployed at:", address(proxy));
        
        // 4. 验证初始化
        WrapperUpgradeable wrapper = WrapperUpgradeable(address(proxy));
        require(wrapper.realToken() == realToken, "Real token not set correctly");
        require(wrapper.owner() == initialOwner, "Owner not set correctly");
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(implementation));
        console.log("Proxy:", address(proxy));
        console.log("Real Token:", realToken);
        console.log("Owner:", initialOwner);
    }
}
