// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {XNYAdapter} from "../src/XNYAdapter.sol";
import {GaslessAdapterBase} from "../src/GaslessAdapterBase.sol";
import {ERC2612} from "../src/ERC2612.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract WrapperTest is Test {
    XNYAdapter public wrapper;
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
        // Deploy Mock ERC20 token
        mockToken = new MockERC20("Test Token", "TEST");

        // Deploy XNYAdapter contract
        vm.prank(owner);
        wrapper = new XNYAdapter(TOKEN_NAME, TOKEN_VERSION, address(mockToken), owner);

        // Give users some tokens
        mockToken.mint(user1, 1000 * 10 ** 18);
        mockToken.mint(user2, 1000 * 10 ** 18);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(wrapper.realToken(), address(mockToken));
        assertEq(wrapper.owner(), owner);
        assertFalse(wrapper.paused());
        assertEq(wrapper.name(), "Wrapper Test Token");
        assertEq(wrapper.symbol(), "WTEST");
        assertEq(wrapper.decimals(), 18);
    }

    // ============ Transfer Tests ============

    function test_Transfer_Success() public {
        uint256 amount = 100 * 10 ** 18;

        // user1 approves wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);

        // user1 transfers to user2
        vm.prank(user1);
        bool success = wrapper.transfer(user2, amount);

        assertTrue(success);
        assertEq(mockToken.balanceOf(user2), 1000 * 10 ** 18 + amount);
    }

    function test_Transfer_InsufficientAllowance() public {
        uint256 amount = 100 * 10 ** 18;

        // user1 has not approved
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(GaslessAdapterBase.UnderlyingInsufficientAllowance.selector, user1, 0, amount)
        );
        assertFalse(wrapper.transfer(user2, amount), "Transfer should revert when insufficient allowance");
    }

    function test_Transfer_WhenPaused() public {
        uint256 amount = 100 * 10 ** 18;

        // user1 approves
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);

        // owner pauses contract
        vm.prank(owner);
        wrapper.pause();

        // transfer should fail
        vm.prank(user1);
        vm.expectRevert();
        assertFalse(wrapper.transfer(user2, amount), "Transfer should revert when paused");
    }

    // ============ TransferFrom Tests ============

    function test_TransferFrom_Success() public {
        uint256 amount = 100 * 10 ** 18;

        // user1 approves spender
        vm.prank(user1);
        wrapper.approve(spender, amount);

        // user1 approves underlying token to wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);

        // spender transfers on behalf of user1
        vm.prank(spender);
        bool success = wrapper.transferFrom(user1, user2, amount);

        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), 0);
        assertEq(mockToken.balanceOf(user2), 1000 * 10 ** 18 + amount);
    }

    function test_TransferFrom_InsufficientAllowance() public {
        uint256 amount = 100 * 10 ** 18;

        // user1 has not approved spender
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(GaslessAdapterBase.ERC20InsufficientAllowance.selector, spender, 0, amount)
        );
        assertFalse(wrapper.transferFrom(user1, user2, amount), "TransferFrom should revert");
    }

    // ============ Approve Tests ============

    function test_Approve_Success() public {
        uint256 amount = 100 * 10 ** 18;

        vm.prank(user1);
        bool success = wrapper.approve(spender, amount);

        assertTrue(success);
        assertEq(wrapper.allowance(user1, spender), amount);
    }

    function test_Approve_ZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GaslessAdapterBase.ERC20InvalidSpender.selector, address(0)));
        wrapper.approve(address(0), 100 * 10 ** 18);
    }

    // ============ Permit Tests ============

    function test_Permit_Success() public {
        uint256 amount = 100 * 10 ** 18;
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
        uint256 amount = 100 * 10 ** 18;
        uint256 deadline = block.timestamp - 1; // expired
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

        vm.expectRevert(abi.encodeWithSelector(ERC2612.ERC2612ExpiredSignature.selector, deadline));
        wrapper.permit(user1, spender, amount, deadline, v, r, s);
    }

    // ============ EIP-3009 TransferWithAuthorization Tests ============

    function test_TransferWithAuthorization_Success() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 validAfter = block.timestamp - 1; // ensure it's already valid
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = keccak256("unique-nonce-1");

        // user1 approves underlying token to wrapper
        vm.prank(user1);
        mockToken.approve(address(wrapper), amount);

        // create authorization signature
        bytes32 structHash = keccak256(
            abi.encode(
                wrapper.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(), user1, user2, amount, validAfter, validBefore, nonce
            )
        );

        bytes32 hash = wrapper.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hash, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // execute authorized transfer
        wrapper.transferWithAuthorization(user1, user2, amount, validAfter, validBefore, nonce, v, r, s);

        assertTrue(wrapper.authorizationState(user1, nonce));
        assertEq(mockToken.balanceOf(user2), 1000 * 10 ** 18 + amount);
    }

    function test_TransferWithAuthorization_ReuseNonce() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 validAfter = block.timestamp - 1; // ensure it's already valid
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = keccak256("unique-nonce-2");

        vm.prank(user1);
        mockToken.approve(address(wrapper), amount * 2);

        bytes32 structHash = keccak256(
            abi.encode(
                wrapper.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(), user1, user2, amount, validAfter, validBefore, nonce
            )
        );

        bytes32 hash = wrapper.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", hash, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // first use should succeed
        wrapper.transferWithAuthorization(user1, user2, amount, validAfter, validBefore, nonce, v, r, s);

        // second use with same nonce should fail
        vm.expectRevert("ERC3009: authorization is used or canceled");
        wrapper.transferWithAuthorization(user1, user2, amount, validAfter, validBefore, nonce, v, r, s);
    }

    // ============ Pause/Unpause Tests ============

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

    // ============ View Function Tests ============

    function test_BalanceOf() public view {
        assertEq(wrapper.balanceOf(user1), 1000 * 10 ** 18);
        assertEq(wrapper.balanceOf(user2), 1000 * 10 ** 18);
    }

    function test_TotalSupply() public view {
        assertEq(wrapper.totalSupply(), mockToken.totalSupply());
    }

    function test_DomainSeparator() public view {
        bytes32 domainSeparator = wrapper.DOMAIN_SEPARATOR();
        assertNotEq(domainSeparator, bytes32(0));
    }
}
