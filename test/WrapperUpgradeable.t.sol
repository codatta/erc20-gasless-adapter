// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WrapperUpgradeable} from "../src/WrapperUpgradeable.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrapperUpgradeableTest is Test {
    WrapperUpgradeable public implementation;
    WrapperUpgradeable public wrapper;
    ERC1967Proxy public proxy;
    MockERC20 public mockToken;
    
    address public owner = address(0x1);
    uint256 private user1PrivateKey = 0x2;
    address public user1 = vm.addr(user1PrivateKey);
    address public user2 = address(0x3);
    address public spender = address(0x4);
    
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_VERSION = "1";
    
    event Upgraded(address indexed implementation);
    event Paused(address account);
    event Unpaused(address account);
    
    function setUp() public {
        // 部署 Mock ERC20 代币
        mockToken = new MockERC20("Test Token", "TEST");
        
        // 部署实现合约
        implementation = new WrapperUpgradeable();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            WrapperUpgradeable.initialize.selector,
            TOKEN_NAME,
            TOKEN_VERSION,
            address(mockToken),
            owner
        );
        
        // 部署代理合约
        proxy = new ERC1967Proxy(address(implementation), initData);
        wrapper = WrapperUpgradeable(address(proxy));
        
        // 给用户一些代币
        mockToken.mint(user1, 1000 * 10**18);
        mockToken.mint(user2, 1000 * 10**18);
    }
    
    // ============ 部署和初始化测试 ============
    
    function test_Deployment() public {
        assertEq(wrapper.realToken(), address(mockToken));
        assertEq(wrapper.owner(), owner);
        assertFalse(wrapper.paused());
        assertEq(wrapper.name(), "Wrapper Test Token");
        assertEq(wrapper.symbol(), "WTEST");
        assertEq(wrapper.decimals(), 18);
    }
    
    function test_Initialize_OnlyOnce() public {
        vm.expectRevert();
        wrapper.initialize(TOKEN_NAME, TOKEN_VERSION, address(mockToken), owner);
    }
    
    function test_Initialize_ZeroRealToken() public {
        WrapperUpgradeable newImpl = new WrapperUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            WrapperUpgradeable.initialize.selector,
            TOKEN_NAME,
            TOKEN_VERSION,
            address(0),
            owner
        );
        
        vm.expectRevert("ERC20X402Wrapper: realToken cannot be the zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }
    
    function test_Initialize_ZeroOwner() public {
        WrapperUpgradeable newImpl = new WrapperUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            WrapperUpgradeable.initialize.selector,
            TOKEN_NAME,
            TOKEN_VERSION,
            address(mockToken),
            address(0)
        );
        
        vm.expectRevert("ERC20X402Wrapper: initialOwner cannot be the zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }
    
    // ============ 升级测试 ============
    
    function test_Upgrade_Success() public {
        // 部署新实现
        WrapperUpgradeable newImplementation = new WrapperUpgradeable();
        
        // owner 升级合约
        vm.prank(owner);
        wrapper.upgradeToAndCall(address(newImplementation), "");
        
        // 验证升级成功（通过检查实现地址）
        // 注意：这里我们验证功能仍然正常
        assertEq(wrapper.realToken(), address(mockToken));
        assertEq(wrapper.owner(), owner);
    }
    
    function test_Upgrade_NotOwner() public {
        WrapperUpgradeable newImplementation = new WrapperUpgradeable();
        
        vm.prank(user1);
        vm.expectRevert();
        wrapper.upgradeToAndCall(address(newImplementation), "");
    }
    
    // ============ Transfer 测试 ============
    
    function test_Transfer_Success() public {
        uint256 amount = 100 * 10**18;
        
        // user1 授权给 wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        // user1 转账给 user2
        vm.prank(user1);
        bool success = wrapper.transfer(user2, amount);
        
        assertTrue(success);
        assertEq(mockToken.balanceOf(user2), 1000 * 10**18 + amount);
    }
    
    function test_Transfer_InsufficientAllowance() public {
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                WrapperUpgradeable.UnderlyingInsufficientAllowance.selector,
                user1,
                0,
                amount
            )
        );
        wrapper.transfer(user2, amount);
    }
    
    function test_Transfer_WhenPaused() public {
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        vm.prank(owner);
        wrapper.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        wrapper.transfer(user2, amount);
    }
    
    // ============ TransferFrom 测试 ============
    
    function test_TransferFrom_Success() public {
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        wrapper.approve(spender, amount);
        
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        vm.prank(spender);
        bool success = wrapper.transferFrom(user1, user2, amount);
        
        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), 0);
        assertEq(mockToken.balanceOf(user2), 1000 * 10**18 + amount);
    }
    
    // ============ Approve 测试 ============
    
    function test_Approve_Success() public {
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        bool success = wrapper.approve(spender, amount);
        
        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), amount);
    }
    
    // ============ Permit 测试 ============
    
    function test_Permit_Success() public {
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = wrapper.nonces(user1);
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user1,
                spender,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 hash = wrapper.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hash, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        
        wrapper.permit(user1, spender, amount, deadline, v, r, s);
        
        assertEq(wrapper.allowance(user1, spender), amount);
        assertEq(wrapper.nonces(user1), nonce + 1);
    }
    
    function test_Permit_ExpiredDeadline() public {
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = wrapper.nonces(user1);
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user1,
                spender,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 hash = wrapper.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hash, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        
        vm.expectRevert(
            abi.encodeWithSelector(WrapperUpgradeable.ERC2612ExpiredSignature.selector, deadline)
        );
        wrapper.permit(user1, spender, amount, deadline, v, r, s);
    }
    
    // ============ EIP-3009 TransferWithAuthorization 测试 ============
    
    function test_TransferWithAuthorization_Success() public {
        uint256 amount = 100 * 10**18;
        uint256 validAfter = block.timestamp - 1; // 确保已经生效
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = keccak256("unique-nonce-1");
        
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        bytes32 structHash = keccak256(
            abi.encode(
                wrapper.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(),
                user1,
                user2,
                amount,
                validAfter,
                validBefore,
                nonce
            )
        );
        
        bytes32 hash = wrapper.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hash, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        
        wrapper.transferWithAuthorization(
            user1,
            user2,
            amount,
            validAfter,
            validBefore,
            nonce,
            v,
            r,
            s
        );
        
        assertTrue(wrapper.authorizationState(user1, nonce));
        assertEq(mockToken.balanceOf(user2), 1000 * 10**18 + amount);
    }
    
    // ============ Pause/Unpause 测试 ============
    
    function test_Pause_OnlyOwner() public {
        vm.prank(owner);
        wrapper.pause();
        
        assertTrue(wrapper.paused());
    }
    
    function test_Pause_NotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        wrapper.pause();
    }
    
    function test_Unpause_Success() public {
        vm.prank(owner);
        wrapper.pause();
        
        assertTrue(wrapper.paused());
        
        vm.prank(owner);
        wrapper.unpause();
        
        assertFalse(wrapper.paused());
    }
    
    // ============ View 函数测试 ============
    
    function test_BalanceOf() public {
        assertEq(wrapper.balanceOf(user1), 1000 * 10**18);
        assertEq(wrapper.balanceOf(user2), 1000 * 10**18);
    }
    
    function test_TotalSupply() public {
        assertEq(wrapper.totalSupply(), mockToken.totalSupply());
    }
    
    function test_DomainSeparator() public {
        bytes32 domainSeparator = wrapper.DOMAIN_SEPARATOR();
        assertNotEq(domainSeparator, bytes32(0));
    }
    
    // ============ 升级后功能测试 ============
    
    function test_Upgrade_PreservesState() public {
        // 设置一些状态
        uint256 amount = 100 * 10**18;
        vm.prank(user1);
        wrapper.approve(spender, amount);
        
        // 升级
        WrapperUpgradeable newImplementation = new WrapperUpgradeable();
        vm.prank(owner);
        wrapper.upgradeToAndCall(address(newImplementation), "");
        
        // 验证状态保留
        assertEq(wrapper.allowance(user1, spender), amount);
        assertEq(wrapper.realToken(), address(mockToken));
        assertEq(wrapper.owner(), owner);
    }
}
