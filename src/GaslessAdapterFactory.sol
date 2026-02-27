// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {StandardGaslessAdapter} from "./StandardGaslessAdapter.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title GaslessAdapterFactory
 * @notice Factory contract for deploying standard gasless adapters for any ERC20 token.
 * @dev
 * Deploys {StandardGaslessAdapter} instances for any standard ERC20 token.
 *
 * Usage:
 * 1. Call {deployAdapter} with the underlying token address, EIP712 name/version, and owner.
 * 2. The factory returns the deployed adapter address.
 * 3. Use the adapter's ERC2612 (permit) and ERC3009 (gasless transfer) functions.
 */
contract GaslessAdapterFactory {
    /// @notice Emitted when a new adapter is deployed.
    event AdapterDeployed(
        address indexed adapter,
        address indexed underlyingToken,
        address indexed owner,
        string tokenName,
        string tokenVersion
    );

    /// @notice Mapping from underlying token address to array of deployed adapter addresses.
    mapping(address => address[]) private _adaptersByToken;

    /// @notice Mapping from adapter address to its underlying token address.
    mapping(address => address) private _underlyingTokenByAdapter;

    /**
     * @dev Error thrown when the underlying token address is zero.
     */
    error GaslessAdapterFactoryUnderlyingTokenZero();

    /**
     * @dev Error thrown when the adapter owner address is zero.
     */
    error GaslessAdapterFactoryOwnerZero();

    /**
     * @dev Error thrown when the underlying token does not implement IERC20Metadata.
     */
    error GaslessAdapterFactoryUnderlyingTokenNotIERC20Metadata();

    /**
     * @notice Deploy a new gasless adapter for an underlying ERC20 token.
     * @param underlyingToken Address of the underlying ERC20 token (must implement IERC20 & IERC20Metadata).
     * @param tokenName EIP712 domain name (e.g., "MyToken Adapter" or "MyToken").
     * @param tokenVersion EIP712 domain version (e.g., "1" or "1.0").
     * @param owner Address that will own the adapter (can pause/unpause transfers).
     * @return adapter The address of the newly deployed adapter.
     */
    function deployAdapter(
        address underlyingToken,
        string memory tokenName,
        string memory tokenVersion,
        address owner
    ) external returns (address adapter) {
        if (underlyingToken == address(0)) {
            revert GaslessAdapterFactoryUnderlyingTokenZero();
        }
        if (owner == address(0)) {
            revert GaslessAdapterFactoryOwnerZero();
        }

        // Verify that the underlying token implements IERC20Metadata
        // This will revert if the token doesn't have name(), symbol(), or decimals()
        try IERC20Metadata(underlyingToken).name() returns (string memory) {} catch {
            revert GaslessAdapterFactoryUnderlyingTokenNotIERC20Metadata();
        }
        try IERC20Metadata(underlyingToken).symbol() returns (string memory) {} catch {
            revert GaslessAdapterFactoryUnderlyingTokenNotIERC20Metadata();
        }
        try IERC20Metadata(underlyingToken).decimals() returns (uint8) {} catch {
            revert GaslessAdapterFactoryUnderlyingTokenNotIERC20Metadata();
        }

        // Deploy the standard adapter
        StandardGaslessAdapter newAdapter = new StandardGaslessAdapter(
            tokenName,
            tokenVersion,
            underlyingToken,
            owner
        );
        adapter = address(newAdapter);

        // Record the deployment
        _adaptersByToken[underlyingToken].push(adapter);
        _underlyingTokenByAdapter[adapter] = underlyingToken;

        emit AdapterDeployed(adapter, underlyingToken, owner, tokenName, tokenVersion);
    }

    /**
     * @notice Get all adapters deployed for a specific underlying token.
     * @param underlyingToken Address of the underlying ERC20 token.
     * @return Array of adapter addresses.
     */
    function getAdaptersForToken(address underlyingToken) external view returns (address[] memory) {
        return _adaptersByToken[underlyingToken];
    }

    /**
     * @notice Get the underlying token address for a given adapter.
     * @param adapter Address of the adapter.
     * @return The underlying token address, or address(0) if not found.
     */
    function getUnderlyingToken(address adapter) external view returns (address) {
        return _underlyingTokenByAdapter[adapter];
    }

    /**
     * @notice Get the number of adapters deployed for a specific underlying token.
     * @param underlyingToken Address of the underlying ERC20 token.
     * @return The number of adapters.
     */
    function getAdapterCount(address underlyingToken) external view returns (uint256) {
        return _adaptersByToken[underlyingToken].length;
    }
}

