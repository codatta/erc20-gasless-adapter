// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {GaslessAdapterBase} from "./GaslessAdapterBase.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StandardGaslessAdapter
 * @notice Standard implementation of a gasless adapter for any underlying ERC20 token.
 * @dev
 * - This is the standard adapter implementation deployed by {GaslessAdapterFactory}.
 * - Inherits {GaslessAdapterBase} to provide ERC2612 (permit) and ERC3009 (gasless transfer) functionality.
 * - Uses {Pausable} and {Ownable} to allow an owner to pause/unpause transfers.
 *
 * This contract can be used directly via the factory, or as a template for custom adapters.
 * Any standard IERC20 + IERC20Metadata token can be used as the underlying token.
 */
contract StandardGaslessAdapter is GaslessAdapterBase, Ownable, Pausable {
    /// @notice Address of the underlying ERC20 token that this adapter wraps.
    address public underlyingToken;

    /**
     * @notice Deploy a new gasless adapter for a specific underlying ERC20 token.
     * @param tokenName     EIP712 domain name used for ERC2612 / ERC3009 signatures (visible to wallets).
     * @param tokenVersion  EIP712 domain version string.
     * @param _underlyingToken Address of the underlying ERC20 token implementing IERC20 & IERC20Metadata.
     * @param initialOwner  Address that will receive ownership (can pause/unpause via {Pausable}).
     */
    constructor(
        string memory tokenName,
        string memory tokenVersion,
        address _underlyingToken,
        address initialOwner
    ) GaslessAdapterBase(tokenName, tokenVersion) Ownable(initialOwner) {
        require(_underlyingToken != address(0), "StandardGaslessAdapter: underlyingToken cannot be the zero address");
        require(initialOwner != address(0), "StandardGaslessAdapter: initialOwner cannot be the zero address");
        underlyingToken = _underlyingToken;
    }

    /**
     * @dev Returns the underlying token address. Required by {GaslessAdapterBase}.
     *      Any standard ERC20 can be used as the underlying implementation.
     */
    function _getUnderlyingToken() internal view override returns (address) {
        return underlyingToken;
    }

    /**
     * @dev Hook to check if transfers should be paused.
     *      This overrides the hook in {GaslessAdapterBase} and delegates to {Pausable}.
     */
    function _requireNotPaused() internal view override(GaslessAdapterBase, Pausable) {
        // Use Pausable's _requireNotPaused
        super._requireNotPaused();
    }

    /**
     * @notice Pause the contract, disabling transfer operations
     * @dev Only the owner can call this function
     *      After pausing, transfer, _transfer, transferWithAuthorization and receiveWithAuthorization functions will be unavailable
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract, enabling transfer operations
     * @dev Only the owner can call this function
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}

