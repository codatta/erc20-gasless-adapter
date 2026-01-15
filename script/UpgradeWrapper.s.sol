// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/WrapperUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title 升级脚本示例
 * @notice 此脚本演示如何升级 WrapperUpgradeable 合约
 * @dev 使用前请确保：
 * 1. 新的实现合约已经部署
 * 2. 调用者是当前合约的所有者
 * 3. 新实现合约通过了所有必要的测试
 */
contract UpgradeWrapper is Script {
    function run() public {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address newImplementation = vm.envAddress("NEW_IMPLEMENTATION_ADDRESS");
        
        vm.startBroadcast(deployer);
        
        WrapperUpgradeable wrapper = WrapperUpgradeable(proxyAddress);
        
        // 验证调用者是所有者
        require(wrapper.owner() == msg.sender, "Only owner can upgrade");
        
        console.log("Current implementation:", address(wrapper));
        console.log("Upgrading to:", newImplementation);
        
        // 执行升级
        wrapper.upgradeToAndCall(newImplementation, "");
        
        console.log("Upgrade completed successfully!");
        
        vm.stopBroadcast();
    }
}
