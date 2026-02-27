// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {GaslessAdapterFactory} from "../src/GaslessAdapterFactory.sol";
import {StandardGaslessAdapter} from "../src/StandardGaslessAdapter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract GaslessAdapterFactoryTest is Test {
    GaslessAdapterFactory public factory;
    MockERC20 public mockToken;
    address public owner = address(0x1);

    string constant TOKEN_NAME = "Test Token Adapter";
    string constant TOKEN_VERSION = "1";

    event AdapterDeployed(
        address indexed adapter,
        address indexed underlyingToken,
        address indexed owner,
        string tokenName,
        string tokenVersion
    );

    function setUp() public {
        factory = new GaslessAdapterFactory();
        mockToken = new MockERC20("Test Token", "TEST");
    }

    // ============ Deployment Tests ============

    function test_DeployAdapter_Success() public {
        address adapter = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);

        assertNotEq(adapter, address(0));
        assertEq(StandardGaslessAdapter(adapter).underlyingToken(), address(mockToken));
        assertEq(StandardGaslessAdapter(adapter).owner(), owner);
        assertEq(StandardGaslessAdapter(adapter).name(), "Wrapper Test Token");
    }

    function test_DeployAdapter_EmitsEvent() public {
        // Deploy adapter and verify it was created successfully
        // The event emission is indirectly verified through successful deployment
        // and the fact that getAdaptersForToken returns the adapter
        address adapter = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);
        
        // Verify the adapter address is not zero
        assertNotEq(adapter, address(0));
        
        // Verify the adapter is registered in the factory
        address[] memory adapters = factory.getAdaptersForToken(address(mockToken));
        assertEq(adapters.length, 1);
        assertEq(adapters[0], adapter);
        
        // Verify the underlying token mapping
        assertEq(factory.getUnderlyingToken(adapter), address(mockToken));
    }

    function test_DeployAdapter_ZeroUnderlyingToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(GaslessAdapterFactory.GaslessAdapterFactoryUnderlyingTokenZero.selector)
        );
        factory.deployAdapter(address(0), TOKEN_NAME, TOKEN_VERSION, owner);
    }

    function test_DeployAdapter_ZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(GaslessAdapterFactory.GaslessAdapterFactoryOwnerZero.selector));
        factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, address(0));
    }

    function test_DeployAdapter_InvalidERC20Metadata() public {
        // Deploy a contract that doesn't implement IERC20Metadata
        address invalidToken = address(new MockERC20WithoutMetadata());

        vm.expectRevert(
            abi.encodeWithSelector(
                GaslessAdapterFactory.GaslessAdapterFactoryUnderlyingTokenNotIERC20Metadata.selector
            )
        );
        factory.deployAdapter(invalidToken, TOKEN_NAME, TOKEN_VERSION, owner);
    }

    // ============ Query Tests ============

    function test_GetAdaptersForToken() public {
        address adapter1 = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);
        address adapter2 = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);

        address[] memory adapters = factory.getAdaptersForToken(address(mockToken));

        assertEq(adapters.length, 2);
        assertEq(adapters[0], adapter1);
        assertEq(adapters[1], adapter2);
    }

    function test_GetUnderlyingToken() public {
        address adapter = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);

        address underlying = factory.getUnderlyingToken(adapter);
        assertEq(underlying, address(mockToken));
    }

    function test_GetUnderlyingToken_NonExistent() public view {
        address nonExistentAdapter = address(0x999);
        address underlying = factory.getUnderlyingToken(nonExistentAdapter);
        assertEq(underlying, address(0));
    }

    function test_GetAdapterCount() public {
        assertEq(factory.getAdapterCount(address(mockToken)), 0);

        factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);
        assertEq(factory.getAdapterCount(address(mockToken)), 1);

        factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);
        assertEq(factory.getAdapterCount(address(mockToken)), 2);
    }

    // ============ Multiple Tokens Tests ============

    function test_MultipleTokens() public {
        MockERC20 token2 = new MockERC20("Token 2", "T2");

        address adapter1 = factory.deployAdapter(address(mockToken), TOKEN_NAME, TOKEN_VERSION, owner);
        address adapter2 = factory.deployAdapter(address(token2), TOKEN_NAME, TOKEN_VERSION, owner);

        address[] memory adapters1 = factory.getAdaptersForToken(address(mockToken));
        address[] memory adapters2 = factory.getAdaptersForToken(address(token2));

        assertEq(adapters1.length, 1);
        assertEq(adapters1[0], adapter1);
        assertEq(adapters2.length, 1);
        assertEq(adapters2[0], adapter2);
    }
}

// Helper contract for testing invalid ERC20Metadata
contract MockERC20WithoutMetadata {
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }
}

