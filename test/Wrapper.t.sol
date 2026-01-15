// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Wrapper} from "../src/Wrapper.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrapperTest is Test {
    Wrapper public wrapper;
    MockERC20 public mockToken;
    
    address public owner = address(0x1);
    uint256 private user1PrivateKey = 0x2;
    address public user1 = vm.addr(user1PrivateKey);
    address public user2 = address(0x3);
    address public spender = address(0x4);
    
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_VERSION = "1";
    
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address account);
    event Unpaused(address account);
    
    function setUp() public {
        // 部署 Mock ERC20 代币
        mockToken = new MockERC20("Test Token", "TEST");
        
        // 部署 Wrapper 合约
        vm.prank(owner);
        wrapper = new Wrapper(TOKEN_NAME, TOKEN_VERSION, address(mockToken), owner);
        
        // 给用户一些代币
        mockToken.mint(user1, 1000 * 10**18);
        mockToken.mint(user2, 1000 * 10**18);
    }
    
    // ============ 部署测试 ============
    
    function test_Deployment() public view {
        assertEq(wrapper.realToken(), address(mockToken));
        assertEq(wrapper.owner(), owner);
        assertFalse(wrapper.paused());
        assertEq(wrapper.name(), "Wrapper Test Token");
        assertEq(wrapper.symbol(), "WTEST");
        assertEq(wrapper.decimals(), 18);
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
        
        // user1 没有授权
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Wrapper.UnderlyingInsufficientAllowance.selector,
                user1,
                0,
                amount
            )
        );
        wrapper.transfer(user2, amount);
    }
    
    function test_Transfer_WhenPaused() public {
        uint256 amount = 100 * 10**18;
        
        // user1 授权
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        // owner 暂停合约
        vm.prank(owner);
        wrapper.pause();
        
        // 尝试转账应该失败
        vm.prank(user1);
        vm.expectRevert();
        wrapper.transfer(user2, amount);
    }
    
    // ============ TransferFrom 测试 ============
    
    function test_TransferFrom_Success() public {
        uint256 amount = 100 * 10**18;
        
        // user1 授权给 spender
        vm.prank(user1);
        wrapper.approve(spender, amount);
        
        // user1 授权底层代币给 wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        // spender 代表 user1 转账
        vm.prank(spender);
        bool success = wrapper.transferFrom(user1, user2, amount);
        
        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), 0);
        assertEq(mockToken.balanceOf(user2), 1000 * 10**18 + amount);
    }
    
    function test_TransferFrom_InsufficientAllowance() public {
        uint256 amount = 100 * 10**18;
        
        // user1 没有授权给 spender
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                Wrapper.ERC20InsufficientAllowance.selector,
                spender,
                0,
                amount
            )
        );
        wrapper.transferFrom(user1, user2, amount);
    }
    
    // ============ Approve 测试 ============
    
    function test_Approve_Success() public {
        uint256 amount = 100 * 10**18;
        
        vm.prank(user1);
        bool success = wrapper.approve(spender, amount);
        
        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), amount);
    }
    
    function test_Approve_ZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Wrapper.ERC20InvalidSpender.selector, address(0))
        );
        wrapper.approve(address(0), 100 * 10**18);
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
        uint256 deadline = block.timestamp - 1; // 已过期
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
            abi.encodeWithSelector(Wrapper.ERC2612ExpiredSignature.selector, deadline)
        );
        wrapper.permit(user1, spender, amount, deadline, v, r, s);
    }
    
    // ============ EIP-3009 TransferWithAuthorization 测试 ============
    
    function test_TransferWithAuthorization_Success() public {
        uint256 amount = 100 * 10**18;
        uint256 validAfter = block.timestamp - 1; // 确保已经生效
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = keccak256("unique-nonce-1");
        
        // user1 授权底层代币给 wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);
        
        // 创建授权签名
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
        
        // 执行授权转账
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
    
    function test_TransferWithAuthorization_ReuseNonce() public {
        uint256 amount = 100 * 10**18;
        uint256 validAfter = block.timestamp - 1; // 确保已经生效
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = keccak256("unique-nonce-2");
        
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount * 2);
        
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
        
        // 第一次使用应该成功
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
        
        // 第二次使用相同 nonce 应该失败
        vm.expectRevert("FiatTokenV2: authorization is used or canceled");
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
    
    function test_Unpause_NotOwner() public {
        vm.prank(owner);
        wrapper.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        wrapper.unpause();
    }
    
    // ============ View 函数测试 ============
    
    function test_BalanceOf() public view {
        assertEq(wrapper.balanceOf(user1), 1000 * 10**18);
        assertEq(wrapper.balanceOf(user2), 1000 * 10**18);
    }
    
    function test_TotalSupply() public view {
        assertEq(wrapper.totalSupply(), mockToken.totalSupply());
    }
    
    function test_DomainSeparator() public view {
        bytes32 domainSeparator = wrapper.DOMAIN_SEPARATOR();
        assertNotEq(domainSeparator, bytes32(0));
    }
}
